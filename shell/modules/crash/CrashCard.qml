import QtQuick
import qs.config
import qs.services
import qs.components

// Eine App ist abgestürzt (Gruppe aus Crashes): „Discord crashed“, Zeile mit Prozess/Signal/Uhrzeit/„3rd time today“,
// Knöpfe Restart (nur wenn die App nicht mehr läuft) · Details (klappt Stack-Anfang auf, dort „Open in terminal“) · Dismiss.
// Stürzte nur ein Kindprozess ab und die App läuft weiter, geht die Karte nach 30 s von selbst (nicht beim Überfahren).
Glass {
    id: card

    property string groupKey
    property bool isClosing: false
    signal finished()

    // Gruppe live lesen (bleibt in Crashes.groups, auch nach Dismiss). Kopie je rev, sonst meldet die Bindung
    // bei demselben Objekt keine Änderung und g.child/g.running blieben stehen
    readonly property var g: {
        Crashes.rev;
        return Object.assign({}, Crashes.byKey(groupKey) || {});
    }
    readonly property int today: {
        Crashes.rev;
        return Crashes.todayCount(groupKey);
    }
    readonly property bool running: !!g.running
    readonly property bool canRestart: !!g.canRestart && !running
    property bool expanded: false

    height: body.implicitHeight + 28
    opacity: 0
    strong: true
    border.color: g.child ? Theme.border : Qt.alpha(Theme.accent, 0.38)

    Component.onCompleted: if (!isClosing) enterAnim.start()
    onIsClosingChanged: {
        if (!isClosing)
            return;
        enterAnim.stop();
        if (opacity > 0)
            exitAnim.start();
        else
            card.finished();
    }

    ParallelAnimation {
        id: enterAnim
        NumberAnimation { target: card; property: "opacity"; to: 1; duration: Theme.slide; easing.type: Easing.OutCubic }
        NumberAnimation { target: slide; property: "y"; from: 8; to: 0; duration: Theme.slide; easing.type: Easing.OutCubic }
    }
    ParallelAnimation {
        id: exitAnim
        NumberAnimation { target: card; property: "opacity"; to: 0; duration: Theme.fade; easing.type: Easing.InCubic }
        NumberAnimation { target: slide; property: "y"; to: 6; duration: Theme.fade; easing.type: Easing.InCubic }
        onFinished: card.finished()
    }
    transform: Translate { id: slide }

    function ordinal(n: int): string {
        const s = n % 100 >= 11 && n % 100 <= 13 ? "th" : ({ 1: "st", 2: "nd", 3: "rd" })[n % 10] || "th";
        return n + s;
    }
    function meta(): string {
        const parts = [];
        if (g.child)
            parts.push(g.childType.charAt(0).toUpperCase() + g.childType.slice(1));
        if (g.sig)
            parts.push(g.sig);
        if (g.time)
            parts.push(Qt.formatTime(new Date(g.time), "HH:mm"));
        if (today > 1)
            parts.push(ordinal(today) + " time today");
        return parts.join("  ·  ");
    }
    function status(): string {
        if (g.child)
            return running ? "Only a " + g.childType + " – " + g.name + " is still running." : g.name + " has closed.";
        // Prozessname ohne App (CLI-Tool): andere Prozesse gleichen Namens sagen nichts
        return running && g.canRestart ? g.name + " is running again." : g.name + " has closed.";
    }
    // Stack-Anfang aus der Journal-Meldung: Kopf + die ersten Frames
    function trace(): string {
        const lines = String(g.message || "").split("\n").filter(l => l.trim() !== "" && !/^ELF object|^Module /.test(l));
        return lines.slice(0, 7).join("\n");
    }

    HoverHandler {
        id: hover
    }
    // Kindprozess, App läuft weiter: kein Grund, ewig stehen zu bleiben
    Timer {
        running: !card.isClosing && !!card.g.child && card.running && !hover.hovered && !card.expanded
        interval: 30000
        onTriggered: Crashes.dismiss(card.groupKey)
    }

    Row {
        id: body
        x: 16
        y: 14
        width: parent.width - 32
        spacing: 12

        // Symbol in sanfter Glut-Fläche (deckend getönt, kein Leuchten)
        Rectangle {
            width: 36
            height: 36
            radius: Theme.radiusSm
            color: card.g.child ? Theme.surfaceSunken : Theme.accentFill
            Icon {
                anchors.centerIn: parent
                name: card.g.child ? "report" : "bug_report"
                size: 20
                fill: true
                color: card.g.child ? Theme.textMuted : Theme.accentText
            }
        }

        Column {
            width: parent.width - 48
            spacing: 2

            Txt {
                width: parent.width
                text: card.meta()
                color: Theme.textFaint
                font.pixelSize: 12
                font.weight: Font.Normal
            }
            Txt {
                width: parent.width
                text: (card.g.name || "An app") + " crashed"
                font.pixelSize: 14
                font.weight: Font.DemiBold
            }
            Txt {
                width: parent.width
                text: card.status()
                color: Theme.textMuted
                font.pixelSize: 13
                font.weight: Font.Normal
            }

            Item {
                width: 1
                height: 6
                visible: card.expanded
            }
            // Details: Programm, PID, Anfang des Stack-Traces
            Rectangle {
                width: parent.width
                visible: card.expanded
                height: visible ? detailCol.implicitHeight + 20 : 0
                radius: Theme.radiusSm
                color: Theme.surfaceSunken
                border.width: 1
                border.color: Theme.border

                Column {
                    id: detailCol
                    x: 10
                    y: 10
                    width: parent.width - 20
                    spacing: 6

                    MonoTxt {
                        width: parent.width
                        text: String(card.g.exe || card.g.comm || "").replace(/^\/home\/[^\/]+/, "~") + "\nPID " + (card.g.pid || "?")
                        color: Theme.textMuted
                        font.pixelSize: 11
                        wrapMode: Text.WrapAnywhere
                        maximumLineCount: 3
                        elide: Text.ElideRight
                    }
                    MonoTxt {
                        width: parent.width
                        visible: text !== ""
                        text: card.trace()
                        color: Theme.textFaint
                        font.pixelSize: 11
                        wrapMode: Text.WrapAnywhere
                        maximumLineCount: 9
                        elide: Text.ElideRight
                    }
                    Txt {
                        text: "Open full report in terminal"
                        color: termArea.containsMouse ? Theme.text : Theme.accentText
                        font.pixelSize: 12
                        Behavior on color { ColorAnimation { duration: Theme.fade } }
                        MouseArea {
                            id: termArea
                            anchors.fill: parent
                            anchors.margins: -4
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Crashes.openDetails(card.groupKey)
                        }
                    }
                }
            }

            Row {
                topPadding: 8
                spacing: 8
                Button {
                    visible: card.canRestart
                    primary: true
                    icon: "restart_alt"
                    text: "Restart"
                    onClicked: Crashes.restart(card.groupKey)
                }
                Button {
                    icon: card.expanded ? "expand_less" : "expand_more"
                    text: "Details"
                    onClicked: card.expanded = !card.expanded
                }
                Button {
                    text: "Dismiss"
                    onClicked: Crashes.dismiss(card.groupKey)
                }
            }
        }
    }
}

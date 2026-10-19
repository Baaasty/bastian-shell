import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.config
import qs.services
import qs.components

// Nach der Ruhezeit einmal ein kleiner Hinweis „N while you were away“ (kein Popup-Sturm: die Meldungen liegen im Panel).
// Erscheint erst, wenn die Ruhezeit vorbei ist, der Rechner nicht gesperrt/ungenutzt ist, bleibt 12 s und zählt dann als gesehen.
// Klick schließt früher. Abschaltbar: quiet.summary = false in der Konfiguration.
Scope {
    id: root

    property bool shown: false
    property int count: 0
    property bool locked: false      // Sperrbildschirm aktiv (Lock.qml schreibt „locked“/„unlocked“)
    readonly property bool want: Notifs.summaryDue && !idle.isIdle && !locked

    onWantChanged: {
        if (want && !shown) {
            count = Notifs.missed;
            shown = true;
            hideTimer.restart();
        }
    }
    function done(): void {
        shown = false;
        hideTimer.stop();
        Notifs.ackSummary();
    }

    Timer {
        id: hideTimer
        interval: 12000
        onTriggered: root.done()
    }
    FileView {
        path: Quickshell.env("XDG_RUNTIME_DIR") + "/desktop-lock"
        blockLoading: true
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: root.locked = text().trim() === "locked"
        onLoadFailed: root.locked = false
    }
    IdleMonitor {
        id: idle
        timeout: 90
    }

    Variants {
        model: Config.mainScreens

        PanelWindow {
            id: win

            required property var modelData

            screen: modelData
            visible: root.shown || pill.opacity > 0
            anchors.bottom: true
            margins.bottom: 96
            implicitWidth: row.implicitWidth + 52
            implicitHeight: 48
            exclusionMode: ExclusionMode.Ignore
            color: "transparent"
            WlrLayershell.namespace: "dock"   // ohne Öffnen-Animation (wie das „Saved“-Pillchen der Notizen)
            WlrLayershell.layer: WlrLayer.Top
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

            Glass {
                id: pill
                anchors.fill: parent
                strong: true
                radius: height / 2
                opacity: root.shown ? 1 : 0
                scale: root.shown ? 1 : 0.96
                Behavior on opacity { NumberAnimation { duration: Theme.slide; easing.type: Easing.OutCubic } }
                Behavior on scale { NumberAnimation { duration: Theme.slide; easing.type: Easing.OutCubic } }

                Row {
                    id: row
                    anchors.centerIn: parent
                    spacing: 10
                    Icon {
                        anchors.verticalCenter: parent.verticalCenter
                        name: "notifications"
                        size: 18
                        color: Theme.accentText
                    }
                    Txt {
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.count + " while you were away"
                        color: Theme.text
                        font.weight: Font.Normal
                    }
                    Txt {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "· in the panel"
                        color: Theme.textFaint
                        font.pixelSize: 12
                        font.weight: Font.Normal
                    }
                }
                MouseArea {
                    anchors.fill: parent
                    enabled: root.shown
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.done()
                }
            }
        }
    }
}

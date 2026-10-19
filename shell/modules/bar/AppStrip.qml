import QtQuick
import Quickshell
import Quickshell.Widgets
import qs.config
import qs.services
import qs.components

// Schlanke Taskleiste: offene Apps des aktuellen Desktops als kleine Icons (Quelle: Hyprland).
// Klick = aktivieren (aktive App: minimieren), Mittelklick = schließen. Mehrere Fenster = Zahl.
Row {
    id: strip

    // unten (Arbeitsplatz-Leiste): Namen über dem Icon zeigen
    property bool tipAbove: false

    spacing: 6

    // 0 = unbegrenzt; sonst schrumpfen die Kacheln, damit alle Apps in diese Breite passen
    property real maxWidth: 0
    readonly property real tileW: maxWidth > 0 && apps.length > 0
        ? Math.max(30, Math.min(60, (maxWidth - spacing * (apps.length - 1)) / apps.length)) : 60

    // App-IDs in Startreihenfolge; nur neu gesetzt, wenn sich die Menge ändert (Delegaten bleiben stehen)
    property var apps: []
    function collect(): void {
        const out = [];
        for (const t of Hypr.toplevels.values) {
            const id = Hypr.appId(t);
            if (id && Hypr.usable(t) && Hypr.deskOf(t) === Hypr.currentDesk && !out.includes(id))
                out.push(id);
        }
        if (out.join("\n") !== apps.join("\n"))
            apps = out;
    }
    Connections {
        target: Hypr
        function onVersionChanged() { strip.collect(); }
    }
    Component.onCompleted: collect()

    Repeater {
        model: strip.apps

        Rectangle {
            id: app

            required property string modelData
            // Fenster dieser App auf dem aktuellen Desktop (zuletzt benutztes zuerst)
            readonly property var wins: {
                Hypr.version;
                return Hypr.toplevels.values.filter(t => Hypr.appId(t) === modelData && Hypr.usable(t) && Hypr.deskOf(t) === Hypr.currentDesk)
                    .sort((a, b) => Hypr.stacking(b) - Hypr.stacking(a));
            }
            readonly property var first: wins[0] ?? null
            readonly property bool isActive: { Hypr.version; return wins.some(t => Hypr.isActive(t)); }
            readonly property bool attention: { Hypr.version; return wins.some(t => Hypr.isUrgent(t)); }
            readonly property bool allMinimized: wins.length > 0 && wins.every(t => Hypr.isMinimized(t))
            readonly property int windows: Math.max(1, wins.length)

            // Spotify/Discord sind Einbettungen, keine Taskleisten-Apps
            readonly property bool parked: Parked.isParked(modelData)
            visible: !parked
            width: parked ? 0 : strip.tileW
            height: 60
            radius: Theme.radiusMd
            // ruhige deckende Kachel; aktive App: Akzent-Tönung + Rahmen; Hover heller, Pressed dunkler
            color: isActive ? (area.pressed ? Theme.surfaceSunken : Theme.accentFill)
                : area.pressed ? Theme.surfaceSunken : area.containsMouse ? Qt.lighter(Theme.surfaceRaised, 1.18) : Theme.surfaceRaised
            border.width: isActive ? 2 : 1
            border.color: isActive ? Theme.accent : area.containsMouse ? Theme.borderStrong : Theme.border
            Behavior on color { ColorAnimation { duration: Theme.fade } }

            IconImage {
                anchors.centerIn: parent
                implicitSize: Math.min(38, strip.tileW - 12)
                source: app.first ? Hypr.iconPath(app.first) : ""
                opacity: app.allMinimized ? 0.45 : 1
            }

            // aktive App: Glut-Punkt, Aufmerksamkeit: Amber
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 4
                width: app.isActive ? Math.min(20, strip.tileW - 16) : 8
                height: 5
                radius: 2.5
                visible: app.isActive || app.attention
                color: app.attention ? Theme.warning : Theme.accent
                Behavior on width { NumberAnimation { duration: Theme.fade; easing.type: Easing.OutCubic } }
            }

            // Anzahl Fenster
            Rectangle {
                visible: app.windows > 1
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 2
                width: 22
                height: 22
                radius: 11
                color: Theme.accent
                MonoTxt {
                    anchors.centerIn: parent
                    text: app.windows
                    font.pixelSize: 14
                    font.weight: Font.Bold
                    color: Theme.onAccent
                }
            }

            // mehrere Fenster: Klick holt das nächste (reihum)
            MouseArea {
                id: area
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                cursorShape: Qt.PointingHandCursor
                onClicked: mouse => {
                    if (!app.first)
                        return;
                    if (mouse.button === Qt.MiddleButton) {
                        for (const t of app.wins)
                            Hypr.close(t);
                    } else if (app.isActive && app.windows === 1) {
                        Hypr.minimize(app.first);
                    } else if (app.windows > 1 && app.isActive) {
                        // aktives Fenster ist vorne (stacking): das nächste nehmen
                        Hypr.activate(app.wins[1]);
                    } else {
                        Hypr.activate(app.first);
                    }
                }
            }

            // Name beim Überfahren
            Rectangle {
                visible: area.containsMouse
                y: strip.tipAbove ? -height - 14 : parent.height + 10
                anchors.horizontalCenter: parent.horizontalCenter
                width: tip.width + 22
                height: 40
                radius: Theme.radiusSm
                color: Theme.surfaceRaised
                border.width: 1
                border.color: Theme.borderStrong
                z: 30
                Txt {
                    id: tip
                    anchors.centerIn: parent
                    width: Math.min(implicitWidth, 360)
                    elide: Text.ElideRight
                    // ein Fenster: sein Titel, mehrere: Name der App (wie die Gruppe in KWins Taskleiste)
                    text: {
                        Hypr.version;
                        if (!app.first)
                            return "";
                        if (app.windows === 1)
                            return Hypr.title(app.first);
                        const e = DesktopEntries.byId(app.modelData) ?? DesktopEntries.heuristicLookup(app.modelData);
                        return e?.name || app.modelData;
                    }
                    font.pixelSize: 17
                }
            }
        }
    }
}

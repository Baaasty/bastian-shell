import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.config
import qs.services
import qs.components

// Power-Menü (Meta+Esc): fünf Kacheln mit Tastenbuchstaben, Fokus startet auf "Sperren"
Scope {
    id: root

    property bool open: false
    property int selected: 0
    property bool dryRun: false   // Testmodus: Aktion nur ins Log
    property int pending: -1

    readonly property var actions: [
        // scripts/lock: Quickshell-Sperre unter Hyprland (ohne Shell hyprlock), unter KWin loginctl lock-session
        { key: "L", icon: "lock", label: "Lock", cmd: [Quickshell.shellDir + "/../scripts/lock", "now"] },
        // Hyprland: Abmelden über uwsm (falls die Sitzung damit läuft), sonst Hyprland direkt beenden
        { key: "O", icon: "logout", label: "Log Out", cmd: ["sh", "-c", "if command -v uwsm >/dev/null && uwsm check is-active >/dev/null 2>&1; then exec uwsm stop; else exec hyprctl dispatch exit; fi"] },
        { key: "S", icon: "bedtime", label: "Sleep", cmd: ["systemctl", "suspend"] },
        { key: "R", icon: "restart_alt", label: "Restart", cmd: ["systemctl", "reboot"] },
        { key: "P", icon: "power_settings_new", label: "Power Off", cmd: ["systemctl", "poweroff"] }
    ]
    readonly property int tile: Theme.layout.powerTile || 168
    readonly property var dimPower: (Theme.data.glass && Theme.data.glass.dimPower) || ({})
    readonly property int focusLeft: Math.ceil(Focus.remaining / 60000)

    function toggle(): void {
        open = !open;
        if (open)
            selected = 0;
    }
    // Testmodus endet mit dem Schließen (außer eine Aktion wartet noch)
    onOpenChanged: if (!open && pending < 0) dryRun = false

    // erst schließen, dann ausführen (sonst liegt das Menü über dem Sperrbildschirm)
    function run(i: int): void {
        if (i < 0 || i >= actions.length)
            return;
        pending = i;
        open = false;
        later.restart();
    }

    Timer {
        id: later
        interval: Theme.fade
        onTriggered: {
            const a = root.actions[root.pending];
            root.pending = -1;
            if (!a)
                return;
            if (root.dryRun)
                console.warn("power (Test): " + a.cmd.join(" "));
            else
                Quickshell.execDetached(a.cmd);
            root.dryRun = false;
        }
    }

    IpcHandler {
        target: "power"

        function toggle(): void {
            root.toggle();
        }
        // zum Testen: öffnet das Menü, Aktionen werden nur geloggt
        function test(): void {
            if (!root.open)
                root.toggle();
            root.dryRun = true;
        }
    }

    Variants {
        model: Config.mainScreens

        PanelWindow {
            id: win

            required property var modelData

            screen: modelData
            visible: root.open
            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }
            exclusionMode: ExclusionMode.Ignore
            color: "transparent"
            WlrLayershell.namespace: "dock" // "dock": ohne Öffnen-Animation (Hyprland: layerrule noanim)
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: root.open ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

            // ganzer Bildschirm unscharf
            BackgroundEffect.blurRegion: Region {
                Region { x: 0; y: 0; width: 1; height: 1 }
                Region { item: backdrop }
            }

            onVisibleChanged: if (visible) keys.forceActiveFocus()

            Rectangle {
                id: backdrop
                anchors.fill: parent
                color: Qt.alpha(Theme.dim, root.dimPower.opacity || 0.55)
                opacity: root.open ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: Theme.fade; easing.type: Easing.OutCubic } }

                // Klick daneben schließt
                MouseArea {
                    anchors.fill: parent
                    onClicked: root.open = false
                }
            }

            Item {
                id: keys
                anchors.fill: parent
                focus: true
                opacity: root.open ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: Theme.fade; easing.type: Easing.OutCubic } }

                Keys.onEscapePressed: root.open = false
                Keys.onLeftPressed: root.selected = Math.max(0, root.selected - 1)
                Keys.onRightPressed: root.selected = Math.min(root.actions.length - 1, root.selected + 1)
                Keys.onReturnPressed: root.run(root.selected)
                Keys.onEnterPressed: root.run(root.selected)
                Keys.onPressed: event => {
                    if (event.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier))
                        return;
                    // Buchstabe wählt aus, Enter führt aus – nur Sperren (L) geht sofort
                    const i = root.actions.findIndex(a => a.key === event.text.toUpperCase());
                    if (i >= 0) {
                        if (root.actions[i].key === "L")
                            root.run(i);
                        else
                            root.selected = i;
                        event.accepted = true;
                    }
                }

                Column {
                    anchors.centerIn: parent
                    spacing: 28

                    Txt {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "See you later, Bastian"
                        font.pixelSize: 24
                        font.weight: Font.DemiBold
                    }

                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 20

                        Repeater {
                            model: root.actions

                            Glass {
                                id: tileItem

                                required property var modelData
                                required property int index
                                readonly property bool on: root.selected === index

                                width: root.tile
                                height: root.tile
                                radius: Theme.radiusXl

                                // Fokus-Ring außen (2 px Glut)
                                Rectangle {
                                    anchors.fill: parent
                                    anchors.margins: -2
                                    radius: parent.radius + 2
                                    color: "transparent"
                                    border.width: 2
                                    border.color: Theme.accent
                                    visible: tileItem.on
                                }

                                // Tastenbuchstabe: dieselbe Kappe wie überall
                                KeyCap {
                                    anchors.top: parent.top
                                    anchors.topMargin: 12
                                    anchors.right: parent.right
                                    anchors.rightMargin: 14
                                    main: true
                                    label: tileItem.modelData.key
                                }

                                Column {
                                    anchors.centerIn: parent
                                    spacing: 16

                                    Icon {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        name: tileItem.modelData.icon
                                        size: 34
                                        color: tileItem.on ? Theme.accentText : Theme.text
                                    }
                                    Txt {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: tileItem.modelData.label
                                        font.pixelSize: Theme.fontMd
                                    }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onEntered: root.selected = tileItem.index
                                    onClicked: root.run(tileItem.index)
                                }
                            }
                        }
                    }

                    // Hinweis bei laufendem Fokus-Block
                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        visible: Focus.mode === "focus"
                        width: warnRow.implicitWidth + 32
                        height: warnRow.implicitHeight + 20
                        radius: Theme.radiusMd
                        color: Theme.col(Theme.t.warningSoft, Qt.alpha(Theme.warning, 0.16))

                        Row {
                            id: warnRow
                            anchors.centerIn: parent
                            spacing: 10
                            Icon {
                                anchors.verticalCenter: parent.verticalCenter
                                name: "timer"
                                size: 18
                                color: Theme.warning
                            }
                            Txt {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "Focus block still running · " + root.focusLeft + " min left"
                                color: Theme.warning
                                font.pixelSize: Theme.fontMd
                                font.weight: Font.Normal
                            }
                        }
                    }

                    KeyHintRow {
                        anchors.horizontalCenter: parent.horizontalCenter
                        hints: [["←→", "choose"], ["Enter", "run"], ["Esc", "close"]]
                    }
                }
            }
        }
    }
}

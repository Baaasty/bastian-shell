pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.config
import qs.services

// Kamin-Idle: nach Leerlauf ein ruhiger Kamin-Bildschirm auf dem Hauptmonitor, auf den anderen Monitoren dunkel.
// hypridle → scripts/idle show|hide → IPC „fireplace“ (hypr/hypridle.conf). Doku: docs/IDLE.md
// KEINE Sperre: gesperrt wird weiter von der Lock-Kette (scripts/lock, Lock.qml). Die Sperre liegt über diesem Fenster.
// Jede Taste/Mausbewegung beendet es: hypridle ruft beim Resume „hide“, zusätzlich beendet jede Mausbewegung
// auf dem Kamin es selbst (falls hypridle nicht läuft). Fenster gibt es nur, solange der Kamin sichtbar ist.
Scope {
    id: root

    readonly property bool supported: !!Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE")
    property bool shown: false

    function show(force: bool): string {
        if (!supported)
            return "unsupported";
        // Fokus-Block: Lesen/Denken am Bildschirm nicht stören (wie das Dimmen)
        if (!force && Focus.active)
            return "skip";
        shown = true;
        return "ok";
    }
    function hide(): void {
        shown = false;
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: win

            required property var modelData
            // Config.mainScreen fällt schon auf den ersten Monitor zurück, wenn DP-2 fehlt
            readonly property bool isMain: modelData.name === Config.mainScreen
            // 0 → 1 beim Einblenden (langsam), schnell wieder weg
            property real level: root.shown ? 1 : 0
            property bool armed: false

            screen: modelData
            visible: root.shown || level > 0
            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }
            exclusionMode: ExclusionMode.Ignore
            color: "transparent"
            WlrLayershell.namespace: "desktop-fireplace"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

            Behavior on level { NumberAnimation { duration: root.shown ? 1400 : 220; easing.type: Easing.OutCubic } }

            // erst kurz nach dem Einblenden auf die Maus hören (Zeiger „betritt“ das Fenster)
            Timer {
                id: arm
                interval: 1500
                onTriggered: win.armed = true
            }
            Connections {
                target: root
                function onShownChanged() {
                    win.armed = false;
                    if (root.shown)
                        arm.restart();
                }
            }

            Item {
                anchors.fill: parent
                opacity: win.level

                Rectangle {
                    anchors.fill: parent
                    visible: !win.isMain
                    color: Qt.darker(Theme.bgBottom, 1.8)
                }
                Loader {
                    anchors.fill: parent
                    active: win.isMain && win.visible
                    sourceComponent: Fireplace {
                        active: root.shown
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.BlankCursor
                    acceptedButtons: Qt.AllButtons
                    onPositionChanged: if (win.armed) root.hide()
                    onPressed: root.hide()
                    onWheel: root.hide()
                }
            }
        }
    }

    // qs ipc --any-display -p ~/Workspace/bastian-shell/shell call fireplace on false
    IpcHandler {
        target: "fireplace"

        // Achtung: „show“ als Funktionsname geht nicht (kollidiert mit dem Unterbefehl „qs ipc show“)
        function on(force: bool): string {
            return root.show(force);
        }
        function off(): void {
            root.hide();
        }
        function toggle(): string {
            if (root.shown) {
                root.hide();
                return "hidden";
            }
            return root.show(true);
        }
        function status(): string {
            return root.shown ? "shown" : "hidden";
        }
    }
}

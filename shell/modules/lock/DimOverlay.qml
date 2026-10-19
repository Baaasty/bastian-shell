pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config

// Leerlauf-Dimmen (statt PowerDevil, das die Monitore per DDC/CI dunkler stellte): warmes Fast-Schwarz
// über allen Monitoren, klickdurchlässig. hypridle → scripts/lock dim/undim → IPC „idle“ (Lock.qml).
// Fenster gibt es nur, solange gedimmt wird (kein Dauer-Zeichnen).
Scope {
    id: root

    property bool dimmed: false
    // Plasma dimmt auf 30 %: 0,7 Abdeckung
    readonly property real strength: 0.7

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: win

            required property var modelData

            screen: modelData
            visible: root.dimmed || shade.opacity > 0
            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }
            exclusionMode: ExclusionMode.Ignore
            color: "transparent"
            WlrLayershell.namespace: "desktop-dim"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            // leere Maske: Klicks gehen durch
            mask: Region {}

            Rectangle {
                id: shade
                anchors.fill: parent
                color: Qt.alpha(Theme.dim, 1)
                opacity: root.dimmed ? root.strength : 0
                // langsam dunkler, sofort wieder hell
                Behavior on opacity { NumberAnimation { duration: root.dimmed ? 1000 : Theme.fade; easing.type: Easing.OutCubic } }
            }
        }
    }
}

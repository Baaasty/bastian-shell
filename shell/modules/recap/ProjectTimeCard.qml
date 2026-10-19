import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.config
import qs.services
import qs.components
import qs.modules.dashboard

// Wochen-Übersicht „Zeit pro Projekt“ als eigene Karte (IPC projecttime open|toggle, Super+Alt+T):
// dieselbe Kachel wie im Dashboard, mittig über abgedunkeltem Grund. Esc oder Klick daneben schließt.
Scope {
    id: root

    property string screenName: Config.mainScreen

    Connections {
        target: ProjectTime
        function onOpenChanged() {
            if (ProjectTime.open)
                root.screenName = Hyprland.focusedMonitor?.name ?? Config.mainScreen;
        }
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: win

            required property var modelData

            screen: modelData
            visible: ProjectTime.open && modelData.name === root.screenName
            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }
            exclusionMode: ExclusionMode.Ignore
            color: "transparent"
            WlrLayershell.namespace: "dock"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

            onVisibleChanged: if (visible) keys.forceActiveFocus()

            Rectangle {
                anchors.fill: parent
                color: Qt.alpha(Theme.dim, 0.45)
                opacity: win.visible ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: Theme.fade; easing.type: Easing.OutCubic } }
                MouseArea {
                    anchors.fill: parent
                    onClicked: ProjectTime.open = false
                }
            }

            FocusScope {
                id: keys
                anchors.fill: parent
                focus: true
                Keys.onPressed: event => {
                    if (event.key === Qt.Key_Escape) {
                        ProjectTime.open = false;
                        event.accepted = true;
                    } else if (event.key === Qt.Key_Left) {
                        ProjectTime.shiftWeek(-1);
                        event.accepted = true;
                    } else if (event.key === Qt.Key_Right) {
                        ProjectTime.shiftWeek(1);
                        event.accepted = true;
                    }
                }
            }

            ProjectTimeTile {
                strong: true
                radius: Theme.radiusXl
                width: 560
                height: 420
                x: (parent.width - width) / 2
                y: Math.round((parent.height - height) * 0.3)
                opacity: win.visible ? 1 : 0
                scale: win.visible ? 1 : 0.97
                Behavior on opacity { NumberAnimation { duration: Theme.slide; easing.type: Easing.OutCubic } }
                Behavior on scale { NumberAnimation { duration: Theme.slide; easing.type: Easing.OutCubic } }
            }
        }
    }
}

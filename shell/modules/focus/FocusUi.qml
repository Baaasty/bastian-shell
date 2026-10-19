import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.services
import qs.components

// Fokus-Fenster: Aufgabe eingeben, Pausen-Banner (alles nur auf dem Hauptmonitor).
// Hyperfokus-Wecker: eigenes Modul modules/breaks (services/Breaks.qml)
Scope {
    Variants {
        model: Config.mainScreens

        Scope {
            id: scr

            required property var modelData

            // ---------- Eingabe (Aufgabe, Desktop-Name …) ----------
            PanelWindow {
                id: editor

                screen: scr.modelData
                visible: Prompt.open
                anchors {
                    top: Prompt.where === "top"
                    bottom: Prompt.where === "bottom"
                    left: true
                }
                margins {
                    top: Theme.barMargin + Theme.barHeight + 8
                    // über der Arbeitsplatz-Leiste (bis 52 px hoch)
                    bottom: Theme.barMargin + 52 + 8
                    left: Theme.barMargin
                }
                implicitWidth: 560
                implicitHeight: 64
                exclusionMode: ExclusionMode.Ignore
                color: "transparent"
                WlrLayershell.namespace: "dock" // "dock": ohne Öffnen-Animation (Hyprland: layerrule noanim)
                WlrLayershell.layer: WlrLayer.Overlay
                WlrLayershell.keyboardFocus: Prompt.open ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

                BackgroundEffect.blurRegion: Region {
                    Region { x: 0; y: 0; width: 1; height: 1 }
                    Region { item: box; radius: Theme.radiusMd }
                }

                onVisibleChanged: if (visible) {
                    input.text = Prompt.initial;
                    input.selectAll();
                    input.forceActiveFocus();
                }

                Glass {
                    id: box
                    anchors.fill: parent
                    anchors.margins: 4
                    strong: true
                    radius: Theme.radiusMd
                    border.color: Theme.accent

                    Icon {
                        id: promptIcon
                        anchors.left: parent.left
                        anchors.leftMargin: 16
                        anchors.verticalCenter: parent.verticalCenter
                        name: Prompt.icon
                        size: 18
                        color: Theme.accentText
                    }
                    TextInput {
                        id: input
                        anchors.left: promptIcon.right
                        anchors.leftMargin: 12
                        anchors.right: parent.right
                        anchors.rightMargin: 16
                        anchors.verticalCenter: parent.verticalCenter
                        color: Theme.text
                        selectionColor: Theme.accentSoft
                        selectedTextColor: Theme.text
                        font.family: Theme.fontUi
                        font.pixelSize: 16
                        clip: true
                        Keys.onReturnPressed: Prompt.accept(text)
                        Keys.onEnterPressed: Prompt.accept(text)
                        Keys.onEscapePressed: Prompt.cancel()
                        onActiveFocusChanged: if (!activeFocus && Prompt.open) closeLater.start()

                        Txt {
                            anchors.fill: parent
                            visible: input.text === ""
                            text: Prompt.placeholder
                            color: Theme.textFaint
                            font.pixelSize: 16
                            font.weight: Font.Normal
                        }
                    }
                }

                Timer {
                    id: closeLater
                    interval: 150
                    onTriggered: if (!input.activeFocus) Prompt.cancel()
                }
            }

            // ---------- Pausen-Banner unter der Bar ----------
            PanelWindow {
                screen: scr.modelData
                visible: Focus.breakDue
                anchors.top: true
                margins.top: Theme.barMargin + Theme.barHeight + 8
                implicitWidth: 660
                implicitHeight: 60
                exclusionMode: ExclusionMode.Ignore
                color: "transparent"
                WlrLayershell.namespace: "dock" // "dock": ohne Öffnen-Animation (Hyprland: layerrule noanim)
                WlrLayershell.layer: WlrLayer.Top

                BackgroundEffect.blurRegion: Region {
                    Region { x: 0; y: 0; width: 1; height: 1 }
                    Region { item: banner; radius: Theme.radiusMd }
                }

                Glass {
                    id: banner
                    anchors.fill: parent
                    anchors.margins: 4
                    strong: true
                    radius: Theme.radiusMd

                    Row {
                        anchors.left: parent.left
                        anchors.leftMargin: 16
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 12
                        Icon {
                            anchors.verticalCenter: parent.verticalCenter
                            name: "check_circle"
                            size: 20
                            color: Theme.success
                        }
                        Txt {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Block done. Take a " + Focus.breakMin + "-minute break?"
                            font.pixelSize: 14
                        }
                    }
                    Row {
                        anchors.right: parent.right
                        anchors.rightMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 8
                        Button {
                            primary: true
                            text: "Start Break"
                            onClicked: Focus.startBreak()
                        }
                        Button {
                            text: "Keep Going"
                            onClicked: Focus.start()
                        }
                    }
                }
            }
        }
    }
}

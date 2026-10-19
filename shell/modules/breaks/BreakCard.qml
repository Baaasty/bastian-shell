import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.services
import qs.components

// Hyperfokus-Wecker: ruhige Karte oben mittig unter der Bar (Hauptmonitor), Logik in services/Breaks.qml.
// Keine Tastatur (kein Fokusklau), klickbar ist nur die Karte. Steht das Pausen-Banner des Fokus-Timers
// dort schon, rutscht die Karte darunter. Doku: docs/BREAKS.md
Scope {
    Variants {
        model: Config.mainScreens

        PanelWindow {
            id: win

            required property var modelData

            screen: modelData
            visible: Breaks.shown || card.opacity > 0
            anchors.top: true
            margins.top: Theme.barMargin + Theme.barHeight + Theme.windowGap + (Focus.breakDue ? 60 + Theme.windowGap : 0)
            implicitWidth: card.width + Theme.barMargin * 2
            implicitHeight: card.height + Theme.barMargin
            exclusionMode: ExclusionMode.Ignore
            color: "transparent"
            WlrLayershell.namespace: "dock"   // ohne Öffnen-Animation des Compositors, die Karte blendet selbst ein
            WlrLayershell.layer: WlrLayer.Top
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

            mask: Region {
                item: card
            }
            BackgroundEffect.blurRegion: Region {
                Region { x: 0; y: 0; width: 1; height: 1 }
                Region { item: card; radius: Theme.radiusLg }
            }

            Glass {
                id: card

                x: Theme.barMargin
                width: 420
                height: body.implicitHeight + 28
                strong: true
                radius: Theme.radiusLg
                border.color: Qt.alpha(Theme.accent, 0.38)
                opacity: Breaks.shown ? 1 : 0
                transform: Translate {
                    y: Breaks.shown ? 0 : -8
                    Behavior on y { NumberAnimation { duration: Theme.slide; easing.type: Easing.OutCubic } }
                }
                Behavior on opacity { NumberAnimation { duration: Theme.slide; easing.type: Easing.OutCubic } }

                Column {
                    id: body
                    x: 16
                    y: 14
                    width: parent.width - 32
                    spacing: 10

                    // Kopf: Symbol + Art, rechts die Zeit am Stück
                    Item {
                        width: parent.width
                        height: 20

                        Row {
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 8
                            Icon {
                                anchors.verticalCenter: parent.verticalCenter
                                name: "local_cafe"
                                size: 16
                                color: Theme.accentText
                            }
                            Txt {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "Break"
                                color: Theme.textMuted
                                font.pixelSize: 12
                                font.weight: Font.DemiBold
                            }
                        }
                        MonoTxt {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            visible: Breaks.activeMin > 0
                            text: Breaks.fmt(Breaks.activeMin) + " straight"
                            color: Theme.textFaint
                            font.pixelSize: 11
                        }
                    }

                    Txt {
                        width: parent.width
                        text: "Time for a break"
                        font.pixelSize: 14
                        font.weight: Font.DemiBold
                    }
                    Txt {
                        width: parent.width
                        text: Breaks.message
                        color: Theme.textMuted
                        font.pixelSize: 13
                        font.weight: Font.Normal
                        wrapMode: Text.WordWrap
                        elide: Text.ElideNone
                    }

                    Row {
                        spacing: 8
                        topPadding: 2
                        Button {
                            height: 32
                            primary: true
                            text: "Taking a break"
                            onClicked: Breaks.takeBreak()
                        }
                        Button {
                            height: 32
                            text: Breaks.snoozeMin + " more min"
                            onClicked: Breaks.snooze(Breaks.snoozeMin)
                        }
                        Button {
                            height: 32
                            text: "Not today"
                            onClicked: Breaks.notToday()
                        }
                    }
                }
            }
        }
    }
}

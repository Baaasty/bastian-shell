import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.config
import qs.services

// Top-Bar nur auf dem Hauptmonitor. Ist sie ausgewichen, holt sie die obere Kante zurück: Hyprland meldet keine
// Bildschirmkanten, also ein 2-px-Streifen oben, nur solange die Bar weg ist (normal sofort, bei Vollbild nach kurzem Verweilen).
Scope {
    Variants {
        model: Config.mainScreens

        Scope {
            id: perScreen

            required property var modelData

            BarWindow {
                id: barWindow
                screen: perScreen.modelData
            }

            IpcHandler {
                target: "bar"
                // von außen (früher KWin-Script desktop-edges): Bar holen / Maus hat den oberen Streifen verlassen
                // (ob die Maus oben bleibt, sieht die Bar unter Hyprland selbst – topZone in BarWindow)
                function reveal(): void {
                    barWindow.revealed = true;
                }
                function leave(): void {
                    barWindow.inZone = false;
                }
            }

            // 2 px am oberen Rand: Maus oben = Bar kommt (bei Vollbild erst nach kurzem Verweilen, Spiele)
            PanelWindow {
                screen: perScreen.modelData
                // nicht im Vollbild/bei Spielen (Windows.bare): Overlay-Flächen kosten dort Tearing/direct scanout
                visible: Windows.topBlocked && !barWindow.shown && !Windows.bare
                anchors {
                    top: true
                    left: true
                    right: true
                }
                implicitHeight: 2
                exclusionMode: ExclusionMode.Ignore
                color: "transparent"
                WlrLayershell.namespace: "dock"
                WlrLayershell.layer: WlrLayer.Overlay
                WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    onEntered: {
                        if (Windows.fullscreen)
                            dwell.restart();
                        else
                            barWindow.revealed = true;
                    }
                    onExited: dwell.stop()
                }

                Timer {
                    id: dwell
                    interval: 250
                    onTriggered: barWindow.revealed = true
                }
            }
        }
    }
}

pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.config
import qs.services

// Auffächern nach dem Login: Der Plasma-Greeter wird nach dem Login sofort beendet, eine Animation dort würde
// abgeschnitten. Darum zeigt die Shell beim Start kurz das Bild des Login-Bildschirms (Wallpaper unscharf wie bei
// eingeblendetem Feld) und fächert es wie beim Entsperren auf (SplitReveal).
// Nur einmal je Hyprland-Start (Merkdatei mit der Instanz-Kennung): ein Shell-Neustart spielt es nicht nochmal.
// Sperrt die Shell beim Start gleich wieder (Absturz im gesperrten Zustand), liegt die Sperre ohnehin darüber.
Scope {
    id: root

    readonly property string signature: Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE") ?? ""
    property bool active: false
    property int done: 0

    LockWallpaper {
        id: wallpaper
    }

    FileView {
        path: root.signature ? Quickshell.env("XDG_RUNTIME_DIR") + "/desktop-reveal-" + root.signature : ""
        printErrors: false
        onLoadFailed: {
            setText("shown\n");
            root.active = true;
        }
    }

    Variants {
        model: root.active && Hypr.running ? Quickshell.screens : []

        PanelWindow {
            id: win

            required property var modelData

            screen: modelData
            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }
            exclusionMode: ExclusionMode.Ignore
            color: "transparent"
            mask: Region {}
            WlrLayershell.namespace: "desktop-reveal"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

            // wie LockSurface bei eingeblendetem Feld (factor 1)
            Item {
                id: content
                anchors.fill: parent

                Image {
                    id: base
                    anchors.fill: parent
                    source: "file://" + wallpaper.path
                    fillMode: Image.PreserveAspectCrop
                    sourceSize.width: win.width
                    sourceSize.height: win.height
                    smooth: true
                    onStatusChanged: {
                        if (status === Image.Ready)
                            holdTimer.start();
                        else if (status === Image.Error)
                            root.done++;
                    }
                }
                MultiEffect {
                    anchors.fill: parent
                    source: base
                    autoPaddingEnabled: false
                    blurEnabled: true
                    blurMax: 50
                    blur: 1
                    saturation: 0.5
                    contrast: -0.2
                }
                Rectangle {
                    anchors.fill: parent
                    color: Qt.alpha(Theme.dim, 0.3)
                }
            }

            SplitReveal {
                id: split
                anchors.fill: parent
                sourceItem: content
                onFinished: root.done++
            }

            // kurz stehen lassen: der Login-Bildschirm war eben noch zu sehen, dann auffächern
            Timer {
                id: holdTimer
                interval: 250
                onTriggered: split.start()
            }
        }
    }

    // alle Monitore fertig → Fenster weg; Notbremse, falls ein Bild nie lädt
    onDoneChanged: if (done >= Quickshell.screens.length) active = false
    Timer {
        running: root.active
        interval: 5000
        onTriggered: root.active = false
    }
}

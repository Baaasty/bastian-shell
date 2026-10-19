import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.components

// Kleine Bestätigung unten auf dem Monitor (statt Benachrichtigung): "Text copied · 142 chars", Farbfleck + Hex.
// Liegt über allem, nimmt keine Klicks und verschwindet von selbst. Aufruf: toast.show({...}).
Scope {
    id: root

    property bool shown: false
    property string screenName: ""
    property string icon: ""        // Material-Symbol, leer = keins
    property string text: ""
    property string sub: ""         // kleinere Zweitzeile (Mono), leer = keine
    property color swatch: "transparent"
    property bool hasSwatch: false

    // opts: { screen, icon, text, sub, swatch, ms }
    function show(opts: var): void {
        screenName = opts.screen || Config.mainScreen;
        icon = opts.icon || "";
        text = opts.text || "";
        sub = opts.sub || "";
        hasSwatch = !!opts.swatch;
        swatch = opts.swatch || "transparent";
        hide.interval = opts.ms || 2600;
        shown = true;
        hide.restart();
    }

    Timer {
        id: hide
        onTriggered: root.shown = false
    }

    Variants {
        model: Quickshell.screens.filter(s => s.name === root.screenName)

        PanelWindow {
            id: win

            required property var modelData

            screen: modelData
            visible: root.shown || pill.opacity > 0
            anchors.bottom: true
            margins.bottom: 110
            implicitWidth: pill.width
            implicitHeight: pill.height
            exclusionMode: ExclusionMode.Ignore
            color: "transparent"
            WlrLayershell.namespace: "dock" // "dock": ohne Öffnen-Animation (Hyprland: layerrule noanim)
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            // leere Maske: Klicks gehen durch
            mask: Region {}

            Glass {
                id: pill
                width: row.implicitWidth + 40
                height: root.sub ? 56 : 44
                radius: height / 2
                strong: true
                opacity: root.shown ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: Theme.fade; easing.type: Easing.OutCubic } }

                Row {
                    id: row
                    anchors.centerIn: parent
                    spacing: 10
                    // Farbfleck (Pipette)
                    Rectangle {
                        visible: root.hasSwatch
                        anchors.verticalCenter: parent.verticalCenter
                        width: 24
                        height: 24
                        radius: Theme.radii.xs || 6
                        color: root.swatch
                        border.width: 1
                        border.color: Theme.borderStrong
                    }
                    Icon {
                        visible: root.icon !== "" && !root.hasSwatch
                        anchors.verticalCenter: parent.verticalCenter
                        name: root.icon
                        size: 20
                        color: Theme.accentText
                    }
                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 1
                        Txt {
                            text: root.text
                            font.pixelSize: 14
                        }
                        MonoTxt {
                            visible: root.sub !== ""
                            text: root.sub
                            color: Theme.textFaint
                            font.pixelSize: 11
                        }
                    }
                }
            }
        }
    }
}

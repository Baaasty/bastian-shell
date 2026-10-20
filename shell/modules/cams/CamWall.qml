import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.services
import qs.components

// Kamera-Overlay: alle Kameras der anderen im Call aus dem Discord-Plugin (Cams.qml) zusammen in einer Karte, in einer
// Ecke eines wählbaren Monitors (Cams.screen/Cams.corner; oben unter der Bar). Ein Schalter für alle (Kamera-Knopf im
// Discord-Popout, Super+C). Bedienung:
//  - Karte ziehen: folgt der Maus, auch auf einen anderen Monitor; beim Loslassen gleitet sie in die nächste Ecke
//    (Super+Ziehen geht nicht: das nimmt Hyprland für das Fenster darunter). Super+Alt+Pfeile = Ecke per Tastatur.
//  - Griff an der inneren Ecke (beim Darüberfahren) ziehen = Größe stufenlos; Mausrad = in Schritten.
//  - Klick auf eine Kachel = nur diese groß, nochmal = alle. Doppelklick = Discord holen.
// Je Monitor ein bildschirmgroßes, durchsichtiges Fenster, das IMMER gemappt bleibt (Eingaben nur auf der Karte per mask):
// würde es beim Ausschalten verschwinden, beendet Hyprland den Popup-Grab und das Discord-Popout klappt zu.
// Liegt auf der Top-Ebene (unter Benachrichtigungen, Popouts und Overlays); im echten Vollbild/Spiel (Windows.bare)
// ist die Karte weg und das Plugin bekommt keine Bilder angefordert. Einstellungen: ~/.config/desktop/cams.json
Scope {
    id: root

    // Größe gedeckelt: Karte höchstens halb so breit wie der Monitor und 80 % so hoch (Bastian: „max halber Bildschirm“)
    readonly property var target: Quickshell.screens.find(s => s.name === screenName) ?? null
    readonly property int maxTileW: target ? Math.floor((target.width / 2 - 2 * pad - (columns - 1) * gap) / columns) : 960
    readonly property int maxTileH: target ? Math.floor((target.height * 0.8 - 2 * pad - Math.max(0, rows - 1) * gap) / Math.max(1, rows)) : 540
    readonly property int tileWidth: Math.max(Cams.minWidth, Math.min(Cams.tileWidth, maxTileW, Math.floor(maxTileH * 16 / 9)))
    readonly property int tileHeight: Math.round(tileWidth * 9 / 16)
    readonly property int gap: 8
    readonly property int pad: 8
    readonly property int count: Cams.pinned.length
    // Fokus: eine Kachel füllt die ganze Karte, die anderen sind ausgeblendet
    readonly property bool focused: Cams.focusKey !== "" && Cams.pinned.indexOf(Cams.focusKey) >= 0
    // 1 Kamera: eine Spalte; ab 2 nebeneinander, dann Reihen (6 = 2 × 3)
    readonly property int columns: count <= 1 ? 1 : 2
    readonly property int rows: focused ? 1 : Math.ceil(count / columns)
    readonly property int cardWidth: columns * tileWidth + (columns - 1) * gap + 2 * pad
    readonly property int bigWidth: cardWidth - 2 * pad
    readonly property bool top: Cams.corner.indexOf("top") === 0
    readonly property bool left: Cams.corner.indexOf("left") > 0
    readonly property bool shown: Cams.connected && Discord.inVoice && count > 0 && !Windows.bare
    // Monitor der Karte: gespeicherter, sonst der Hauptmonitor
    readonly property string screenName: Quickshell.screens.some(s => s.name === Cams.screen) ? Cams.screen : Config.mainScreen

    // Ziehen: Lage der Karte in globalen Koordinaten – jeder Monitor zeichnet seinen Teil, so bleibt sie auch über
    // Monitorgrenzen hinweg sichtbar (der Zeiger bleibt während des Drückens beim Fenster, auf dem es losging)
    property bool dragging: false
    property real dragGX: 0
    property real dragGY: 0

    Binding {
        target: Cams
        property: "paused"
        value: !root.shown
    }

    // Monitor + Ecke aus einem Punkt in globalen Koordinaten
    function dockAt(gx: real, gy: real): void {
        const s = Quickshell.screens.find(s => gx >= s.x && gx < s.x + s.width && gy >= s.y && gy < s.y + s.height);
        if (!s)
            return;
        Cams.setScreen(s.name);
        Cams.setCorner((gy - s.y < s.height / 2 ? "top" : "bottom") + "-" + (gx - s.x < s.width / 2 ? "left" : "right"));
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: win

            required property var modelData
            readonly property bool here: modelData.name === root.screenName
            readonly property bool active: root.shown && here

            screen: modelData
            visible: true
            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }
            exclusionMode: ExclusionMode.Ignore
            color: "transparent"
            WlrLayershell.namespace: "cams"
            WlrLayershell.layer: WlrLayer.Top
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

            // Eingaben nur auf der Karte; ohne Karte gar keine (Fenster bleibt trotzdem gemappt)
            mask: Region {
                item: win.active || (root.dragging && dock.pressed) ? card : null
            }

            BackgroundEffect.blurRegion: Region {
                x: 0
                y: 0
                width: 1
                height: 1
            }

            // Ecken-Lage der Karte
            readonly property real topY: Theme.barMargin + Theme.barHeight + Theme.windowGap
            readonly property real dockX: root.left ? Theme.barMargin : width - Theme.barMargin - card.width
            readonly property real dockY: root.top ? topY : height - Theme.barMargin - card.height

            // eine deckende Karte für alle Kacheln
            Rectangle {
                id: card
                visible: win.active || (root.dragging && root.shown)
                // beim Ziehen folgt sie der Maus (globale Lage, auf jedem Monitor umgerechnet), sonst sitzt sie in ihrer Ecke
                x: root.dragging ? root.dragGX - win.modelData.x : win.dockX
                y: root.dragging ? root.dragGY - win.modelData.y : win.dockY
                Behavior on x {
                    enabled: !root.dragging && !grip.pressed
                    NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
                }
                Behavior on y {
                    enabled: !root.dragging && !grip.pressed
                    NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
                }
                width: root.cardWidth
                height: root.focused ? Math.round(root.bigWidth * 9 / 16) + 2 * root.pad
                    : root.rows * root.tileHeight + Math.max(0, root.rows - 1) * root.gap + 2 * root.pad
                radius: Theme.radiusLg + root.pad / 2
                color: Theme.surface
                border.width: 1
                border.color: root.dragging || grip.pressed ? Theme.accent : Theme.border

                HoverHandler {
                    id: cardHover
                }

                // Mausrad: kleiner/größer in Schritten; ein Schritt je Rasterstufe (120), Touchpad sammelt erst
                WheelHandler {
                    property real acc: 0
                    acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                    onWheel: event => {
                        if (event.angleDelta.y === 0)
                            return;
                        acc += event.angleDelta.y;
                        if (Math.abs(acc) < 120)
                            return;
                        Cams.stepSize(acc > 0 ? 1 : -1);
                        acc = 0;
                    }
                }

                Grid {
                    id: grid
                    x: root.pad
                    y: root.pad
                    columns: root.focused ? 1 : root.columns
                    spacing: root.gap

                    // Kacheln nur, wo die Karte zu sehen ist (sonst lädt jeder Monitor alle Bilder mit)
                    Repeater {
                        model: win.here || root.dragging ? Cams.pinned : []

                        CamTile {
                            required property string modelData
                            readonly property bool big: root.focused && modelData === Cams.focusKey
                            camKey: modelData
                            visible: !root.focused || big
                            width: big ? root.bigWidth : root.tileWidth
                            height: big ? Math.round(root.bigWidth * 9 / 16) : root.tileHeight
                        }
                    }
                }

                // Ziehen: ab 10 px Bewegung folgt die Karte der Maus (ein Klick bleibt ein Klick), auch über den
                // Monitorrand hinaus (der Zeiger bleibt während des Drückens bei diesem Fenster); Griffpunkt bleibt unter der Maus
                MouseArea {
                    id: dock
                    property real grabX: 0
                    property real grabY: 0
                    property bool moved: false
                    property bool wasDrag: false
                    anchors.fill: parent
                    z: 10
                    acceptedButtons: Qt.LeftButton
                    cursorShape: moved ? Qt.ClosedHandCursor : Qt.PointingHandCursor
                    onPressed: mouse => {
                        grabX = mouse.x;
                        grabY = mouse.y;
                        moved = false;
                        wasDrag = false;
                    }
                    onPositionChanged: mouse => {
                        if (!pressed)
                            return;
                        const p = mapToItem(win.contentItem, mouse.x, mouse.y);
                        if (!moved) {
                            if (Math.hypot(mouse.x - grabX, mouse.y - grabY) < 10)
                                return;
                            moved = true;
                        }
                        root.dragGX = win.modelData.x + p.x - grabX;
                        root.dragGY = win.modelData.y + p.y - grabY;
                        root.dragging = true;
                    }
                    onReleased: {
                        wasDrag = moved;
                        if (moved)
                            root.dockAt(root.dragGX + card.width / 2, root.dragGY + card.height / 2);
                        moved = false;
                        root.dragging = false;
                    }
                    onCanceled: {
                        moved = false;
                        root.dragging = false;
                    }
                    // Klick: diese Kachel groß / wieder alle
                    onClicked: mouse => {
                        if (wasDrag)
                            return;
                        const q = grid.mapFromItem(dock, mouse.x, mouse.y);
                        const t = grid.childAt(q.x, q.y);
                        if (t && t.camKey)
                            Cams.toggleFocus(t.camKey);
                    }
                    // Doppelklick: Discord holen (nicht, wenn es schon draußen ist)
                    onDoubleClicked: if (Parked.out.discord !== true) Parked.toggle("discord")
                }

                // Größe: Griff an der inneren unteren/oberen Ecke (zur Bildschirmmitte hin), stufenlos
                Rectangle {
                    id: gripVis
                    z: 11
                    width: 22
                    height: 22
                    radius: 7
                    x: root.left ? parent.width - width - 4 : 4
                    y: root.top ? parent.height - height - 4 : 4
                    color: grip.pressed || grip.containsMouse ? Theme.surfaceRaised : Qt.alpha(Theme.bg, 0.86)
                    opacity: cardHover.hovered || grip.pressed ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: Theme.fade } }

                    Icon {
                        anchors.centerIn: parent
                        name: "open_in_full"
                        size: 13
                        color: Theme.text
                        rotation: root.left === root.top ? 90 : 0
                    }
                    MouseArea {
                        id: grip
                        property real startX: 0
                        property int startW: 0
                        anchors.fill: parent
                        anchors.margins: -4
                        hoverEnabled: true
                        cursorShape: root.left === root.top ? Qt.SizeFDiagCursor : Qt.SizeBDiagCursor
                        onPressed: mouse => {
                            startX = mapToItem(win.contentItem, mouse.x, mouse.y).x;
                            startW = Cams.tileWidth;
                        }
                        onPositionChanged: mouse => {
                            if (!pressed)
                                return;
                            // vom Rand weg ziehen = größer (rechts angedockt: nach links)
                            const dx = (mapToItem(win.contentItem, mouse.x, mouse.y).x - startX) * (root.left ? 1 : -1);
                            Cams.setWidth(startW + dx / root.columns, false);
                        }
                        onReleased: Cams.setWidth(Cams.tileWidth, true)
                    }
                }
            }
        }
    }
}

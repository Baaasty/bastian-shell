import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.config
import qs.services
import qs.components

// Gemeinsame Basis für die kleinen Popups dort, wo getippt wird (Zwischenablage Super+V, Emoji Super+.):
// an der Maus, wenn sie im aktiven Fenster steht, sonst im unteren Drittel des Fensters (die Schreibmarke fremder Apps
// ist unter Wayland nicht abfragbar). Merkt sich das Fenster (target), damit Einfügen dort landet (Clipboard.copy*).
// Liefert Karte, Filterfeld und Hinweiszeile; der Inhalt dazwischen kommt vom Modul (default property).
// Esc schließt; alle anderen Tasten im Feld gehen zuerst an keyPressed (event.accepted = true schluckt sie).
// Doku: docs/knowledge/shell-features.md
Scope {
    id: popup

    property string name                 // für Hypr.panelOpened (anderes Panel geht auf → dieses zu)
    property string icon
    property string placeholder
    property var hints: []
    property int cardW: 480
    property int bodyMaxH: 0             // höchster Inhalt – entscheidet, ob die Karte unter den Anker passt
    default property alias content: body.data

    property bool open: false
    property string query: ""
    property var target: null            // { address, cls } – Fenster, in dem vor dem Öffnen getippt wurde
    property string screenName: ""
    property real ax: 0                  // Ankerpunkt in Bildschirm-Koordinaten des Monitors
    property real ay: 0
    property bool above: false           // Karte über dem Anker statt darunter (unten kein Platz)

    readonly property int pad: Theme.space3
    readonly property int gap: Theme.space3    // Abstand Maus → Karte
    readonly property int edge: Theme.space4   // Mindestabstand zum Bildschirmrand
    readonly property int maxCardH: 2 * pad + Theme.buttonHeight + bodyMaxH + 2 * Theme.space2 + Theme.keyCapHeightSm + Theme.keyCapLip

    signal shown()                       // Position steht, gleich sichtbar: Auswahl zurücksetzen, Liste bauen
    signal keyPressed(var event)

    onOpenChanged: if (open) Hypr.panelOpened(name)
    Connections {
        target: Hypr
        function onPanelOpened(name: string): void {
            if (name !== popup.name && popup.open)
                popup.open = false;
        }
    }

    function toggle(): void {
        if (open) {
            open = false;
            return;
        }
        locate.running = true;
    }
    function close(): void {
        open = false;
    }

    // aktives Fenster + Maus holen (frisch von Hyprland, lastIpcObject kann veraltet sein)
    Process {
        id: locate
        command: ["sh", "-c", "hyprctl activewindow -j; printf '\\036'; hyprctl cursorpos -j"]
        stdout: StdioCollector {
            onStreamFinished: {
                const parts = text.split("\x1e");
                let w = null, c = null;
                try {
                    const o = JSON.parse(parts[0]);
                    if (o && o.address && o.at && o.size)
                        w = { address: o.address, cls: o.class || "", x: o.at[0], y: o.at[1], w: o.size[0], h: o.size[1] };
                } catch (e) {}
                try {
                    c = JSON.parse(parts[1] || "");
                } catch (e) {}
                popup.show(w, c);
            }
        }
    }

    function screenAt(x: real, y: real): var {
        const ss = Quickshell.screens;
        return ss.find(s => x >= s.x && x < s.x + s.width && y >= s.y && y < s.y + s.height) ?? Config.mainScreenObj ?? ss[0];
    }

    function show(w: var, c: var): void {
        target = w ? { address: w.address, cls: w.cls } : null;
        const inside = w && c && c.x >= w.x && c.x < w.x + w.w && c.y >= w.y && c.y < w.y + w.h;
        let px, py, centered = false;
        if (c && (inside || !w)) {
            px = c.x;
            py = c.y;
        } else if (w) {
            px = w.x + w.w / 2;
            py = w.y + Math.round(w.h * 2 / 3);
            centered = true;
        } else {
            const s = Config.mainScreenObj ?? Quickshell.screens[0];
            px = s.x + s.width / 2;
            py = s.y + s.height / 3;
            centered = true;
        }
        const s = screenAt(px, py);
        screenName = s.name;
        let lx = px - s.x, ly = py - s.y;
        // waagerecht: rechts neben der Maus, sonst links davon; zentriert beim Fenster-Ersatz; dann einklemmen
        let x = centered ? lx - cardW / 2 : (lx + gap + cardW <= s.width - edge ? lx + gap : lx - gap - cardW);
        ax = Math.max(edge, Math.min(x, s.width - edge - cardW));
        above = ly + gap + maxCardH > s.height - edge && ly - gap - maxCardH >= edge;
        ay = ly;
        query = "";
        shown();
        open = true;
    }

    PanelWindow {
        id: win

        screen: Quickshell.screens.find(s => s.name === popup.screenName) ?? Config.mainScreenObj ?? Quickshell.screens[0]
        // ohne Ausblenden: das Panel muss sofort weg sein, damit der Fokus zurück kann
        visible: popup.open
        anchors {
            top: true
            left: true
        }
        margins.left: popup.ax
        margins.top: Math.max(popup.edge, popup.above ? popup.ay - popup.gap - card.height : popup.ay + popup.gap)
        implicitWidth: popup.cardW
        implicitHeight: card.height + Theme.space1   // Platz für den Schatten
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"
        WlrLayershell.namespace: "dock" // ohne Öffnen-Animation (Hyprland: layerrule noanim)
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: popup.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

        // Klick daneben (auch auf anderen Monitoren) schließt, ohne einzufügen
        HyprlandFocusGrab {
            active: popup.open
            windows: [win]
            onCleared: popup.open = false
        }

        onVisibleChanged: if (visible) input.forceActiveFocus()

        Glass {
            id: card
            width: parent.width
            height: col.implicitHeight + 2 * popup.pad
            radius: Theme.radiusLg

            Column {
                id: col
                x: popup.pad
                y: popup.pad
                width: parent.width - 2 * popup.pad
                spacing: Theme.space2

                // Filterfeld
                Rectangle {
                    width: parent.width
                    height: Theme.buttonHeight
                    radius: Theme.radiusSm
                    color: Theme.raise
                    Icon {
                        id: fieldIcon
                        x: Theme.space3
                        anchors.verticalCenter: parent.verticalCenter
                        name: popup.icon
                        size: Theme.iconSize
                        color: Theme.textFaint
                    }
                    TextInput {
                        id: input
                        anchors.left: fieldIcon.right
                        anchors.leftMargin: Theme.space2
                        anchors.right: parent.right
                        anchors.rightMargin: Theme.space3
                        anchors.verticalCenter: parent.verticalCenter
                        text: popup.query
                        onTextChanged: popup.query = text
                        Connections {
                            target: popup
                            function onQueryChanged() {
                                if (input.text !== popup.query)
                                    input.text = popup.query;
                            }
                        }
                        color: Theme.text
                        selectionColor: Theme.accentSoft
                        font.family: Theme.fontUi
                        font.pixelSize: Theme.fontMd
                        focus: true
                        Keys.onPressed: event => {
                            if (event.key === Qt.Key_Escape) {
                                popup.open = false;
                                event.accepted = true;
                                return;
                            }
                            popup.keyPressed(event);
                        }
                        Txt {
                            anchors.fill: parent
                            visible: input.text === ""
                            text: popup.placeholder
                            color: Theme.textFaint
                            font.pixelSize: Theme.fontMd
                            font.weight: Font.Normal
                        }
                    }
                }

                // Inhalt des Moduls (Liste, Raster …)
                Column {
                    id: body
                    width: parent.width
                    spacing: Theme.space2
                }

                // Tasten-Hinweise (dieselbe Zeile wie überall)
                KeyHintRow {
                    x: Theme.space1
                    width: parent.width - 2 * Theme.space1
                    gap: Theme.space3
                    small: true   // schmale Karte: kleine Kappen, damit alle Tasten in eine Zeile passen
                    hints: popup.hints
                }
            }
        }
    }
}

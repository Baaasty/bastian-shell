import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.config
import qs.services
import qs.components

// Zwischenablage-Popup (Super+V) dort, wo getippt wird: an der Maus, wenn sie im aktiven Fenster steht, sonst im
// unteren Drittel des Fensters (die Schreibmarke fremder Apps ist unter Wayland nicht abfragbar).
// Enter fügt ins vorige Fenster ein (Clipboard.copy mit Ziel), Shift+Enter kopiert nur. Doku: docs/knowledge/shell-features.md
Scope {
    id: root

    property bool open: false
    property string query: ""
    property int selected: 0
    property var items: []
    property var target: null        // { address, cls } – Fenster, in dem vor dem Öffnen getippt wurde
    property string screenName: ""
    property real ax: 0              // Ankerpunkt in Bildschirm-Koordinaten des Monitors
    property real ay: 0
    property bool above: false       // Karte über dem Anker statt darunter (unten kein Platz)

    readonly property int cardW: 480
    readonly property int rowH: 48
    readonly property int maxRows: 8
    readonly property int gap: 14    // Abstand Maus → Karte
    readonly property int edge: 16   // Mindestabstand zum Bildschirmrand
    // höchste Karte (Feld + maxRows + Hinweise) – entscheidet, ob sie unter den Anker passt
    readonly property int maxCardH: 20 + 36 + 8 + maxRows * (rowH + 2) + 8 + 22

    onOpenChanged: if (open) Hypr.panelOpened("clip")
    Connections {
        target: Hypr
        function onPanelOpened(name: string): void {
            if (name !== "clip" && root.open)
                root.open = false;
        }
    }

    function toggle(): void {
        if (open) {
            open = false;
            return;
        }
        Clipboard.refresh();
        locate.running = true;
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
                root.show(w, c);
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
        selected = 0;
        rebuild();
        open = true;
    }

    function rebuild(): void {
        const t = query.trim();
        let out = [];
        const add = (item, score) => {
            if (score >= 0)
                out.push(Object.assign({ score: score }, item));
        };
        for (const p of Clipboard.pins)
            add({ key: "pin:" + p, pinText: p, title: p, pinned: true }, t ? Fuzzy.score(t, p) : 2);
        for (const c of Clipboard.entries) {
            if (!c.image && Clipboard.isPinned(c.text))
                continue;
            add({
                key: "clip:" + c.id, clipId: c.id,
                pinText: c.image ? "" : c.text,
                thumb: c.image ? Clipboard.thumb(c.id) : "",
                title: c.image ? "Image · " + c.w + " × " + c.h : c.text
            }, t ? Fuzzy.score(t, c.image ? "image picture bild " + c.image : c.text) : 1);
        }
        if (t)
            out.sort((a, b) => b.score - a.score);
        items = out.slice(0, 60);
        selected = Math.max(0, Math.min(selected, items.length - 1));
    }
    onQueryChanged: if (open) {
        selected = 0;
        rebuild();
    }
    Connections {
        target: Clipboard
        function onEntriesChanged() { if (root.open) root.rebuild(); }
        function onThumbsVersionChanged() { if (root.open) root.rebuild(); }
    }

    function activate(i: int, copyOnly: bool): void {
        const r = items[i];
        if (!r)
            return;
        const t = target;
        // erst zu: Panel weg, Tastaturfokus frei – Clipboard holt ihn danach ausdrücklich ans Ziel zurück
        open = false;
        if (r.clipId)
            Clipboard.copy(r.clipId, !copyOnly, t);
        else
            Clipboard.copyText(r.pinText, !copyOnly, t);
    }

    IpcHandler {
        target: "clip"

        function toggle(): void {
            root.toggle();
        }
        function close(): void {
            root.open = false;
        }
    }

    PanelWindow {
        id: win

        screen: Quickshell.screens.find(s => s.name === root.screenName) ?? Config.mainScreenObj ?? Quickshell.screens[0]
        // ohne Ausblenden: das Panel muss sofort weg sein, damit der Fokus zurück kann
        visible: root.open
        anchors {
            top: true
            left: true
        }
        margins.left: root.ax
        margins.top: Math.max(root.edge, root.above ? root.ay - root.gap - card.height : root.ay + root.gap)
        implicitWidth: root.cardW
        implicitHeight: card.height + 4   // Platz für den Schatten
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"
        WlrLayershell.namespace: "dock" // ohne Öffnen-Animation (Hyprland: layerrule noanim)
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: root.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

        // Klick daneben (auch auf anderen Monitoren) schließt, ohne einzufügen
        HyprlandFocusGrab {
            active: root.open
            windows: [win]
            onCleared: root.open = false
        }

        onVisibleChanged: if (visible) input.forceActiveFocus()

        Glass {
            id: card
            width: parent.width
            height: col.implicitHeight + 20
            radius: Theme.radiusLg

            Column {
                id: col
                x: 10
                y: 10
                width: parent.width - 20
                spacing: 8

                // Filterfeld
                Rectangle {
                    width: parent.width
                    height: 36
                    radius: Theme.radiusSm
                    color: Theme.raise
                    Icon {
                        id: fieldIcon
                        x: 10
                        anchors.verticalCenter: parent.verticalCenter
                        name: "content_paste"
                        size: 18
                        color: Theme.textFaint
                    }
                    TextInput {
                        id: input
                        anchors.left: fieldIcon.right
                        anchors.leftMargin: 8
                        anchors.right: parent.right
                        anchors.rightMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.query
                        onTextChanged: root.query = text
                        Connections {
                            target: root
                            function onQueryChanged() {
                                if (input.text !== root.query)
                                    input.text = root.query;
                            }
                        }
                        color: Theme.text
                        selectionColor: Theme.accentSoft
                        font.family: Theme.fontUi
                        font.pixelSize: Theme.fontMd
                        focus: true
                        Keys.onPressed: event => {
                            const k = event.key;
                            const ctrl = event.modifiers & Qt.ControlModifier;
                            const last = root.items.length - 1;
                            if (k === Qt.Key_Escape) {
                                root.open = false;
                            } else if (k === Qt.Key_Return || k === Qt.Key_Enter) {
                                root.activate(root.selected, !!(event.modifiers & Qt.ShiftModifier));
                            } else if (k === Qt.Key_Down || k === Qt.Key_Tab) {
                                root.selected = Math.min(last, root.selected + 1);
                            } else if (k === Qt.Key_Up || k === Qt.Key_Backtab) {
                                root.selected = Math.max(0, root.selected - 1);
                            } else if (k === Qt.Key_PageDown) {
                                root.selected = Math.min(last, root.selected + root.maxRows);
                            } else if (k === Qt.Key_PageUp) {
                                root.selected = Math.max(0, root.selected - root.maxRows);
                            } else if (k === Qt.Key_Delete) {
                                const r = root.items[root.selected];
                                if (r && r.clipId)
                                    Clipboard.remove(r.clipId);
                                else if (r && r.pinned)
                                    Clipboard.togglePin(r.pinText);
                                root.rebuild();
                            } else if (k === Qt.Key_P && ctrl) {
                                const r = root.items[root.selected];
                                if (r && r.pinText) {
                                    Clipboard.togglePin(r.pinText);
                                    root.rebuild();
                                }
                            } else {
                                return;
                            }
                            event.accepted = true;
                        }
                        Txt {
                            anchors.fill: parent
                            visible: input.text === ""
                            text: "Clipboard · type to filter"
                            color: Theme.textFaint
                            font.pixelSize: Theme.fontMd
                            font.weight: Font.Normal
                        }
                    }
                }

                ListView {
                    id: list
                    visible: count > 0
                    width: parent.width
                    height: Math.max(0, Math.min(count, root.maxRows) * (root.rowH + spacing) - spacing)
                    spacing: 2
                    clip: true
                    interactive: count > root.maxRows
                    boundsBehavior: Flickable.StopAtBounds
                    model: root.items
                    currentIndex: root.selected
                    highlightFollowsCurrentItem: false
                    onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)
                    delegate: Rectangle {
                        id: row
                        required property var modelData
                        required property int index
                        readonly property bool on: index === root.selected
                        width: ListView.view.width
                        height: root.rowH
                        radius: Theme.radiusSm
                        color: on ? Theme.accentFill : rowArea.containsMouse ? Theme.raise : "transparent"

                        Rectangle {
                            id: tile
                            x: 8
                            anchors.verticalCenter: parent.verticalCenter
                            width: 32
                            height: 32
                            radius: Theme.radiusXs
                            color: Theme.wood
                            clip: true
                            Image {
                                anchors.fill: parent
                                visible: !!row.modelData.thumb
                                source: row.modelData.thumb || ""
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                                cache: false
                                sourceSize.width: 64
                            }
                            Icon {
                                anchors.centerIn: parent
                                visible: !row.modelData.thumb
                                name: row.modelData.pinned ? "push_pin" : "content_paste"
                                size: 18
                                fill: !!row.modelData.pinned
                                color: row.modelData.pinned ? Theme.accentText : Theme.text
                            }
                        }
                        Txt {
                            anchors.left: tile.right
                            anchors.leftMargin: 12
                            anchors.right: kind.left
                            anchors.rightMargin: 10
                            anchors.verticalCenter: parent.verticalCenter
                            // mehrzeilige Kopien als eine Zeile zeigen
                            text: row.modelData.title.replace(/\s+/g, " ").slice(0, 300)
                            font.pixelSize: Theme.fontMd
                            font.weight: row.on ? Font.Medium : Font.Normal
                        }
                        // gewählte Zeile: Taste als kleine Kappe + was sie tut; sonst „Pinned“
                        Item {
                            id: kind
                            anchors.right: parent.right
                            anchors.rightMargin: 12
                            anchors.verticalCenter: parent.verticalCenter
                            width: row.on ? kindKey.implicitWidth : pinTxt.implicitWidth
                            height: Math.max(kindKey.implicitHeight, pinTxt.implicitHeight)
                            KeyHintRow {
                                id: kindKey
                                visible: row.on
                                anchors.verticalCenter: parent.verticalCenter
                                small: true
                                textColor: Theme.accentText
                                hints: [["↵", Clipboard.canPaste ? "paste" : "copy"]]
                            }
                            Txt {
                                id: pinTxt
                                visible: !row.on
                                anchors.verticalCenter: parent.verticalCenter
                                text: row.modelData.pinned ? "Pinned" : ""
                                color: Theme.textFaint
                                font.pixelSize: Theme.fontSm
                                font.weight: Font.Normal
                            }
                        }
                        MouseArea {
                            id: rowArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.activate(row.index, false)
                        }
                    }
                }

                Txt {
                    visible: root.items.length === 0
                    width: parent.width
                    height: 40
                    horizontalAlignment: Text.AlignHCenter
                    text: root.query ? "No match" : "Nothing copied yet"
                    color: Theme.textMuted
                    font.pixelSize: Theme.fontSm
                    font.weight: Font.Normal
                }

                // Tasten-Hinweise (dieselbe Zeile wie überall)
                KeyHintRow {
                    x: Theme.space1
                    width: parent.width - 2 * Theme.space1
                    gap: Theme.space3
                    small: true   // schmale Karte: kleine Kappen, damit alle Tasten in eine Zeile passen
                    hints: (Clipboard.canPaste ? [["↵", "paste"], ["Shift+↵", "copy"]] : [["↵", "copy"]]).concat([["Ctrl+P", "pin"], ["Del", "delete"], ["Esc", "close"]])
                }
            }
        }
    }
}

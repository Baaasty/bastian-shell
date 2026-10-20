import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import qs.services
import qs.components

// Emoji-Popup (Super+.) dort, wo getippt wird – Position, Ziel-Fenster und Karte aus InlinePopup (wie Super+V).
// Raster: Tippen filtert nach dem englischen Namen, ohne Suchtext zuletzt benutzte zuerst (Emoji.recent).
// Enter fügt ins vorige Fenster ein – über die Zwischenablage wie Super+V (Clipboard.copyText mit Ziel),
// Shift+Enter kopiert nur. Doku: docs/knowledge/shell-features.md
InlinePopup {
    id: root

    property int selected: 0
    property var items: []           // [{ ch, name, recent }]

    readonly property int cols: 9
    readonly property int rows: 5
    readonly property int cell: Theme.rowHeightTall + Theme.space1
    readonly property var current: items[selected] ?? null

    name: "emoji"
    icon: "mood"
    placeholder: "Emoji · type a name"
    cardW: cols * cell + 2 * pad
    bodyMaxH: rows * cell + Theme.space2 + Theme.rowHeight
    hints: (Clipboard.canPaste ? [["↵", "insert"], ["Shift+↵", "copy"]] : [["↵", "copy"]]).concat([["↑↓←→", "pick"], ["Esc", "close"]])

    onShown: {
        selected = 0;
        rebuild();
    }

    // Suchwörter müssen alle im Namen stecken (keine lose Buchstabenfolge: bei ~1400 Namen passt sonst fast alles);
    // Reihenfolge nach Fuzzy (Wortanfang vor Wortmitte), zuletzt benutzte etwas vorgezogen
    function rebuild(): void {
        const t = query.trim().toLowerCase();
        const recent = Emoji.recent;
        let out;
        if (!t) {
            const seen = new Set(recent);
            out = recent.filter(ch => Emoji.names[ch] !== undefined).map(ch => ({ ch: ch, name: Emoji.names[ch], recent: true }))
                .concat(Emoji.list.filter(([ch]) => !seen.has(ch)).map(([ch, name]) => ({ ch: ch, name: name, recent: false })));
        } else {
            const words = t.split(/\s+/);
            out = [];
            for (const [ch, name] of Emoji.list) {
                if (!words.every(w => name.includes(w)))
                    continue;
                const r = recent.indexOf(ch);
                out.push({ ch: ch, name: name, recent: r >= 0, score: Fuzzy.score(t, name) + (r >= 0 ? 400 - r : 0) });
            }
            out.sort((a, b) => b.score - a.score);
        }
        items = out;
        selected = Math.max(0, Math.min(selected, items.length - 1));
    }
    onQueryChanged: if (open) {
        selected = 0;
        rebuild();
    }
    Connections {
        target: Emoji
        function onListChanged() { if (root.open) root.rebuild(); }
    }

    function activate(i: int, copyOnly: bool): void {
        const r = items[i];
        if (!r)
            return;
        const t = target;
        open = false;
        Emoji.use(r.ch);
        Clipboard.copyText(Emoji.glyph(r.ch), !copyOnly, t);
    }

    onKeyPressed: event => {
        const k = event.key;
        const last = items.length - 1;
        const page = cols * rows;
        if (k === Qt.Key_Return || k === Qt.Key_Enter) {
            activate(selected, !!(event.modifiers & Qt.ShiftModifier));
        } else if (k === Qt.Key_Right || k === Qt.Key_Tab) {
            selected = Math.min(last, selected + 1);
        } else if (k === Qt.Key_Left || k === Qt.Key_Backtab) {
            selected = Math.max(0, selected - 1);
        } else if (k === Qt.Key_Down) {
            selected = Math.min(last, selected + cols);
        } else if (k === Qt.Key_Up) {
            selected = selected >= cols ? selected - cols : selected;
        } else if (k === Qt.Key_PageDown) {
            selected = Math.min(last, selected + page);
        } else if (k === Qt.Key_PageUp) {
            selected = Math.max(0, selected - page);
        } else {
            return;
        }
        event.accepted = true;
    }

    IpcHandler {
        target: "emoji"

        function toggle(): void {
            root.toggle();
        }
        function close(): void {
            root.close();
        }
    }

    GridView {
        id: grid
        visible: count > 0
        width: root.cols * root.cell
        height: Math.min(Math.ceil(count / root.cols), root.rows) * root.cell
        cellWidth: root.cell
        cellHeight: root.cell
        clip: true
        interactive: contentHeight > height
        boundsBehavior: Flickable.StopAtBounds
        model: root.items
        currentIndex: root.selected
        highlightFollowsCurrentItem: false
        onCurrentIndexChanged: positionViewAtIndex(currentIndex, GridView.Contain)
        delegate: Item {
            id: cellItem
            required property var modelData
            required property int index
            readonly property bool on: index === root.selected
            width: root.cell
            height: root.cell

            Rectangle {
                anchors.fill: parent
                anchors.margins: Theme.space1 / 2
                radius: Theme.radiusSm
                color: cellItem.on ? Theme.accentFill : cellArea.containsMouse ? Theme.raise : "transparent"
                border.width: cellItem.on ? 2 : 0
                border.color: Theme.accent
            }
            Text {
                anchors.centerIn: parent
                text: Emoji.glyph(cellItem.modelData.ch)
                font.pixelSize: Math.round(root.cell * 0.55)
            }
            MouseArea {
                id: cellArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.activate(cellItem.index, false)
            }
        }
    }

    // gewähltes Emoji mit Namen (die Kacheln selbst sind zu klein für Text)
    Item {
        width: parent.width
        height: Theme.rowHeight
        Txt {
            anchors.left: parent.left
            anchors.leftMargin: Theme.space1
            anchors.right: recentTxt.left
            anchors.rightMargin: Theme.space2
            anchors.verticalCenter: parent.verticalCenter
            text: root.current ? root.current.name : root.query ? "No match" : "Emoji list missing (shell/data/emoji.json)"
            color: root.current ? Theme.text : Theme.textMuted
            font.pixelSize: Theme.fontMd
            font.weight: root.current ? Font.Medium : Font.Normal
        }
        Txt {
            id: recentTxt
            anchors.right: parent.right
            anchors.rightMargin: Theme.space1
            anchors.verticalCenter: parent.verticalCenter
            visible: !!root.current && root.current.recent
            text: "Recent"
            color: Theme.textFaint
            font.pixelSize: Theme.fontSm
            font.weight: Font.Normal
        }
    }
}

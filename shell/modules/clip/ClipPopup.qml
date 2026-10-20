import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import qs.services
import qs.components

// Zwischenablage-Popup (Super+V) dort, wo getippt wird – Position, Ziel-Fenster und Karte aus InlinePopup.
// Enter fügt ins vorige Fenster ein (Clipboard.copy mit Ziel), Shift+Enter kopiert nur. Doku: docs/knowledge/shell-features.md
InlinePopup {
    id: root

    property int selected: 0
    property var items: []

    readonly property int rowH: Theme.rowHeightTall + Theme.space2
    readonly property int maxRows: 8

    name: "clip"
    icon: "content_paste"
    placeholder: "Clipboard · type to filter"
    cardW: 500   // alle Tasten-Hinweise in einer Zeile
    bodyMaxH: maxRows * (rowH + 2)
    hints: (Clipboard.canPaste ? [["↵", "paste"], ["Shift+↵", "copy"]] : [["↵", "copy"]]).concat([["Ctrl+P", "pin"], ["Del", "delete"], ["Esc", "close"]])

    // Clipboard schon beim Start anlegen: sein Wächter speichert jede Kopie, nicht erst ab dem ersten Öffnen
    Component.onCompleted: Clipboard.entries

    onShown: {
        Clipboard.refresh();
        selected = 0;
        rebuild();
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

    onKeyPressed: event => {
        const k = event.key;
        const ctrl = event.modifiers & Qt.ControlModifier;
        const last = items.length - 1;
        if (k === Qt.Key_Return || k === Qt.Key_Enter) {
            activate(selected, !!(event.modifiers & Qt.ShiftModifier));
        } else if (k === Qt.Key_Down || k === Qt.Key_Tab) {
            selected = Math.min(last, selected + 1);
        } else if (k === Qt.Key_Up || k === Qt.Key_Backtab) {
            selected = Math.max(0, selected - 1);
        } else if (k === Qt.Key_PageDown) {
            selected = Math.min(last, selected + maxRows);
        } else if (k === Qt.Key_PageUp) {
            selected = Math.max(0, selected - maxRows);
        } else if (k === Qt.Key_Delete) {
            const r = items[selected];
            if (r && r.clipId)
                Clipboard.remove(r.clipId);
            else if (r && r.pinned)
                Clipboard.togglePin(r.pinText);
            rebuild();
        } else if (k === Qt.Key_P && ctrl) {
            const r = items[selected];
            if (r && r.pinText) {
                Clipboard.togglePin(r.pinText);
                rebuild();
            }
        } else {
            return;
        }
        event.accepted = true;
    }

    Connections {
        target: Clipboard
        function onEntriesChanged() { if (root.open) root.rebuild(); }
        function onThumbsVersionChanged() { if (root.open) root.rebuild(); }
    }

    IpcHandler {
        target: "clip"

        function toggle(): void {
            root.toggle();
        }
        function close(): void {
            root.close();
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
                x: Theme.space2
                anchors.verticalCenter: parent.verticalCenter
                width: Theme.iconButton
                height: Theme.iconButton
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
                    sourceSize.width: 2 * Theme.iconButton
                }
                Icon {
                    anchors.centerIn: parent
                    visible: !row.modelData.thumb
                    name: row.modelData.pinned ? "push_pin" : "content_paste"
                    size: Theme.iconSize
                    fill: !!row.modelData.pinned
                    color: row.modelData.pinned ? Theme.accentText : Theme.text
                }
            }
            Txt {
                anchors.left: tile.right
                anchors.leftMargin: Theme.space3
                anchors.right: kind.left
                anchors.rightMargin: Theme.space2
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
                anchors.rightMargin: Theme.space3
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
        height: Theme.rowHeightTall
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        text: root.query ? "No match" : "Nothing copied yet"
        color: Theme.textMuted
        font.pixelSize: Theme.fontSm
        font.weight: Font.Normal
    }
}

import QtQuick
import Quickshell
import qs.config
import qs.services
import qs.components
import "../notifications"

// Verlauf der letzten Benachrichtigungen; ✕ beim Überfahren löscht einen Eintrag, „Clear all“ alle.
// Tastatur: das Dashboard holt die Kachel per enter() (↓ aus der leeren Suche), leave() gibt an die Suche zurück.
Tile {
    id: tile

    title: "Notifications"

    // zurück zur Suche; typed = getippter Text, der dort weiterlaufen soll („einfach lostippen“ gilt auch hier)
    signal leave(string typed)

    readonly property var shown: Notifs.history.slice(0, 3)
    readonly property bool kb: kbItem.activeFocus
    property int sel: 0     // markierte Zeile; -1 = „Clear all“ (steht oben, also über der ersten Zeile)

    function enter(): void {
        if (shown.length === 0)
            return;
        sel = 0;
        kbItem.forceActiveFocus();
    }
    // wie die Karte im Popup (Popups.qml openIt): Datei öffnen, sonst die App nach vorn holen
    function openEntry(h): void {
        if (!h)
            return;
        if (h.file) {
            Notifs.openFile(h.file);   // Launch → Dashboard geht zu
            return;
        }
        Parked.focus(h.desktop || h.app);
        Launch.launched();
    }

    // Liste schrumpft (Entf, Meldung von der App zurückgezogen): Markierung nachziehen, leer → zurück zur Suche
    onShownChanged: {
        if (!kb)
            return;
        if (shown.length === 0)
            leave("");
        else
            sel = Math.min(sel, shown.length - 1);
    }

    Item {
        id: kbItem
        Keys.onPressed: e => {
            const k = e.key;
            const n = tile.shown.length;
            if (k === Qt.Key_Escape) {
                tile.leave("");
            } else if (k === Qt.Key_Up) {
                if (tile.sel < 0)
                    tile.leave("");
                else
                    tile.sel = tile.sel - 1;
            } else if (k === Qt.Key_Down) {
                tile.sel = Math.min(n - 1, tile.sel + 1);
            } else if (k === Qt.Key_Return || k === Qt.Key_Enter) {
                if (tile.sel < 0)
                    Notifs.clearHistory();
                else
                    tile.openEntry(tile.shown[tile.sel]);
            } else if (k === Qt.Key_Delete) {
                if (tile.sel >= 0 && tile.shown[tile.sel])
                    Notifs.removeHistory(tile.shown[tile.sel].key);
            } else if (e.text !== "" && e.text.charCodeAt(0) >= 32 && !(e.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier))) {
                tile.leave(e.text);
            } else {
                return;
            }
            e.accepted = true;
        }
    }

    actions: Button {
        visible: Notifs.history.length > 0
        text: "Clear all"
        kind: "ghost"
        small: true
        focused: tile.kb && tile.sel < 0
        onClicked: Notifs.clearHistory()
    }

    Txt {
        anchors.centerIn: parent
        visible: Notifs.history.length === 0
        text: "All quiet."
        color: Theme.textFaint
        font.weight: Font.Normal
    }

    Column {
        width: parent.width
        spacing: 8

        Repeater {
            model: tile.shown

            Rectangle {
                id: row
                required property var modelData
                required property int index
                readonly property bool on: tile.kb && tile.sel === index
                width: parent.width
                height: 46
                radius: Theme.radiusMd
                color: on ? Theme.accentFill : Theme.raise

                NotifIcon {
                    id: ico
                    x: 8
                    anchors.verticalCenter: parent.verticalCenter
                    size: 30
                    kind: modelData.kind || NotifIcons.kindOf(modelData.app, modelData.summary, "", modelData.urgent ? "critical" : "normal", modelData.desktop)
                    appIcon: modelData.icon || ""
                    desktop: modelData.desktop || ""
                }
                Column {
                    anchors.left: ico.right
                    anchors.leftMargin: 10
                    anchors.right: tm.left
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    Txt {
                        width: parent.width
                        maximumLineCount: 1
                        text: (modelData.summary || modelData.app || "").replace(/\s*\n+\s*/g, " · ")
                    }
                    Txt {
                        width: parent.width
                        // mehrzeilige Meldungen (Browser: "Seite\n\nText") in eine Zeile, sonst überlappen die Einträge
                        maximumLineCount: 1
                        text: (modelData.body || "").replace(/\s*\n+\s*/g, " · ")
                        visible: text !== ""
                        color: Theme.textMuted
                        font.pixelSize: 12
                        font.weight: Font.Normal
                    }
                }
                // Klick = wie Enter (Datei öffnen bzw. App nach vorn); Rechtsklick auf Screenshot/Aufnahme = im Ordner zeigen
                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    cursorShape: Qt.PointingHandCursor
                    onClicked: e => {
                        if (e.button === Qt.RightButton) {
                            if (row.modelData.file)
                                Notifs.showFile(row.modelData.file);
                        } else {
                            tile.openEntry(row.modelData);
                        }
                    }
                }
                MonoTxt {
                    id: tm
                    anchors.right: parent.right
                    anchors.rightMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    text: modelData.time
                    color: row.on ? Theme.accentText : Theme.textFaint
                    font.pixelSize: 11
                    opacity: rowHover.hovered ? 0 : 1
                }
                HoverHandler {
                    id: rowHover
                }
                // löschen: ✕ beim Überfahren an der Stelle der Uhrzeit
                Icon {
                    anchors.right: parent.right
                    anchors.rightMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    visible: rowHover.hovered
                    name: "close"
                    size: 16
                    color: delArea.containsMouse ? Theme.accentText : Theme.textFaint
                    MouseArea {
                        id: delArea
                        anchors.fill: parent
                        anchors.margins: -8
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Notifs.removeHistory(row.modelData.key)
                    }
                }
            }
        }
    }

    // Tasten nur zeigen, solange die Kachel die Tastatur hat
    KeyHintRow {
        visible: tile.kb
        anchors.bottom: parent.bottom
        width: parent.width
        small: true
        gap: Theme.space3
        hints: tile.sel < 0 ? [["↵", "clear all"], ["↓", "list"], ["Esc", "back"]]
                            : [["↑↓", "select"], ["↵", "open"], ["Del", "delete"], ["Esc", "back"]]
    }
}

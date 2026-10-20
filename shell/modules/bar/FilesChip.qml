import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import qs.services
import qs.components

// Dateimanager-Chip in der Bar (ersetzt den Downloads-Chip): Klick = Dolphin im Home, Mittelklick = Dolphin im
// Downloads-Ordner (dort landet, was der Browser lädt), Rechtsklick = die letzten Downloads (DownloadsPopout.qml).
// Dolphin fest wie Super+E: inode/directory zeigt per xdg-mime auf kitty-open, ein echter Dateimanager ist dort nicht eingetragen.
// Bar-Modus (Super+Leertaste): E = Dateimanager (auch Super+E), D = letzte Downloads. Doku: docs/knowledge/shell-features.md
// IPC: qs ipc call files home|downloads · qs ipc call downloads open|close|toggle|status|cleanupPreview <tage>|testDir <pfad>|askCleanup
Chip {
    id: chip
    hintKey: BarKeys.keyFor("files")   // Bar-Modus (Super+Leertaste)

    property var barWindow: QsWindow.window

    function openDir(path: string): void {
        Launch.cmd(["dolphin", "--new-window", path]);
    }

    padding: 8
    active: popout.visible
    tip: "Files · middle: Downloads · right: recent downloads · Super+E"
    onClicked: mouse => {
        if (mouse.button === Qt.RightButton)
            popout.toggle();
        else if (mouse.button === Qt.MiddleButton)
            chip.openDir(Downloads.dir);
        else
            chip.openDir(Downloads.home);
    }

    Icon {
        anchors.verticalCenter: parent.verticalCenter
        name: "folder"
        size: 18
        color: Theme.textMuted
    }

    Connections {
        target: BarKeys
        function onActionRequested(name) {
            if (name === "files")
                chip.openDir(Downloads.home);
        }
    }

    DownloadsPopout {
        id: popout
        barWindow: chip.barWindow
        chip: chip
    }

    IpcHandler {
        target: "files"
        function home(): void {
            chip.openDir(Downloads.home);
        }
        function downloads(): void {
            chip.openDir(Downloads.dir);
        }
    }

    // vom früheren Downloads-Chip übernommen (Popout hängt jetzt hier)
    IpcHandler {
        target: "downloads"
        function open(): void {
            if (!popout.visible)
                popout.openWith(false);      // ohne Klick-Fang: ein Klick daneben schließt nicht, dafür `downloads close`
        }
        function close(): void {
            popout.close();
        }
        function toggle(): void {
            popout.toggle();
        }
        function status(): string {
            return JSON.stringify({ dir: Downloads.dir, items: Downloads.items.length, loading: Downloads.loading, fresh: Downloads.fresh,
                freshName: Downloads.freshName, recent: Downloads.recent.map(i => i.name + (i.loading ? " (loading)" : "")) });
        }
        // nur anzeigen, was „Clean up“ in den Papierkorb legen würde (ändert nichts)
        function cleanupPreview(days: int): string {
            return Downloads.oldItems(days > 0 ? days : Downloads.cleanupDays).map(i => i.name).join("\n");
        }
        // Test: anderen Ordner zeigen (leer = zurück zu ~/Downloads), wird nicht gespeichert
        function testDir(path: string): void {
            Downloads.testDir = path;
        }
        // Test: Rückfrage „Clean up“ zeigen (Bestätigen nur per Klick)
        function askCleanup(): void {
            popout.asking = true;
        }
    }
}

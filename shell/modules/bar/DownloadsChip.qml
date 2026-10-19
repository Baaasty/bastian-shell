import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import qs.services
import qs.components

// Downloads-Chip in der Bar: sonst ein leises Symbol; lädt gerade etwas -> „downloading“ im Glut-Ton,
// ist eben ein Download fertig geworden -> Haken-Symbol + Punkt (15 min oder bis man das Popout öffnet).
// Klick öffnet das Downloads-Popout (DownloadsPopout.qml). Doku: docs/DOWNLOADS.md
// IPC: qs ipc call downloads open|close|toggle|status|cleanupPreview <tage>|testDir <pfad>|fresh
Chip {
    id: chip
    hintKey: BarKeys.keyFor("downloads")   // Bar-Modus (Super+B)

    property var barWindow: QsWindow.window

    padding: 7
    active: popout.visible
    onClicked: popout.toggle()

    Item {
        anchors.verticalCenter: parent.verticalCenter
        width: 18
        height: 18
        Icon {
            anchors.centerIn: parent
            name: Downloads.loading ? "downloading" : Downloads.fresh ? "download_done" : "download"
            size: 18
            color: Downloads.loading || Downloads.fresh ? Theme.accentText : Theme.textFaint
            Behavior on color { ColorAnimation { duration: Theme.fade } }
        }
        // „neu“-Punkt
        Rectangle {
            visible: Downloads.fresh && !Downloads.loading
            x: parent.width - 3
            y: -2
            width: 7
            height: 7
            radius: 3.5
            color: Theme.accent
            border.width: 1
            border.color: Theme.surfaceRaised
        }
    }

    DownloadsPopout {
        id: popout
        barWindow: chip.barWindow
        chip: chip
    }

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
        // Test: Chip im Zustand „neu“
        function fresh(): void {
            Downloads.freshAt = Date.now();
            Downloads.freshName = "test";
        }
        // Test: Rückfrage „Clean up“ zeigen (Bestätigen nur per Klick)
        function askCleanup(): void {
            popout.asking = true;
        }
    }
}

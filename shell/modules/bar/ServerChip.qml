import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import qs.services
import qs.components

// Server-Chip in der Bar (nur Symbol): Klick öffnet das Server-Popout (ServerPopout.qml) – Server aus scripts/sshs,
// pro Server Upload (Datei-Wähler der Shell), Files (yazi per SFTP) und Terminal. Läuft ein Upload: Symbol im Glut-Ton.
// Kürzel: Super+Alt+U (barmode popout servers). Doku: docs/SSHS.md
// IPC: qs ipc call servers open|close|toggle|status|refresh
Chip {
    id: chip
    hintKey: BarKeys.keyFor("servers")   // Bar-Modus (Super+B), falls dort ein Buchstabe vergeben ist

    property var barWindow: QsWindow.window

    padding: 7
    active: popout.visible
    onClicked: popout.toggle()

    Icon {
        anchors.verticalCenter: parent.verticalCenter
        name: Servers.uploading ? "cloud_upload" : "dns"
        size: 18
        color: Servers.uploading ? Theme.accentText : Theme.textFaint
        Behavior on color { ColorAnimation { duration: Theme.fade } }
    }

    ServerPopout {
        id: popout
        barWindow: chip.barWindow
        chip: chip
    }

    IpcHandler {
        target: "servers"
        function open(): void {
            if (!popout.visible)
                popout.openWith(false);      // ohne Klick-Fang: ein Klick daneben schließt nicht, dafür `servers close`
        }
        function close(): void {
            popout.close();
        }
        function toggle(): void {
            popout.toggle();
        }
        function refresh(): void {
            Servers.refresh();
        }
        function status(): string {
            return JSON.stringify({ ready: Servers.ready, error: Servers.error, servers: Servers.list.map(s => s.name),
                uploading: Servers.upHost, count: Servers.upCount, note: Servers.note });
        }
    }
}

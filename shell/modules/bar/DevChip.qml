import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import qs.services
import qs.components

// Dev-Dienste-Chip in der Bar: immer da (der Reiter Server mit Konsolen + sshs lebt im selben Popout), Zahl nur,
// solange etwas läuft (Dev-Server oder Container). Läuft ein sshs-Upload: Symbol im Glut-Ton.
// Klick öffnet das Dev-Dienste-Popout (DevPopout.qml). Daten: DevServices.qml (30 s, bei offenem Popout 5 s), Servers.qml.
// Kürzel: Super+Alt+U = Reiter Server (barmode popout servers, Alias in BarKeys.qml)
// IPC: qs ipc -p ~/Workspace/desktop-hyprland/shell call devservices open|close|toggle|refresh|status
//      qs ipc -p ~/Workspace/desktop-hyprland/shell call servers open|close|toggle|refresh|status (Reiter Server)
Chip {
    id: chip
    hintKey: BarKeys.keyFor("devservices")   // Bar-Modus (Super+B)

    property var barWindow: QsWindow.window
    property bool quiet: false          // Fokus-Modus der rechten Bar-Seite (von BarWindow)
    property bool forced: false         // per IPC im Fokus-Modus geöffnet: Chip kurz zeigen, damit das Popout einen Anker hat

    visible: !quiet || popout.visible || forced

    // erst den Chip einblenden (Row legt ihn neu an), dann öffnen
    function ipcOpen(tab: string): void {
        forced = true;
        popout.nextTab = tab;
        Qt.callLater(() => popout.openWith(false));      // ohne Klick-Fang: ein Klick daneben schließt nicht, dafür `devservices close`
    }
    padding: 9
    active: popout.visible
    onClicked: popout.toggle()

    Row {
        anchors.verticalCenter: parent.verticalCenter
        spacing: 5
        Icon {
            anchors.verticalCenter: parent.verticalCenter
            name: Servers.uploading ? "cloud_upload" : "dns"
            size: 18
            color: Servers.uploading ? Theme.accentText : Theme.textMuted
            Behavior on color { ColorAnimation { duration: Theme.fade } }
        }
        MonoTxt {
            anchors.verticalCenter: parent.verticalCenter
            visible: DevServices.count > 0
            text: DevServices.count
            color: Theme.textMuted
            font.pixelSize: 12
        }
    }

    DevPopout {
        id: popout
        barWindow: chip.barWindow
        chip: chip
        onVisibleChanged: if (!visible) chip.forced = false
    }

    IpcHandler {
        target: "devservices"
        function open(): void {
            if (!popout.visible)
                chip.ipcOpen("");
        }
        function close(): void {
            popout.close();
        }
        function toggle(): void {
            if (popout.visible)
                popout.close();
            else
                chip.ipcOpen("");
        }
        function refresh(): void {
            DevServices.refresh();
        }
        function status(): string {
            return DevServices.summary();
        }
    }
    // früher eigener Server-Chip: dieselben Befehle, öffnen jetzt den Reiter Server
    IpcHandler {
        target: "servers"
        function open(): void {
            if (popout.visible)
                popout.tab = "server";
            else
                chip.ipcOpen("server");
        }
        function close(): void {
            popout.close();
        }
        function toggle(): void {
            if (popout.visible)
                popout.close();
            else
                chip.ipcOpen("server");
        }
        function refresh(): void {
            Servers.refresh();
        }
        function status(): string {
            return JSON.stringify({ ready: Servers.ready, error: Servers.error, servers: Servers.list.map(s => s.name),
                consoles: Servers.consoles.map(c => ({ id: c.id, url: !!c.url })),
                uploading: Servers.upHost, count: Servers.upCount, note: Servers.note });
        }
    }
}

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import qs.services
import qs.components

// Dev-Dienste-Chip in der Bar: nur sichtbar, solange etwas läuft (Dev-Server oder Container), zeigt die Zahl.
// Klick öffnet das Dev-Dienste-Popout (DevPopout.qml). Daten: DevServices.qml (30 s, bei offenem Popout 5 s).
// IPC: qs ipc -p ~/Workspace/desktop-hyprland/shell call devservices open|close|toggle|refresh|status
Chip {
    id: chip
    hintKey: BarKeys.keyFor("devservices")   // Bar-Modus (Super+B)

    property var barWindow: QsWindow.window
    property bool quiet: false          // Fokus-Modus der rechten Bar-Seite (von BarWindow)
    property bool forced: false         // per IPC geöffnet, obwohl nichts läuft: Chip kurz zeigen, damit das Popout einen Anker hat

    visible: !quiet && (DevServices.count > 0 || popout.visible || forced)

    // erst den Chip einblenden (Row legt ihn neu an), dann öffnen
    function ipcOpen(): void {
        forced = true;
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
            name: "dns"
            size: 18
            color: Theme.textMuted
        }
        MonoTxt {
            anchors.verticalCenter: parent.verticalCenter
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
                chip.ipcOpen();
        }
        function close(): void {
            popout.close();
        }
        function toggle(): void {
            if (popout.visible)
                popout.close();
            else
                chip.ipcOpen();
        }
        function refresh(): void {
            DevServices.refresh();
        }
        function status(): string {
            return DevServices.summary();
        }
    }
}

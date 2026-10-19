import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import qs.services
import qs.components

// Netz-Chip in der Bar (rechts neben dem Lautsprecher): nur ein Symbol (Kabel/WLAN/VPN), offline = Wolke durchgestrichen in Warnfarbe.
// Klick öffnet das Netz-Popout (NetPopout.qml). Die Daten kommen aus NetInfo.qml: nur bei Netz-Ereignissen, nicht per Dauer-Polling.
// IPC (zum Testen ohne Maus): qs ipc call net open|close|toggle|refresh|status
Chip {
    id: chip
    hintKey: BarKeys.keyFor("net")   // Bar-Modus (Super+B)

    property var barWindow: QsWindow.window

    padding: 9
    active: popout.visible
    onClicked: popout.toggle()

    Icon {
        anchors.verticalCenter: parent.verticalCenter
        name: !NetInfo.up ? "cloud_off" : NetInfo.kind === "wifi" ? "wifi" : NetInfo.kind === "vpn" ? "vpn_lock" : "lan"
        size: 18
        color: NetInfo.up ? Theme.textMuted : Theme.warning
    }

    NetPopout {
        id: popout
        barWindow: chip.barWindow
        chip: chip
    }

    IpcHandler {
        target: "net"
        function open(): void {
            if (!popout.visible)
                popout.openWith(false);      // ohne Klick-Fang: ein Klick daneben schließt nicht, dafür `net close`
        }
        function close(): void {
            popout.close();
        }
        function toggle(): void {
            popout.toggle();
        }
        function refresh(): void {
            NetInfo.refresh();
        }
        function status(): string {
            return NetInfo.summary();
        }
    }
}

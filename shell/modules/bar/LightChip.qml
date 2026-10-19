import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import qs.services
import qs.components

// Licht-Chip in der Bar (links neben dem Lautsprecher). Klick öffnet das Licht-Popout (LightPopout.qml):
// Key Light, Hue-Szenen + Farbwähler, Kamera-Belichtung – derselbe Licht-Teil wie in der Dashboard-Kachel.
// Die Birne ist immer grau wie die anderen Bar-Symbole (kein Glut-Ton mehr, wenn ein Licht brennt – darum auch kein Nachsehen).
// IPC (zum Testen ohne Maus): qs ipc call light open|close|toggle|status|picker
Chip {
    id: chip

    property var barWindow: QsWindow.window

    padding: 8
    hintKey: BarKeys.keyFor("light")
    active: popout.visible
    onClicked: popout.toggle()

    Icon {
        anchors.verticalCenter: parent.verticalCenter
        name: "lightbulb"
        size: 18
        color: Theme.textMuted
    }

    LightPopout {
        id: popout
        barWindow: chip.barWindow
        chip: chip
    }

    IpcHandler {
        target: "light"
        function open(): void {
            if (!popout.visible)
                popout.openWith(false);      // ohne Klick-Fang: ein Klick daneben schließt nicht, dafür `light close`
        }
        function close(): void {
            popout.close();
        }
        function toggle(): void {
            popout.toggle();
        }
        function status(): string {
            return JSON.stringify({ keyLight: { online: KeyLight.online, on: KeyLight.on, brightness: KeyLight.brightness, kelvin: KeyLight.kelvin },
                hue: { status: Hue.status, room: Hue.group ? Hue.group.name : "", anyOn: Hue.anyOn, others: Hue.othersCount },
                camera: { present: Camera.present, busy: Camera.busy, percent: Camera.percent } });
        }
        // Test: Farbwähler im offenen Popout auf/zu
        function picker(): void {
            popout.panel.pickerOpen = !popout.panel.pickerOpen;
        }
    }
}

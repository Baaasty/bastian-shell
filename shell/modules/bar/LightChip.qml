import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import qs.services
import qs.components

// Licht-Chip in der Bar (links neben dem Lautsprecher). Klick öffnet das Licht-Popout (LightPopout.qml):
// Key Light, Hue-Szenen + Farbwähler, Kamera-Belichtung – derselbe Licht-Teil wie in der Dashboard-Kachel.
// Brennt ein Licht (Key Light oder irgendeine Hue-Lampe), steht die Birne leise im Glut-Ton. Dafür sieht der Chip
// alle 60 s einmal nach (nur solange die Bar da ist); bei offenem Popout/Dashboard pollen die Dienste ohnehin öfter.
// IPC (zum Testen ohne Maus): qs ipc call light open|close|toggle|status|picker
Chip {
    id: chip

    property var barWindow: QsWindow.window
    readonly property bool lit: KeyLight.on || Hue.anyOn

    padding: 8
    hintKey: BarKeys.keyFor("light")
    active: popout.visible
    onClicked: popout.toggle()

    Icon {
        anchors.verticalCenter: parent.verticalCenter
        name: "lightbulb"
        size: 18
        color: chip.lit ? Theme.accentText : Theme.textMuted
        Behavior on color { ColorAnimation { duration: Theme.fade } }
    }

    Timer {
        interval: 60000
        repeat: true
        running: chip.visible && !Windows.bare && !KeyLight.active
        triggeredOnStart: true
        onTriggered: {
            KeyLight.refresh();
            Hue.refresh();
        }
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

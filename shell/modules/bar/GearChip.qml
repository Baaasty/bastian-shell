import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import qs.services
import qs.components

// Gear-Chip (rechts neben dem Licht-Chip): Klick öffnet das Gear-Popout (GearPopout.qml) – PC-Licht, Maus, System.
// Grau wie die Birne; Akku der Maus unter 15 % (nicht am Laden): Akku-Symbol + Prozent im warning-Ton.
// IPC (zum Testen ohne Maus): qs ipc call gear open|close|toggle|status|geom|tune <sat> <bri>|stage <i>|revert
Chip {
    id: chip

    property var barWindow: QsWindow.window

    padding: 8
    hintKey: BarKeys.keyFor("gear")
    active: popout.visible
    tip: Devices.lowBattery ? "Mouse battery " + Devices.battery + " %" : ""
    onClicked: popout.toggle()

    Icon {
        anchors.verticalCenter: parent.verticalCenter
        name: Devices.lowBattery ? "battery_alert" : "mouse"
        size: 18
        color: Devices.lowBattery ? Theme.warning : Theme.textMuted
    }
    MonoTxt {
        anchors.verticalCenter: parent.verticalCenter
        visible: Devices.lowBattery
        text: Devices.battery + "%"
        color: Theme.warning
        font.pixelSize: 12
    }

    GearPopout {
        id: popout
        barWindow: chip.barWindow
        chip: chip
    }

    IpcHandler {
        target: "gear"
        function open(): void {
            if (!popout.visible)
                popout.openWith(false);      // ohne Klick-Fang (wie light open), zu mit `gear close`
        }
        function close(): void {
            popout.close();
        }
        function toggle(): void {
            popout.toggle();
        }
        function status(): string {
            return JSON.stringify({
                rgb: { ready: Devices.rgbReady, installed: Devices.rgbInstalled, on: Devices.rgbOn, color: Devices.rgbToken, led: Devices.rgbLed,
                    saturation: Devices.shownSat, brightness: Devices.shownBri, running: Devices.rgbRunning, last: Devices.rgbLast },
                mouse: { state: Devices.mouseState, battery: Devices.battery, charging: Devices.charging, low: Devices.lowBattery,
                    profile: Devices.profile, resolutions: Devices.shownRes, defaultIndex: Devices.shownDefault, color: Devices.shownColor,
                    dirty: Devices.mouseDirty, saving: Devices.saving, note: Devices.saveNote }
            });
        }
        // Tests (ohne Flash): Balken-Entwurf PC-Licht, DPI-Stufe zum Bearbeiten wählen, Maus-Entwurf verwerfen
        function tune(sat: real, bri: real): void {
            Devices.tuneRgb(sat, bri);
        }
        function stage(i: int): void {
            popout.stage = i;
        }
        function revert(): void {
            Devices.revertMouse();
        }
        // Lage der Karte auf dem Bildschirm (Test-Screenshot nur dieses Bereichs)
        function geom(): string {
            const sc = chip.barWindow ? chip.barWindow.screen : null;
            return JSON.stringify({ x: (sc ? sc.x : 0) + popout.anchor.rect.x + 1 - popout.cardW, y: (sc ? sc.y : 0) + popout.anchor.rect.y + 1,
                w: popout.cardW, h: Math.ceil(popout.cardH) });
        }
    }
}

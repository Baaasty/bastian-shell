import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import qs.services
import qs.components

// Lautsprecher-Chip in der Bar (rechts neben dem Licht-Chip). Klick öffnet den Mixer (MixerPopout.qml):
// Lautstärke pro App, GoXLR-Pegel und -Routing. Das Symbol zeigt nur, ob der Ausgang stumm ist.
// IPC (zum Testen ohne Maus): qs ipc call mixer open|close|toggle|status|setApp <app> <0-100>|muteApp <app> <true|false>
Chip {
    id: chip
    hintKey: BarKeys.keyFor("mixer")   // Bar-Modus (Super+Leertaste)

    property var barWindow: QsWindow.window

    padding: 8
    active: popout.visible
    onClicked: popout.toggle()

    Icon {
        anchors.verticalCenter: parent.verticalCenter
        name: Audio.muted ? "volume_off" : "volume_up"
        size: 18
        color: Audio.muted ? Theme.warning : Theme.textMuted
    }

    MixerPopout {
        id: popout
        barWindow: chip.barWindow
        chip: chip
    }

    IpcHandler {
        target: "mixer"
        function open(): void {
            if (!popout.visible)
                popout.openWith(false);      // ohne Klick-Fang: ein Klick daneben schließt nicht, dafür `mixer close`
        }
        function close(): void {
            popout.close();
        }
        function toggle(): void {
            popout.toggle();
        }
        function status(): string {
            return Mixer.summary();
        }
        // Lautstärke einer App (0-100); nie der Ausgang
        function setApp(app: string, percent: int): string {
            const a = Mixer.findApp(app);
            if (!a)
                return "no such app: " + app;
            Mixer.setAppVolume(a, percent / 100);
            return a.name + " -> " + percent;
        }
        function muteApp(app: string, on: bool): string {
            const a = Mixer.findApp(app);
            if (!a)
                return "no such app: " + app;
            Mixer.setAppMuted(a, on);
            return a.name + (on ? " muted" : " unmuted");
        }
    }
}

import QtQuick
import Quickshell.Io
import qs.config
import qs.services
import qs.components

// Einstellungen-Chip (Gruppe „Programme“: Files · Browser · Settings): Klick holt das offene KDE-Systemeinstellungen-Fenster
// nach vorn, sonst startet es sie. Mittelklick = direkt die Bluetooth-Seite.
// systemsettings.desktop ist der Override aus config/applications/ (SDL_HIDAPI_LIBUSB=0: sonst hängt der Start 15–17 s
// in kcm_gamecontroller über libusb an einem defekten USB-Port); Seiten direkt darum mit derselben Umgebung.
// Display (kcm_kscreen) braucht KWin, darum nicht angeboten.
// Bar-Modus (Super+Leertaste): I · Kürzel Super+I (wie KDE, dort Meta+I)
// IPC: qs ipc call settings open|bluetooth|status
Chip {
    id: chip
    hintKey: BarKeys.keyFor("settings")   // Bar-Modus (Super+Leertaste)

    readonly property var classRe: /systemsettings/i

    function windows(): var {
        return Hypr.toplevels.values
            .filter(t => Hypr.usable(t) && classRe.test(Hypr.appId(t)) && !Hypr.isStashed(t))
            .sort((a, b) => Hypr.stacking(b) - Hypr.stacking(a));
    }
    function open(): void {
        const wins = windows();
        if (wins.length)
            Hypr.activate(wins[0]);
        else
            Launch.app("systemsettings");
    }
    // eine Seite direkt: läuft die App schon, wechselt sie nur die Seite (eine Instanz, D-Bus)
    function page(kcm: string): void {
        Launch.cmd(["env", "SDL_HIDAPI_LIBUSB=0", "systemsettings", kcm]);
    }

    padding: 8
    tip: "System Settings · middle: Bluetooth · Super+I"
    onClicked: mouse => {
        if (mouse.button === Qt.MiddleButton)
            chip.page("kcm_bluetooth");
        else if (mouse.button === Qt.LeftButton)
            chip.open();
    }

    Icon {
        anchors.verticalCenter: parent.verticalCenter
        name: "settings"
        size: 18
        color: Theme.textMuted
    }

    Connections {
        target: BarKeys
        function onActionRequested(name) {
            if (name === "settings")
                chip.open();
        }
    }

    IpcHandler {
        target: "settings"
        function open(): void {
            chip.open();
        }
        function bluetooth(): void {
            chip.page("kcm_bluetooth");
        }
        function status(): string {
            return JSON.stringify(chip.windows().map(t => Hypr.title(t)));
        }
    }
}

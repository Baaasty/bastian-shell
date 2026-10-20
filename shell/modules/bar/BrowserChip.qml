import QtQuick
import Quickshell.Io
import qs.config
import qs.services
import qs.components

// Browser-Chip in der Bar (Helium, Standard für http/https laut xdg-mime): Klick holt das zuletzt benutzte
// Helium-Fenster nach vorn (ist es schon vorn: das nächste, reihum wie in der App-Leiste), sonst startet Helium.
// Mittelklick = neues Fenster. Weggeräumte Fenster (special:parked) zählen nicht.
// Bar-Modus (Super+Leertaste): B · Kürzel Super+B, alt Super+W (hypr/binds.conf, ohne Shell startet es Helium direkt)
// IPC: qs ipc call browser focus|newWindow|status
Chip {
    id: chip
    hintKey: BarKeys.keyFor("browser")   // Bar-Modus (Super+Leertaste)

    readonly property string desktopId: "helium"
    readonly property var classRe: /helium/i

    // Helium-Fenster, vorderstes zuerst
    function windows(): var {
        return Hypr.toplevels.values
            .filter(t => Hypr.usable(t) && classRe.test(Hypr.appId(t)) && !Hypr.isStashed(t))
            .sort((a, b) => Hypr.stacking(b) - Hypr.stacking(a));
    }
    function raise(): void {   // nicht „focus“: kollidiert mit Item.focus (bool)
        const wins = windows();
        if (!wins.length) {
            Launch.app(desktopId);
            return;
        }
        Hypr.activate(wins.length > 1 && Hypr.isActive(wins[0]) ? wins[1] : wins[0]);
    }
    function newWindow(): void {
        Launch.cmd([desktopId, "--new-window"]);
    }

    padding: 8
    tip: "Browser · middle: new window · Super+B"
    onClicked: mouse => {
        if (mouse.button === Qt.MiddleButton)
            chip.newWindow();
        else if (mouse.button === Qt.LeftButton)
            chip.raise();
    }

    Icon {
        anchors.verticalCenter: parent.verticalCenter
        name: "public"
        size: 18
        color: Theme.textMuted
    }

    Connections {
        target: BarKeys
        function onActionRequested(name) {
            if (name === "browser")
                chip.raise();
        }
    }

    IpcHandler {
        target: "browser"
        function focus(): void {
            chip.raise();
        }
        function newWindow(): void {
            chip.newWindow();
        }
        function status(): string {
            return JSON.stringify(chip.windows().map(t => Hypr.title(t)));
        }
    }
}

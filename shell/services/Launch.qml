pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Einzige Stelle, die Apps startet: nie als Kind von Quickshell (sonst sterben sie beim Neustart mit).
// Hyprland: über "uwsm app --", wenn uwsm da ist (eigene app-…-Unit), sonst "systemd-run --user --scope".
// launched: es geht gleich ein Fenster auf -> Dashboard & Co. machen Platz
Singleton {
    id: root

    signal launched()

    // VS Code: natives RPM (/usr/bin/code), wenn installiert, sonst das Flatpak.
    // codeNative wird beim Start und alle 5 min geprüft; code() entscheidet beim Aufruf selbst neu.
    readonly property string codeFlatpak: "com.visualstudio.code"
    property bool codeNative: false
    // uwsm vorhanden? (einmal beim Start geprüft)
    property bool uwsm: false

    readonly property var scope: ["systemd-run", "--user", "--scope", "--slice=app.slice", "--quiet", "--"]

    // App über ihre .desktop-ID (mit oder ohne ".desktop")
    function app(desktopId: string): void {
        const id = String(desktopId).replace(/\.desktop$/, "");
        if (uwsm) {
            Quickshell.execDetached(["uwsm", "app", "--", id + ".desktop"]);
        } else {
            const e = DesktopEntries.byId(id) ?? DesktopEntries.heuristicLookup(id);
            if (!e || !e.command || !e.command.length) {
                console.warn("Launch.app: keine .desktop-Datei für " + id);
                return;
            }
            const cmdline = e.runInTerminal ? ["xdg-terminal-exec"].concat(e.command) : e.command;
            if (e.workingDirectory)
                Quickshell.execDetached({ command: scope.concat(cmdline), workingDirectory: e.workingDirectory });
            else
                Quickshell.execDetached(scope.concat(cmdline));
        }
        launched();
    }

    function cmd(args: var): void {
        Quickshell.execDetached((uwsm ? ["uwsm", "app", "--"] : scope).concat(args));
        launched();
    }

    // Discord (Chat-Client, Name steht in Chat.qml), Spotify, Thunderbird, Equibop (alter Rückfall): natives RPM zuerst, sonst das Flatpak (entscheidet scripts/app-run beim Start)
    readonly property string appRun: Quickshell.shellDir + "/../scripts/app-run"
    function run(name: string, args: var): void {
        cmd([appRun, name].concat(args || []));
    }

    // VS Code mit Argumenten starten, z. B. code(["--new-window", pfad])
    function code(args: var): void {
        cmd(["sh", "-c", "if [ -x /usr/bin/code ]; then exec /usr/bin/code \"$@\"; else exec flatpak run " + codeFlatpak + " \"$@\"; fi",
            "code"].concat(args || []));
        codeCheck.running = true;
    }

    Process {
        id: codeCheck
        command: ["test", "-x", "/usr/bin/code"]
        onExited: exitCode => root.codeNative = exitCode === 0
    }
    Process {
        id: uwsmCheck
        running: true
        command: ["sh", "-c", "command -v uwsm >/dev/null"]
        onExited: exitCode => root.uwsm = exitCode === 0
    }

    Timer {
        interval: 300000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: codeCheck.running = true
    }
}

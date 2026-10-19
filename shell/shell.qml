//@ pragma UseQApplication
//@ pragma Env QSG_RENDER_LOOP=threaded
// Desktop – Quickshell über Hyprland (Branch hyprland). Start: qs -p ~/Workspace/bastian-shell/shell
import QtQuick
import Quickshell
import Quickshell.Io
import qs.services
import qs.modules.background
import qs.modules.bar
import qs.modules.breaks
import qs.modules.cams
import qs.modules.claude
import qs.modules.crash
import qs.modules.dashboard
import qs.modules.focus
import qs.modules.idle
import qs.modules.launcher
import qs.modules.morning
import qs.modules.notifications
import qs.modules.recap
import qs.modules.notes
import qs.modules.screenshot
import qs.modules.switcher
import qs.modules.workbar
import qs.modules.osd
import qs.modules.power
import qs.modules.lock
import qs.modules.keys
import qs.modules.packages
import qs.modules.passwords
import qs.modules.polkit
import qs.modules.sharepicker
import qs.modules.layouts
import qs.modules.filepicker

ShellRoot {
    Background {}
    Bar {}
    BreakCard {}
    CamWall {}
    Attention {}
    Crash {}
    Dashboard {
        launcher: launcher
    }
    FocusUi {}
    Launcher {
        id: launcher
    }
    Popups {}
    MorningCard {}
    RecapCard {}
    ProjectTimeCard {}
    NotesWindow {}
    Snip {}
    Switcher {}
    WorkBar {}
    Osd {}
    Power {}
    Lock {}
    Idle {}
    Keys {}
    Packages {}
    Passwords {}
    Polkit {}
    SharePicker {}
    Layouts {}
    FilePickerPanel {}

    // Szenen-Engine (Singleton) beim Start laden: IPC "scene" und Fokus-Kopplung
    Component.onCompleted: Scenes.init()

    // qs ipc --any-display -p ~/Workspace/bastian-shell/shell call shell status
    IpcHandler {
        target: "shell"

        function status(): string {
            return JSON.stringify({
                topBlocked: Windows.topBlocked,
                fullscreen: Windows.fullscreen,
                game: Windows.game,
                desktops: Desktops.names,
                cpu: Cpu.temp,
                gpu: Gpu.temp,
                spotify: Players.spotify ? Players.spotify.trackTitle : null,
                notifications: Notifs.history.length
            });
        }
    }
}

pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// iCloud Drive jetzt synchronisieren (Launcher, Dateien-Popout). Die ganze Logik steckt in icloud-sync-now
// (auch im Dolphin-Kontextmenü): startet die Unit, meldet „läuft schon“ und am Ende per Benachrichtigung.
// Das Skript ist nach ~1 s fertig (der Wächter läuft als eigene Unit) – darum hier ein normaler Process.
Singleton {
    id: root

    readonly property string bin: Quickshell.shellDir + "/../system/dotfiles/.local/bin/icloud-sync-now"
    property string note: ""     // letzte Rückmeldung des Skripts, nach ein paar Sekunden wieder leer

    function syncNow(): void {
        if (!proc.running)
            proc.running = true;
    }

    Process {
        id: proc
        command: [root.bin]
        stdout: StdioCollector {
            onStreamFinished: {
                root.note = text.trim();
                noteClear.restart();
            }
        }
    }
    Timer {
        id: noteClear
        interval: 4000
        onTriggered: root.note = ""
    }
}

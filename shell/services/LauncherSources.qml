pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Daten für die Launcher-Wort-Präfixe:
//  - Wort-Präfixe zerlegen (c + Web-Kürzel aus WebShortcuts)
//  - Claude fragen (c <text>): neuer Chat mit dem Text in Claude Desktop (claude://), sonst claude.ai in Helium
Singleton {
    id: root

    // ------------------------------------------------------------ Präfixe
    // "c foo" -> { mode: "c ", term: "foo", key: "c" }, "yt foo" -> { mode: <Web-Chip>, term: "foo", key: "yt" }
    // einzelne Zeichen (# = / @) bleiben im Launcher
    function parse(q: string): var {
        const sp = q.indexOf(" ");
        if (sp > 0) {
            const key = q.slice(0, sp).toLowerCase();
            const rest = q.slice(sp + 1).trim();
            if (key === "c")
                return { mode: key + " ", term: rest, key: key };
            const w = WebShortcuts.find(key);
            if (w)
                return { mode: WebShortcuts.chipPrefix, term: rest, key: w.key };
        }
        return null;
    }

    // ------------------------------------------------------------ Claude fragen (c <text>)
    // Claude Desktop (distrobox "ubuntu") meldet sich für x-scheme-handler/claude an. Dann öffnet
    // claude://claude.ai/new?q=… dort einen neuen Chat mit dem Text (gleiches Schema wie die "New Chat"-Aktion
    // der .desktop-Datei); ohne Handler claude.ai/new?q=… in Helium. Handler wird beim ersten c-Präfix geprüft.
    property string claudeHandler: ""   // .desktop-ID, leer = keiner (oder noch nicht geprüft)
    property bool claudeChecked: false

    function claudeEnsure(): void {
        if (!claudeChecked && !claudeCheck.running)
            claudeCheck.running = true;
    }

    function askClaude(q: string): void {
        const t = String(q || "").trim();
        const path = "claude.ai/new" + (t ? "?q=" + encodeURIComponent(t) : "");
        if (claudeHandler)
            Launch.cmd(["xdg-open", "claude://" + path]);
        else
            Launch.cmd(["helium", "https://" + path]);
    }

    Process {
        id: claudeCheck
        command: ["xdg-mime", "query", "default", "x-scheme-handler/claude"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.claudeHandler = text.trim();
                root.claudeChecked = true;
            }
        }
    }
}

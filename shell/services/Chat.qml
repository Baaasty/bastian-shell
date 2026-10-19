pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Der Chat-Client (Discord-Familie) an EINER Stelle: Name, Startbefehl, Fensterklassen.
// Bastian nutzt das normale Discord (RPM von RPM Fusion, /usr/bin/discord, Klasse "discord") mit eigenem
// Equicord-Build (Plugin desktopBridge); das Flatpak com.discordapp.Discord (Klasse "com.discordapp.Discord") ist
// Rückfall, Equibop/Vesktop bleiben als alter Rückfall erkannt. Alles andere (Parked, Hypr.follows, Chip, Popout)
// fragt hier – nur die Hyprland-Regeln (hypr/pins.conf, rules.conf) und die Liste in config/hyprflow brauchen die
// Klassen noch einmal als Text (Hyprland kennt kein QML).
//
// Wichtig: nur Discord-Fenster, die der Shell als „Hintergrund-App“ gelten, sind hier gelistet.
Singleton {
    id: root

    // Anzeigename im UI
    readonly property string title: installed === "equibop" ? "Equibop" : "Discord"
    // Teile der Fensterklasse (kleingeschrieben, Teilstring-Treffer), bevorzugter Client zuerst
    // ("discord" trifft RPM und Flatpak "com.discordapp.Discord")
    readonly property var parts: ["discord", "equibop", "vesktop"]
    // Name für scripts/app-run (Launch.run): "discord" (RPM, sonst Flatpak) oder – nur falls Discord fehlt – "equibop"
    readonly property string runName: installed === "equibop" ? "equibop" : "discord"
    // Symbolname (Reihenfolge: erster vorhandener gewinnt)
    readonly property string icon: installed === "equibop" ? "equibop" : "discord"
    readonly property string iconFallback: "discord"

    // discord | equibop | none – entscheidet scripts/app-run --which (einmal beim Start)
    property string installed: "discord"

    function matches(appId: string): bool {
        const a = (appId || "").toLowerCase();
        return parts.some(p => a.indexOf(p) >= 0);
    }
    // welcher Teil gehört zur Klasse (z. B. "com.discordapp.Discord" -> "discord"), sonst ""
    function partOf(appId: string): string {
        const a = (appId || "").toLowerCase();
        return parts.find(p => a.indexOf(p) >= 0) ?? "";
    }

    Process {
        running: true
        command: ["sh", "-c", "r=\"$1\"; if \"$r\" --which discord >/dev/null; then echo discord; elif \"$r\" --which equibop >/dev/null; then echo equibop; else echo none; fi",
            "chat", Quickshell.shellDir + "/../scripts/app-run"]
        stdout: StdioCollector {
            onStreamFinished: {
                const w = text.trim();
                // Discord (RPM oder Flatpak) zuerst; Equibop nur, wenn kein Discord da ist
                root.installed = w === "equibop" || w === "none" ? w : "discord";
            }
        }
    }
}

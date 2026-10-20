pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "notifsound.js" as NS

// Kurze, warme Systemklänge (ein dumpfer, weicher Einzelton). Dateien: design/sounds/*.wav (erzeugt von theme/gen/sounds.py).
// Wiedergabe über pw-play (pipewire-utils, ist schon da) – kurz und losgelöst, kein App-Start, darum nicht über Launch.
// Eigener Stream-Name „desktop-sounds“ statt media.role „Notification“: WirePlumber merkt sich Lautstärke/Stumm je Rolle,
// und die Rolle Notification steht hier stumm (aus Plasma-Zeiten) – damit war nichts zu hören. Ziel = Standard-Sink (GoXLR „System“). Wann es klingt: notifsound.js; Konfig: Schlüssel „sound“ in config/notifications.json
// (über NotifRules, eigene Werte in ~/.config/desktop/notifications.json, live gelesen).
Singleton {
    id: root

    readonly property var cfg: NotifRules.cfg.sound && typeof NotifRules.cfg.sound === "object" ? NotifRules.cfg.sound : ({})
    readonly property string dir: Quickshell.shellDir + "/../design/sounds/"
    property real last: 0

    // Klang abspielen (ohne Regeln), Lautstärke aus der Konfig
    function play(name: string): void {
        // nur eigene Dateinamen, kein Pfad von außen (IPC)
        if (!/^[a-z][a-z-]*$/.test(name))
            return;
        Quickshell.execDetached(["pw-play", "-P", "{ application.name = \"desktop-sounds\" media.name = \"desktop-sounds\" }", "--volume", String(NS.volumeOf(cfg)), dir + name + ".wav"]);
    }

    // neue Meldung: n = { app, desktop, summary, urgent, low, suppress }, shown = Popup erscheint wirklich -> Grund (leer = klingt)
    function notification(n: var, shown: bool): string {
        const now = Date.now();
        const v = NS.soundFor(cfg, n, { shown: shown, now: now, last: last });
        if (v.name) {
            last = now;
            play(v.name);
        }
        return v.why;
    }

    IpcHandler {
        target: "sounds"

        // Probehören: play notify | notify-urgent
        function play(name: string): void {
            root.play(name || "notify");
        }
        // klingt diese Meldung jetzt? Nur Logik, spielt nichts (Popup als erschienen angenommen)
        function check(app: string, urgent: bool): string {
            return JSON.stringify(NS.soundFor(root.cfg, { app: app, desktop: "", summary: "", urgent: urgent, low: false, suppress: false }, { shown: true, now: Date.now(), last: root.last }));
        }
    }
}

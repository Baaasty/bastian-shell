pragma Singleton
import QtQuick
import Quickshell
import qs.config

// Daten für den Sound-Mixer in der Bar (Popout MixerPopout.qml). Nur App-Lautstärke setzen:
//  - Apps kommen aus AudioOut.qml (PipeWire-Streams, gruppiert nach App).
//  - Die System-Lautstärke (Standard-Ausgang) wird hier NIE verändert – sie bleibt fest auf 100 % (Wächter in Audio.qml,
//    Doku docs/setup/goxlr.md). Ausgang und Eingang sind fest (GoXLR System / Chat Mic) und werden hier nicht gewechselt.
//  - GoXLR-Pegel/Routing: gemeinsame Komponente components/GoxlrPanel.qml (Daten: GoXLR.qml).
// Doku: docs/knowledge/shell-features.md
Singleton {
    id: root

    // Symbolname aus dem Icon-Theme (leer = kein Treffer -> Platzhalter-Symbol)
    function appIcon(app: var): string {
        const n = app && app.nodes && app.nodes[0];
        const p = (n && n.properties) || {};
        const bin = (p["application.process.binary"] || "").toLowerCase();
        const cands = [p["application.icon-name"], bin, String(app.name).toLowerCase(), String(app.name).toLowerCase() + "-client", p["pipewire.access.portal.app_id"]];
        for (const c of cands)
            if (c && Quickshell.iconPath(c, true) !== "")
                return c;
        // Desktop-Eintrag der App (z. B. Spotify: com.spotify.Client)
        const e = DesktopEntries.heuristicLookup(String(app.name));
        if (e && e.icon && Quickshell.iconPath(e.icon, true) !== "")
            return e.icon;
        return "";
    }
    function appMuted(app: var): bool {
        return !!app && app.nodes.length > 0 && app.nodes.every(n => n && n.ready && n.audio && n.audio.muted);
    }
    function setAppMuted(app: var, on: bool): void {
        if (!app)
            return;
        for (const n of app.nodes)
            if (n && n.ready && n.audio)
                n.audio.muted = on;
    }
    // Lautstärke einer App (0..1): schreibt nur in deren Streams, nie in einen Ausgang
    function setAppVolume(app: var, v: real): void {
        AudioOut.setAppVolume(app, v);
    }
    function findApp(name: string): var {
        const q = String(name).toLowerCase();
        return AudioOut.apps.find(a => a.name.toLowerCase() === q) || AudioOut.apps.find(a => a.name.toLowerCase().includes(q)) || null;
    }

    // Gruppe einer App nach Bastians festem Setup: Spotify -> Music, Discord (alt Equibop) -> Chat, alles andere -> System
    function group(app: var): string {
        const n = String(app.name).toLowerCase();
        if (n.includes("spotify"))
            return "music";
        if (n.includes("equibop") || n.includes("discord") || n.includes("webrtc"))
            return "chat";
        return "system";
    }

    // ---- Text für IPC `mixer status` ----
    function summary(): string {
        const out = [];
        out.push("output: " + AudioOut.sinkLabel(AudioOut.sink) + (Audio.guarding ? " (locked 100%)" : "") + " vol=" + Math.round(Audio.volume * 100) + (Audio.muted ? " muted" : ""));
        for (const a of AudioOut.apps)
            out.push("app: " + a.name + " x" + a.nodes.length + " vol=" + Math.round(AudioOut.appVolume(a) * 100) + (appMuted(a) ? " muted" : ""));
        out.push("goxlr: " + (GoXLR.online ? GoXLR.levels.map(c => c.label + "=" + c.pct + (c.muted ? "m" : "")).join(" ") : "offline"));
        return out.join("\n");
    }
}

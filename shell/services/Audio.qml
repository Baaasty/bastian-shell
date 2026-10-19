pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire

// Lautstärke des Standard-Ausgangs (Pipewire, hier der GoXLR "System").
// Die Hardware-Fader am GoXLR laufen nicht über Pipewire und lösen nichts aus.
// Wächter: Bastian regelt alles am GoXLR, der PC-Ausgang bleibt fest auf 100 %. Ändert sich die Lautstärke des
// GoXLR-Standard-Ausgangs von außen, setzt der Wächter sie (entprellt) auf 1.0 zurück. Stumm bleibt bedienbar.
// Schalter: ~/.config/desktop/audio.json { "lockVolume": true, "onlyGoxlr": true } (fehlt = an), Doku docs/setup/goxlr.md
Singleton {
    id: root

    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property bool ready: !!sink && sink.ready && !!sink.audio
    readonly property real volume: ready ? sink.audio.volume : 0
    readonly property bool muted: ready && sink.audio.muted
    readonly property string name: sink ? (sink.description || sink.name) : ""

    // nur echte Änderungen, nicht das Laden oder ein Gerätewechsel
    signal changed()

    // Erst nach kurzer Ruhe gelten Werte als Ausgangslage
    property bool settled: false

    function setVolume(v: real): void {
        if (ready) {
            sink.audio.muted = false;
            sink.audio.volume = Math.max(0, Math.min(1.5, v));
        }
    }
    function toggleMute(): void {
        if (ready)
            sink.audio.muted = !sink.audio.muted;
    }

    Component.onCompleted: settle.restart()
    onSinkChanged: {
        settled = false;
        settle.restart();
    }
    onReadyChanged: {
        settled = false;
        settle.restart();
    }
    // kein Lautstärke-OSD, solange der Wächter die Lautstärke festhält
    onVolumeChanged: {
        if (settled && !guarding)
            changed();
        guard.restart();
    }
    onMutedChanged: if (settled) changed()

    // ---- Wächter ----
    property bool lockVolume: true
    property bool onlyGoxlr: true
    readonly property bool guarding: lockVolume && ready && (!onlyGoxlr || /goxlr/i.test(sink.name || ""))
    property var fixTimes: []        // Zeitpunkte der letzten Korrekturen (gegen Endlosschleifen)
    property double pausedUntil: 0

    onGuardingChanged: guard.restart()

    Timer {
        id: guard
        interval: 400
        onTriggered: {
            if (!root.guarding || Math.abs(root.volume - 1.0) < 0.005)
                return;
            const now = Date.now();
            if (now < root.pausedUntil)
                return;
            // kämpft ein Programm dagegen an (mehr als 6 Korrekturen in 10 s): 60 s Pause
            root.fixTimes = root.fixTimes.filter(t => now - t < 10000).concat([now]);
            if (root.fixTimes.length > 6) {
                root.pausedUntil = now + 60000;
                root.fixTimes = [];
                console.warn("Audio: Lautstärke-Wächter pausiert 60 s (ein Programm ändert sie ständig)");
                return;
            }
            root.sink.audio.volume = 1.0;
        }
    }

    FileView {
        path: Quickshell.env("HOME") + "/.config/desktop/audio.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoadFailed: {
            root.lockVolume = true;
            root.onlyGoxlr = true;
        }
        onLoaded: {
            try {
                const d = JSON.parse(text());
                root.lockVolume = d.lockVolume !== false;
                root.onlyGoxlr = d.onlyGoxlr !== false;
            } catch (e) {
                root.lockVolume = true;
                root.onlyGoxlr = true;
            }
        }
    }

    Timer {
        id: settle
        interval: 300
        onTriggered: root.settled = root.ready
    }

    // ohne Tracker liefert Pipewire keine Lautstärke
    PwObjectTracker {
        objects: [root.sink]
    }
}

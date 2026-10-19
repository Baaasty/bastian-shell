pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Stats-Kachel: Spotify-Hörzeit und Discord-Callzeit (heute + dieses Jahr), Bildschirmzeit-Verlauf.
// Lokal mitgezählt aus MPRIS (Players.spotify), Discord.qml und Focus.qml; dazu stats.fm (scripts/statsfm-stats,
// öffentliche API, Nutzer in secrets.json "statsfm.user") – zählt auch Handy/andere Geräte.
// Zähler liegen in ~/.local/state/desktop/stats.json (klein: ein Eintrag pro Tag, Songs nur die letzten 14 Tage):
//   { "v": 2, "voiceLastAt": ms, "live": { "at", "playing", "track", "inVoice" },
//     "days": { "2026-10-18": { "spotifyMs", "discordMs", "calls", "screenMin", "tracks": { "Titel · Künstler": ms } } } }
// Ein Call = zusammenhängende Voice-Zeit; Lücken unter 2 min (Reconnect, Kanalwechsel, Shell-Reload) zählen mit.
Singleton {
    id: root

    readonly property string path: (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state") + "/desktop/stats.json"
    readonly property int trackDays: 14          // so lange bleiben die Songlisten
    readonly property int maxTracks: 40          // pro Tag, die meistgehörten
    readonly property int callGapMs: 120000      // kürzere Unterbrechungen gehören zum selben Call

    property var days: ({})
    property bool loaded: false
    property bool dirty: false
    property real voiceLastAt: 0                 // zuletzt in Voice gesehen (für die Call-Zählung)
    property var savedLive: null                 // Zustand beim letzten Speichern (Reload-Lücke gutschreiben)

    // heute
    property string today: dayKey(new Date())
    property real spotifyToday: 0
    property real discordToday: 0
    property int callsToday: 0
    property string topSong: ""                  // Titel · Künstler, letzte 7 Tage (lokal)
    property real topSongMs: 0
    property real spotifyWeek: 0
    // dieses Jahr (lokal, seit Beginn der Aufzeichnung)
    property real spotifyYear: 0
    property real discordYear: 0
    property int callsYear: 0
    property string firstDay: today              // ältester Tag dieses Jahres in der Datei
    readonly property bool fullYear: firstDay.endsWith("-01-01")
    // Bildschirmzeit: Durchschnitt der letzten 7 Tage (ohne heute), 0 = noch keine Daten
    property real screenAvgMin: 0

    // stats.fm
    property bool sfmOk: false
    property bool sfmStale: false                // letzter guter Stand, aktueller Abruf ging schief
    property string sfmError: ""                 // unconfigured | network | private | notfound | limit
    property real sfmTodayMs: 0
    property int sfmTodayStreams: 0
    property string sfmTopToday: ""
    property real sfmYearMs: 0
    property int sfmYearStreams: 0
    property string sfmTopTrack: ""
    property string sfmTopArtist: ""
    property real sfmTopArtistMs: 0
    property string sfmDay: ""

    // zusammengeführt: stats.fm sieht alle Geräte, hinkt aber ein paar Minuten nach -> das Größere gilt
    readonly property bool sfmToday: sfmOk && sfmDay === today
    readonly property real listenToday: Math.max(spotifyToday, sfmToday ? sfmTodayMs : 0)
    readonly property real listenYear: Math.max(spotifyYear, sfmOk ? sfmYearMs : 0)
    readonly property bool listenYearFull: fullYear || sfmOk

    // Live-Zustand
    readonly property var player: Players.spotify
    readonly property bool livePlaying: player !== null && player.isPlaying
    readonly property string liveTrack: player && player.trackTitle ? player.trackTitle + (player.trackArtist ? " · " + player.trackArtist : "") : ""
    readonly property bool liveInVoice: Discord.inVoice
    readonly property bool inCall: Discord.inVoice

    // zuletzt gezählter Zustand: Zeit seit dem letzten Tick gehört noch dazu
    property real last: 0
    property bool wasPlaying: false
    property string wasTrack: ""
    property bool wasInVoice: false

    // Date -> "2026-10-18" (lokale Zeit)
    function dayKey(d: var): string {
        return d.getFullYear() + "-" + String(d.getMonth() + 1).padStart(2, "0") + "-" + String(d.getDate()).padStart(2, "0");
    }
    // ms -> "1 h 05" bzw. "42 min" (abgerundet)
    function fmtDur(ms: real): string {
        const m = Math.floor(ms / 60000);
        // ab 10 h nur Stunden ("303 h"), sonst liest sich die Minutenzahl wie ein Tippfehler ("303 h 13")
        if (m >= 600)
            return Math.floor(m / 60) + " h";
        return m >= 60 ? Math.floor(m / 60) + " h " + String(m % 60).padStart(2, "0") : m + " min";
    }
    // "2026-10-18" -> "Oct 18"
    function fmtDay(key: string): string {
        const p = key.split("-");
        return ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"][Number(p[1]) - 1] + " " + Number(p[2]);
    }

    function bucket(key: string): var {
        if (!days[key])
            days[key] = { spotifyMs: 0, discordMs: 0, calls: 0, screenMin: 0, tracks: {} };
        return days[key];
    }

    // Zeit seit dem letzten Tick dem vorigen Zustand gutschreiben, dann den neuen Zustand merken
    function tick(): void {
        if (!loaded)
            return;
        const now = Date.now();
        // nach Ruhezustand o. Ä. nicht die ganze Lücke zählen
        const dt = last > 0 ? Math.max(0, Math.min(now - last, 30000)) : 0;
        last = now;
        const key = dayKey(new Date(now));
        const b = bucket(key);
        if (dt > 0 && wasPlaying) {
            b.spotifyMs += dt;
            if (wasTrack !== "")
                b.tracks[wasTrack] = (b.tracks[wasTrack] || 0) + dt;
            dirty = true;
        }
        if (dt > 0 && wasInVoice) {
            b.discordMs += dt;
            dirty = true;
        }
        // Call: neu nur nach > 2 min ohne Voice; solange drin, Zeitstempel mitziehen
        if (liveInVoice) {
            if (now - voiceLastAt > callGapMs) {
                b.calls = (b.calls || 0) + 1;
                dirty = true;
            }
            voiceLastAt = now;
        }
        // Bildschirmzeit kommt aus Focus.qml (zählt pro Tag selbst), hier nur für den Verlauf
        if (Focus.day === key && Focus.screenMin !== (b.screenMin || 0)) {
            b.screenMin = Focus.screenMin;
            dirty = true;
        }
        // Ereignis (Play/Pause, Songwechsel, Call an/aus): gleich sichern, Shell-Neustarts verlieren sonst Zeit
        const changed = wasPlaying !== livePlaying || wasTrack !== liveTrack || wasInVoice !== liveInVoice;
        wasPlaying = livePlaying;
        wasTrack = liveTrack;
        wasInVoice = liveInVoice;
        summarize();
        if (changed)
            save();
    }

    function summarize(): void {
        const now = new Date();
        const key = dayKey(now);
        const b = days[key] || { spotifyMs: 0, discordMs: 0, calls: 0, tracks: {} };
        today = key;
        spotifyToday = b.spotifyMs;
        discordToday = b.discordMs;
        callsToday = b.calls || 0;
        // dieses Jahr
        const year = String(now.getFullYear()) + "-";
        let sy = 0, dy = 0, cy = 0, first = key;
        for (const k in days) {
            if (!k.startsWith(year))
                continue;
            sy += days[k].spotifyMs || 0;
            dy += days[k].discordMs || 0;
            cy += days[k].calls || 0;
            if (k < first)
                first = k;
        }
        spotifyYear = sy;
        discordYear = dy;
        callsYear = cy;
        firstDay = first;
        // letzte 7 Tage: Hörzeit, Top-Song, Bildschirmzeit-Schnitt (ohne heute)
        const sum = {};
        let week = 0, scr = 0, scrDays = 0;
        const d = new Date();
        for (let i = 0; i < 7; i++) {
            const day = days[dayKey(d)];
            if (day) {
                week += day.spotifyMs || 0;
                for (const t in day.tracks || {})
                    sum[t] = (sum[t] || 0) + day.tracks[t];
                if (i > 0 && (day.screenMin || 0) > 0) {
                    scr += day.screenMin;
                    scrDays++;
                }
            }
            d.setDate(d.getDate() - 1);
        }
        let top = "", topMs = 0;
        for (const t in sum) {
            if (sum[t] > topMs) {
                top = t;
                topMs = sum[t];
            }
        }
        spotifyWeek = week;
        topSong = top;
        topSongMs = topMs;
        screenAvgMin = scrDays > 0 ? scr / scrDays : 0;
    }

    function save(): void {
        if (!loaded)
            return;
        // Tage dieses Jahres (plus 14 Tage zurück über den Jahreswechsel) behalten, Songlisten nur 14 Tage
        const now = new Date();
        const year = String(now.getFullYear()) + "-";
        const cut = new Date();
        cut.setDate(cut.getDate() - trackDays);
        const cutKey = dayKey(cut);
        const out = {};
        for (const k in days) {
            if (!k.startsWith(year) && k < cutKey)
                continue;
            const b = days[k];
            const e = { spotifyMs: Math.round(b.spotifyMs || 0), discordMs: Math.round(b.discordMs || 0), calls: b.calls || 0, screenMin: b.screenMin || 0 };
            if (k >= cutKey) {
                const tracks = {};
                Object.keys(b.tracks || {}).sort((x, y) => b.tracks[y] - b.tracks[x]).slice(0, maxTracks)
                    .forEach(t => tracks[t] = Math.round(b.tracks[t]));
                e.tracks = tracks;
            }
            out[k] = e;
        }
        days = out;
        file.setText(JSON.stringify({
            v: 2, voiceLastAt: voiceLastAt,
            live: { at: last, playing: wasPlaying, track: wasTrack, inVoice: wasInVoice },
            days: out
        }));
        dirty = false;
    }

    // Zustandswechsel sofort verbuchen, damit die Zeit beim richtigen Song/Call landet
    onLivePlayingChanged: tick()
    onLiveTrackChanged: tick()
    onLiveInVoiceChanged: tick()

    Timer {
        interval: 10000
        repeat: true
        running: root.loaded
        onTriggered: root.tick()
    }
    // alle 30 s sichern (auch ohne Änderung, damit "live.at" frisch bleibt und Reloads nahtlos weiterzählen)
    Timer {
        interval: 30000
        repeat: true
        running: root.loaded
        onTriggered: root.save()
    }
    Component.onDestruction: {
        tick();
        save();
    }

    FileView {
        id: file
        path: root.path
        printErrors: false
        blockWrites: true
        onLoaded: {
            if (root.loaded)
                return;
            try {
                const d = JSON.parse(text());
                root.days = d && typeof d.days === "object" ? d.days : {};
                root.voiceLastAt = d.voiceLastAt || 0;
                root.savedLive = d.live || null;
                if (!d.v)
                    root.migrate();
            } catch (e) {
                root.days = {};
            }
            root.start();
        }
        onLoadFailed: {
            if (!root.loaded) {
                root.days = {};
                root.start();
            }
        }
    }

    // v1 zählte jeden Reconnect/Kanalwechsel als neuen Call (z. B. "12 min · 15 calls").
    // Verlauf der Einzel-Calls gibt es nicht -> Tage mit Callzeit als ein Call werten.
    function migrate(): void {
        const key = dayKey(new Date());
        for (const k in days) {
            const b = days[k];
            b.calls = (b.discordMs || 0) > 0 ? 1 : 0;
            if (k === key && b.discordMs > 0)
                voiceLastAt = Math.max(voiceLastAt, b.lastCall || 0, Date.now());
            delete b.lastCall;
        }
        dirty = true;
    }

    function start(): void {
        loaded = true;
        // Reload: Lücke seit dem letzten Speichern dem damaligen Zustand gutschreiben (höchstens 45 s alt)
        const s = savedLive;
        if (s && s.at > 0 && Date.now() - s.at < 45000) {
            last = s.at;
            wasPlaying = s.playing === true;
            wasTrack = s.track || "";
            wasInVoice = s.inVoice === true;
        } else {
            last = 0;
            wasPlaying = false;
            wasTrack = "";
            wasInVoice = false;
        }
        tick();
        refreshSfm();
    }

    // ---------- stats.fm ----------
    // Skript cacht selbst (höchstens alle 30 min ein echter Abruf, 5 kleine Anfragen)
    function refreshSfm(): void {
        if (!sfm.running)
            sfm.running = true;
    }
    function applySfm(d: var): void {
        sfmTodayMs = d.today.ms || 0;
        sfmTodayStreams = d.today.streams || 0;
        sfmTopToday = d.today.topTrack || "";
        sfmYearMs = d.year.ms || 0;
        sfmYearStreams = d.year.streams || 0;
        sfmTopTrack = d.year.topTrack || "";
        sfmTopArtist = d.year.topArtist || "";
        sfmTopArtistMs = d.year.topArtistMs || 0;
        sfmDay = d.day || "";
        sfmOk = true;
    }

    Process {
        id: sfm
        command: [Quickshell.shellDir + "/../scripts/statsfm-stats"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const d = JSON.parse(text);
                    if (d.ok) {
                        root.applySfm(d);
                        root.sfmStale = false;
                        root.sfmError = "";
                    } else if (d.stale) {
                        root.applySfm(d.stale);
                        root.sfmStale = true;
                        root.sfmError = d.error || "";
                    } else {
                        root.sfmOk = false;
                        root.sfmError = d.error || "network";
                    }
                } catch (e) {
                    root.sfmOk = false;
                    root.sfmError = "network";
                }
            }
        }
    }

    Timer {
        interval: 600000
        repeat: true
        running: root.loaded
        onTriggered: root.refreshSfm()
    }

    IpcHandler {
        target: "stats"

        function status(): string {
            return JSON.stringify({
                listening: { today: root.fmtDur(root.listenToday), year: root.fmtDur(root.listenYear),
                    local: { today: root.fmtDur(root.spotifyToday), year: root.fmtDur(root.spotifyYear), week: root.fmtDur(root.spotifyWeek) },
                    playing: root.livePlaying, topSongWeek: root.topSong },
                statsfm: root.sfmOk ? { stale: root.sfmStale, today: root.fmtDur(root.sfmTodayMs), todayStreams: root.sfmTodayStreams,
                    topToday: root.sfmTopToday, year: root.fmtDur(root.sfmYearMs), yearStreams: root.sfmYearStreams,
                    topTrack: root.sfmTopTrack, topArtist: root.sfmTopArtist, topArtistTime: root.fmtDur(root.sfmTopArtistMs) } : root.sfmError,
                calls: { today: root.fmtDur(root.discordToday), count: root.callsToday, year: root.fmtDur(root.discordYear),
                    countYear: root.callsYear, inCall: root.inCall },
                screen: { today: Focus.screenMin, avg7: Math.round(root.screenAvgMin) },
                since: root.firstDay
            });
        }
        function refresh(): void {
            root.refreshSfm();
            root.tick();
        }
        function save(): void {
            root.save();
        }
    }
}

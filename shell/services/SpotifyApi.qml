pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Spotify Web API über scripts/spotify-api (JSON auf stdout). Tokens liest nur das Skript, nie die Shell.
// Vorladen, damit das Popout sofort eine Liste hat: letzter Stand aus now.json beim Start, dann still im
// Hintergrund bei Songwechsel (höchstens alle bgGap) – nur solange Spotify läuft. Kopplung: docs/setup/spotify.md
Singleton {
    id: root

    property bool active: false          // Popout offen -> Warteschlange/Kontext laden
    property bool libraryOpen: false     // Bibliothek sichtbar -> Playlists laden

    property bool configured: false
    // unconfigured | idle | loading | ok | error
    property string status: "unconfigured"
    property string error: ""            // reauth | premium | rate_limited | no_device | network | forbidden | …
    property string notice: ""           // kurzer Hinweis nach Fehlern beim Abspielen

    property var queue: []               // [{ uri, name, artists, image, duration_ms }]
    property string current: ""          // laut API
    property string contextUri: ""
    property string contextType: ""      // playlist | album | collection | artist | …
    property string contextName: ""
    property string contextImage: ""
    property bool contextRestricted: false   // Dev-Mode: fremde Playlists ohne Inhalt
    property var contextTracks: []       // wie queue + { index, current }
    property bool apiShuffle: false      // laut API (Ersatz, falls MPRIS kein Shuffle meldet)
    property real fetchedAt: 0           // Stand der Liste (ms, auch aus now.json)
    property real lastFetchAt: 0         // letzter Abruf-Start (Drossel für den Hintergrund)
    property string listUri: ""          // Song, auf den queue gerade ausgerichtet ist (siehe trim)
    property var played: []              // in dieser Sitzung gehörte Songs (Shuffle-Filter), neueste zuerst
    property string lastMpris: ""
    property bool bgPending: false       // Hintergrund-Abruf steht noch aus (z. B. wegen Sperre)
    readonly property int bgGap: 20000   // ms – höchstens ein Hintergrund-Abruf so oft
    readonly property real bornAt: Date.now()

    readonly property bool spotifyRunning: Players.spotify !== null
    // Spotify läuft, hat aber nichts geladen (frisch gestartet): MPRIS meldet Stopped + CanPlay=false, Play wirkt dort nicht
    readonly property bool idle: {
        const p = Players.spotify;
        return p !== null && (!p.canPlay || !p.trackTitle);
    }
    property var lastPlayed: null        // { uri, name, artists, image } – zuletzt gehört laut API, für die leere Anzeige
    property bool resuming: false
    property string resumeError: ""      // kurzer Text, falls resume scheitert
    readonly property bool shuffleOn: {
        const p = Players.spotify;
        return p && p.shuffleSupported ? p.shuffle : apiShuffle;
    }

    property var playlists: []           // [{ uri, name, image, owner, own, liked, total }]
    property bool playlistsLoading: false
    property real playlistsAt: 0
    property real blockedUntil: 0        // nach 429 bis hier Ruhe
    readonly property int maxBlock: 900  // s – nur Schutz gegen Unsinn; die Pause (mit Verdopplung) rechnet das Skript

    // Durchstöbern: eine Playlist, seitenweise (50) nachgeladen
    property var browse: ({})            // { uri, name, image, owner, total, restricted }
    property var browseTracks: []        // wie queue + { index }
    property int browseNext: -1          // nächster offset, -1 = alles da
    property bool browseLoading: false
    property string browseError: ""

    readonly property string script: Quickshell.shellDir + "/../scripts/spotify-api"

    // Gerade laufender Song sofort aus MPRIS (spotify:track:…), sonst laut API
    readonly property string mprisUri: {
        const p = Players.spotify;
        const id = p && p.metadata ? String(p.metadata["mpris:trackid"] || "") : "";
        const m = /track[\/:]([A-Za-z0-9]+)$/.exec(id);
        return m ? "spotify:track:" + m[1] : "";
    }
    readonly property string playingUri: mprisUri || current

    readonly property var messages: ({
        unconfigured: "Connect Spotify: docs/setup/spotify.md",
        reauth: "Reconnect Spotify: scripts/spotify-auth",
        premium: "Requires Spotify Premium",
        rate_limited: "Spotify is rate-limiting – try again shortly",
        no_device: "Spotify isn’t running",
        network: "Can’t reach Spotify",
        forbidden: "Spotify denied access (is the user allowed in the app?)"
    })
    function message(kind: string): string {
        return messages[kind] || ("Spotify error (" + kind + ")");
    }

    // resume-spezifisch: no_device heißt hier „Client noch nicht bei Spotify Connect“
    function resumeMessage(kind: string): string {
        return kind === "no_device" ? "Open Spotify first"
            : kind === "nothing" ? "Nothing to resume – pick something in Library"
            : message(kind);
    }

    // Play/Pause für Spotify: ohne geladenen Song über die Web API auf diesem PC weiterspielen
    function playPause(): void {
        const p = Players.spotify;
        if (!p)
            return;
        if (idle)
            resume();
        else
            p.togglePlaying();
    }

    function resume(): void {
        if (resumeProc.running)
            return;
        if (!configured || blocked()) {
            showResumeError(configured ? "rate_limited" : "unconfigured");
            return;
        }
        resumeError = "";
        resuming = true;
        resumeProc.running = true;
    }

    function showResumeError(kind: string): void {
        resumeError = resumeMessage(kind);
        resumeErrorOff.restart();
    }

    // einmal je Leerlauf-Phase: zuletzt gehörten Song holen (Skript cacht ihn RECENT_TTL)
    function loadLast(): void {
        if (idle && configured && !blocked() && !lastProc.running)
            lastProc.running = true;
    }
    onIdleChanged: {
        if (idle)
            loadLast();
        else
            resumeError = "";
    }
    onConfiguredChanged: loadLast()

    function blocked(): bool {
        return Date.now() < blockedUntil;
    }

    function refresh(): void {
        if (!configured || blocked() || !spotifyRunning)
            return;  // Spotify zu: nichts zu zeigen, also auch nichts fragen
        if (nowProc.running) {
            again.pending = true;
            return;
        }
        if (status !== "ok")
            status = "loading";
        lastFetchAt = Date.now();
        nowProc.running = true;
    }

    // Liste veraltet? (zu alt oder auf einen anderen Song ausgerichtet als MPRIS spielt)
    function stale(maxAge: int): bool {
        return Date.now() - fetchedAt > maxAge || (mprisUri !== "" && mprisUri !== current);
    }

    // Still im Hintergrund nachladen: frühestens nach settle (API hinkt MPRIS hinterher), höchstens alle bgGap.
    // Neustart bei jedem Songwechsel -> beim Durchskippen am Ende genau ein Abruf.
    function refreshBackground(): void {
        if (!configured || !spotifyRunning)
            return;
        bgPending = true;
        const at = Math.max(Date.now() + settle.interval, lastFetchAt + bgGap);
        bgTimer.interval = Math.max(1, at - Date.now());
        bgTimer.restart();
    }

    // Songwechsel sofort zeigen, ohne auf die API zu warten: Gespieltes oben abschneiden
    function trim(): void {
        const uri = mprisUri;
        if (uri === "")
            return;
        if (uri !== listUri) {
            // Warteschlange enthält den laufenden Song nicht -> nur einmal je Song schneiden (sonst träfe es eine Wiederholung)
            const qi = queue.findIndex(t => t.uri === uri);
            if (qi >= 0)
                queue = queue.slice(qi + 1);
            listUri = uri;
        }
        if (!shuffleOn) {
            // mit Shuffle sagt die Playlist-Position nichts – dort filtert SpotifyQueue über played
            const ci = contextTracks.findIndex(t => t.uri === uri);
            if (ci > 0)
                contextTracks = contextTracks.slice(ci);
        }
    }

    function loadPlaylists(force: bool): void {
        if (!configured || blocked() || plProc.running)
            return;
        if (!force && playlists.length > 0 && Date.now() - playlistsAt < 300000)
            return;
        playlistsLoading = true;
        plProc.running = true;
    }

    function playTrack(uri: string, ctx: string): void {
        if (!configured || !uri)
            return;
        current = uri;
        run(["play-track", uri].concat(ctx ? [ctx] : []));
    }

    // mode: "" | "from-start" (ab Song 1, Shuffle aus) | "shuffle"
    function playContext(uri: string, mode: string): void {
        if (!configured || !uri)
            return;
        contextUri = uri;
        run(["play-context", uri].concat(mode === "from-start" || mode === "shuffle" ? ["--" + mode] : []));
    }

    // Playlist öffnen; p = Eintrag aus playlists (Name/Cover sofort sichtbar)
    function openPlaylist(p: var): void {
        if (!p || !p.uri)
            return;
        browseLoading = true;  // sperrt loadMore(), solange umgestellt wird (ListView meldet sich sonst zu früh)
        browseNext = 0;
        browseError = "";
        browse = { uri: p.uri, name: p.name || "", image: p.image || "", owner: p.owner || "", total: p.total, restricted: false, liked: !!p.liked };
        browseTracks = [];
        browseLoading = false;
        loadMore();
    }

    function loadMore(): void {
        if (!configured || blocked() || browseLoading || browseNext < 0 || !browse.uri)
            return;
        browseLoading = true;
        if (browseProc.running) {
            browseProc.again = true;  // alte Abfrage (andere Playlist) erst auslaufen lassen
            return;
        }
        browseProc.wantUri = browse.uri;
        browseProc.wantOffset = browseNext;
        browseProc.command = [script, "playlist", browse.uri, String(browseNext)];
        browseProc.running = true;
    }

    function applyBrowse(j: var, wantUri: string, wantOffset: int): void {
        // Antwort trägt eigene uri/offset -> verlässlicher als der Prozess-Zustand
        const uri = j.uri || wantUri;
        const offset = typeof j.offset === "number" ? j.offset : wantOffset;
        if (uri !== browse.uri)
            return;  // inzwischen andere Playlist offen
        browseLoading = false;
        if (j.failed) {
            browseError = j.failed;
            browseNext = -1;
            return;
        }
        if (offset !== browseTracks.length && offset !== 0)
            return;
        browse = Object.assign({}, browse, {
            name: j.name || browse.name,
            image: j.image || browse.image,
            owner: j.owner || browse.owner,
            total: j.total !== undefined && j.total !== null ? j.total : browse.total,
            restricted: !!j.restricted
        });
        browseTracks = (offset === 0 ? [] : browseTracks).concat(j.tracks || []);
        browseNext = j.next_offset !== undefined && j.next_offset !== null ? j.next_offset : -1;
    }

    function run(args: var): void {
        if (cmdProc.running)
            return;
        cmdProc.command = [script].concat(args);
        cmdProc.running = true;
    }

    // Antwort parsen; Fehler -> false
    function parse(text: string): var {
        let j;
        try {
            j = JSON.parse(text);
        } catch (e) {
            j = { error: "internal" };
        }
        if (j && j.error) {
            if (j.error === "rate_limited") {
                // retry_after kommt schon gedeckelt und mit Verdopplung aus dem Skript (auch das eigene Anfragen-Budget)
                blockedUntil = Date.now() + Math.min(j.retry_after || 5, maxBlock) * 1000;
                blockFile.setText(String(blockedUntil));
            }
            return { failed: j.error };
        }
        return j || {};
    }

    function fail(kind: string): void {
        if (kind === "unconfigured") {
            status = "unconfigured";
            return;
        }
        error = kind;
        status = "error";
    }

    function apply(j: var): void {
        const q = j.queue || {};
        const c = j.context || {};
        queue = q.queue || [];
        // Warteschlange zuerst: im Notfall (Kontext gesperrt) liefert das Skript den alten Kontext mit altem current
        current = q.current ? q.current.uri : (c.current || "");
        listUri = current;
        apiShuffle = !!c.shuffle;
        contextUri = c.uri || "";
        contextType = c.type || "";
        contextName = c.name || "";
        contextImage = c.image || "";
        contextRestricted = !!c.restricted;
        contextTracks = c.tracks || [];
        fetchedAt = j.saved_at || Date.now();
        error = "";
        if (configured)
            status = "ok";
        trim();  // API hinkt MPRIS manchmal hinterher
    }

    // Popout auf: Liste ist schon da (Vorladen), nur still nachladen, wenn sie nicht frisch ist
    onActiveChanged: {
        if (!active)
            return;
        trim();
        if (stale(10000)) {
            bgTimer.stop();
            bgPending = false;
            refresh();
        }
        loadPlaylists(false);
    }
    onLibraryOpenChanged: if (libraryOpen) loadPlaylists(false)
    // Spotify später gestartet -> vorladen; beim Shell-Start übernimmt das der Start-Timer
    onSpotifyRunningChanged: if (spotifyRunning && Date.now() - bornAt > 10000) refreshBackground()

    onMprisUriChanged: {
        if (mprisUri === "")
            return;
        if (lastMpris !== "" && lastMpris !== mprisUri)
            played = [lastMpris].concat(played.filter(u => u !== lastMpris)).slice(0, 100);
        lastMpris = mprisUri;
        trim();
    }

    // Songwechsel: kurz warten, die API hinkt MPRIS etwas hinterher; Popout zu -> gedrosselt im Hintergrund
    Connections {
        target: Players.spotify
        function onTrackTitleChanged() {
            if (root.active)
                settle.restart();
            else
                root.refreshBackground();
        }
    }

    Timer {
        id: bgTimer
        onTriggered: {
            if (root.active) {
                root.bgPending = false;  // Popout lädt selbst
                return;
            }
            if (root.blocked())
                return;  // unblock holt es nach
            root.bgPending = false;
            if (root.stale(5000))  // Liste passt schon (z. B. Popout hat eben geladen) -> keine Anfrage
                root.refresh();
        }
    }

    // Einmal kurz nach dem Start: Spotify läuft schon -> Liste und Bibliothek vorladen.
    // Liste aus now.json noch frisch und zum Song passend -> keine Anfrage (Shell-Neustarts beim Basteln)
    Timer {
        interval: 10000
        running: true
        onTriggered: {
            if (!root.spotifyRunning)
                return;
            if (root.stale(60000))
                root.refreshBackground();
            root.loadPlaylists(false);
        }
    }

    // letzter now-Stand (schreibt scripts/spotify-api) -> erstes Öffnen ohne „Loading…“
    FileView {
        path: Quickshell.env("HOME") + "/.cache/desktop/spotify/now.json"
        printErrors: false
        onLoaded: {
            if (root.fetchedAt > 0)
                return;  // schon frischer geladen
            try {
                const j = JSON.parse(text());
                if (j && j.queue && j.context)
                    root.apply(j);
            } catch (e) {}
        }
    }

    // Sperre nach 429 überlebt Shell-Neustarts: sonst fragt jede neue Instanz sofort wieder an
    // und Spotify verlängert die Sperre (viele Neustarts hintereinander = lange Rate-Limits)
    FileView {
        id: blockFile
        path: Quickshell.env("HOME") + "/.cache/desktop/spotify/blocked-until"
        printErrors: false
        watchChanges: true
        onFileChanged: reload()
        // 0 (oder vergangen) in die Datei schreiben hebt die Sperre auf
        onLoaded: {
            const t = Number(text().trim());
            root.blockedUntil = t > Date.now() ? Math.min(t, Date.now() + root.maxBlock * 1000) : 0;
        }
    }
    // Sperre vorbei: von selbst neu laden (sonst bliebe „rate-limiting“ stehen, bis sich am Song etwas ändert);
    // Popout zu -> nur, wenn ein Hintergrund-Abruf liegen geblieben ist
    Timer {
        id: unblock
        interval: Math.max(1000, root.blockedUntil - Date.now() + 500)
        running: root.blockedUntil > Date.now()
        onTriggered: {
            if (root.active)
                root.refresh();
            else if (root.bgPending)
                root.refreshBackground();
        }
    }

    Timer {
        id: settle
        interval: 1200
        onTriggered: root.refresh()
    }
    // nach Shuffle/Repeat: Spotify mischt die Warteschlange neu, die API hinkt etwas hinterher
    function refreshSoon(): void {
        if (!active)
            return;
        settle.restart();
        settleLate.restart();   // zweiter Blick, falls die erste Antwort noch die alte Reihenfolge hatte
    }
    Timer {
        id: settleLate
        interval: 3500
        onTriggered: root.refresh()
    }

    // Wunsch nach refresh() während ein Abruf läuft -> danach einmal nachholen
    Timer {
        id: again
        property bool pending: false
        interval: 50
        onTriggered: {
            pending = false;
            root.refresh();
        }
    }

    Timer {
        id: resumeErrorOff
        interval: 6000
        onTriggered: root.resumeError = ""
    }

    Process {
        id: lastProc
        command: [root.script, "last"]
        stdout: StdioCollector {
            onStreamFinished: {
                const j = root.parse(text);
                if (!j.failed)
                    root.lastPlayed = j.track || null;
            }
        }
    }

    Process {
        id: resumeProc
        command: [root.script, "resume"]
        stdout: StdioCollector {
            onStreamFinished: {
                const j = root.parse(text);
                root.resuming = false;
                if (j.failed) {
                    root.showResumeError(j.failed);
                    return;
                }
                if (j.track)
                    root.lastPlayed = j.track;
                settle.restart();  // Warteschlange/Kontext zum neuen Song nachladen
            }
        }
    }

    Timer {
        id: noticeOff
        interval: 4000
        onTriggered: root.notice = ""
    }

    FileView {
        path: Quickshell.shellDir + "/../secrets.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            let ok = false;
            try {
                const s = JSON.parse(text()).spotify || {};
                ok = !!s.client_id && !!s.refresh_token;
            } catch (e) {}
            root.configured = ok;
            if (!ok)
                root.status = "unconfigured";
            else if (root.status === "unconfigured") {
                root.status = root.fetchedAt > 0 ? "ok" : "idle";  // now.json war evtl. schneller da
                if (root.active)
                    root.refresh();
                if (root.libraryOpen)
                    root.loadPlaylists(true);  // Vorladen beim Start macht der Start-Timer (nur mit laufendem Spotify)
            }
        }
        onLoadFailed: {
            root.configured = false;
            root.status = "unconfigured";
        }
    }

    Process {
        id: nowProc
        command: [root.script, "now"]
        stdout: StdioCollector {
            onStreamFinished: {
                const j = root.parse(text);
                // kurze Sperre bei schon geladener Liste: Liste behalten, nur Hinweis (lädt nach der Pause von selbst neu)
                if (j.failed === "rate_limited" && root.status === "ok") {
                    if (root.active) {
                        root.notice = "Spotify is busy – list may be a bit behind";
                        noticeOff.restart();
                    }
                } else if (j.failed)
                    root.fail(j.failed);
                else
                    root.apply(j);
                if (again.pending)
                    again.restart();
            }
        }
    }

    Process {
        id: plProc
        command: [root.script, "playlists"]
        stdout: StdioCollector {
            onStreamFinished: {
                const j = root.parse(text);
                root.playlistsLoading = false;
                if (j.failed) {
                    root.fail(j.failed);
                    return;
                }
                root.playlists = j.playlists || [];
                root.playlistsAt = Date.now();
            }
        }
    }

    Process {
        id: browseProc
        property string wantUri
        property int wantOffset
        property bool again: false
        stdout: StdioCollector {
            onStreamFinished: root.applyBrowse(root.parse(text), browseProc.wantUri, browseProc.wantOffset)
        }
        onRunningChanged: {
            if (!running && browseProc.again) {
                browseProc.again = false;
                root.browseLoading = false;
                Qt.callLater(root.loadMore);
            }
        }
    }

    Process {
        id: cmdProc
        stdout: StdioCollector {
            onStreamFinished: {
                const j = root.parse(text);
                if (j.failed) {
                    root.notice = root.message(j.failed);
                    noticeOff.restart();
                }
                // echten Zustand nachlesen (Kontext/Warteschlange haben sich geändert)
                settle.restart();
            }
        }
    }
}

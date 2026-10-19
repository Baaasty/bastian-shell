pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Spotify Web API über scripts/spotify-api (JSON auf stdout). Sparsam: lädt nur, solange das
// Popout offen ist (active) und dann bei Songwechsel. Tokens liest nur das Skript, nie die Shell.
// Kopplung: docs/setup/spotify.md
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

    property var playlists: []           // [{ uri, name, image, owner, own, liked, total }]
    property bool playlistsLoading: false
    property real playlistsAt: 0
    property real blockedUntil: 0        // nach 429 bis hier Ruhe
    readonly property int maxBlock: 120  // s – längste Pause nach 429 (siehe parse)

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

    function blocked(): bool {
        return Date.now() < blockedUntil;
    }

    function refresh(): void {
        if (!configured || blocked())
            return;
        if (nowProc.running) {
            again.pending = true;
            return;
        }
        if (status !== "ok")
            status = "loading";
        nowProc.running = true;
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
                // Spotify schickt manchmal Retry-After von Stunden (2026-10-18: ~5 h), antwortet aber oft viel früher
                // wieder. Darum höchstens maxBlock warten, dann ein Versuch; ist die Sperre noch da, wieder maxBlock Ruhe.
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
        current = c.current || (q.current ? q.current.uri : "");
        contextUri = c.uri || "";
        contextType = c.type || "";
        contextName = c.name || "";
        contextImage = c.image || "";
        contextRestricted = !!c.restricted;
        contextTracks = c.tracks || [];
        error = "";
        status = "ok";
    }

    // Bibliothek vorladen: beim Start und beim Öffnen des Popouts, damit sie sofort da ist
    onActiveChanged: {
        if (!active)
            return;
        refresh();
        loadPlaylists(false);
    }
    onLibraryOpenChanged: if (libraryOpen) loadPlaylists(false)

    // Songwechsel: kurz warten, die API hinkt MPRIS etwas hinterher
    Connections {
        target: Players.spotify
        function onTrackTitleChanged() {
            if (root.active)
                settle.restart();
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
    // Sperre vorbei: von selbst neu laden (sonst bliebe „rate-limiting“ stehen, bis sich am Song etwas ändert)
    Timer {
        id: unblock
        interval: Math.max(1000, root.blockedUntil - Date.now() + 500)
        running: root.blockedUntil > Date.now()
        onTriggered: root.refresh()
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
                root.status = "idle";
                if (root.active)
                    root.refresh();
                root.loadPlaylists(root.libraryOpen);
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
                    root.notice = "Spotify is busy – list may be a bit behind";
                    noticeOff.restart();
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

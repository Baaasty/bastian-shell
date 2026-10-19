import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.config
import qs.services

// Passwort-Speicher (Super+O): iCloud-Schlüsselbund über scripts/passwords (icp, nur lesend).
// Lokal änderbar: Titel + Websites (Overrides). Passwörter ändern: auf iPhone/Mac.
// Geheimnisse bleiben nur so lange im Speicher, wie sie angezeigt werden; Kopieren läuft im CLI
// (wl-copy --sensitive, nach 30 s geleert), nie über QML.
Scope {
    id: root

    property bool open: false
    property string screenName: Config.mainScreen

    property var items: []              // [{id,title,user,urls,hasTotp,hasPassword,hasNotes,custom}]
    property string loadState: ""       // "" | loading | ready | error:…
    property string query: ""
    property int sel: 0
    // Ausblenden (nur Anzeige, nichts wird gelöscht): Einstellungen aus ~/.config/desktop/passwords.json
    property bool hideWifi: true        // gespeicherte WLAN-Passwörter („AirPort“) ausblenden
    property var hiddenIds: []          // von Hand ausgeblendet
    property var shownIds: []           // trotz hideWifi sichtbar
    property bool showHidden: false     // „Show hidden“: Ausgeblendete anzeigen (nur diese Sitzung)
    readonly property var liveItems: items.filter(e => !isHidden(e))
    readonly property int hiddenWifiCount: items.filter(e => isHidden(e) && !hiddenIds.includes(e.id)).length
    readonly property int hiddenManualCount: items.filter(e => hiddenIds.includes(e.id)).length
    readonly property int hiddenCount: items.length - liveItems.length
    readonly property var rows: filterRows(showHidden ? items : liveItems, query)
    readonly property var cur: sel >= 0 && sel < rows.length ? rows[sel] : null

    // Detail (nur für den gewählten Eintrag)
    property string revealed: ""        // Passwort im Klartext, solange das Auge offen ist
    property bool revealOn: false
    property string notes: ""           // Notiz im Klartext (kann API-Keys enthalten), nur solange aufgedeckt
    property bool notesOn: false
    property var totp: null             // {code, period, expires(ms)}
    property real now: Date.now()

    property bool syncBusy: false
    property string syncMsg: ""
    property string toast: ""

    readonly property string bin: Quickshell.shellDir + "/../scripts/passwords"

    // offen = globale Kürzel aus (Super+Enter & Co. im Hintergrund), siehe Hypr.setModal
    onOpenChanged: Hypr.setModal("passwords", open)
    Component.onDestruction: Hypr.setModal("passwords", false)

    // ------------------------------------------------------------ Liste / Suche
    function isHidden(e: var): bool {
        return hiddenIds.includes(e.id) || (hideWifi && !!e.wifi && !shownIds.includes(e.id));
    }
    function hostOf(url: string): string {
        return (url || "").replace(/^[a-z]+:\/\//i, "").split("/")[0].replace(/^www\./, "");
    }
    function domainOf(e: var): string {
        return e && e.urls && e.urls.length ? hostOf(e.urls[0]) : "";
    }
    function filterRows(list: var, q: string): var {
        q = q.trim();
        if (!q)
            return list;
        const out = [];
        for (const e of list) {
            const s = Math.max(Fuzzy.score(q, e.title), Fuzzy.score(q, (e.urls || []).map(hostOf).join(" ")) - 20, Fuzzy.score(q, e.user) - 40);
            if (s > 0)
                out.push({ e: e, s: s });
        }
        out.sort((a, b) => b.s - a.s);
        return out.map(x => x.e);
    }
    readonly property string curId: cur ? cur.id : ""
    onQueryChanged: sel = 0
    onCurIdChanged: resetDetail()

    function moveSel(d: int): void {
        if (rows.length === 0)
            return;
        sel = Math.max(0, Math.min(rows.length - 1, sel + d));
    }
    function selectId(id: string): void {
        const i = rows.findIndex(r => r.id === id);
        if (i >= 0)
            sel = i;
    }

    // ------------------------------------------------------------ Website-Icons (scripts/favicons, Service Favicons)
    // Domains aller Logins, ab dem gewählten Eintrag (sichtbare/nahe zuerst); nur Einträge mit Website
    function iconDomains(): var {
        // Ausgeblendete werden übersprungen
        return Favicons.domainsOf(liveItems, e => Favicons.hostOf(domainOf(e)), Math.max(0, liveItems.findIndex(e => cur && e.id === cur.id)));
    }
    // force: alle neu holen/aktualisieren; sonst nur fehlende (bereits Gecachtes/„kein Icon“ übersprungen das Skript)
    function loadIcons(force: bool): void {
        if (Favicons.running)
            Favicons.stop();
        else
            Favicons.start(iconDomains(), force);
    }

    // ------------------------------------------------------------ öffnen / schließen
    function toggle(): void {
        if (open) close(); else openIt();
    }
    function openIt(): void {
        if (open)
            return;
        screenName = Hyprland.focusedMonitor?.name ?? Config.mainScreen;
        query = "";
        sel = 0;
        syncMsg = "";
        Favicons.refresh();
        loadSettings();
        load();
        open = true;
    }
    function close(): void {
        open = false;
        resetDetail();
    }
    function resetDetail(): void {
        revealed = "";
        revealOn = false;
        notes = "";
        notesOn = false;
        totp = null;
        if (open && cur && cur.hasTotp)
            fetchTotp();
    }

    // ------------------------------------------------------------ Backend
    // args -> (stdout-Text, Exitcode) an cb. Fehlertext (stderr) enthält nie Geheimnisse.
    function run(args: var, cb: var): void {
        jobComp.createObject(root, { command: [bin].concat(args), cb: cb, running: true });
    }
    function runJson(args: var, cb: var): void {
        run(args, (text, code, err) => {
            let d = null;
            if (code === 0) {
                try {
                    d = JSON.parse(text);
                } catch (e) {
                    d = null;
                }
            }
            cb(d, err);
        });
    }
    function applySettings(d: var): void {
        if (!d)
            return;
        hideWifi = d.hideWifi !== false;
        hiddenIds = d.hidden || [];
        shownIds = d.shown || [];
        sel = Math.min(sel, Math.max(0, rows.length - 1));
    }
    function loadSettings(): void {
        runJson(["config"], d => applySettings(d));
    }
    // Eintrag ausblenden bzw. wieder einblenden (Taste Ctrl+H / Knopf in der Zeile)
    function toggleHide(e: var): void {
        if (!e)
            return;
        const hide = !isHidden(e);
        runJson([hide ? "hide" : "unhide", e.id], (d, err) => {
            if (d) {
                applySettings(d);
                showToast(hide ? "Hidden · use Show hidden to see it again" : "Shown again");
            } else {
                showToast(err || "Could not save");
            }
        });
    }
    function setHideWifi(on: bool): void {
        runJson(["config", "hideWifi", on ? "on" : "off"], d => applySettings(d));
    }
    function load(): void {
        if (loadState !== "ready")
            loadState = "loading";
        const keep = cur ? cur.id : "";
        runJson(["list"], (d, err) => {
            if (!d) {
                loadState = "error:" + (err || "no answer from scripts/passwords");
                return;
            }
            items = d;
            loadState = "ready";
            if (keep)
                selectId(keep);
            if (Favicons.auto && !Favicons.running && Date.now() - Favicons.lastAuto > 3600000)
                Favicons.start(iconDomains(), false);
        });
    }
    function replaceItem(e: var): void {
        if (!e || !e.id)
            return;
        items = items.map(x => x.id === e.id ? e : x).sort((a, b) => a.title.toLowerCase().localeCompare(b.title.toLowerCase()));
        selectId(e.id);
    }
    function copy(field: string): void {
        const e = cur;
        if (!e)
            return;
        if (field === "password" && !e.hasPassword || field === "totp" && !e.hasTotp || field === "notes" && !e.hasNotes)
            return;
        run(["copy", e.id, field], (t, code) => {
            showToast(code === 0 ? ({ password: "Password", user: "Username", totp: "2FA code", notes: "Note" })[field] + " copied · clears in 30 s" : "Copy failed");
        });
    }
    function toggleReveal(): void {
        const e = cur;
        if (!e || !e.hasPassword)
            return;
        if (revealOn) {
            revealOn = false;
            revealed = "";
            return;
        }
        run(["get", e.id, "password"], (t, code) => {
            if (code === 0 && cur && cur.id === e.id) {
                revealed = t;
                revealOn = true;
            }
        });
    }
    function toggleNotes(): void {
        const e = cur;
        if (!e || !e.hasNotes)
            return;
        if (notesOn) {
            notesOn = false;
            notes = "";
            return;
        }
        run(["get", e.id, "notes"], (t, code) => {
            if (code === 0 && cur && cur.id === e.id) {
                notes = t;
                notesOn = true;
            }
        });
    }
    function fetchTotp(): void {
        const e = cur;
        if (!e || !e.hasTotp)
            return;
        runJson(["get", e.id, "totp", "--json"], d => {
            if (d && cur && cur.id === e.id)
                totp = { code: d.code, period: d.period || 30, expires: Date.now() + d.remaining * 1000 };
        });
    }
    function mutate(args: var): void {
        runJson(args, (d, err) => {
            if (d)
                replaceItem(d);
            else
                showToast(err || "Could not save");
        });
    }
    function rename(title: string): void {
        if (cur && title.trim() && title.trim() !== cur.title)
            mutate(["rename", cur.id, title.trim()]);
    }
    function addUrl(url: string): void {
        if (cur && url.trim())
            mutate(["add-url", cur.id, url.trim()]);
    }
    function removeUrl(url: string): void {
        if (cur)
            mutate(["remove-url", cur.id, url]);
    }
    function resetOverride(): void {
        if (cur)
            mutate(["reset", cur.id]);
    }
    function sync(): void {
        if (syncBusy)
            return;
        syncBusy = true;
        syncMsg = "Syncing with iCloud…";
        run(["sync"], (t, code, err) => {
            syncBusy = false;
            const line = (t || "").trim().split("\n").pop();
            syncMsg = code === 0 ? (line || "Synced") : "Sync failed" + (err ? ": " + err.split("\n").pop() : "");
            load();
        });
    }
    function showToast(msg: string): void {
        toast = msg;
        toastTimer.restart();
    }

    Timer {
        id: toastTimer
        interval: 2600
        onTriggered: root.toast = ""
    }
    // TOTP-Countdown: lokal runterzählen, beim Wechsel neu holen
    Timer {
        interval: 250
        repeat: true
        running: root.open && root.totp !== null
        onTriggered: {
            root.now = Date.now();
            if (root.totp && root.now >= root.totp.expires) {
                root.totp = null;
                root.fetchTotp();
            }
        }
    }

    Component {
        id: jobComp

        Process {
            id: job

            property var cb
            property int left: 3            // stdout fertig + stderr fertig + beendet
            property int code: -1

            function step(): void {
                if (--left > 0)
                    return;
                const t = out.text;
                const e = (errOut.text || "").trim().replace(/^passwords: /, "");
                job.cb(t, job.code, e);
                job.destroy();
            }

            stdout: StdioCollector {
                id: out
                onStreamFinished: job.step()
            }
            stderr: StdioCollector {
                id: errOut
                onStreamFinished: job.step()
            }
            onExited: c => {
                job.code = c;
                job.step();
            }
        }
    }

    // qs ipc --any-display -p ~/Workspace/desktop/shell call passwords toggle
    IpcHandler {
        target: "passwords"

        function toggle(): void {
            root.toggle();
        }
        function open(): void {
            root.openIt();
        }
        function close(): void {
            root.close();
        }
        // Icons laden (nur fehlende) bzw. mit force alle aktualisieren; zweiter Aufruf während des Laufs stoppt
        function icons(force: bool): void {
            root.loadIcons(force);
        }
        // Ausgeblendete anzeigen (zum Testen)
        function hidden(show: bool): void {
            root.showHidden = show;
        }
        // zum Testen: Suchtext setzen
        function search(text: string): void {
            root.openIt();
            root.query = text;
        }
    }

    PanelWindow {
        id: win

        property real progress: root.open ? 1 : 0
        Behavior on progress { NumberAnimation { duration: root.open ? 150 : 110; easing.type: Easing.OutCubic } }

        screen: Quickshell.screens.find(s => s.name === root.screenName) ?? Quickshell.screens[0]
        visible: root.open || progress > 0
        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"
        WlrLayershell.namespace: "dock" // ohne Öffnen-Animation (Hyprland: layerrule noanim)
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: root.open ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

        // Klick daneben (auch auf anderen Monitoren) schließt
        HyprlandFocusGrab {
            active: root.open
            windows: [win]
            onCleared: root.close()
        }

        readonly property bool blurOn: root.open && progress > 0.4
        BackgroundEffect.blurRegion: Region {
            Region { x: 0; y: 0; width: 1; height: 1 }
            Region { item: win.blurOn ? backdrop : null }
            Region { item: panel; radius: Theme.radiusXl }
        }

        onVisibleChanged: if (visible && root.open) panel.focusSearch()
        Connections {
            target: root
            function onOpenChanged() { if (root.open) panel.focusSearch(); }
        }

        Rectangle {
            id: backdrop
            anchors.fill: parent
            opacity: win.progress
            color: Theme.dim
            MouseArea {
                anchors.fill: parent
                onClicked: root.close()
            }
        }

        PwPanel {
            id: panel

            pw: root
            width: Math.min(1000, parent.width - 80)
            height: Math.min(660, parent.height - 100)
            x: (parent.width - width) / 2
            y: (parent.height - height) / 2 - 10 + (1 - win.progress) * 14
            opacity: win.progress
            scale: 0.98 + 0.02 * win.progress

            // Klick auf freie Fläche im Fenster schluckt das Fenster selbst – sonst fiele er auf backdrop und schlösse
            MouseArea {
                anchors.fill: parent
                z: -1
                acceptedButtons: Qt.AllButtons
                onClicked: panel.focusSearch()
            }
        }
    }
}

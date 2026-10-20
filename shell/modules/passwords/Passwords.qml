import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.config
import qs.services

// Passwort-Speicher (Super+O): iCloud-Schlüsselbund über scripts/passwords (icp, nur lesend).
// Nur Anzeige: icp liest nur, Titel/Websites/Passwörter ändern auf iPhone/Mac.
// Aktualisieren ohne Knopf: Timer desktop-passwords (alle 15 min) + beim Öffnen, wenn älter als 5 min;
// icp bremst selbst (Mindestabstand, Backoff, nie Passwort-Login/2FA im Hintergrund).
// Geheimnisse bleiben nur so lange im Speicher, wie sie angezeigt werden; Kopieren läuft im CLI
// (wl-copy --sensitive, nach 30 s geleert), nie über QML.
Scope {
    id: root

    property bool open: false
    property string screenName: Config.mainScreen

    property var items: []              // [{id,title,user,urls,hasTotp,hasPassword,hasNotes,custom,wifi,group}]
    property string loadState: ""       // "" | loading | ready | error:…
    property string query: ""
    property int sel: 0
    // Ausblenden (nur Anzeige, nichts wird gelöscht): Einstellungen aus ~/.config/desktop/passwords.json
    readonly property bool hideWifi: true   // gespeicherte WLAN-Passwörter („AirPort“) immer ausblenden
    property var hiddenIds: []          // von Hand ausgeblendet
    property var shownIds: []           // trotz hideWifi sichtbar
    property bool showHidden: false     // eigene Liste „Hidden“ (Tab): nur Ausgeblendete, manuell zuerst
    readonly property var liveItems: items.filter(e => !isHidden(e))
    readonly property int hiddenWifiCount: items.filter(e => isHidden(e) && !hiddenIds.includes(e.id)).length
    readonly property int hiddenManualCount: items.filter(e => hiddenIds.includes(e.id)).length
    readonly property int hiddenCount: items.length - liveItems.length
    readonly property var hiddenItems: items.filter(e => isHidden(e)).sort((a, b) => (hiddenIds.includes(b.id) ? 1 : 0) - (hiddenIds.includes(a.id) ? 1 : 0) || a.title.toLowerCase().localeCompare(b.title.toLowerCase()))
    readonly property var rows: filterRows(showHidden ? hiddenItems : liveItems, query)
    readonly property var cur: sel >= 0 && sel < rows.length ? rows[sel] : null

    // Detail (nur für den gewählten Eintrag)
    property string revealed: ""        // Passwort im Klartext, solange das Auge offen ist
    property bool revealOn: false
    property string notes: ""           // Notiz im Klartext (kann API-Keys enthalten), nur solange aufgedeckt
    property bool notesOn: false
    property var totp: null             // {code, period, expires(ms)}
    property real now: Date.now()

    // Sync-Stand (scripts/passwords status = icp status --json, kein Netz)
    property var syncState: null        // {last_success, next_allowed, needs_login, last_error, failures, vault_mtime, now}
    property bool syncBusy: false
    property real vaultMtime: 0
    readonly property int staleSec: 300
    readonly property string syncText: {
        const d = syncState;
        if (syncBusy)
            return "Updating from iCloud…";
        if (!d)
            return "";
        if (d.needs_login)
            return "iCloud login needed · run icp login";
        if (d.failures > 0 && d.next_allowed)
            return "Update failed · next try " + Qt.formatTime(new Date(d.next_allowed * 1000), "HH:mm");
        if (!d.last_success)
            return "";
        const s = Date.now() / 1000 - d.last_success;
        return "Updated " + (s < 60 ? "just now" : s < 3600 ? Math.floor(s / 60) + " min ago" : Math.floor(s / 3600) + " h ago");
    }
    readonly property bool syncProblem: !!syncState && (syncState.needs_login || syncState.failures > 0)
    property string toast: ""

    readonly property string bin: Quickshell.shellDir + "/../scripts/passwords"

    // offen = globale Kürzel aus (Super+Enter & Co. im Hintergrund), siehe Hypr.setModal
    onOpenChanged: Hypr.setModal("passwords", open)
    Component.onDestruction: Hypr.setModal("passwords", false)

    // ------------------------------------------------------------ Liste / Suche
    // warum ausgeblendet: "manual" (Ctrl+H) oder "Wi-Fi" (automatisch erkannt)
    function hiddenKind(e: var): string {
        return hiddenIds.includes(e.id) ? "manual" : "Wi-Fi";
    }
    function toggleHiddenView(): void {
        showHidden = !showHidden;
        sel = 0;
    }
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
            const s = Math.max(Fuzzy.score(q, e.title), Fuzzy.score(q, (e.urls || []).map(hostOf).join(" ")) - 20, Fuzzy.score(q, e.user) - 40, Fuzzy.score(q, e.group || "") - 30);
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
        showHidden = false;
        syncIfStale();
        Favicons.refresh();
        loadSettings();
        load();
        Hypr.panelOpened("passwords");
        open = true;
    }

    // Anderes Panel geht auf → dieses zu (Hypr.panelOpened)
    Connections {
        target: Hypr
        function onPanelOpened(name: string): void {
            if (name !== "passwords" && root.open)
                root.close();
        }
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
                showToast(hide ? "Hidden · Tab shows the hidden list" : "Shown again");
            } else {
                showToast(err || "Could not save");
            }
        });
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
            // fehlende Logos immer nachladen, höchstens 1×/h (Abruf direkt bei den Seiten, gedrosselt)
            if (!Favicons.running && Date.now() - Favicons.lastAuto > 3600000)
                Favicons.start(iconDomains(), false);
        });
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
    // Stand holen; hat sich der Tresor geändert (Timer hat synchronisiert), Liste still neu laden
    function refreshStatus(): void {
        runJson(["status"], d => {
            if (!d)
                return;
            syncState = d;
            if (vaultMtime && d.vault_mtime && d.vault_mtime !== vaultMtime)
                load();
            vaultMtime = d.vault_mtime || 0;
        });
    }
    // beim Öffnen: älter als 5 min -> Hintergrund-Sync. Was icp gerade nicht erlaubt (zu früh, Backoff,
    // Login nötig), lassen wir aus – icp würde es ohnehin mit Exit 75 ablehnen.
    function syncIfStale(): void {
        runJson(["status"], d => {
            if (!d)
                return;
            syncState = d;
            vaultMtime = d.vault_mtime || 0;
            if (syncBusy || d.needs_login || d.now - (d.last_success || 0) < staleSec || (d.next_allowed && d.now < d.next_allowed))
                return;
            syncBusy = true;
            run(["sync", "--background"], () => {
                syncBusy = false;
                refreshStatus();
            });
        });
    }
    function showToast(msg: string): void {
        toast = msg;
        toastTimer.restart();
    }

    // offen: Stand alle 20 s (Anzeige „vor n min“, neuer Tresor vom Timer)
    Timer {
        interval: 20000
        repeat: true
        running: root.open
        onTriggered: root.refreshStatus()
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

    // qs ipc --any-display -p ~/Workspace/bastian-shell/shell call passwords toggle
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

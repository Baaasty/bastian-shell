import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.config
import qs.services

// Passwort-Speicher (Super+O): iCloud-Schlüsselbund über scripts/passwords (icp).
// F2 bearbeitet den gewählten Login (PwEdit) und schreibt über icp zurück nach iCloud;
// geteilte Gruppen und WLAN bleiben nur lesbar.
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
    // Speichern läuft im Hintergrund (scripts/passwords edit --detach): bis icp fertig ist, zeigt die Liste
    // schon den neuen Stand. id -> {title, user, urls, hasTotp, hasNotes} bzw. {deleted: true}
    property var pending: ({})
    readonly property var shownItems: items.filter(e => !(pending[e.id] && pending[e.id].deleted)).map(e => pending[e.id] ? Object.assign({}, e, pending[e.id], { saving: true }) : e)
    // Gespeicherte WLAN-Passwörter (Schlüsselbund-Dienst „AirPort“, scripts/passwords is_wifi) sind nie zu sehen
    readonly property var liveItems: shownItems.filter(e => !e.wifi)
    // Chips oben: "" = alle, "\u0001own" = eigener Schlüsselbund, sonst Name der geteilten Gruppe
    readonly property string ownGroup: "\u0001own"
    property string group: ""
    readonly property var groups: {
        const names = [];
        for (const e of liveItems)
            if (e.group && !names.includes(e.group))
                names.push(e.group);
        names.sort((a, b) => a.toLowerCase().localeCompare(b.toLowerCase()));
        return names.length ? ["", ownGroup].concat(names) : [];
    }
    readonly property var groupItems: group === "" ? liveItems : liveItems.filter(e => (e.group || ownGroup) === group)
    readonly property var rows: filterRows(groupItems, query)
    readonly property var cur: sel >= 0 && sel < rows.length ? rows[sel] : null

    // Detail (nur für den gewählten Eintrag)
    property string revealed: ""        // Passwort im Klartext, solange das Auge offen ist
    property bool revealOn: false
    property string notes: ""           // Notiz im Klartext (kann API-Keys enthalten), nur solange aufgedeckt
    property bool notesOn: false
    property var totp: null             // {code, period, expires(ms)}
    property real now: Date.now()

    // Bearbeiten (F2): Formular rechts statt Details, Speichern über scripts/passwords edit → icp
    property bool editing: false
    property bool editBusy: false
    property string editError: ""
    property string editNotes: ""       // Notiz im Klartext fürs Formular, nur solange es offen ist
    property string editId: ""          // fest beim Start – die Liste kann im Hintergrund neu laden
    signal editEnded()                  // Fokus zurück in die Suche (PwPanel)

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
    function groupLabel(g: string): string {
        return g === "" ? "All" : g === ownGroup ? "Personal" : g;
    }
    function groupCount(g: string): int {
        return g === "" ? liveItems.length : liveItems.filter(e => (e.group || ownGroup) === g).length;
    }
    // Tab / Shift+Tab: nächster bzw. vorheriger Chip
    function stepGroup(d: int): void {
        if (groups.length === 0)
            return;
        const i = Math.max(0, groups.indexOf(group));
        group = groups[(i + d + groups.length) % groups.length];
        sel = 0;
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
        // WLAN wird übersprungen
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
        screenName = Config.mainScreen;     // große Panels immer mittig auf dem Hauptmonitor
        query = "";
        group = "";
        sel = 0;
        syncIfStale();
        Favicons.refresh();
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
        if (!editBusy)
            editing = false;
        editNotes = "";
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
            if (pendingSel) {
                selectId(pendingSel);
                pendingSel = "";
            } else if (keep) {
                selectId(keep);
            }
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
    // ------------------------------------------------------------ Bearbeiten
    function startEdit(): void {
        const e = cur;
        if (!e || editing)
            return;
        if (!e.editable) {
            showToast(e.group ? "Shared groups are read-only for now" : "Wi-Fi passwords can't be edited here");
            return;
        }
        if (e.saving) {
            showToast("Still saving the last change…");
            return;
        }
        editError = "";
        editId = e.id;
        if (!e.hasNotes) {
            editNotes = "";
            editing = true;
            return;
        }
        run(["get", e.id, "notes"], (t, code) => {
            if (code === 0 && cur && cur.id === e.id) {
                editNotes = t;
                editing = true;
            }
        });
    }
    function cancelEdit(): void {
        if (editBusy)
            return;
        editing = false;
        editNotes = "";
        editError = "";
        editEnded();
    }
    // form = {title, user, notes, urls, password?, totp?, removeTotp?} – geht als JSON-Zeile über stdin
    // Prüfen geht schnell (lokal), gespeichert wird im Hintergrund: Formular sofort zu, Liste zeigt den neuen
    // Stand; Ergebnis kommt per IPC (editDone / editFailed), ein Fehler auch als Benachrichtigung.
    function saveEdit(form: var): void {
        const id = editId;
        if (!id || editBusy)
            return;
        editBusy = true;
        editError = "";
        jobComp.createObject(root, {
            command: [bin, "edit", id, "--detach"],
            input: JSON.stringify(form) + "\n",
            cb: (text, code, err) => {
                editBusy = false;
                let d = null;
                try {
                    d = code === 0 ? JSON.parse(text) : null;
                } catch (x) {
                    d = null;
                }
                if (!d) {
                    editError = err || "Could not save";
                    return;
                }
                setPending(id, form);
                editing = false;
                editNotes = "";
                showToast(form.delete ? "Moving to Recently Deleted…" : "Saving to iCloud in the background");
                editEnded();
            },
            running: true
        });
    }
    function setPending(id: string, form: var): void {
        const p = Object.assign({}, pending);
        if (form.delete) {
            p[id] = { deleted: true };
        } else {
            const o = {};
            if (form.title)
                o.title = form.title;
            if (form.user !== undefined)
                o.user = form.user;
            if (form.urls)
                o.urls = form.urls.map(u => /^[a-z]+:\/\//i.test(u) ? u : "https://" + u);
            if (form.notes !== undefined)
                o.hasNotes = form.notes !== "";
            if (form.totp)
                o.hasTotp = true;
            else if (form.removeTotp)
                o.hasTotp = false;
            p[id] = o;
        }
        pending = p;
    }
    function clearPending(id: string): void {
        const p = Object.assign({}, pending);
        delete p[id];
        pending = p;
    }
    property string pendingSel: ""      // nach dem Laden diesen Eintrag wählen (neue id bei neuer Website/Benutzer)

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
            property string input: ""       // Geheimnisse (Passwort, Notiz) gehen über stdin, nie als Argument
            property int left: 3            // stdout fertig + stderr fertig + beendet
            property int code: -1

            stdinEnabled: input !== ""
            onStarted: {
                if (input !== "") {
                    write(input);
                    input = "";
                    stdinEnabled = false;   // EOF
                }
            }

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
        // von scripts/passwords _edit-worker: Hintergrund-Speichern fertig bzw. gescheitert
        function editDone(id: string, newId: string): void {
            if (root.cur && root.cur.id === id && newId)
                root.pendingSel = newId;
            root.clearPending(id);
            root.load();
        }
        function editFailed(id: string, message: string): void {
            root.clearPending(id);
            root.load();
            if (root.open)
                root.showToast("Couldn't save · " + message);
        }
        // Klick auf die Fehler-Benachrichtigung: Panel am (unveränderten) Eintrag öffnen
        function openAt(id: string): void {
            root.pendingSel = id;
            if (root.open)
                root.load();
            else
                root.openIt();
        }
        // Gruppen-Chip wählen ("" = alle, "own" = eigene, sonst Gruppenname) – zum Testen
        function group(name: string): void {
            root.group = name === "own" ? root.ownGroup : name;
            root.sel = 0;
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

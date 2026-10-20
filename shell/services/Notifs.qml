pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications

// Benachrichtigungen: Quickshell übernimmt org.freedesktop.Notifications, sobald Plasmas Applet weg ist.
// Verlauf-Eintrag = { key, file, app, summary, body, icon, desktop, kind, urgent, time }.
// Popups: normal 6 s, dringend bis Klick. Fokus-Modus: nur Dringendes poppt auf. Verlauf: letzte 50.
// Klang zum Popup: Sounds.qml. Ruhezeiten + App-Regeln: NotifRules.qml, Doku docs/knowledge/shell-features.md.
// Flüchtig (Hint „transient“ oder App-Regel „transient“): nur Popup, nie im Verlauf – Meldungen, deren Inhalt anderswo
// steht (Mail-Kachel) oder die nur Rückmeldung sind (Screenshot gespeichert, kopiert …).
Singleton {
    id: root

    property var popups: []      // aktive Notification-Objekte
    property var history: []     // [{ app, summary, body, icon, time, file }]
    readonly property int popupMs: 6000
    // hält Sounds ab dem Start wach (Singletons entstehen erst beim ersten Zugriff, sonst fehlt das IPC-Ziel „sounds“)
    readonly property bool soundOn: Sounds.cfg.enabled !== false

    // jede neue Meldung (auch im Fokus-Modus), z. B. für ClaudeChats
    signal received(var n)

    // Art für die Icon-Kachel (Tabelle: config/notif-icons.json, Regeln in NotifIcons)
    function kindOf(n): string {
        const cat = n.hints ? String(n.hints["category"] || "") : "";
        const urg = n.urgency === NotificationUrgency.Critical ? "critical" : n.urgency === NotificationUrgency.Low ? "low" : "normal";
        return NotifIcons.kindOf(n.appName, n.summary, cat, urg, n.desktopEntry);
    }

    function isUrgent(n) {
        return n.urgency === NotificationUrgency.Critical;
    }

    // Datei zur Meldung: KDE-Apps (Spectacle …) hängen sie als x-kde-urls an, unser Snip als Bild-Icon (-i <pfad>)
    function fileOf(n): string {
        const urls = n.hints ? n.hints["x-kde-urls"] : null;
        const u = String((Array.isArray(urls) ? urls[0] : urls) || "");
        // nur lokale Dateien: die Meldung kommt von irgendeiner App, ein beliebiges Schema (https:, „--opt“ …)
        // ginge sonst ungeprüft an xdg-open/dolphin. %20 usw. dekodieren, sonst findet xdg-open die Datei nicht
        if (u)
            return u.startsWith("file:///") ? _decode(u.slice(7)) : "";
        // Snip schickt notify-send -i <pfad>: libnotify ≥ 0.8 legt Dateipfade als Hint image-path ab, appIcon bleibt
        // leer (n.image ist dann "image://icon//pfad") – vorher kam deshalb nie eine Datei an (geprüft per Test-Meldung).
        // image-path nur bei Snip (sonst wären z. B. Discord-Avatare plötzlich „Dateien“)
        const ip = n.hints && n.appName === "Snip" ? n.hints["image-path"] : "";
        const cands = [n.appIcon || "", String(ip || "")];
        for (const c of cands) {
            const p = c.startsWith("file:///") ? _decode(c.slice(7)) : c;
            if (/^\/.+\.(png|jpe?g|webp|gif|webm|mp4|mkv)$/i.test(p))
                return p;
        }
        return "";
    }
    function _decode(s: string): string {
        try {
            return decodeURIComponent(s);
        } catch (e) {
            return "";
        }
    }
    // Datei öffnen (Standard-App) bzw. in Dolphin markiert zeigen
    function openFile(path: string): void {
        if (path)
            Launch.cmd(["xdg-open", path]);
    }
    function showFile(path: string): void {
        if (path)
            Launch.cmd(["dolphin", "--select", path]);
    }

    NotificationServer {
        id: server
        keepOnReload: true
        bodySupported: true
        bodyMarkupSupported: false
        actionsSupported: true
        imageSupported: true
        persistenceSupported: true

        onNotification: n => {
            n.tracked = true;
            // keepOnReload liefert offene Meldungen nach jedem Shell-Neustart erneut aus: die stehen schon
            // im Verlauf (und haben schon gepoppt) -> nur weiter verfolgen, nicht doppelt eintragen
            if (n.lastGeneration) {
                // der closed-Handler hing an der alten Generation und ist mit ihr weg: neu verbinden, sonst bleibt
                // eine Meldung, die die App nach einem Shell-Neustart zurückzieht, für immer im Verlauf (getestet).
                // Schlüssel unbekannt -> neuester Eintrag mit dieser ID
                n.closed.connect(reason => {
                    if (reason !== NotificationCloseReason.CloseRequested)
                        return;
                    const i = root.history.findIndex(h => String(h.key || "").endsWith("-" + n.id));
                    if (i >= 0) {
                        root.history = root.history.filter((h, j) => j !== i);
                        root.saveHistory();
                    }
                });
                return;
            }
            const key = Date.now() + "-" + n.id;
            const urgent = root.isUrgent(n);
            const verdict = NotifRules.decide({ app: n.appName, desktop: n.desktopEntry || "", summary: n.summary, urgent: urgent });
            if (verdict.hide) {
                // App-Regel „hide“: weder Popup noch Panel
                root.received(n);
                n.dismiss();
                return;
            }
            // Fokus-Modus: nur Dringendes poppt auf; Ruhezeit und App-Regeln kommen obendrauf
            const shown = (!Focus.active || urgent) && verdict.popup;
            const fleeting = n.transient || verdict.transient;
            if (fleeting && !shown) {
                // flüchtig und gerade kein Popup erlaubt: nirgends anzeigen (wartende Absender wie mail-watch kommen frei)
                root.received(n);
                n.dismiss();
                return;
            }
            if (!fleeting) {
                root.history = [{
                    key: key,
                    file: root.fileOf(n),
                    app: n.appName,
                    summary: n.summary,
                    body: n.body,
                    icon: n.appIcon,
                    desktop: n.desktopEntry || "",
                    kind: root.kindOf(n),
                    urgent: urgent,
                    time: Qt.formatTime(new Date(), "HH:mm")
                }].concat(root.history).slice(0, 50);
                root.saveHistory();
            }
            if (shown)
                root.popups = root.popups.concat([n]);
            if (fleeting)
                root._fleeting = root._fleeting.concat([n]);
            // leiser Ton nur zum sichtbaren Popup (Regeln: notifsound.js)
            const ss = n.hints ? n.hints["suppress-sound"] : false;
            Sounds.notification({
                app: n.appName,
                desktop: n.desktopEntry || "",
                summary: n.summary,
                urgent: urgent,
                low: n.urgency === NotificationUrgency.Low,
                suppress: ss === true || ss === 1 || ss === "true"
            }, shown);
            if (verdict.held)
                root.holdBack();
            root.received(n);
            n.closed.connect(reason => {
                root.popups = root.popups.filter(p => p !== n);
                root._fleeting = root._fleeting.filter(p => p !== n);
                // zieht die App ihre Meldung selbst zurück (z. B. „Spectacle is Finishing … Please wait“),
                // gehört sie auch nicht in den Verlauf
                if (reason === NotificationCloseReason.CloseRequested) {
                    root.history = root.history.filter(h => h.key !== key);
                    root.saveHistory();
                }
            });
        }
    }

    // flüchtige Meldungen, deren Popup noch steht: geht das Popup, schließt die Meldung ganz
    property var _fleeting: []

    // nur schließen, was der Server noch verfolgt (Apps schließen Meldungen auch selbst)
    function close(n) {
        if (n && n.tracked)
            n.dismiss();
        popups = popups.filter(p => p !== n);
    }
    function dismissPopup(n) {
        if (_fleeting.includes(n)) {
            close(n);
            return;
        }
        popups = popups.filter(p => p !== n);
    }
    function clearHistory() {
        history = [];
        saveHistory();
    }
    // einen Verlaufs-Eintrag löschen; steht die Meldung noch als Popup da, verschwindet das mit
    function removeHistory(key: string): void {
        if (!key)
            return;
        for (const p of popups.slice())
            if (p && String(key).endsWith("-" + p.id))
                close(p);
        history = history.filter(h => h.key !== key);
        saveHistory();
    }
    // Popup wegklicken UND aus dem Verlauf löschen (Entf im Tastatur-Modus)
    function deletePopup(n): void {
        if (!n)
            return;
        const i = history.findIndex(h => String(h.key || "").endsWith("-" + n.id));
        close(n);
        if (i >= 0) {
            history = history.filter((h, j) => j !== i);
            saveHistory();
        }
    }

    // ---------- Ruhezeit: wie viel kam, während du weg warst ----------
    property int missed: 0
    // Zusammenfassung „N while you were away“ ist fällig (Ruhezeit vorbei, etwas liegt im Panel)
    readonly property bool summaryDue: missed > 0 && !NotifRules.quietNow && NotifRules.summaryEnabled
    function holdBack(): void {
        missed++;
        saveQuiet();
    }
    function ackSummary(): void {
        if (missed === 0)
            return;
        missed = 0;
        saveQuiet();
    }
    FileView {
        id: quietFile
        path: Quickshell.env("HOME") + "/.local/state/desktop/notifs-quiet.json"
        blockLoading: true
        printErrors: false
        onLoaded: {
            try {
                root.missed = Math.max(0, parseInt(JSON.parse(text()).missed) || 0);
            } catch (e) {}
        }
    }
    function saveQuiet() {
        quietFile.setText(JSON.stringify({ missed: missed }));
    }

    FileView {
        id: historyFile
        path: Quickshell.env("HOME") + "/.local/state/desktop/notifications.json"
        printErrors: false
        onLoaded: {
            try {
                root.history = JSON.parse(text());
            } catch (e) {}
        }
    }
    function saveHistory() {
        historyFile.setText(JSON.stringify(history));
    }

    IpcHandler {
        target: "notifs"

        function status(): string {
            return JSON.stringify({ popups: root.popups.length, history: root.history.length, missed: root.missed, quiet: NotifRules.quietNow });
        }
        function clear(): void {
            root.clearHistory();
        }
        // einen Eintrag löschen: Nr. index (0 = neuester), wie das ✕ in der Liste
        function remove(index: int): string {
            const h = root.history[index];
            if (!h)
                return "no such entry";
            root.removeHistory(h.key);
            return "ok";
        }
        // Test-Meldungen aus dem Panel entfernen (alle Einträge einer App), Antwort: Anzahl
        function forget(app: string): string {
            const n = root.history.length;
            root.history = root.history.filter(h => h.app !== app);
            root.saveHistory();
            return String(n - root.history.length);
        }
        // Ruhezeit-Entscheidung prüfen: decide "App" "Titel" false  ->  { popup, hide, held, why } (mit der Uhrzeit von jetzt)
        function decide(app: string, summary: string, urgent: bool): string {
            return JSON.stringify(NotifRules.decide({ app: app, desktop: "", summary: summary, urgent: urgent }));
        }
        // Liegt diese Zeit ("2026-10-18T23:30") in einer Ruhezeit? Nur Logik, ändert nichts.
        function quietAt(iso: string): string {
            const d = new Date(iso);
            return isNaN(d.getTime()) ? "invalid time" : String(NotifRules.quietAt(d));
        }
        function dismissAll(): void {
            for (const n of root.popups)
                if (n && n.tracked)
                    n.dismiss();
            root.popups = [];
        }
    }
}

pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Ungelesene Mails aus ~/.cache/desktop/mail.json (gepflegt von scripts/mail-status über desktop-mail.timer).
// Abruf nur Header (nichts wird dabei gelesen). Öffnen / gelesen / Papierkorb: scripts/mail-action (IMAP),
// Lesen/Schreiben selbst macht Thunderbird.
Singleton {
    id: root

    property string status: "loading"   // ok | no-config | config-error | loading
    property var accounts: []           // [{ name, label, status, error, unread, messages }]
    property real updated: 0
    readonly property int total: accounts.reduce((n, a) => n + (a.unread || 0), 0)
    readonly property bool configured: status === "ok"
    // Konten, die noch etwas brauchen (Benutzer, Passwort, Login)
    readonly property var problems: accounts.filter(a => a.status !== "ok")
    // neueste ungelesene über alle Konten (accountName = Schlüssel in secrets.json für mail-action)
    readonly property var latest: accounts.reduce((l, a) => l.concat((a.messages || []).map(m => Object.assign({ account: a.label, accountName: a.name }, m))), [])
        .sort((x, y) => y.date - x.date)

    // Konten + app-spezifische Passwörter stehen in secrets.json ("accounts"), Anleitung im Repo
    readonly property string configPath: "secrets.json"
    readonly property string guidePath: "docs/setup/mail-calendar.md"

    // leiser Hinweis zu einem Konto, das noch etwas braucht (auch für Agenda)
    function problemText(a: var): string {
        switch (a.status) {
        case "no-user":
            return a.label + ": add your user name in " + configPath + " (accounts)";
        case "no-password":
            return a.label + ": add your app-specific password in " + configPath + " (accounts)";
        case "auth":
            return a.label + ": login failed, check the app-specific password";
        default:
            return a.label + ": " + (a.error || "unreachable");
        }
    }
    // kurze Zeitangabe: heute "14:02", gestern "Yesterday", diese Woche "Mon", sonst "12 Oct"
    readonly property var dayNames: ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
    readonly property var monthNames: ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
    function when(t: real): string {
        if (!t)
            return "";
        const d = new Date(t);
        const today = new Date();
        today.setHours(0, 0, 0, 0);
        const days = Math.floor((today.getTime() - new Date(d.getFullYear(), d.getMonth(), d.getDate()).getTime()) / 86400000 + 0.5);
        if (days <= 0)
            return Qt.formatTime(d, "HH:mm");
        if (days === 1)
            return "Yesterday";
        if (days < 7)
            return dayNames[d.getDay()];
        return d.getDate() + " " + monthNames[d.getMonth()];
    }

    // Thunderbird da (natives RPM, sonst Flatpak org.mozilla.thunderbird_esr – scripts/app-run)? Sonst nur Anzeige
    property bool clientInstalled: false

    // Thunderbird in einer Ansicht öffnen: -mail = erster Tab (Mail), -calendar = Kalender-Tab.
    // Läuft er schon, reicht Thunderbird die Flags an die laufende Instanz weiter: Fenster nach vorn, Tab wechselt.
    function openView(flag: string): void {
        if (clientInstalled)
            Launch.run("thunderbird", [flag]);
    }
    function openClient(): void {
        openView("-mail");
    }
    function openCalendar(): void {
        openView("-calendar");
    }
    // Öffnen + Markieren: scripts/mail-action. Nicht direkt "thunderbird mid:…" – frisch gestartet kennt Thunderbird
    // neue Mails noch nicht (Dialog „Message … not found“); mail-action wartet, bis sie in seinem Index steht.
    readonly property string actionBin: Quickshell.shellDir + "/../scripts/mail-action"
    function canMarkRead(m: var): bool {
        return !!m && m.uid > 0 && !!m.accountName;
    }
    function actionArgs(m: var): var {
        const a = [];
        if (m.accountName)
            a.push("--account", m.accountName);
        if (m.uid > 0)
            a.push("--uid", String(m.uid));
        if (m.mid)
            a.push("--mid", m.mid);
        return a;
    }
    // genau diese Mail in Thunderbird öffnen und als gelesen markieren; ohne Message-ID den Posteingang
    function openMessage(m: var): void {
        if (!clientInstalled)
            return;
        if (!m || !m.mid) {
            openClient();
            return;
        }
        // eigener Scope über Launch: mail-action startet Thunderbird und wartet ggf. bis zu 60 s
        Launch.cmd([actionBin, "open"].concat(actionArgs(m)));
        if (canMarkRead(m))
            dropLocally(m);
    }
    // nur als gelesen markieren (Thunderbird bleibt zu)
    function markRead(m: var): void {
        if (!canMarkRead(m))
            return;
        Quickshell.execDetached([actionBin, "seen"].concat(actionArgs(m)));
        dropLocally(m);
    }
    // in den Papierkorb (IMAP, wiederherstellbar), nie endgültig löschen
    function trash(m: var): void {
        if (!canMarkRead(m))
            return;
        Quickshell.execDetached([actionBin, "trash"].concat(actionArgs(m)));
        dropLocally(m);
    }
    // sofort aus Kachel/Launcher nehmen; mail-action schreibt mail.json gleich mit, der nächste Abruf bestätigt
    function dropLocally(m: var): void {
        accounts = accounts.map(a => a.name !== m.accountName ? a : Object.assign({}, a, {
            unread: Math.max(0, (a.unread || 0) - 1),
            messages: (a.messages || []).filter(x => x.uid !== m.uid)
        }));
    }

    Process {
        id: clientCheck
        running: true
        command: [Launch.appRun, "--which", "thunderbird"]
        onExited: code => root.clientInstalled = code === 0
    }
    // nachinstalliert? alle 10 min nachsehen, bis er da ist
    Timer {
        interval: 600000
        repeat: true
        running: !root.clientInstalled
        onTriggered: clientCheck.running = true
    }

    FileView {
        path: Quickshell.env("HOME") + "/.cache/desktop/mail.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            try {
                const d = JSON.parse(text());
                root.status = d.status || "ok";
                root.accounts = d.accounts || [];
                root.updated = d.updated || 0;
            } catch (e) {}
        }
        onLoadFailed: root.status = "no-config"
    }
}

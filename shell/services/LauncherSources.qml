pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Daten für die Launcher-Präfixe, die nicht in eigenen Diensten stecken:
//  - Wort-Präfixe zerlegen (pw, cal, m, c + Web-Kürzel aus WebShortcuts)
//  - Passwörter: nur Metadaten (Titel, Websites, Benutzername) aus scripts/passwords list – nie ein Geheimnis in der Liste.
//    Kopieren ruft scripts/passwords copy auf (wl-copy --sensitive, nach 30 s geleert), wie das Passwort-Panel.
//  - Kalender: kommende Termine aus Agenda
//  - Claude fragen (c <text>): neuer Chat mit dem Text in Claude Desktop (claude://), sonst claude.ai in Helium
Singleton {
    id: root

    readonly property string pwBin: Quickshell.shellDir + "/../scripts/passwords"

    // ------------------------------------------------------------ Präfixe
    // "pw foo" -> { mode: "pw ", term: "foo", key: "" }, "yt foo" -> { mode: <Web-Chip>, term: "foo", key: "yt" }
    // einzelne Zeichen (# = : ; / @ ?) bleiben im Launcher
    function parse(q: string): var {
        const sp = q.indexOf(" ");
        if (sp > 0) {
            const key = q.slice(0, sp).toLowerCase();
            const rest = q.slice(sp + 1).trim();
            if (key === "pw" || key === "cal" || key === "c" || key === "m")
                return { mode: key + " ", term: rest, key: key };
            const w = WebShortcuts.find(key);
            if (w)
                return { mode: WebShortcuts.chipPrefix, term: rest, key: w.key };
        }
        return null;
    }

    // ------------------------------------------------------------ Claude fragen (c <text>)
    // Claude Desktop (distrobox "ubuntu") meldet sich für x-scheme-handler/claude an. Dann öffnet
    // claude://claude.ai/new?q=… dort einen neuen Chat mit dem Text (gleiches Schema wie die "New Chat"-Aktion
    // der .desktop-Datei); ohne Handler claude.ai/new?q=… in Helium. Handler wird beim ersten c-Präfix geprüft.
    property string claudeHandler: ""   // .desktop-ID, leer = keiner (oder noch nicht geprüft)
    property bool claudeChecked: false

    function claudeEnsure(): void {
        if (!claudeChecked && !claudeCheck.running)
            claudeCheck.running = true;
    }

    function askClaude(q: string): void {
        const t = String(q || "").trim();
        const path = "claude.ai/new" + (t ? "?q=" + encodeURIComponent(t) : "");
        if (claudeHandler)
            Launch.cmd(["xdg-open", "claude://" + path]);
        else
            Launch.cmd(["helium", "https://" + path]);
    }

    Process {
        id: claudeCheck
        command: ["xdg-mime", "query", "default", "x-scheme-handler/claude"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.claudeHandler = text.trim();
                root.claudeChecked = true;
            }
        }
    }

    // ------------------------------------------------------------ Passwörter (Metadaten)
    property var pwItems: []          // [{ id, title, user, urls, hasPassword, hasTotp, wifi }]
    property bool pwReady: false
    property string pwError: ""
    property real pwLoadedAt: 0

    // beim ersten pw-Präfix (und danach höchstens alle 5 min) laden
    function pwEnsure(): void {
        if (pwList.running || (pwReady && Date.now() - pwLoadedAt < 300000))
            return;
        pwList.running = true;
    }

    // wie PwPanel: gespeicherte WLAN-Passwörter bleiben weg
    function pwVisible(e: var): bool {
        return !e.wifi;
    }

    function hostOf(url: string): string {
        return (url || "").replace(/^[a-z]+:\/\//i, "").split("/")[0].replace(/^www\./, "");
    }

    // [{ e, host, score }] – Titel, Website, Benutzername (Gewichtung wie im Panel)
    function pwSearch(term: string): var {
        const out = [];
        for (const e of pwItems) {
            if (!pwVisible(e))
                continue;
            const host = e.urls && e.urls.length ? hostOf(e.urls[0]) : "";
            const s = term ? Math.max(Fuzzy.score(term, e.title), Fuzzy.score(term, (e.urls || []).map(hostOf).join(" ")) - 20, Fuzzy.score(term, e.user) - 40) : 1;
            if (s > 0)
                out.push({ e: e, host: host, score: s });
        }
        return out;
    }

    // Passwort (bzw. 2FA-Code, wenn es nur den gibt) in die Zwischenablage – das Skript macht --sensitive + Leeren nach 30 s
    function pwCopy(e: var): void {
        const field = e.hasPassword ? "password" : "totp";
        Quickshell.execDetached(["sh", "-c", "\"$0\" copy \"$1\" \"$2\" && notify-send -u low -t 2500 -a Launcher \"$3\" 'Clears in 30 s'",
            pwBin, e.id, field, field === "password" ? "Password copied" : "2FA code copied"]);
    }

    Process {
        id: pwList
        command: [root.pwBin, "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const d = JSON.parse(text);
                    root.pwItems = d.map(e => ({ id: e.id, title: e.title || "", user: e.user || "", urls: e.urls || [], hasPassword: !!e.hasPassword, hasTotp: !!e.hasTotp, wifi: !!e.wifi }));
                    root.pwReady = true;
                    root.pwError = "";
                    root.pwLoadedAt = Date.now();
                } catch (e) {
                    root.pwError = "Passwords not available (scripts/passwords list)";
                }
            }
        }
    }

    // ------------------------------------------------------------ Kalender
    // Termine, die noch laufen oder kommen (nach Beginn sortiert)
    function upcoming(): var {
        const now = Agenda.now;
        return Agenda.allEvents.filter(e => (e.end > e.start ? e.end : e.start + 1) > now).sort((a, b) => a.start - b.start);
    }

    // "Today · 10:00–11:00", "Tomorrow · all day", "Mon 19 Oct · 09:30"
    function when(e: var): string {
        const en = Qt.locale("en_US");
        const day = Agenda.dayOf(e.start);
        let d = day <= Agenda.dayStart ? "Today" : day === Agenda.dayEnd ? "Tomorrow" : en.toString(new Date(e.start), "ddd d MMM");
        if (e.start < Agenda.dayStart && e.end > Agenda.dayStart)
            d = "Today";
        if (e.allDay)
            return d + " · all day";
        return d + " · " + en.toString(new Date(e.start), "HH:mm") + (e.end > e.start ? "–" + en.toString(new Date(e.end), "HH:mm") : "");
    }
}

pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Absturz-Meldungen statt DrKonqi (Karte: modules/crash, Doku: docs/knowledge/shell-features.md).
// Quelle: systemd-coredump schreibt jeden Absturz eines User-Prozesses ins User-Journal (lesbar ohne sudo).
//  - seed:   einmal beim Start `journalctl --user -t systemd-coredump --since today` → zählt die Abstürze von heute, zeigt nichts
//  - follow: `journalctl --user -f -n 0 …` → ereignisgesteuert, jede neue Zeile = ein neuer Absturz → Karte
// Abstürze derselben App werden zu einer Gruppe zusammengefasst (Schlüssel = App-Name klein).
// Kindprozesse von Chromium/Electron (--type=renderer, gpu-process, utility …) sind markiert: die App läuft dann oft weiter.
// Ob die App noch läuft, prüft `pgrep -x <comm>` – nur solange eine Karte steht (alle 5 s), sonst gar nicht.
Singleton {
    id: root

    // sichtbare Gruppen, neueste zuerst: [key]
    property var items: []
    // Zähler für Bindungen (Gruppen sind einfache JS-Objekte)
    property int rev: 0

    // key → { key, name, desktopId, runName, exe, comm, pid, sig, time, child, childType, running, message, cmdline, times[], fake, shown }
    // (Test-Abstürze: fake = true, zählen nicht zu „heute“)
    property var groups: ({})
    // schon gesehene Einträge (Cursor), damit seed + follow nichts doppelt zählen
    property var seen: ({})
    readonly property real startedAt: Date.now()

    readonly property var fields: ["COREDUMP_PID", "COREDUMP_SIGNAL", "COREDUMP_SIGNAL_NAME", "COREDUMP_EXE", "COREDUMP_COMM",
        "COREDUMP_CMDLINE", "COREDUMP_TIMESTAMP", "COREDUMP_USER_UNIT", "COREDUMP_CGROUP", "MESSAGE"]
    readonly property var journalBase: ["journalctl", "--user", "--no-pager", "-o", "json", "-t", "systemd-coredump",
        "--output-fields=" + fields.join(",")]

    // Apps, die scripts/app-run startet (RPM zuerst, Flatpak-Rückfall)
    readonly property var runNames: ["discord", "spotify", "thunderbird", "equibop"]
    // hübsche Namen, wo die .desktop-Datei nichts Passendes liefert
    readonly property var names: ({
        qs: "Desktop shell", quickshell: "Desktop shell", hyprland: "Hyprland", code: "VS Code",
        helium: "Helium", "xdg-desktop-por": "Desktop portal", "drkonqi-coredum": "DrKonqi"
    })
    // nie per Knopf neu starten (startet systemd selbst bzw. ist die Sitzung)
    readonly property var noRestart: ["qs", "quickshell", "hyprland", "xdg-desktop-por", "drkonqi-coredum", "ksecretd"]

    readonly property var sigNames: ({ 4: "SIGILL", 5: "SIGTRAP", 6: "SIGABRT", 7: "SIGBUS", 8: "SIGFPE", 11: "SIGSEGV", 31: "SIGSYS" })

    function byKey(key: string): var {
        return groups[key] || null;
    }

    function startOfToday(): real {
        const d = new Date();
        d.setHours(0, 0, 0, 0);
        return d.getTime();
    }
    function todayCount(key: string): int {
        const g = groups[key];
        if (!g)
            return 0;
        const t0 = startOfToday();
        return g.times.filter(t => t >= t0).length;
    }

    // systemd-Unit → App-ID: app-discord-327185.scope, app-flatpak-com.x.Y-123.scope, app-Hyprland-foo@ab.service
    function unitApp(unit: string): string {
        let u = String(unit || "").replace(/.*\//, "").replace(/\\x2d/g, "-");
        if (!u.startsWith("app-"))
            return "";
        u = u.replace(/^app-/, "").replace(/\.(scope|service)$/, "").replace(/@.*$/, "");
        u = u.replace(/^(flatpak|Hyprland|KDE|gnome)-/, "");
        return u.replace(/-[0-9a-f]+$/, "");
    }

    // .desktop-Datei: zuerst exakt (Unit-App-ID, Programmname), dann geraten über den Prozessnamen
    function entryFor(ids: var, guess: string): var {
        for (const id of ids) {
            const e = id ? DesktopEntries.byId(id) : null;
            if (e && e.name)
                return e;
        }
        const h = guess ? DesktopEntries.heuristicLookup(guess) : null;
        return h && h.name ? h : null;
    }

    function cleanCmdline(c: string): string {
        let s = String(c || "");
        if (s.startsWith("$'"))
            s = s.slice(2).replace(/'$/, "");
        return s;
    }

    function childType(cmdline: string): string {
        const m = /--type=([a-z-]+)/.exec(cmdline);
        if (!m)
            return "";
        return ({ renderer: "renderer", "gpu-process": "GPU process", utility: "utility process", zygote: "zygote",
            broker: "broker", "crashpad-handler": "crash handler" })[m[1]] || m[1];
    }

    function strOf(v: var): string {
        if (v === undefined || v === null)
            return "";
        // nicht-UTF-8 liefert journalctl als Byte-Liste
        if (Array.isArray(v))
            return String.fromCharCode.apply(null, v.slice(0, 4000));
        return String(v);
    }

    function ingest(d: var, live: bool): void {
        const pid = strOf(d.COREDUMP_PID);
        if (!pid)
            return;
        const cursor = d.__CURSOR || (pid + "@" + d.__REALTIME_TIMESTAMP);
        if (seen[cursor])
            return;
        seen[cursor] = true;

        const exe = strOf(d.COREDUMP_EXE);
        const comm = strOf(d.COREDUMP_COMM);
        const cmdline = cleanCmdline(strOf(d.COREDUMP_CMDLINE));
        const unitId = unitApp(strOf(d.COREDUMP_USER_UNIT) || strOf(d.COREDUMP_CGROUP));
        const base = exe.replace(/.*\//, "");
        const time = Number(strOf(d.COREDUMP_TIMESTAMP) || strOf(d.__REALTIME_TIMESTAMP)) / 1000 || Date.now();
        const sigNum = Number(strOf(d.COREDUMP_SIGNAL));

        const lc = comm.toLowerCase();
        // die Unit zählt nur, wenn sie zum Prozess passt: im VS-Code-Terminal gestartete Tools (pnpm, biome) laufen
        // in VS Codes Unit, sind aber nicht VS Code
        const ul = unitId.toLowerCase();
        const ulast = ul.replace(/.*\./, "");
        const unitFits = ulast !== "" && lc !== "" && (ulast.includes(lc) || lc.includes(ulast));
        const runName = runNames.find(n => lc === n || base.toLowerCase() === n || (unitFits && ul === n)) || "";
        const entry = noRestart.includes(lc) ? null : entryFor([unitFits ? unitId : "", base, base.toLowerCase(), lc], lc);
        const name = names[lc] || (runName ? runName.charAt(0).toUpperCase() + runName.slice(1) : "")
            || (entry ? entry.name : "") || (base ? base.charAt(0).toUpperCase() + base.slice(1) : comm);
        const key = name.toLowerCase();

        const g = groups[key] || { key: key, times: [], shown: false, running: false };
        g.name = name;
        g.desktopId = entry ? entry.id : "";
        g.runName = runName;
        g.canRestart = !noRestart.includes(lc) && (runName !== "" || g.desktopId !== "");
        g.exe = exe;
        g.comm = comm;
        g.pid = pid;
        g.sig = strOf(d.COREDUMP_SIGNAL_NAME) || sigNames[sigNum] || (sigNum ? "signal " + sigNum : "");
        g.time = time;
        g.cmdline = cmdline;
        g.childType = childType(cmdline);
        g.child = g.childType !== "";
        g.message = strOf(d.MESSAGE);
        g.fake = !!d.fake;
        // Test-Abstürze zählen nicht mit
        if (!g.fake)
            g.times.push(time);
        groups[key] = g;

        // nur neue Abstürze zeigen (der Seed zählt nur) – Ausnahme: die Shell selbst ist eben abgestürzt und neu gestartet
        const shellJustDied = !live && (lc === "qs" || lc === "quickshell") && time > startedAt - 120000;
        // Karte nur für Apps (eigene .desktop/Startname/bekannter Name) – CLI-Tools aus dem Terminal (pnpm, biome …)
        // zählen nur mit, ohne Karte (`crash list` zeigt sie)
        const isApp = g.fake || runName !== "" || g.desktopId !== "" || names[lc] !== undefined || lc === "qs" || lc === "quickshell";
        if (isApp && (live || shellJustDied)) {
            g.shown = true;
            items = [key].concat(items.filter(k => k !== key));
            checkRunning();
        }
        rev++;
    }

    function dismiss(key: string): void {
        const g = groups[key];
        if (g)
            g.shown = false;
        items = items.filter(k => k !== key);
        rev++;
    }
    function hideAll(): void {
        for (const k of items)
            if (groups[k])
                groups[k].shown = false;
        items = [];
        rev++;
    }

    function restart(key: string): void {
        const g = groups[key];
        if (!g || !g.canRestart)
            return;
        if (g.runName)
            Launch.run(g.runName);
        else
            Launch.app(g.desktopId);
        dismiss(key);
    }

    // volle Meldung (Stack-Trace, Module …) im Terminal; coredumpctl blättert selbst (less)
    function openDetails(key: string): void {
        const g = groups[key];
        if (!g)
            return;
        if (g.fake)
            Launch.cmd(["xdg-terminal-exec", "sh", "-c", "coredumpctl list --since today; echo; echo '(test crash – no real dump)'; read -r _"]);
        else
            Launch.cmd(["xdg-terminal-exec", "coredumpctl", "info", g.pid]);
    }

    // Test: Absturz vortäuschen (Discord, Hauptprozess bzw. Renderer), ändert nichts am System
    function fake(child: bool): void {
        const now = Date.now();
        ingest({
            __CURSOR: "fake-" + now,
            fake: true,
            COREDUMP_PID: String(90000 + Math.floor(Math.random() * 9999)),
            COREDUMP_SIGNAL: "11",
            COREDUMP_SIGNAL_NAME: "SIGSEGV",
            COREDUMP_EXE: Quickshell.env("HOME") + "/.config/discord/app-1.0.162/Discord",
            COREDUMP_COMM: "Discord",
            COREDUMP_CMDLINE: Quickshell.env("HOME") + "/.config/discord/app-1.0.162/Discord" + (child ? " --type=renderer" : ""),
            COREDUMP_TIMESTAMP: String(now * 1000),
            COREDUMP_USER_UNIT: "app-discord-1.scope",
            MESSAGE: "Process 12345 (Discord) of user 1000 dumped core.\n\nTest crash from `qs ipc call crash test`.\n\nStack trace of thread 12345:\n#0  0x00007fe17461b021 n/a (n/a + 0x0)\n#1  0x00005578a1c3e9f0 n/a (/app/discord/Discord + 0x3e9f0)\n#2  0x00007fe1745d2b8a start_thread (libc.so.6 + 0x92b8a)\nELF object binary architecture: AMD x86-64"
        }, true);
    }

    // ---------- läuft die App noch? ----------
    property var checkQueue: []
    function checkRunning(): void {
        if (running.running)
            return;
        const ks = items.filter(k => groups[k] && groups[k].comm);
        if (!ks.length)
            return;
        checkQueue = ks;
        // pro Gruppe eine Zeile: 0 = läuft, 1 = nicht
        running.command = ["sh", "-c", "for c in \"$@\"; do if pgrep -x -u \"$(id -u)\" -- \"$c\" >/dev/null; then echo 0; else echo 1; fi; done", "sh"]
            .concat(ks.map(k => groups[k].comm));
        running.running = true;
    }
    Process {
        id: running
        property var out: []
        stdout: SplitParser {
            onRead: line => running.out.push(line.trim())
        }
        onExited: {
            const q = root.checkQueue;
            for (let i = 0; i < q.length; i++) {
                const g = root.groups[q[i]];
                // Test-Absturz eines Hauptprozesses: als „läuft nicht“ zeigen, damit Restart zu sehen ist
                if (g)
                    g.running = g.fake && !g.child ? false : out[i] === "0";
            }
            out = [];
            root.rev++;
        }
    }
    // nur solange eine Karte steht; kurz nach dem Absturz ein zweites Mal (Kindprozesse sterben verzögert)
    Timer {
        interval: 5000
        repeat: true
        running: root.items.length > 0
        onTriggered: root.checkRunning()
    }
    Timer {
        id: recheck
        interval: 1500
        onTriggered: root.checkRunning()
    }
    onItemsChanged: if (items.length)
        recheck.restart()

    // ---------- Journal ----------
    Process {
        id: seed
        running: true
        command: root.journalBase.concat(["--since", "today"])
        stdout: SplitParser {
            onRead: line => root.parse(line, false)
        }
    }
    Process {
        id: follow
        running: true
        command: root.journalBase.concat(["-f", "-n", "0"])
        stdout: SplitParser {
            onRead: line => root.parse(line, true)
        }
        // journalctl beendet (Journal rotiert, Fehler): nach kurzer Pause neu
        onExited: restartFollow.start()
    }
    Timer {
        id: restartFollow
        interval: 10000
        onTriggered: follow.running = true
    }

    function parse(line: string, live: bool): void {
        if (!line || line[0] !== "{")
            return;
        try {
            ingest(JSON.parse(line), live);
        } catch (e) {
            console.warn("Crashes: Journalzeile nicht lesbar: " + e);
        }
    }
}

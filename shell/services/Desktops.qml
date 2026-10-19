pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Virtuelle Desktops unter Hyprland. Liste (Reihenfolge + Namen) gehört der Shell und liegt in
// ~/.local/state/desktop/desktops.json – Hyprland löscht leere Workspaces, ein Desktop bleibt trotzdem.
// id = Workspace-Nummer auf dem Hauptmonitor (als Text, wie früher die KWin-IDs); Nebenmonitore: siehe Hypr.
// Umsortieren ändert nur die Liste (kein Fenster wandert), Namen hängen am Desktop.
Singleton {
    id: root

    // [{ id: 3, name: "Code" }, …] in Anzeige-Reihenfolge. name = "" heißt: kein eigener Name,
    // angezeigt wird dann "Workspace <Platz>" (folgt dem Platz in der Leiste, nicht der Hyprland-ID).
    property var list: []
    readonly property var ids: list.map(d => String(d.id))
    readonly property var names: list.map((d, i) => d.name || ("Workspace " + (i + 1)))
    readonly property string current: String(Hypr.currentDesk)
    readonly property int count: list.length
    property bool _loaded: false

    // Standardnamen ("Workspace 3", früher "Desktop 3") werden nie gespeichert – nur eigene Namen
    function _clean(name: var): string {
        const n = String(name ?? "").trim();
        return /^(Workspace|Desktop) \d+$/.test(n) ? "" : n;
    }
    function _save(): void {
        if (broken)
            return;
        file.setText(JSON.stringify(list.map(d => ({ id: d.id, name: d.name })), null, 1));
    }
    function _set(next: var): void {
        list = next;
        _save();
    }
    function _freeId(): int {
        const used = list.map(d => d.id);
        for (let i = 1; i < 100; i++)
            if (!used.includes(i))
                return i;
        return 99;
    }

    FileView {
        id: file
        path: Quickshell.env("HOME") + "/.local/state/desktop/desktops.json"
        printErrors: false
        onLoaded: {
            try {
                const j = JSON.parse(text());
                const raw = (Array.isArray(j) ? j : []).filter(d => d && d.id > 0 && d.id < 100);
                root.list = raw.map(d => ({ id: Number(d.id), name: root._clean(d.name) }));
                // einmalige Reparatur: Standardnamen aus der Datei entfernen
                if (raw.some(d => d.name !== root._clean(d.name)))
                    root._save();
            } catch (e) {
                root.list = [];
                if (text().trim() !== "") {
                    // kaputte Datei nicht mit der neu erkannten Liste überschreiben: erst sichern, bis dahin nicht speichern
                    console.warn("Desktops: desktops.json is broken (" + e + "), backing it up before the next save");
                    root.broken = true;
                    backup.command = ["cp", "--", file.path, file.path + ".broken-" + Date.now() + ".bak"];
                    backup.running = true;
                }
            }
            root._start();
        }
        onLoadFailed: root._start()
    }
    // true = desktops.json war kaputt und ist noch nicht gesichert → _save() schreibt nichts
    property bool broken: false
    Process {
        id: backup
        onExited: code => {
            if (code === 0) {
                root.broken = false;
                root._save();
            } else {
                console.warn("Desktops: backup of broken desktops.json failed, not saving");
            }
        }
    }
    function _start(): void {
        _loaded = true;
        adopt();
        _sync();
    }
    // einmal beim Start (sobald Hyprland seine Monitore gemeldet hat): Nebenmonitore auf den aktuellen Desktop stellen
    property bool _synced: false
    function _sync(): void {
        if (_synced || !_loaded || !Hypr.mainMonitor || Hypr.monitors.values.length < 1)
            return;
        _synced = true;
        Hypr.batch(Hypr.switchCmds(Hypr.currentDesk), null);
    }

    // Workspaces, die es gibt, aber in der Liste fehlen (z. B. per Hyprland-Kürzel angelegt), aufnehmen
    function adopt(): void {
        if (!_loaded)
            return;
        const have = list.map(d => d.id);
        const want = [Hypr.currentDesk];
        for (const t of Hypr.toplevels.values) {
            const d = Hypr.deskOf(t);
            if (d > 0)
                want.push(d);
        }
        const add = [];
        for (const d of want)
            if (d > 0 && !have.includes(d) && !add.includes(d))
                add.push(d);
        if (!add.length && list.length)
            return;
        const next = list.slice();
        for (const d of add.sort((a, b) => a - b))
            next.push({ id: d, name: "" });
        if (!next.length)
            next.push({ id: 1, name: "" });
        _set(next);
    }
    Connections {
        target: Hypr
        function onVersionChanged() {
            root.adopt();
            root._sync();
        }
    }

    function switchTo(id: string): void {
        const d = Number(id);
        if (d > 0)
            Hypr.batch(Hypr.switchCmds(d), null);
    }
    // früher ohne KWins Schiebe-Animation; Umsortieren wechselt unter Hyprland gar nicht mehr
    function switchToQuiet(id: string): void {
        switchTo(id);
    }

    // neuer, leerer Desktop am Ende – und gleich hin; onCreated(id) läuft, wenn der Wechsel durch ist
    function add(name: string, onCreated: var): void {
        const id = _freeId();
        const next = list.slice();
        next.push({ id: id, name: _clean(name) });
        _set(next);
        Hypr.batch(Hypr.switchCmds(id), () => {
            if (onCreated)
                onCreated(String(id));
        });
    }

    // entfernen: Fenster wandern auf den Nachbar-Desktop (gleicher Monitor), wie bei KWin
    function remove(id: string): void {
        const d = Number(id);
        const i = list.findIndex(x => x.id === d);
        if (count <= 1 || i < 0)
            return;
        const to = (list[i - 1] ?? list[i + 1]).id;
        const cmds = [];
        if (Hypr.currentDesk === d)
            for (const c of Hypr.switchCmds(to))
                cmds.push(c);
        for (const t of Hypr.toplevels.values) {
            if (Hypr.deskOf(t) !== d)
                continue;
            const ws = Hypr.wsFor(Hypr.slotOf(t), to);
            cmds.push("dispatch movetoworkspacesilent " + (Hypr.isMinimized(t) ? "special:m" + ws : ws) + "," + Hypr.sel(t));
        }
        const next = list.slice();
        next.splice(i, 1);
        _set(next);
        Hypr.batch(cmds, null);
    }

    function rename(id: string, name: string): void {
        const d = Number(id);
        _set(list.map(x => x.id === d ? { id: x.id, name: _clean(name) } : x));
    }

    // Reihenfolge: Desktop von Platz from nach Platz to
    function move(from: int, to: int): void {
        if (from === to || from < 0 || to < 0 || from >= list.length || to >= list.length)
            return;
        const next = list.slice();
        next.splice(to, 0, next.splice(from, 1)[0]);
        _set(next);
    }

    // Platz n (1 = erster) – für Super+1…9
    function goIndex(n: int): void {
        const d = list[n - 1];
        if (d)
            switchTo(String(d.id));
    }

    IpcHandler {
        target: "desktops"
        function status(): string {
            return JSON.stringify({ current: root.current, desktops: root.list.map((d, i) => ({ id: d.id, name: d.name, label: root.names[i] })) });
        }
        // Super+1…9 = Desktop auf Platz n
        function go(n: int): void {
            root.goIndex(n);
        }
        // aktives Fenster auf Desktop-Platz n schieben (ohne mitzugehen)
        function moveWindow(n: int): void {
            const d = root.list[n - 1];
            if (d && Hypr.activeToplevel)
                Hypr.moveToDesk(Hypr.activeToplevel, d.id);
        }
        function add(): void {
            root.add("", null);
        }
    }
}

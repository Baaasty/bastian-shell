pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Szenen-Engine: Gruppen von Schritten (Licht, Ruhe, Fenster, Musik …) auf einer Taste, an und aus.
// Dateibasiert und ohne KI pflegbar: config/scenes.json (Format und Beispiele: docs/SCENES.md).
// Beim Einschalten merkt sich jeder Schritt den vorherigen Zustand (nur die Felder, die er ändert);
// beim Ausschalten wird er zurückgesetzt, danach laufen die "off"-Schritte der Szene.
// Zustand: ~/.local/state/desktop/scenes.json. Bedienung: scripts/scene, IPC "scene", Kürzel in hypr/binds.conf.
// Schritt fehlt der Dienst (Hue nicht gekoppelt, Lampe offline …), wird er übersprungen und im Log vermerkt.
Singleton {
    id: root

    readonly property string home: Quickshell.env("HOME")
    // Inhalt von config/scenes.json: { settings, commands, scenes }
    property var cfg: ({ settings: {}, commands: {}, scenes: {} })
    property bool cfgReady: false
    // eingeschaltete Szenen: Name -> { at, prev: [{ ...schritt, snap }] }
    property var active: ({})
    property bool stateReady: false
    readonly property var names: Object.keys(cfg.scenes || {})

    property string busy: ""         // Szene, die gerade läuft
    property var lastRun: []         // Protokollzeilen des letzten Laufs
    property var _jobs: []
    property var _job: null
    property var _wait: null
    property bool _inited: false
    property bool _mute: false       // Fokus-Schritt einer Szene ändert den Timer selbst

    // Aufruf aus shell.qml: Singletons werden erst beim ersten Zugriff geladen
    function init(): void {
        if (_inited)
            return;
        _inited = true;
    }

    function note(msg: string): void {
        console.log("scenes: " + msg);
        lastRun = lastRun.concat([msg]);
    }

    // ---------- Bedienung ----------
    // dir: "on" | "off" | "toggle"; dry = nur zeigen, nichts ändern
    function run(name: string, dir: string, dry: bool): void {
        _jobs = _jobs.concat([{ name: name, dir: dir, dry: !!dry }]);
        _next();
    }
    function isOn(name: string): bool {
        return active[name] !== undefined;
    }
    function _next(): void {
        if (_job || !_jobs.length)
            return;
        const j = _jobs[0];
        _jobs = _jobs.slice(1);
        _job = j;
        busy = j.name;
        lastRun = [];
        _start(j);
    }
    function _finish(): void {
        _job = null;
        _wait = null;
        busy = "";
        _next();
    }

    function _start(j: var): void {
        const sc = (cfg.scenes || {})[j.name];
        if (!cfgReady || !sc) {
            note("unknown scene '" + j.name + "'" + (names.length ? " (known: " + names.join(", ") + ")" : ""));
            return _finish();
        }
        const dir = j.dir === "toggle" ? (isOn(j.name) ? "off" : "on") : j.dir;
        j.dir = dir;
        if (dir === "off") {
            if (!isOn(j.name) && !j.dry) {
                note(j.name + ": already off");
                return _finish();
            }
            _runOff(j, sc);
            return _finish();
        }
        if (isOn(j.name) && !j.dry) {
            note(j.name + ": already on");
            return _finish();
        }
        const steps = (sc.on || []).filter(s => s && s.enabled !== false);
        note(j.name + ": on" + (j.dry ? " (dry run)" : ""));
        // Fokus-Schritte zuerst: sie lösen ggf. andere Szenen aus (Fokus-Kopplung), deren Licht muss
        // zurück sein, bevor wir den Ausgangszustand für diese Szene lesen
        for (const s of steps) {
            if (s.do !== "focus")
                continue;
            // Fokus wird beendet: Szene "focus" (Fokus-Kopplung) gleich hier zurücknehmen, nicht erst nach diesem Lauf
            if ((s.action || "stop") === "stop" && focusLink && focusScene !== j.name && isOn(focusScene) && Focus.mode !== "idle")
                _runOff({ name: focusScene, dir: "off", dry: j.dry }, cfg.scenes[focusScene]);
            _exec(s, j, null);
        }
        const rest = steps.filter(s => s.do !== "focus");
        _prepare(rest, () => _applyOn(j, rest));
    }

    // Zustand der Dienste frisch lesen (nur was die Schritte brauchen), dann weitermachen
    function _prepare(steps: var, done: var): void {
        const need = d => steps.some(s => s.do === d);
        const w = { hue: need("hue"), key: need("keylight"), br: need("brightness"), t0: Date.now(), done: done,
            hueBefore: Hue.groups, hueAsked: false, keyAsked: false, brAsked: false };
        if (!w.hue && !w.key && !w.br)
            return done();
        _wait = w;
        waitTimer.restart();
    }
    function _tick(): void {
        const w = _wait;
        if (!w)
            return waitTimer.stop();
        const el = Date.now() - w.t0;
        // Hue: erst lesen, wenn die Bridge nicht mehr schreibt (sonst überspringt refresh)
        if (w.hue && !w.hueAsked && Hue.paired && !Hue.inflight && Hue.queue.length === 0) {
            w.hueBefore = Hue.groups;
            Hue.refresh();
            w.hueAsked = true;
        }
        if (w.key && !w.keyAsked) {
            KeyLight.refresh();
            w.keyAsked = true;
            w.keyAt = Date.now();
        }
        if (w.br && !w.brAsked) {
            Brightness.step(0, "");   // liest nur (schreibt nur bei Abweichung)
            w.brAsked = true;
        }
        // nach der Erkennung auch die übrigen Monitore lesen (vorher kennt Brightness nur den Hauptmonitor)
        if (w.br && w.brAsked && !w.brAll && Brightness._detected) {
            w.brAll = true;
            for (const n of Brightness.names)
                if (Brightness.displays[n].num && !(Brightness.displays[n].max > 0))
                    Brightness.step(0, n);
        }
        const hueDone = !w.hue || !Hue.paired || (w.hueAsked && Hue.groups !== w.hueBefore);
        const keyDone = !w.key || (w.keyAsked && Date.now() - w.keyAt >= 700);
        const brDone = !w.br || (w.brAll && Brightness.names.every(n => !Brightness.displays[n].num || Brightness.displays[n].max > 0));
        if ((hueDone && keyDone && brDone) || el > 4000) {
            waitTimer.stop();
            _wait = null;
            if (el > 4000)
                note("reading device state timed out, using last known values");
            w.done();
        }
    }
    Timer {
        id: waitTimer
        interval: 120
        repeat: true
        onTriggered: root._tick()
    }

    function _applyOn(j: var, steps: var): void {
        const prev = [];
        for (const s of steps) {
            const e = _exec(s, j, prev);
            if (e && e.snap !== undefined && s.restore !== false)
                prev.push(Object.assign({}, s, { snap: e.snap }));
        }
        // auch reine focus-Schritte (ohne Zustand) gehören zur Szene
        if (!j.dry) {
            const a = Object.assign({}, active);
            a[j.name] = { at: Date.now(), prev: prev };
            active = a;
            saveState();
        }
        note(j.name + ": " + (j.dry ? "dry run done" : "on"));
        _finish();
    }

    // Schritt ausführen bzw. (dry) beschreiben. Gibt { snap } zurück, wenn er etwas gemerkt hat.
    function _exec(s: var, j: var, prev: var): var {
        const p = _plan(s);
        if (p.skip) {
            note("  skip " + s.do + ": " + p.skip);
            return null;
        }
        note("  " + (j.dry ? "would " : "") + p.text);
        if (!j.dry)
            p.run();
        return p;
    }

    function _runOff(j: var, sc: var): void {
        note(j.name + ": off" + (j.dry ? " (dry run)" : ""));
        const entry = active[j.name];
        const prev = entry ? entry.prev : [];
        for (let i = prev.length - 1; i >= 0; i--) {
            const u = _undo(prev[i]);
            if (u.skip) {
                note("  skip restore " + prev[i].do + ": " + u.skip);
                continue;
            }
            note("  " + (j.dry ? "would " : "") + u.text);
            if (!j.dry)
                u.run();
        }
        if (!entry)
            note("  (scene is not on: nothing to restore)");
        for (const s of (sc.off || [])) {
            if (!s || s.enabled === false)
                continue;
            _exec(s, j, null);
        }
        if (!j.dry) {
            const a = Object.assign({}, active);
            delete a[j.name];
            active = a;
            saveState();
        }
    }

    // ---------- Schritt-Typen ----------
    // _plan: { skip } | { text, snap?, run }   – snap = Zustand vor der Änderung (nur geänderte Felder)
    // _undo: { skip } | { text, run }
    function _skip(reason: string): var {
        return { skip: reason };
    }
    function _hueGroup(s: var): var {
        return Hue.groups.find(x => x.name === (s.room || Hue.homeGroup)) ?? null;
    }
    function _hueOk(): string {
        if (!Hue.paired)
            return "Hue not paired (scripts/hue-pair)";
        if (Hue.status !== "ok")
            return "Hue " + Hue.status;
        return "";
    }
    function _keyOk(): string {
        return KeyLight.ready && KeyLight.online ? "" : "Key Light offline";
    }
    function _appKey(app: string): string {
        return app === "chat" ? Parked.chatKey : app;
    }
    function _player(s: var): var {
        return s.player === "any" ? Players.active : Players.spotify;
    }
    function _dispNames(s: var): var {
        const all = Brightness.names.filter(n => (Brightness.displays[n].max ?? 0) > 0);
        return s.display ? all.filter(n => n === s.display) : all;
    }

    function _plan(s: var): var {
        switch (s.do) {
        case "hue": {
            const bad = _hueOk();
            if (bad)
                return _skip(bad);
            const g = _hueGroup(s);
            if (!g || !g.lightId)
                return _skip("room '" + (s.room || Hue.homeGroup) + "' not found");
            let sc = null;
            if (s.scene) {
                sc = Hue.scenes.find(x => x.groupId === g.id && x.name.toLowerCase() === String(s.scene).toLowerCase()) ?? null;
                if (!sc)
                    return _skip("scene '" + s.scene + "' not in room " + g.name);
            }
            const cur = Hue.scenes.find(x => x.groupId === g.id && x.active);
            const snap = { gid: g.id, on: g.on, bri: g.bri, mode: g.mode, mirek: g.mirek, xy: g.xy, sceneId: cur ? cur.id : "" };
            const what = s.off ? "off" : sc ? "scene " + sc.name : [s.mirek ? s.mirek + " mirek" : "", s.bri ? s.bri + " %" : ""].filter(x => x).join(", ");
            return { snap: snap, text: "Hue " + g.name + ": " + what, run: () => {
                if (s.off) {
                    Hue.off(g.id);
                    return;
                }
                if (sc)
                    Hue.recall(sc.id);
                else if (s.mirek && g.hasCt)
                    Hue.setMirek(g.id, s.mirek);
                if (s.bri)
                    Hue.setBrightness(g.id, s.bri);
            } };
        }
        case "keylight": {
            const bad = _keyOk();
            if (bad)
                return _skip(bad);
            if (s.only_if_on && !KeyLight.on)
                return _skip("Key Light is off (only_if_on)");
            const snap = {};
            if (s.on !== undefined)
                snap.on = KeyLight.on;
            if (s.brightness !== undefined)
                snap.brightness = KeyLight.brightness;
            if (s.kelvin !== undefined)
                snap.kelvin = KeyLight.kelvin;
            const what = [s.on !== undefined ? (s.on ? "on" : "off") : "", s.brightness !== undefined ? s.brightness + " %" : "", s.kelvin !== undefined ? s.kelvin + " K" : ""].filter(x => x).join(", ");
            return { snap: snap, text: "Key Light: " + what, run: () => {
                if (s.kelvin !== undefined)
                    KeyLight.setKelvin(s.kelvin);
                if (s.brightness !== undefined)
                    KeyLight.setBrightness(s.brightness);
                if (s.on !== undefined)
                    KeyLight.setOn(!!s.on);
            } };
        }
        case "brightness": {
            const ds = _dispNames(s);
            if (!ds.length)
                return _skip("no display values (ddcutil)");
            const snap = {};
            for (const n of ds)
                snap[n] = Brightness.ratio(n);
            const target = n => s.percent !== undefined ? s.percent / 100 : Brightness.ratio(n) * (s.scale ?? 1);
            return { snap: snap, text: "Brightness " + ds.map(n => n + " " + Math.round(Brightness.ratio(n) * 100) + "→" + Math.round(target(n) * 100) + " %").join(", "), run: () => {
                for (const n of ds)
                    Brightness.set(target(n), n);
            } };
        }
        case "dnd": {
            const v = s.value !== false;
            return { snap: { dnd: Notifs.dnd }, text: "Do not disturb " + (v ? "on" : "off"), run: () => { Notifs.dnd = v; } };
        }
        case "bar": {
            const v = s.hidden !== false;
            return { snap: { v: Windows.forceBare }, text: "Bar " + (v ? "hidden" : "shown"), run: () => { Windows.forceBare = v; } };
        }
        case "park": {
            const k = _appKey(s.app || "chat");
            if (!Parked.impl)
                return _skip("window service not ready");
            return { snap: { out: Parked.out[k] === true }, text: (s.app || "chat") + ": put away" + (Parked.out[k] === true ? "" : " (already away)"), run: () => {
                if (Parked.out[k] === true)
                    Parked.toggle(s.app || "chat");
            } };
        }
        case "music": {
            const p = _player(s);
            if (!p)
                return _skip((s.player === "any" ? "no player" : "Spotify") + " not running");
            const act = s.action || "play";
            return { snap: { playing: p.isPlaying }, text: "Music: " + act + (p.isPlaying ? " (playing now)" : " (paused now)"), run: () => {
                if (act === "play" && !p.isPlaying)
                    p.play();
                else if (act === "pause" && p.isPlaying)
                    p.pause();
                else if (act === "toggle")
                    p.isPlaying ? p.pause() : p.play();
            } };
        }
        case "focus": {
            const act = s.action || "stop";
            if (act === "stop" && Focus.mode === "idle")
                return _skip("focus timer is not running");
            return { text: "Focus timer: " + act, run: () => {
                root._mute = true;   // die Kopplung (onModeChanged) soll nicht dazwischenfunken
                act === "start" ? Focus.start() : Focus.stop();
                root._mute = false;
            } };
        }
        case "cmd": {
            const argv = (cfg.commands || {})[s.name];
            if (!Array.isArray(argv) || !argv.length || !argv.every(a => typeof a === "string"))
                return _skip("command '" + s.name + "' is not in the \"commands\" list");
            return { text: "Run command '" + s.name + "'", run: () => Quickshell.execDetached(Launch.scope.concat(argv)) };
        }
        }
        return _skip("unknown step type '" + s.do + "'");
    }

    function _undo(e: var): var {
        const sn = e.snap;
        switch (e.do) {
        case "hue": {
            const bad = _hueOk();
            if (bad)
                return _skip(bad);
            const g = Hue.groups.find(x => x.id === sn.gid);
            if (!g || !g.lightId)
                return _skip("room gone");
            return { text: "Hue " + g.name + ": back to " + (sn.on ? (sn.sceneId ? "scene" : sn.mode === "ct" ? sn.mirek + " mirek" : "colour") + ", " + Math.round(sn.bri) + " %" : "off"), run: () => {
                if (!sn.on) {
                    Hue.off(g.id);
                    return;
                }
                const path = "/grouped_light/" + g.lightId;
                if (sn.sceneId && Hue.scenes.some(x => x.id === sn.sceneId))
                    Hue.recall(sn.sceneId);
                else if (sn.mode === "ct" && sn.mirek)
                    Hue.put(path, { on: { on: true }, color_temperature: { mirek: sn.mirek } });
                else if (sn.mode === "xy" && sn.xy)
                    Hue.put(path, { on: { on: true }, color: { xy: sn.xy } });
                else
                    Hue.put(path, { on: { on: true } });
                Hue.put(path, { dimming: { brightness: Math.max(1, sn.bri) } });
            } };
        }
        case "keylight": {
            const bad = _keyOk();
            if (bad)
                return _skip(bad);
            return { text: "Key Light: back to " + JSON.stringify(sn), run: () => {
                if (sn.kelvin !== undefined)
                    KeyLight.setKelvin(sn.kelvin);
                if (sn.brightness !== undefined)
                    KeyLight.setBrightness(sn.brightness);
                if (sn.on !== undefined)
                    KeyLight.setOn(sn.on);
            } };
        }
        case "brightness": {
            const ds = Object.keys(sn).filter(n => (Brightness.displays[n]?.max ?? 0) > 0);
            if (!ds.length)
                return _skip("no display values");
            return { text: "Brightness: back to " + ds.map(n => n + " " + Math.round(sn[n] * 100) + " %").join(", "), run: () => {
                for (const n of ds)
                    Brightness.set(sn[n], n);
            } };
        }
        case "dnd":
            return { text: "Do not disturb back to " + (sn.dnd ? "on" : "off"), run: () => { Notifs.dnd = sn.dnd; } };
        case "bar":
            return { text: "Bar back to " + (sn.v ? "hidden" : "shown"), run: () => { Windows.forceBare = sn.v; } };
        case "park": {
            const k = _appKey(e.app || "chat");
            if (!sn.out || Parked.out[k] === true)
                return _skip("nothing to bring back");
            return { text: (e.app || "chat") + ": bring back", run: () => Parked.toggle(e.app || "chat") };
        }
        case "music": {
            const p = _player(e);
            if (!p)
                return _skip("player gone");
            if (p.isPlaying === sn.playing)
                return _skip("music already as before");
            return { text: "Music: back to " + (sn.playing ? "playing" : "paused"), run: () => { sn.playing ? p.play() : p.pause(); } };
        }
        }
        return _skip("nothing to restore");
    }

    // ---------- Fokus-Kopplung (Idee f) ----------
    // Der Fokus-Timer läuft in Focus.qml unverändert; wir hören nur auf sein "mode".
    // Block startet -> Szene an, Block endet / Pause / Stopp -> Szene aus. "paused" ändert nichts.
    // Abschalten: settings.focusLink = false in config/scenes.json.
    readonly property bool focusLink: cfgReady && (cfg.settings || {}).focusLink !== false
    readonly property string focusScene: (cfg.settings || {}).focusScene || "focus"
    Connections {
        target: Focus
        function onModeChanged() {
            // beim Start lädt Focus den alten Zustand aus der Datei (ready ist dann noch false): nicht reagieren
            if (root._mute || !Focus.ready || !root.focusLink || !root.cfg.scenes[root.focusScene])
                return;
            if (Focus.mode === "focus")
                root.run(root.focusScene, "on", false);
            else if (Focus.mode === "idle" || Focus.mode === "break")
                root.run(root.focusScene, "off", false);
        }
        function onReadyChanged() {
            root._reconcile();
        }
    }
    // Shell war aus, während der Block endete: Szene "focus" steht noch auf an -> aufräumen
    function _reconcile(): void {
        if (!Focus.ready || !focusLink || !stateReady || !isOn(focusScene))
            return;
        if (Focus.mode === "idle" || Focus.mode === "break")
            run(focusScene, "off", false);
    }
    onFocusLinkChanged: _reconcile()
    onStateReadyChanged: _reconcile()

    // ---------- Zustand ----------
    FileView {
        id: stateFile
        path: root.home + "/.local/state/desktop/scenes.json"
        printErrors: false
        onLoaded: {
            try {
                const s = JSON.parse(text());
                root.active = s.active && typeof s.active === "object" ? s.active : {};
            } catch (e) {}
            root.stateReady = true;
            root._reapply();
        }
        onLoadFailed: {
            root.stateReady = true;
        }
    }
    function saveState(): void {
        stateFile.setText(JSON.stringify({ active: active }, null, 1));
    }
    // Nach einem Shell-Neustart sind Bar-Schalter und "Nicht stören" wieder aus: bei eingeschalteten Szenen neu setzen
    property bool _reapplied: false
    function _reapply(): void {
        if (_reapplied || !stateReady || !cfgReady)
            return;
        _reapplied = true;
        for (const n of Object.keys(active)) {
            const sc = (cfg.scenes || {})[n];
            for (const s of ((sc && sc.on) || [])) {
                if (s && s.enabled !== false && (s.do === "dnd" || s.do === "bar")) {
                    note(n + ": restoring " + s.do + " after shell restart");
                    _plan(s).run();
                }
            }
        }
    }

    FileView {
        id: cfgFile
        path: Quickshell.shellDir + "/../config/scenes.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            try {
                const c = JSON.parse(text());
                root.cfg = { settings: c.settings || {}, commands: c.commands || {}, scenes: c.scenes || {} };
                root.cfgReady = true;
                root._reapply();
            } catch (e) {
                console.warn("scenes: config/scenes.json is not valid JSON: " + e);
            }
        }
        onLoadFailed: console.warn("scenes: config/scenes.json missing")
    }

    // ---------- IPC ----------
    // qs ipc --any-display -p ~/Workspace/desktop-hyprland/shell call scene toggle game
    IpcHandler {
        target: "scene"

        function on(name: string): string {
            root.run(name, "on", false);
            return "ok";
        }
        function off(name: string): string {
            root.run(name, "off", false);
            return "ok";
        }
        function toggle(name: string): string {
            root.run(name, "toggle", false);
            return "ok";
        }
        // Trockenlauf: zeigt mit dem echten Gerätezustand, was passieren würde (ändert nichts)
        function dry(name: string, dir: string): string {
            root.run(name, dir || "on", true);
            return "ok";
        }
        function status(): string {
            return JSON.stringify({ busy: root.busy, queued: root._jobs.length, active: Object.keys(root.active), scenes: root.names,
                focusLink: root.focusLink, last: root.lastRun });
        }
        // Zustand der gesteuerten Dienste (ohne Geheimnisse) zum Vergleichen vor/nach einem Test
        function probe(): string {
            return JSON.stringify({
                hue: Hue.groups.map(g => ({ name: g.name, on: g.on, bri: Math.round(g.bri * 10) / 10, mode: g.mode, mirek: g.mirek, scene: (Hue.scenes.find(x => x.groupId === g.id && x.active) || {}).name || "" })),
                keylight: { online: KeyLight.online, on: KeyLight.on, brightness: KeyLight.brightness, kelvin: KeyLight.kelvin },
                brightness: Object.keys(Brightness.displays).map(n => ({ n: n, v: Brightness.displays[n].value, max: Brightness.displays[n].max })),
                dnd: Notifs.dnd,
                bare: Windows.forceBare,
                parked: Parked.out,
                music: Players.spotify ? Players.spotify.isPlaying : null,
                focus: Focus.mode
            });
        }
    }
}

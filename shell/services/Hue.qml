pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Philips Hue Bridge über CLIP v2 (HTTPS, selbstsigniertes Zertifikat) per curl.
// Bridge-Adresse + App-Key aus secrets.json (hue.bridge, hue.key; beides schreibt scripts/hue-pair).
// Der Key geht nur als Umgebungsvariable an curl (--variable/--expand-header), nie in argv oder ins Log.
// Szenen-Reihenfolge pro Raum in ~/.local/state/desktop/hue.json
Singleton {
    id: root

    property string bridge: ""        // LAN-Adresse der Bridge (secrets.json hue.bridge), leer = nicht eingerichtet
    // DESKTOP_HUE_BASE nur für Tests gegen eine Fake-Bridge
    readonly property string base: Quickshell.env("DESKTOP_HUE_BASE") || "https://" + bridge + "/clip/v2/resource"

    // Zuschauer zählen (Dashboard-Kachel und Licht-Popout, components/LightPanel.qml): active = mindestens einer sieht zu -> Polling
    property int watchers: 0
    readonly property bool active: watchers > 0
    function watch(on: bool): void {
        watchers = Math.max(0, watchers + (on ? 1 : -1));
    }
    property string key: ""
    readonly property bool paired: key !== "" && (bridge !== "" || !!Quickshell.env("DESKTOP_HUE_BASE"))
    // unpaired | loading | ok | offline | unauthorized
    property string status: "unpaired"

    property var scenes: []           // [{ id, name, groupId, active }]
    // Räume/Zonen [{ id, name, kind, lightId, on, bri, lights, hasColor, hasCt, mirekMin, mirekMax, gamut, mode, xy, mirek, color }]
    property var groups: []
    property var lights: ({})         // Leuchten-ID -> { on, room }
    property string homeLightId: ""   // grouped_light "ganzes Zuhause"
    property string groupId: ""       // gewählter Raum
    readonly property string homeGroup: "Büro"   // PC-Raum: beim Öffnen des Dashboards immer zuerst
    readonly property var group: groups.find(g => g.id === groupId) || null
    property var order: ({})          // Raum-ID -> [Szenen-IDs], selbst festgelegt
    readonly property var groupScenes: group ? sortedScenes(group.id) : []
    // brennende Leuchten außerhalb des gewählten Raums (einzelne Lampen, nicht Räume)
    readonly property int othersCount: group ? Object.keys(lights).filter(id => lights[id].on && group.lights.indexOf(id) < 0).length : 0
    readonly property bool othersOn: othersCount > 0
    readonly property bool anyOn: Object.keys(lights).some(id => lights[id].on)

    property var queue: []            // ausstehende PUTs [{ path, body }], gleiche Pfade werden zusammengelegt
    property var inflight: null
    property var pending: ({})        // gedrosselte Live-Werte (Farbwähler, Helligkeit): Pfad -> body
    readonly property int liveMs: 150

    function curl(extra: var): var {
        return ["curl", "-sk", "--connect-timeout", "3", "--max-time", "8",
            "--variable", "%HUE_KEY", "--expand-header", "hue-application-key: {{HUE_KEY}}"].concat(extra);
    }

    function refresh(): void {
        if (!paired) {
            status = "unpaired";
            return;
        }
        // während noch geschrieben wird, nicht alten Stand zurückholen (settle liest danach)
        if (reader.running || inflight || queue.length > 0 || throttle.running)
            return;
        if (status === "unpaired")
            status = "loading";
        reader.running = true;
    }

    // ---- Szenen ----

    // Szenen eines Raums: erst noch nicht einsortierte (nach Name), dann die festgelegte Reihenfolge
    function sortedScenes(gid: string): var {
        const ord = order[gid] || [];
        return scenes.filter(s => s.groupId === gid).sort((a, b) => {
            const ia = ord.indexOf(a.id), ib = ord.indexOf(b.id);
            if (ia < 0 && ib < 0)
                return a.name.localeCompare(b.name);
            if (ia < 0)
                return -1;
            if (ib < 0)
                return 1;
            return ia - ib;
        });
    }

    // gespeicherte Reihenfolge an die Bridge anpassen: gelöschte Szenen/Räume raus,
    // neue Szenen vorn einreihen (bleiben dann dort stehen). Räume ohne Reihenfolge bleiben alphabetisch.
    function syncOrder(): void {
        let changed = false;
        const o = {};
        for (const gid in order) {
            if (!groups.some(g => g.id === gid)) {
                changed = true;
                continue;
            }
            const have = scenes.filter(s => s.groupId === gid);
            const kept = (order[gid] || []).filter(id => have.some(s => s.id === id));
            const fresh = have.filter(s => kept.indexOf(s.id) < 0).map(s => s.id);
            o[gid] = fresh.concat(kept);
            if (o[gid].join() !== (order[gid] || []).join())
                changed = true;
        }
        if (changed) {
            order = o;
            prefs.setText(JSON.stringify({ order: o }, null, 1));
        }
    }

    function setOrder(gid: string, ids: var): void {
        const o = Object.assign({}, order);
        o[gid] = ids.slice();
        order = o;
        prefs.setText(JSON.stringify({ order: o }, null, 1));
    }

    // Szene im gewählten Raum verschieben: delta -1/+1, oder ganz nach vorn (toFront)
    function moveScene(sceneId: string, delta: int, toFront: bool): void {
        const ids = groupScenes.map(s => s.id);
        const i = ids.indexOf(sceneId);
        if (i < 0 || !group)
            return;
        const j = toFront ? 0 : Math.max(0, Math.min(ids.length - 1, i + delta));
        if (j === i)
            return;
        ids.splice(i, 1);
        ids.splice(j, 0, sceneId);
        setOrder(group.id, ids);
    }

    // Szene aktivieren
    function recall(sceneId: string): void {
        const s = scenes.find(x => x.id === sceneId);
        if (!s)
            return;
        scenes = scenes.map(x => x.groupId === s.groupId ? Object.assign({}, x, { active: x.id === sceneId }) : x);
        const g = groups.find(x => x.id === s.groupId);
        if (g)
            markLights(g.lights, true);
        put("/scene/" + sceneId, { recall: { action: "active" } });
    }

    // ---- Schalten ----

    // Raum/Zone ausschalten (grouped_light)
    function off(gid: string): void {
        const g = groups.find(x => x.id === (gid || groupId));
        if (!g || !g.lightId)
            return;
        markLights(g.lights, false);
        put("/grouped_light/" + g.lightId, { on: { on: false } });
    }

    // alles außer dem gewählten Raum aus. Räume ohne gemeinsame Leuchten per grouped_light,
    // überlappende (Zone im Raum) leuchtenweise, damit der gewählte Raum an bleibt
    function offOthers(): void {
        const cur = group;
        if (!cur)
            return;
        const keep = cur.lights;
        const offLights = [];
        for (const g of groups) {
            if (g.id === cur.id || g.kind !== "room")
                continue;
            const rest = g.lights.filter(l => keep.indexOf(l) < 0);
            if (!rest.some(l => lights[l] && lights[l].on))
                continue;
            if (rest.length === g.lights.length && g.lightId)
                put("/grouped_light/" + g.lightId, { on: { on: false } });
            else
                for (const l of rest)
                    if (lights[l] && lights[l].on)
                        offLights.push(l);
        }
        // Leuchten in keinem Raum
        for (const id in lights)
            if (!lights[id].room && lights[id].on && keep.indexOf(id) < 0)
                offLights.push(id);
        for (const l of offLights)
            put("/light/" + l, { on: { on: false } });
        markLights(Object.keys(lights).filter(id => keep.indexOf(id) < 0), false);
    }

    function allOff(): void {
        if (homeLightId)
            put("/grouped_light/" + homeLightId, { on: { on: false } });
        else
            for (const g of groups)
                if (g.kind === "room" && g.lightId && g.on)
                    put("/grouped_light/" + g.lightId, { on: { on: false } });
        markLights(Object.keys(lights), false);
    }

    // Zustand sofort zeigen (die Bridge bestätigt beim nächsten Lesen)
    function markLights(ids: var, on: bool): void {
        const l = Object.assign({}, lights);
        for (const id of ids)
            if (l[id])
                l[id] = Object.assign({}, l[id], { on: on });
        lights = l;
        groups = groups.map(g => {
            const st = g.lights.length ? g.lights.some(id => l[id] && l[id].on) : g.on;
            return st === g.on ? g : Object.assign({}, g, { on: st });
        });
        if (!on)
            scenes = scenes.map(s => {
                const g = groups.find(x => x.id === s.groupId);
                return s.active && g && !g.on ? Object.assign({}, s, { active: false }) : s;
            });
    }

    // ---- Farbe / Helligkeit (gedrosselt) ----

    function setBrightness(gid: string, pct: real): void {
        const g = groups.find(x => x.id === gid);
        if (!g || !g.lightId)
            return;
        const b = Math.max(1, Math.min(100, pct));
        patchGroup(g, { bri: b }, false);
        live(g, { dimming: { brightness: b } });
    }

    // Farbton/Sättigung 0..1 -> CIE xy im Gamut der Leuchten
    function setColor(gid: string, h: real, s: real): void {
        const g = groups.find(x => x.id === gid);
        if (!g || !g.lightId || !g.hasColor)
            return;
        const xy = hsvToXy(h, s, g.gamut);
        patchGroup(g, { mode: "xy", xy: xy, color: xyToColor(xy.x, xy.y) }, true);
        live(g, { color: { xy: xy } });
    }

    function setMirek(gid: string, mirek: real): void {
        const g = groups.find(x => x.id === gid);
        if (!g || !g.lightId || !g.hasCt)
            return;
        const m = Math.round(Math.max(g.mirekMin, Math.min(g.mirekMax, mirek)));
        patchGroup(g, { mode: "ct", mirek: m, color: mirekToColor(m) }, true);
        live(g, { color_temperature: { mirek: m } });
    }

    function patchGroup(g: var, patch: var, ownColor: bool): void {
        groups = groups.map(x => x.id === g.id ? Object.assign({}, x, patch) : x);
        if (!g.on)
            markLights(g.lights, true);
        // eigene Farbe -> keine Szene mehr aktiv
        if (ownColor)
            scenes = scenes.map(s => s.groupId === g.id && s.active ? Object.assign({}, s, { active: false }) : s);
    }

    // erster Wert sofort, danach höchstens alle liveMs, der letzte kommt immer an
    function live(g: var, patch: var): void {
        const path = "/grouped_light/" + g.lightId;
        const p = Object.assign({}, pending);
        p[path] = merge(p[path] || {}, Object.assign({ on: { on: true } }, patch));
        pending = p;
        if (!throttle.running)
            flushLive();
    }
    function flushLive(): void {
        const p = pending;
        const paths = Object.keys(p);
        if (paths.length === 0)
            return;
        pending = ({});
        for (const path of paths)
            put(path, p[path]);
        throttle.restart();
    }

    // Farbe und Farbtemperatur schließen sich aus: das Neuere gewinnt
    function merge(a: var, b: var): var {
        const r = Object.assign({}, a, b);
        if (b.color)
            delete r.color_temperature;
        if (b.color_temperature)
            delete r.color;
        return r;
    }

    // ---- Farbrechnung (sRGB/D65, wie in Philips' Doku) ----

    function lin(v: real): real {
        return v > 0.04045 ? Math.pow((v + 0.055) / 1.055, 2.4) : v / 12.92;
    }
    function gam(v: real): real {
        return v <= 0.0031308 ? 12.92 * v : 1.055 * Math.pow(v, 1 / 2.4) - 0.055;
    }

    function hsvToXy(h: real, s: real, gamut: var): var {
        const c = Qt.hsva(h, s, 1, 1);
        const r = lin(c.r), g = lin(c.g), b = lin(c.b);
        const X = r * 0.4124 + g * 0.3576 + b * 0.1805;
        const Y = r * 0.2126 + g * 0.7152 + b * 0.0722;
        const Z = r * 0.0193 + g * 0.1192 + b * 0.9505;
        const sum = X + Y + Z;
        let p = sum > 0 ? { x: X / sum, y: Y / sum } : { x: 0.3127, y: 0.329 };
        if (gamut)
            p = clampGamut(p, gamut);
        return { x: Math.round(p.x * 10000) / 10000, y: Math.round(p.y * 10000) / 10000 };
    }

    // xy -> darstellbare Farbe (hellster Kanal = 1)
    function xyToColor(x: real, y: real): color {
        if (y <= 0)
            return Qt.rgba(1, 1, 1, 1);
        const X = x / y, Z = (1 - x - y) / y;
        const r = Math.max(0, X * 3.2406 - 1.5372 - Z * 0.4986);
        const g = Math.max(0, -X * 0.9689 + 1.8758 + Z * 0.0415);
        const b = Math.max(0, X * 0.0557 - 0.204 + Z * 1.057);
        const m = Math.max(r, g, b, 1e-6);
        return Qt.rgba(gam(r / m), gam(g / m), gam(b / m), 1);
    }

    // Farbtemperatur -> xy auf der Planck-Kurve (Kim et al.) -> Farbe
    function mirekToXy(mirek: real): var {
        const T = Math.max(1667, Math.min(25000, 1e6 / Math.max(1, mirek)));
        const t = 1e3 / T;
        const x = T <= 4000 ? -0.2661239 * t * t * t - 0.2343589 * t * t + 0.8776956 * t + 0.17991
            : -3.0258469 * t * t * t + 2.1070379 * t * t + 0.2226347 * t + 0.24039;
        const y = T <= 2222 ? -1.1063814 * x * x * x - 1.3481102 * x * x + 2.18555832 * x - 0.20219683
            : T <= 4000 ? -0.9549476 * x * x * x - 1.37418593 * x * x + 2.09137015 * x - 0.16748867
            : 3.081758 * x * x * x - 5.8733867 * x * x + 3.75112997 * x - 0.37001483;
        return { x: x, y: y };
    }
    function mirekToColor(mirek: real): color {
        const p = mirekToXy(mirek);
        return xyToColor(p.x, p.y);
    }

    // Punkt außerhalb des Leuchten-Dreiecks -> nächster Punkt auf dem Rand
    function clampGamut(p: var, g: var): var {
        const a = g.red, b = g.green, c = g.blue;
        const side = (p1, p2, q) => (p2.x - p1.x) * (q.y - p1.y) - (p2.y - p1.y) * (q.x - p1.x);
        const d1 = side(a, b, p), d2 = side(b, c, p), d3 = side(c, a, p);
        if ((d1 >= 0 && d2 >= 0 && d3 >= 0) || (d1 <= 0 && d2 <= 0 && d3 <= 0))
            return p;
        const near = (p1, p2) => {
            const dx = p2.x - p1.x, dy = p2.y - p1.y;
            const t = Math.max(0, Math.min(1, ((p.x - p1.x) * dx + (p.y - p1.y) * dy) / (dx * dx + dy * dy)));
            return { x: p1.x + t * dx, y: p1.y + t * dy };
        };
        let best = p, bd = 1e9;
        for (const q of [near(a, b), near(b, c), near(c, a)]) {
            const d = (q.x - p.x) * (q.x - p.x) + (q.y - p.y) * (q.y - p.y);
            if (d < bd) {
                bd = d;
                best = q;
            }
        }
        return best;
    }

    // PC-Raum (homeGroup), sonst erster Raum mit Szenen, sonst irgendeiner
    function homeGroupId(): string {
        const home = groups.find(g => g.name === homeGroup && g.kind === "room") || groups.find(g => g.name === homeGroup);
        const first = groups.find(g => scenes.some(s => s.groupId === g.id)) || groups[0];
        return home ? home.id : first ? first.id : "";
    }

    function cycleGroup(): void {
        const withScenes = groups.filter(g => scenes.some(s => s.groupId === g.id));
        if (withScenes.length < 2)
            return;
        const i = withScenes.findIndex(g => g.id === groupId);
        groupId = withScenes[(i + 1) % withScenes.length].id;
    }

    // ---- Schreiben (nacheinander, bei 429 kurz warten) ----

    function put(path: string, body: var): void {
        const i = queue.findIndex(q => q.path === path);
        if (i >= 0) {
            const q = queue.slice();
            q[i] = { path: path, body: merge(q[i].body, body) };
            queue = q;
        } else {
            queue = queue.concat([{ path: path, body: body }]);
        }
        pump();
    }
    function pump(): void {
        if (writer.running || backoff.running || inflight || queue.length === 0 || !paired)
            return;
        inflight = queue[0];
        queue = queue.slice(1);
        writer.command = curl(["-o", "/dev/null", "-w", "%{http_code}", "-X", "PUT",
            "-H", "Content-Type: application/json", "-d", JSON.stringify(inflight.body), base + inflight.path]);
        writer.running = true;
    }
    function written(code: int): void {
        // Bridge drosselt: nochmal (max. 5×), außer es wartet schon ein neuerer Wert
        if (code === 429 && inflight && (inflight.tries || 0) < 5 && !queue.some(q => q.path === inflight.path)) {
            queue = [Object.assign({}, inflight, { tries: (inflight.tries || 0) + 1 })].concat(queue);
            backoff.restart();
        }
        inflight = null;
        next.restart();
    }

    // ---- Lesen ----

    // Antwort aus 5 Abfragen (scene, room, zone, grouped_light, light) zerlegen
    function parse(text: string): void {
        const parts = text.split(/\n<<(\d{3})>>\n/);
        const codes = [], bodies = [];
        for (let i = 0; i + 1 < parts.length; i += 2) {
            bodies.push(parts[i]);
            codes.push(parseInt(parts[i + 1]));
        }
        if (codes.length < 5 || codes.some(c => c === 0)) {
            status = "offline";
            return;
        }
        if (codes.some(c => c === 401 || c === 403)) {
            status = "unauthorized";
            return;
        }
        let d;
        try {
            d = bodies.map(b => JSON.parse(b).data || []);
        } catch (e) {
            status = "offline";
            return;
        }
        const [sc, rooms, zones, gls, ls] = d;
        const glById = {};
        let home = "";
        for (const gl of gls) {
            glById[gl.id] = gl;
            if (gl.owner && gl.owner.rtype === "bridge_home")
                home = gl.id;
        }
        const lightById = {};
        const lmap = {};
        for (const l of ls) {
            lightById[l.id] = l;
            lmap[l.id] = { on: !!(l.on && l.on.on), room: "" };
        }
        // Leuchten eines Raums hängen an seinen Geräten, die einer Zone direkt
        const lightsOf = r => {
            const kids = (r.children || []).map(c => c.rid);
            return ls.filter(l => kids.indexOf(l.id) >= 0 || (l.owner && kids.indexOf(l.owner.rid) >= 0)).map(l => l.id);
        };
        const hasCt = l => !!(l.color_temperature && l.color_temperature.mirek_valid);
        const hasXy = l => !!(l.color && l.color.xy);
        const gs = [];
        for (const [list, kind] of [[rooms, "room"], [zones, "zone"]]) {
            for (const r of list) {
                const svc = (r.services || []).find(s => s.rtype === "grouped_light");
                const gl = svc ? glById[svc.rid] : null;
                const ids = lightsOf(r);
                if (kind === "room")
                    for (const id of ids)
                        lmap[id].room = r.id;
                const own = ids.map(id => lightById[id]);
                const colored = own.filter(hasXy);
                const tunable = own.filter(l => l.color_temperature && l.color_temperature.mirek_schema);
                // angezeigte Farbe: erste brennende Leuchte mit Farbinfo, sonst irgendeine
                const src = own.find(l => l.on && l.on.on && (hasCt(l) || hasXy(l))) || own.find(l => hasCt(l) || hasXy(l));
                let mode = "", xy = null, mirek = 0, col = null;
                if (src && hasCt(src)) {
                    mode = "ct";
                    mirek = src.color_temperature.mirek;
                    col = mirekToColor(mirek);
                } else if (src) {
                    mode = "xy";
                    xy = src.color.xy;
                    col = xyToColor(xy.x, xy.y);
                }
                gs.push({
                    id: r.id,
                    name: (r.metadata && r.metadata.name) || "?",
                    kind: kind,
                    lightId: svc ? svc.rid : "",
                    on: gl ? !!(gl.on && gl.on.on) : false,
                    bri: gl && gl.dimming ? gl.dimming.brightness : 0,
                    lights: ids,
                    // grouped_light meldet "color"/"color_temperature" nur, wenn eine Leuchte es kann
                    hasColor: !!gl && gl.color !== undefined && colored.length > 0,
                    hasCt: !!gl && gl.color_temperature !== undefined && tunable.length > 0,
                    mirekMin: tunable.length ? Math.max.apply(null, tunable.map(l => l.color_temperature.mirek_schema.mirek_minimum)) : 153,
                    mirekMax: tunable.length ? Math.min.apply(null, tunable.map(l => l.color_temperature.mirek_schema.mirek_maximum)) : 500,
                    gamut: colored.length && colored[0].color.gamut ? colored[0].color.gamut : null,
                    mode: mode,
                    xy: xy,
                    mirek: mirek,
                    color: col
                });
            }
        }
        gs.sort((a, b) => a.kind === b.kind ? a.name.localeCompare(b.name) : a.kind === "room" ? -1 : 1);
        const ss = sc.map(s => ({
            id: s.id,
            name: (s.metadata && s.metadata.name) || "?",
            groupId: s.group ? s.group.rid : "",
            active: !!(s.status && s.status.active && s.status.active !== "inactive")
        }));
        ss.sort((a, b) => a.name.localeCompare(b.name));
        homeLightId = home;
        lights = lmap;
        groups = gs;
        scenes = ss;
        // Raum wählen: bisheriger, sonst der PC-Raum
        if (!gs.some(g => g.id === groupId))
            groupId = homeGroupId();
        syncOrder();
        status = "ok";
    }

    FileView {
        id: secrets
        path: Quickshell.shellDir + "/../secrets.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            let k = "", b = "";
            try {
                const j = JSON.parse(text());
                k = (j.hue && j.hue.key) || "";
                b = (j.hue && j.hue.bridge) || "";
            } catch (e) {}
            root.key = k;
            root.bridge = b;
            if (!root.paired)
                root.status = "unpaired";
            else if (root.active)
                root.refresh();
        }
        onLoadFailed: {
            root.key = "";
            root.bridge = "";
            root.status = "unpaired";
        }
    }

    FileView {
        id: prefs
        path: (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state") + "/desktop/hue.json"
        printErrors: false
        onLoaded: {
            try {
                const o = JSON.parse(text()).order;
                if (o && typeof o === "object")
                    root.order = o;
            } catch (e) {}
        }
    }

    Process {
        id: reader
        environment: ({ HUE_KEY: root.key })
        command: root.curl(["-w", "\\n<<%{http_code}>>\\n",
            root.base + "/scene", root.base + "/room", root.base + "/zone", root.base + "/grouped_light", root.base + "/light"])
        stdout: StdioCollector {
            onStreamFinished: root.parse(text)
        }
    }

    Process {
        id: writer
        environment: ({ HUE_KEY: root.key })
        stdout: StdioCollector {
            onStreamFinished: root.written(parseInt(text) || 0)
        }
    }

    // nächster PUT, sobald curl wirklich beendet ist
    Timer {
        id: next
        interval: 10
        onTriggered: {
            if (writer.running)
                restart();
            else if (root.queue.length > 0)
                root.pump();
            else
                settle.restart();
        }
    }

    Timer {
        id: backoff
        interval: 400
        onTriggered: root.pump()
    }

    Timer {
        id: throttle
        interval: root.liveMs
        onTriggered: root.flushLive()
    }

    // nach dem Schalten echten Zustand nachlesen
    Timer {
        id: settle
        interval: 1200
        onTriggered: root.refresh()
    }

    Timer {
        interval: 15000
        repeat: true
        running: root.active && root.paired
        triggeredOnStart: true
        onTriggered: root.refresh()
    }

    // Datei ggf. erst nach dem Start angelegt (hue-pair) -> beim Öffnen neu lesen.
    // Beim Öffnen immer mit dem PC-Raum anfangen (Weiterschalten per Klick bleibt bis zum Schließen)
    onActiveChanged: if (active) {
        if (groups.length)
            groupId = homeGroupId();
        secrets.reload();
    }
}

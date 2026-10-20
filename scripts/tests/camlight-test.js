// Funktionsprüfung für shell/services/camlight.js:  node scripts/tests/camlight-test.js
const fs = require("fs"), path = require("path");
const src = fs.readFileSync(path.join(__dirname, "../../shell/services/camlight.js"), "utf8").replace(/^\.pragma library\s*$/m, "");
const C = new Function(src + "; return { initial, restore, step };")();

let fails = 0;
function eq(name, got, want) {
    const ok = JSON.stringify(got) === JSON.stringify(want);
    if (!ok) fails++;
    console.log((ok ? "ok   " : "FAIL ") + name + (ok ? "" : "  got " + JSON.stringify(got) + " want " + JSON.stringify(want)));
}
// Ereignisse der Reihe nach anwenden, Aktionen sammeln
function run(events, s) {
    s = s || C.initial();
    const acts = [];
    for (const e of events) {
        const r = C.step(s, e);
        s = r.state;
        acts.push(r.action);
    }
    return { s, acts };
}
const start = { type: "start", allowed: true };
const stop = { type: "stop" };
const off = (phase, b, k) => ({ type: "light", phase, ok: true, on: false, brightness: b || 20, kelvin: k || 3300 });
const lit = (phase, b, k) => ({ type: "light", phase, ok: true, on: true, brightness: b || 20, kelvin: k || 3300 });
const fail = phase => ({ type: "light", phase, ok: false });

// Normalfall: Kamera an -> Licht war aus -> an; Kamera aus -> unverändert -> aus
let r = run([start, off("start"), stop, lit("stop")]);
eq("Normalfall", r.acts, ["query-start", "on", "query-stop", "off"]);
eq("Normalfall: Ende frei", r.s, { session: false, owned: false, ref: null });

// war schon an -> nie ausschalten
r = run([start, lit("start"), stop]);
eq("schon an: kein Ausschalten", r.acts, ["query-start", "", ""]);

// selbst ausgeschaltet während der Kamera (manual) -> am Ende nichts
r = run([start, off("start"), { type: "manual" }, stop]);
eq("manuell ausgeschaltet", r.acts, ["query-start", "on", "", ""]);

// von außen verstellt (Elgato-App): Helligkeit anders -> bleibt an
r = run([start, off("start"), stop, lit("stop", 40)]);
eq("von außen verstellt", r.acts, ["query-start", "on", "query-stop", ""]);
eq("von außen verstellt: frei", r.s.owned, false);

// von außen ausgeschaltet -> nichts mehr schicken
r = run([start, off("start"), stop, off("stop")]);
eq("schon aus am Ende", r.acts, ["query-start", "on", "query-stop", ""]);

// Automatik aus / gesperrt -> nichts
r = run([{ type: "start", allowed: false }, stop]);
eq("nicht erlaubt", r.acts, ["", ""]);

// doppelte Starts/Stops ohne Wirkung
r = run([start, start, off("start"), stop, stop, lit("stop")]);
eq("doppelt", r.acts, ["query-start", "", "on", "query-stop", "", "off"]);

// Kamera geht wieder an, bevor die Aus-Abfrage antwortet -> Licht bleibt, gehört weiter der Automatik
r = run([start, off("start"), stop, start, lit("stop")]);
eq("wieder an während Abfrage", r.acts, ["query-start", "on", "query-stop", "", ""]);
eq("wieder an: noch eigen", r.s.owned, true);
r = run([stop, lit("stop")], r.s);
eq("danach aus", r.acts, ["query-stop", "off"]);

// Kamera schon wieder aus, bevor die Start-Abfrage antwortet -> nicht einschalten
r = run([start, stop, off("start")]);
eq("veraltete Startantwort", r.acts, ["query-start", "", ""]);

// Licht nicht erreichbar
r = run([start, fail("start"), stop]);
eq("offline beim Start", r.acts, ["query-start", "unreachable", ""]);
r = run([start, off("start"), stop, fail("stop")]);
eq("offline am Ende", r.acts, ["query-start", "on", "query-stop", "unreachable"]);
eq("offline am Ende: frei", r.s.owned, false);

// Neustart der Shell mitten im Call: gespeicherter Zustand gilt weiter
const saved = JSON.parse(JSON.stringify(run([start, off("start")]).s));
r = run([start, stop, lit("stop")], C.restore(saved));
eq("Neustart: weiter", r.acts, ["", "query-stop", "off"]);
eq("restore: Unsinn", C.restore({ owned: true }), { session: false, owned: false, ref: null });
eq("restore: leer", C.restore(null), C.initial());

process.exit(fails ? 1 : 0);

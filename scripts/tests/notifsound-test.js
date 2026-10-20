// Funktionsprüfung für shell/services/notifsound.js (wann eine Meldung klingt):  node scripts/tests/notifsound-test.js
const fs = require("fs"), path = require("path");
const read = f => fs.readFileSync(path.join(__dirname, "../../shell/services", f), "utf8").replace(/^\.(pragma|import) .*$/mg, "");
const S = new Function(read("timewin.js") + "; const TW = { ruleMatches };" + read("notifsound.js") + "; return { soundFor, volumeOf };")();

let fails = 0;
function eq(name, got, want) {
    const ok = JSON.stringify(got) === JSON.stringify(want);
    if (!ok) fails++;
    console.log((ok ? "ok   " : "FAIL ") + name + (ok ? "" : "  got " + JSON.stringify(got) + " want " + JSON.stringify(want)));
}
const cfg = { enabled: true, volume: 0.4, urgent: true, cooldownMs: 1500, skip: [{ app: "discord|vesktop|equibop" }, { app: "spotify", enabled: false }] };
const msg = o => Object.assign({ app: "Thunderbird", desktop: "", summary: "Neue Mail", urgent: false, low: false, suppress: false }, o || {});
const on = { shown: true, now: 100000, last: 0 };
const name = (c, n, x) => S.soundFor(c, n, x).name;

eq("normal", name(cfg, msg(), on), "notify");
eq("dringend", name(cfg, msg({ urgent: true }), on), "notify-urgent");
eq("dringend, urgent:false", name(Object.assign({}, cfg, { urgent: false }), msg({ urgent: true }), on), "notify");
eq("aus", name(Object.assign({}, cfg, { enabled: false }), msg(), on), "");
eq("kein Popup (Ruhezeit/Fokus/panel)", S.soundFor(cfg, msg(), { shown: false, now: 1, last: 0 }), { name: "", why: "no popup" });
eq("suppress-sound", name(cfg, msg({ suppress: true }), on), "");
eq("niedrig", name(cfg, msg({ low: true }), on), "");
eq("Discord (eigener Ton)", name(cfg, msg({ app: "discord" }), on), "");
eq("Discord dringend auch still", name(cfg, msg({ app: "Discord", urgent: true }), on), "");
eq("Discord per desktop-entry", name(cfg, msg({ app: "", desktop: "vesktop" }), on), "");
eq("abgeschaltete Regel greift nicht", name(cfg, msg({ app: "spotify" }), on), "notify");
eq("Cooldown", name(cfg, msg(), { shown: true, now: 100000, last: 99000 }), "");
eq("nach Cooldown", name(cfg, msg(), { shown: true, now: 100000, last: 98400 }), "notify");
eq("ohne Konfig = an", name(undefined, msg(), on), "notify");
eq("Lautstärke", [S.volumeOf(cfg), S.volumeOf({}), S.volumeOf({ volume: 3 }), S.volumeOf({ volume: -1 })], [0.4, 0.7, 1, 0]);

if (fails) {
    console.log(fails + " Fehler");
    process.exit(1);
}
console.log("alles ok");

// Funktionsprüfung für shell/services/timewin.js:  node scripts/tests/timewin-test.js
const fs = require("fs"), path = require("path");
const src = fs.readFileSync(path.join(__dirname, "../../shell/services/timewin.js"), "utf8").replace(/^\.pragma library\s*$/m, "");
const T = new Function(src + "; return { hm, daySet, inWindow, inAnyWindow, windowEnd, ruleMatches, dayKey, greeting };")();

let fails = 0;
function eq(name, got, want) {
    const ok = JSON.stringify(got) === JSON.stringify(want);
    if (!ok) fails++;
    console.log((ok ? "ok   " : "FAIL ") + name + (ok ? "" : "  got " + JSON.stringify(got) + " want " + JSON.stringify(want)));
}
// 2026-10-16 = Freitag, 17 = Samstag, 18 = Sonntag, 19 = Montag
const d = (day, h, m) => new Date(2026, 9, day, h || 0, m || 0);
const night = { from: "22:00", to: "07:00" };

eq("hm", [T.hm("22:30"), T.hm("7:05"), T.hm("24:00"), T.hm("x")], [1350, 425, -1, -1]);
eq("Nacht: 23:30", T.inWindow(night, d(16, 23, 30)), true);
eq("Nacht: 03:00", T.inWindow(night, d(17, 3, 0)), true);
eq("Nacht: 06:59 / 07:00", [T.inWindow(night, d(17, 6, 59)), T.inWindow(night, d(17, 7, 0))], [true, false]);
eq("Nacht: 21:59 / 22:00", [T.inWindow(night, d(16, 21, 59)), T.inWindow(night, d(16, 22, 0))], [false, true]);
eq("Tag 12:00", T.inWindow(night, d(16, 12, 0)), false);
// nur Fr+Sa (Beginn): Fr 23:00 ja, Sa 02:00 ja (Fenster von Fr), So 02:00 ja (von Sa), So 23:00 nein, Mo 02:00 nein
const fs2 = { from: "22:00", to: "07:00", days: ["fri", "sat"] };
eq("Fr 23:00", T.inWindow(fs2, d(16, 23)), true);
eq("Sa 02:00", T.inWindow(fs2, d(17, 2)), true);
eq("So 02:00", T.inWindow(fs2, d(18, 2)), true);
eq("So 23:00", T.inWindow(fs2, d(18, 23)), false);
eq("Mo 02:00", T.inWindow(fs2, d(19, 2)), false);
// Fenster am selben Tag
const noon = { from: "12:00", to: "13:30", days: ["weekdays"] };
eq("Mittag Fr", T.inWindow(noon, d(16, 13, 0)), true);
eq("Mittag Sa", T.inWindow(noon, d(17, 13, 0)), false);
eq("leer from==to", T.inWindow({ from: "08:00", to: "08:00" }, d(16, 8)), false);
eq("ungültig", T.inWindow({ from: "foo", to: "07:00" }, d(16, 3)), false);
eq("Zahlen-Tage 5=Fr", T.inWindow({ from: "22:00", to: "23:00", days: [5] }, d(16, 22, 30)), true);
eq("mehrere Fenster", T.inAnyWindow([noon, night], d(16, 23)), true);
eq("Ende Nacht", T.windowEnd([night], d(16, 23)).toString() === d(17, 7).toString(), true);
eq("Ende Nacht (nach Mitternacht)", T.windowEnd([night], d(17, 3)).toString() === d(17, 7).toString(), true);
eq("Ende außerhalb", T.windowEnd([night], d(16, 12)), null);

// Regeln
const n = { app: "Discord", desktop: "discord", summary: "Anna is calling you" };
eq("Regel summary", T.ruleMatches({ summary: "is calling|incoming call" }, n), true);
eq("Regel app", T.ruleMatches({ app: "^claude" }, n), false);
eq("Regel app+summary", T.ruleMatches({ app: "discord", summary: "calling" }, n), true);
eq("Regel leer", T.ruleMatches({}, n), false);
eq("Regel Regex kaputt", T.ruleMatches({ app: "(" }, n), false);
eq("Regel aus", T.ruleMatches({ app: "discord", enabled: false }, n), false);

// App-Regeln aus config/notifications.json: erste passende gilt (wie NotifRules.decide)
const cfgApps = JSON.parse(fs.readFileSync(path.join(__dirname, "../../config/notifications.json"), "utf8")).apps;
const modeOf = m => (cfgApps.find(r => T.ruleMatches(r, m)) || {}).mode || "";
// mail-watch meldet als „Mail“ mit Thunderbirds desktop-entry – darf nicht unter die hide-Regel für Thunderbird fallen
eq("Konfig: mail-watch flüchtig", modeOf({ app: "Mail", desktop: "net.thunderbird.Thunderbird", summary: "Anna" }), "transient");
eq("Konfig: Thunderbird selbst versteckt", modeOf({ app: "Thunderbird", desktop: "net.thunderbird.Thunderbird", summary: "New mail" }), "hide");
eq("Konfig: Snip flüchtig", modeOf({ app: "Snip", desktop: "", summary: "Snip saved" }), "transient");
eq("Konfig: Aufnahme flüchtig", modeOf({ app: "Screen Recording", desktop: "", summary: "Recording saved" }), "transient");
eq("Konfig: fremde App normal", modeOf({ app: "Discord", desktop: "discord", summary: "Hi" }), "");

eq("dayKey", T.dayKey(d(5, 9)), "2026-10-05");
eq("greeting", [T.greeting(d(1, 3)), T.greeting(d(1, 8)), T.greeting(d(1, 14)), T.greeting(d(1, 20))], ["Hello, night owl", "Good morning", "Good afternoon", "Good evening"]);
console.log(fails ? fails + " Fehler" : "alles ok");
process.exit(fails ? 1 : 0);

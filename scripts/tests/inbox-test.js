// Funktionsprüfung für shell/services/inbox.js:  node scripts/tests/inbox-test.js
const fs = require("fs"), path = require("path");
const src = fs.readFileSync(path.join(__dirname, "../../shell/services/inbox.js"), "utf8").replace(/^\.pragma library\s*$/m, "");
const I = new Function(src + "; return { parse, markDone, remove, parsePrefix, format };")();

let fails = 0;
function eq(name, got, want) {
    const ok = JSON.stringify(got) === JSON.stringify(want);
    if (!ok) fails++;
    console.log((ok ? "ok   " : "FAIL ") + name + (ok ? "" : "  got " + JSON.stringify(got) + " want " + JSON.stringify(want)));
}

const file = [
    "# Inbox",
    "",
    "- [ ] 2026-10-18 20:15 Milch kaufen #todo",
    "- [ ] 2026-10-18 21:00 Idee für die Bar",
    "    zweite Zeile",
    "",
    "    dritte Zeile",
    "- [x] 2026-10-17 09:00 schon erledigt",
    "- [ ] von Hand ohne Datum",
    "- [ ] 2026-10-18 20:15 Milch kaufen #todo",
    "Freitext dazwischen",
    ""
].join("\n");

const e = I.parse(file);
eq("Anzahl Einträge", e.length, 5);
eq("offen", e.filter(x => !x.done).length, 4);
eq("Datum/Zeit/Text", [e[0].date, e[0].time, e[0].text], ["2026-10-18", "20:15", "Milch kaufen #todo"]);
eq("Folgezeilen mit Leerzeile", [e[1].text, e[1].start, e[1].end], ["Idee für die Bar\nzweite Zeile\n\ndritte Zeile", 3, 6]);
eq("erledigt", e[2].done, true);
eq("ohne Datum", [e[3].date, e[3].text], ["", "von Hand ohne Datum"]);
eq("doppelte Zeile: nth", [e[0].nth, e[4].nth], [0, 1]);
eq("Freitext gehört nicht dazu", e[4].end, 9);

const done = I.markDone(file, e[4].key, 1);
eq("abhaken trifft das zweite Vorkommen", I.parse(done).map(x => x.done), [false, false, true, false, true]);
eq("abhaken: Rest unverändert", done.replace("- [x] 2026-10-18 20:15 Milch", "- [ ] 2026-10-18 20:15 Milch"), file);

const rm = I.remove(file, e[1].key, 0);
eq("löschen nimmt Folgezeilen mit", rm.split("\n").length, file.split("\n").length - 4);
eq("löschen: Nachbarn bleiben", I.parse(rm).map(x => x.text), ["Milch kaufen #todo", "schon erledigt", "von Hand ohne Datum", "Milch kaufen #todo"]);
eq("nicht gefunden", [I.markDone(file, "- [ ] gibt es nicht", 0), I.remove(file, e[0].key, 5)], [null, null]);

eq("Präfix t", I.parsePrefix("t  einkaufen ", ["t ", "!"]), { todo: true, body: "einkaufen" });
eq("Präfix !", I.parsePrefix("!Anruf", ["t ", "!"]), { todo: true, body: "Anruf" });
eq("kein Präfix", I.parsePrefix("tee kochen", ["t ", "!"]), { todo: false, body: "tee kochen" });
eq("nur Präfix", I.parsePrefix("t ", ["t ", "!"]), { todo: false, body: "t" });

const f = I.format("Gedanke\nmehr\n\nende", "2026-10-20 08:00");
eq("format", f, "- [ ] 2026-10-20 08:00 Gedanke\n    mehr\n\n    ende");
eq("format rund", I.parse(f)[0].text, "Gedanke\nmehr\n\nende");
eq("leere Datei", I.parse(""), []);

if (fails) {
    console.log(fails + " FAIL");
    process.exit(1);
}

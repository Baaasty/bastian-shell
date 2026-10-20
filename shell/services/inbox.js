.pragma library

// Gedanken-Inbox (~/Notes/inbox.md) lesen und ändern – reine Textlogik, damit sie ohne Shell testbar ist:
// scripts/tests/inbox-test.js (node). Nichts hier liest die Uhr oder Dateien.
// Format (Markdown, von Hand lesbar und änderbar):
//   - [ ] 2026-10-18 20:15 Text #tag        offen
//       Folgezeile (eingerückt)
//   - [x] 2026-10-18 20:15 Text             erledigt (bleibt als Verlauf in der Datei)
// Ein Eintrag wird über seine Kopfzeile + Vorkommen (nth) gefunden, nicht über die Zeilennummer:
// Bastian bearbeitet die Datei auch von Hand, Zeilen verschieben sich also.

const HEAD = /^- \[([ xX])\] ?(.*)$/;
const STAMP = /^(\d{4}-\d{2}-\d{2})(?: (\d{1,2}:\d{2}))?(?: (.*))?$/;

// Text der Datei -> [{ key, nth, done, date, time, text, start, end }] in Dateireihenfolge
// (start/end = erste/letzte Zeile des Eintrags, Leerzeilen am Ende gehören nicht dazu)
function parse(text) {
    const lines = String(text ?? "").split("\n");
    const out = [];
    const seen = {};
    for (let i = 0; i < lines.length; i++) {
        const m = HEAD.exec(lines[i]);
        if (!m)
            continue;
        let end = i;
        for (let j = i + 1; j < lines.length; j++) {
            if (/^\s+\S/.test(lines[j]))
                end = j;
            else if (lines[j].trim() !== "")
                break;
        }
        const key = lines[i];
        const nth = seen[key] = (seen[key] ?? -1) + 1;
        const s = STAMP.exec(m[2]);
        const first = s ? s[3] ?? "" : m[2];
        const rest = lines.slice(i + 1, end + 1).map(l => l.replace(/^( {1,4}|\t)/, "").replace(/\s+$/, ""));
        out.push({
            key: key,
            nth: nth,
            done: m[1] !== " ",
            date: s ? s[1] : "",
            time: s && s[2] ? s[2] : "",
            text: [first.trim()].concat(rest).join("\n").trim(),
            start: i,
            end: end
        });
    }
    return out;
}

function _find(text, key, nth) {
    return parse(text).find(e => e.key === key && e.nth === nth) ?? null;
}

// Eintrag abhaken ("- [ ]" -> "- [x]"); null = nicht (mehr) gefunden
function markDone(text, key, nth) {
    const e = _find(text, key, nth);
    if (!e)
        return null;
    const lines = String(text).split("\n");
    lines[e.start] = lines[e.start].replace(/^- \[ \]/, "- [x]");
    return lines.join("\n");
}

// Eintrag samt Folgezeilen löschen; null = nicht (mehr) gefunden
function remove(text, key, nth) {
    const e = _find(text, key, nth);
    if (!e)
        return null;
    const lines = String(text).split("\n");
    lines.splice(e.start, e.end - e.start + 1);
    return lines.join("\n");
}

// "t einkaufen" / "!einkaufen" -> { todo: true, body: "einkaufen" } (prefixes aus notes.json)
function parsePrefix(text, prefixes) {
    const t = String(text ?? "").trim();
    const low = t.toLowerCase();
    for (const p of prefixes || []) {
        if (low.startsWith(String(p).toLowerCase()) && t.slice(p.length).trim())
            return { todo: true, body: t.slice(p.length).trim() };
    }
    return { todo: false, body: t };
}

// neuer Eintrag als Markdown: Kopfzeile mit Kästchen + Zeitstempel ("yyyy-MM-dd HH:mm"), Folgezeilen eingerückt
function format(body, stamp) {
    const lines = String(body).split("\n").map(l => l.replace(/\s+$/, ""));
    let out = "- [ ] " + stamp + " " + lines[0];
    for (const l of lines.slice(1))
        out += "\n" + (l ? "    " + l : "");
    return out;
}

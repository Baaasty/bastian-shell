.pragma library

// Zeitfenster (Ruhezeiten, Morgen-Übersicht). Eigene Datei, damit die Logik ohne Shell testbar ist:
// scripts/tests/timewin-test.js (node). Alles nimmt ein Date entgegen, nichts liest die Uhr selbst.

const DAYS = ["sun", "mon", "tue", "wed", "thu", "fri", "sat"];

// "22:30" -> Minuten seit Mitternacht (1350), sonst -1
function hm(s) {
    const m = /^(\d{1,2}):(\d{2})$/.exec(String(s ?? "").trim());
    if (!m)
        return -1;
    const h = parseInt(m[1]), mi = parseInt(m[2]);
    return h > 23 || mi > 59 ? -1 : h * 60 + mi;
}

// Wochentage der Konfiguration -> Menge von 0..6 (So = 0). Leer/fehlend = alle Tage.
// Erlaubt: "mon", "Monday", 1 (Mo) … 7 (So), "weekdays", "weekend"
function daySet(days) {
    if (!Array.isArray(days) || days.length === 0)
        return new Set([0, 1, 2, 3, 4, 5, 6]);
    const out = new Set();
    for (const d of days) {
        if (typeof d === "number") {
            if (d >= 1 && d <= 7)
                out.add(d % 7);
            continue;
        }
        const s = String(d).toLowerCase().trim();
        if (s === "weekdays")
            [1, 2, 3, 4, 5].forEach(x => out.add(x));
        else if (s === "weekend")
            [0, 6].forEach(x => out.add(x));
        else {
            const i = DAYS.indexOf(s.slice(0, 3));
            if (i >= 0)
                out.add(i);
        }
    }
    return out;
}

// Liegt "date" im Fenster {from, to, days}? from > to = über Mitternacht; "days" = Tage, an denen das Fenster BEGINNT
// (22:00–07:00 am Freitag gilt also bis Samstag früh). from == to = leer.
function inWindow(w, date) {
    const f = hm(w && w.from), t = hm(w && w.to);
    if (f < 0 || t < 0 || f === t)
        return false;
    const cur = date.getHours() * 60 + date.getMinutes();
    const days = daySet(w.days);
    const today = date.getDay();
    if (f < t)
        return cur >= f && cur < t && days.has(today);
    if (cur >= f)
        return days.has(today);
    if (cur < t)
        return days.has((today + 6) % 7);
    return false;
}

// Irgendeines der Fenster? (Liste oder einzelnes Objekt)
function inAnyWindow(windows, date) {
    const ws = Array.isArray(windows) ? windows : windows ? [windows] : [];
    return ws.some(w => inWindow(w, date));
}

// Ende des Fensters, in dem "date" liegt (Date) oder null – für „kommt nach den Ruhezeiten wieder“
function windowEnd(windows, date) {
    const ws = Array.isArray(windows) ? windows : [];
    let best = null;
    for (const w of ws) {
        if (!inWindow(w, date))
            continue;
        const t = hm(w.to);
        const end = new Date(date);
        end.setHours(Math.floor(t / 60), t % 60, 0, 0);
        if (end <= date)
            end.setDate(end.getDate() + 1);
        if (!best || end > best)
            best = end;
    }
    return best;
}

// Regel {app, summary, category?} (Regex-Texte, ohne Groß/Klein) passt auf Meldung {app, desktop, summary}?
// Fehlende Felder der Regel zählen als „egal“; eine Regel ganz ohne Felder passt auf nichts.
// Ungültiger Regex = Regel passt nie (statt die Shell zu stören).
function ruleMatches(rule, n) {
    if (!rule || rule.enabled === false)
        return false;
    let any = false;
    if (rule.app) {
        any = true;
        if (!rx(rule.app, (n.app || "") + " " + (n.desktop || "")))
            return false;
    }
    if (rule.summary) {
        any = true;
        if (!rx(rule.summary, n.summary || ""))
            return false;
    }
    return any;
}
function rx(src, text) {
    try {
        return new RegExp(src, "i").test(text);
    } catch (e) {
        return false;
    }
}

// Zeitstempel -> "yyyy-MM-dd" (lokal)
function dayKey(date) {
    return date.getFullYear() + "-" + String(date.getMonth() + 1).padStart(2, "0") + "-" + String(date.getDate()).padStart(2, "0");
}

// Begrüßung nach Tageszeit
function greeting(date) {
    const h = date.getHours();
    return h < 5 ? "Hello, night owl" : h < 12 ? "Good morning" : h < 18 ? "Good afternoon" : "Good evening";
}

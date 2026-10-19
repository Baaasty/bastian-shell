pragma Singleton
import QtQuick
import Quickshell

// Einfache Fuzzy-Suche: alle Zeichen in Reihenfolge; Bonus für Wortanfang, Treffer am Stück und Präfix
Singleton {
    function score(query: string, text: string): real {
        if (!query)
            return 1;
        const q = query.toLowerCase();
        const t = (text || "").toLowerCase();
        if (t.startsWith(q))
            return 1000 - t.length;
        const idx = t.indexOf(q);
        if (idx >= 0)
            return 600 - idx - t.length * 0.1 + (idx === 0 || " -_./".includes(t[idx - 1]) ? 150 : 0);
        let s = 0, ti = 0, run = 0;
        for (let qi = 0; qi < q.length; qi++) {
            const found = t.indexOf(q[qi], ti);
            if (found < 0)
                return -1;
            run = found === ti ? run + 1 : 0;
            s += 10 + run * 5 + (found === 0 || " -_./".includes(t[found - 1]) ? 15 : 0) - (found - ti) * 0.5;
            ti = found + 1;
        }
        return s;
    }

    // Positionen der Treffer (für die Hervorhebung)
    function highlight(query: string, text: string, color: string): string {
        const esc = c => c.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
        if (!query)
            return esc(text);
        const q = query.toLowerCase();
        const t = text.toLowerCase();
        const idx = t.indexOf(q);
        let marks = new Set();
        if (idx >= 0) {
            for (let i = idx; i < idx + q.length; i++) marks.add(i);
        } else {
            let ti = 0;
            for (const c of q) {
                const f = t.indexOf(c, ti);
                if (f < 0) break;
                marks.add(f);
                ti = f + 1;
            }
        }
        let out = "";
        for (let i = 0; i < text.length; i++)
            out += marks.has(i) ? "<font color=\"" + color + "\">" + esc(text[i]) + "</font>" : esc(text[i]);
        return out;
    }
}

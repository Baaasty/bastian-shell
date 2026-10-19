.pragma library

// Sortieren und Abgleichen der Prozessliste (ResourcesPopout). Eigene Datei, damit die Logik ohne Shell testbar ist:
// scripts/tests/resources-sort-test.js (node). Wichtig: Vergleich liefert -1/0/1 aus den ECHTEN Werten (Bytes, Prozent, PID) –
// keine Typangabe "int" und keine Differenz als Rückgabe (Byte-Unterschiede sprengen int, CPU-Bruchteile würden zu 0).

function cmpStr(a, b) {
    const x = String(a).toLowerCase(), y = String(b).toLowerCase();
    return x < y ? -1 : x > y ? 1 : 0;
}

function cmpNum(a, b) {
    return a < b ? -1 : a > b ? 1 : 0;
}

// key: "name" | "cpu" | "rss" | "pid"; asc: aufsteigend. Gleichstand: Name, dann PID (immer aufsteigend, damit Zeilen nicht springen).
function compare(a, b, key, asc) {
    let d;
    switch (key) {
    case "name": d = cmpStr(a.name, b.name); break;
    case "pid": d = cmpNum(a.pid, b.pid); break;
    case "rss": d = cmpNum(a.rss, b.rss); break;
    default: d = cmpNum(a.cpu, b.cpu);
    }
    if (!asc)
        d = -d;
    if (d !== 0)
        return d;
    d = cmpStr(a.name, b.name);
    return d !== 0 ? d : cmpNum(a.pid, b.pid);
}

function sorted(list, key, asc) {
    return list.slice().sort((a, b) => compare(a, b, key, asc));
}

// Liste `arr` (schon sortiert) im ListModel abgleichen, ohne es neu aufzubauen (Scrollstand bleibt).
// cur = Spiegel der Schlüssel im Modell (wird mitgeführt); roleOf(zeile) -> Objekt fürs Modell.
function sync(model, cur, arr, roleOf) {
    const want = new Set(arr.map(r => r.key));
    for (let i = cur.length - 1; i >= 0; i--) {
        if (!want.has(cur[i])) {
            model.remove(i);
            cur.splice(i, 1);
        }
    }
    for (let i = 0; i < arr.length; i++) {
        const j = cur.indexOf(arr[i].key, i);
        if (j < 0) {
            model.insert(i, roleOf(arr[i]));
            cur.splice(i, 0, arr[i].key);
        } else {
            if (j !== i) {
                model.move(j, i, 1);
                cur.splice(i, 0, cur.splice(j, 1)[0]);
            }
            model.set(i, roleOf(arr[i]));
        }
    }
}

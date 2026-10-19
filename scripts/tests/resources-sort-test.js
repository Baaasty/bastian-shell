// Funktionsprüfung für shell/modules/bar/resources-sort.js:  node scripts/tests/resources-sort-test.js
const fs = require("fs");
const path = require("path");
const src = fs.readFileSync(path.join(__dirname, "../../shell/modules/bar/resources-sort.js"), "utf8").replace(/^\.pragma library\s*$/m, "");
const L = new Function(src + "; return { compare, sorted, stable, sync };")();
const assert = require("assert");

const GB = 1073741824, MB = 1048576;
const rows = [
    { key: "a", name: "helium", pid: 300, cpu: 4.2, rss: 1.6 * GB },
    { key: "b", name: "Discord", pid: 100, cpu: 4.4, rss: 800 * MB },
    { key: "c", name: "code", pid: 200, cpu: 0.0, rss: 3.1 * GB },
    { key: "d", name: "bash", pid: 50, cpu: 0.3, rss: 15 * MB },
    { key: "e", name: "alpha", pid: 60, cpu: 0.0, rss: 15 * MB },
    { key: "f", name: "zsh", pid: 70, cpu: 0.0, rss: 2.2 * GB },      // Unterschied > 2^31 zu kleinen Werten
];
const keys = (k, asc) => L.sorted(rows, k, asc).map(r => r.name).join(",");

// Memory: größte zuerst (echte Bytes, nicht Text "1.6 GB" vs "800 MB")
assert.strictEqual(keys("rss", false), "code,zsh,helium,Discord,alpha,bash");
assert.strictEqual(keys("rss", true), "alpha,bash,Discord,helium,zsh,code");
// CPU: Bruchteile zählen (4.4 vor 4.2 vor 0.3), Gleichstand nach Name
assert.strictEqual(keys("cpu", false), "Discord,helium,bash,alpha,code,zsh");
assert.strictEqual(keys("cpu", true), "alpha,code,zsh,bash,helium,Discord");
// Name: ohne Groß/Klein, aufsteigend; PID aufsteigend
assert.strictEqual(keys("name", true), "alpha,bash,code,Discord,helium,zsh");
assert.strictEqual(keys("name", false), "zsh,helium,Discord,code,bash,alpha");
assert.strictEqual(keys("pid", true), "bash,alpha,zsh,Discord,code,helium");
assert.strictEqual(keys("pid", false), "helium,code,Discord,zsh,alpha,bash");
// Gleichstand beim Memory (15 MB): Name, dann PID, in beiden Richtungen gleich
assert.strictEqual(L.sorted([{ name: "x", pid: 9, rss: 5, cpu: 0 }, { name: "x", pid: 3, rss: 5, cpu: 0 }], "rss", false).map(r => r.pid).join(), "3,9");
assert.strictEqual(L.sorted([{ name: "x", pid: 9, rss: 5, cpu: 0 }, { name: "x", pid: 3, rss: 5, cpu: 0 }], "rss", true).map(r => r.pid).join(), "3,9");
// Eingabe bleibt unverändert
assert.strictEqual(rows[0].key, "a");

// Abgleich mit Fake-Modell: nach beliebigen Updates entspricht das Modell genau der gewünschten Reihenfolge
function fakeModel() {
    const m = { items: [], remove: i => m.items.splice(i, 1), insert: (i, o) => m.items.splice(i, 0, o),
        move: (f, t, n) => m.items.splice(t, 0, ...m.items.splice(f, n)), set: (i, o) => { m.items[i] = o; } };
    return m;
}
const model = fakeModel(), cur = [];
let seed = 7;
const rnd = () => (seed = (seed * 1103515245 + 12345) % 2147483648) / 2147483648;
for (let round = 0; round < 300; round++) {
    const n = Math.floor(rnd() * 40);
    const data = Array.from({ length: n }, (_, i) => ({ key: "k" + Math.floor(rnd() * 60), name: "n" + Math.floor(rnd() * 20), pid: i, cpu: rnd() * 100, rss: Math.floor(rnd() * 4 * GB) }));
    const uniq = [...new Map(data.map(r => [r.key, r])).values()];
    const key = ["name", "cpu", "rss", "pid"][round % 4], asc = round % 3 === 0;
    const arr = L.sorted(uniq, key, asc);
    L.sync(model, cur, arr, r => r);
    assert.deepStrictEqual(model.items.map(r => r.key), arr.map(r => r.key));
    assert.deepStrictEqual(cur, arr.map(r => r.key));
    assert.deepStrictEqual(model.items, arr);   // Werte stimmen mit der Sortierung überein
}
// Eingefroren: bekannte Zeilen behalten ihren Platz trotz neuer Werte, Neue hinten (sortiert), Weggefallene fehlen
const fr = L.stable([{ key: "b", name: "b", pid: 2, cpu: 90 }, { key: "x", name: "x", pid: 7, cpu: 5 }, { key: "y", name: "y", pid: 8, cpu: 50 },
    { key: "a", name: "a", pid: 1, cpu: 1 }], ["a", "gone", "b"], "cpu", false, r => r.key);
assert.strictEqual(fr.map(r => r.key).join(), "a,b,y,x");
console.log("ok");

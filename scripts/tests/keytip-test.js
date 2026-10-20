// Funktionsprüfung für shell/components/keytip.js:  node scripts/tests/keytip-test.js
const fs = require("fs"), path = require("path");
const src = fs.readFileSync(path.join(__dirname, "../../shell/components/keytip.js"), "utf8").replace(/^\.pragma library\s*$/m, "");
const K = new Function(src + "; return { parts, keys };")();

let fails = 0;
function eq(name, got, want) {
    const ok = JSON.stringify(got) === JSON.stringify(want);
    if (!ok) fails++;
    console.log((ok ? "ok   " : "FAIL ") + name + (ok ? "" : "  got " + JSON.stringify(got) + " want " + JSON.stringify(want)));
}
const t = text => ({ kind: "text", text });
const k = (text, main) => ({ kind: "key", text, main: !!main });
const sep = { kind: "sep" }, plus = { kind: "plus" };

eq("Name + Kürzel", K.parts("Resources · Super+Alt+R"), [t("Resources"), sep, k("Super"), plus, k("Alt"), plus, k("R", true)]);
eq("Kürzel in der Mitte", K.parts("Browser · middle: new window · Super+B"),
    [t("Browser"), sep, t("middle: new window"), sep, k("Super"), plus, k("B", true)]);
eq("nur Text", K.parts("Mouse battery 12 %"), [t("Mouse battery 12 %")]);
eq("leer", K.parts(""), []);
eq("undefined", K.parts(undefined), []);
eq("Plus im Text bleibt Text", K.parts("C++ · a+b"), [t("C++"), sep, t("a+b")]);
eq("Modifier ohne Taste ist kein Kürzel", K.parts("Super+"), [t("Super+")]);
eq("Hinweis-Taste einzeln", K.keys("Esc"), [k("Esc", true)]);
eq("Hinweis-Kürzel", K.keys("Shift+↵"), [k("Shift"), plus, k("↵", true)]);
eq("Hinweis leer", K.keys(""), []);
eq("leere Abschnitte fallen weg", K.parts("A ·  · Super+Z"), [t("A"), sep, k("Super"), plus, k("Z", true)]);

if (fails) {
    console.log(fails + " failed");
    process.exit(1);
}
console.log("all ok");

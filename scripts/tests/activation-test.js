// Funktionsprüfung für shell/services/activation.js:  node scripts/tests/activation-test.js
const fs = require("fs"), path = require("path");
const src = fs.readFileSync(path.join(__dirname, "../../shell/services/activation.js"), "utf8").replace(/^\.pragma library\s*$/m, "");
const A = new Function(src + "; return { decide };")();

let fails = 0;
function eq(name, got, want) {
    const ok = JSON.stringify(got) === JSON.stringify(want);
    if (!ok) fails++;
    console.log((ok ? "ok   " : "FAIL ") + name + (ok ? "" : "  got " + JSON.stringify(got) + " want " + JSON.stringify(want)));
}
const w = (cls, desk, more) => Object.assign({ cls: cls, desk: desk, current: 1 }, more || {});

eq("Ein-Fenster-App auf anderem Desktop kommt her", A.decide(w("thunderbird", 2)), "pull");
eq("Ein-Fenster-App minimiert hier kommt zurück", A.decide(w("thunderbird", 1, { minimized: true })), "pull");
eq("liegt schon hier", A.decide(w("thunderbird", 1)), "focus");
eq("Browser woanders: hingehen", A.decide(w("helium", 3)), "go");
eq("VS Code woanders: hingehen", A.decide(w("code", 2)), "go");
eq("VS Code Flatpak", A.decide(w("com.visualstudio.code", 2)), "go");
eq("Browser hier", A.decide(w("helium", 1)), "focus");
eq("Steam nur markieren", A.decide(w("steam", 2)), "mark");
eq("Spiel nur markieren", A.decide(w("steam_app_730", 1)), "mark");
eq("Vollbild nur markieren", A.decide(w("thunderbird", 2, { fullscreen: true })), "mark");
eq("Terminal (Claude wartet) nur markieren", A.decide(w("kitty", 2)), "mark");
eq("Konsole nur markieren", A.decide(w("org.kde.konsole", 2)), "mark");
eq("weggeräumt bleibt", A.decide(w("spotify", 0, { stashed: true })), "ignore");
eq("mitkommend bleibt", A.decide(w("discord", 1, { follows: true })), "ignore");
eq("angepinnt: fokussieren", A.decide(w("mpv", 2, { pinned: true })), "focus");
eq("kein Desktop (Spezial)", A.decide(w("thunderbird", 0)), "ignore");
eq("nichts", A.decide(null), "ignore");

process.exit(fails ? 1 : 0);

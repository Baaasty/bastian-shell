.pragma library

// Was tun, wenn ein Fenster nach vorn will (Hyprland-Event „urgent“, focus_on_activate ist aus: hypr/general.conf)?
// Eigene Datei, damit die Regel ohne Shell testbar ist: scripts/tests/activation-test.js (node). Ausgeführt in Hypr.qml.
//   ignore  weggeräumt/mitkommend (Discord/Spotify: Holen macht nur die Bar)
//   mark    nur markieren (Hyprland setzt urgent selbst): Spiele, Steam, Vollbild, Terminals (Claude „wartet“ per Glocke)
//   focus   liegt schon hier (oder überall: angepinnt) → nur fokussieren
//   go      Mehrfenster-Apps gehören zu ihrem Desktop (Browser, VS Code-Projekt) → alle Monitore wechseln dorthin
//   pull    Ein-Fenster-Apps kommen her (gleicher Monitor, aktueller Desktop)

const GO = /^(helium|google-chrome|code|code-url-handler|com\.visualstudio\.code|com\.microsoft\.vscode)$/i;
const MARK = /^(steam|steam_app_.*|kitty|kitty-drop|org\.kde\.konsole|konsole|foot|alacritty|com\.mitchellh\.ghostty)$/i;

// w = { cls, desk, current, fullscreen, minimized, follows, stashed, pinned } (desk: Hypr.deskOf, 0 = keiner)
function decide(w) {
    if (!w || w.stashed || w.follows)
        return "ignore";
    if (w.fullscreen || MARK.test(w.cls || ""))
        return "mark";
    if (w.pinned)
        return "focus";
    if (w.desk <= 0)
        return "ignore";
    if (w.desk === w.current && !w.minimized)
        return "focus";
    return GO.test(w.cls || "") ? "go" : "pull";
}

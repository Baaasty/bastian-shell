-- Monitore wie unter KWin (Werte aus ~/.config/kwinoutputconfig.json, Stand 18.10.2026)
--   HDMI-A-2 links   1920×1080 @144  bei    0,360  (Discord)
--   DP-2     Mitte   2560×1440 @360  bei 1920,0    (volle Shell, Hauptmonitor)
--   DP-1     rechts  1920×1080 @144  bei 4480,360  (Browser), VRR an wie unter KWin („Immer“)
-- Skalierung überall 1. Ändern: hier, Hyprland lädt neu. Ein GUI-Ersatz für KScreen fehlt (docs/knowledge/hyprland.md).
hl.monitor({ output = "HDMI-A-2", mode = "1920x1080@144", position = "0x360", scale = 1, vrr = 0 })
-- kein vrr 2 (G-Sync nur im Vollbild): NVIDIA stellt den Monitor bei jedem Vollbild-Wechsel neu ein → ~0,5 s schwarz
hl.monitor({ output = "DP-2", mode = "2560x1440@360", position = "1920x0", scale = 1, vrr = 0 })
hl.monitor({ output = "DP-1", mode = "1920x1080@144", position = "4480x360", scale = 1, vrr = 1 })
-- unbekannter Monitor (z. B. Beamer): rechts dranhängen statt schwarz
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = 1 })

-- Workspaces = Desktops wie unter KWin, aber pro Monitor (Schema der Shell, shell/services/Hypr.qml):
--   Desktop d = Workspace d auf DP-2, 100+d auf dem linken (HDMI-A-2), 200+d auf dem rechten Monitor (DP-1).
--   Ein Desktop-Wechsel (Super+Leertaste, Workbar) stellt alle drei Monitore um.
-- Desktop 1 gibt es immer (persistent), weitere legen Profile/Projekte an. Desktops über 9 landen trotzdem
-- richtig, weil die Shell vor dem Wechsel den passenden Monitor fokussiert.
-- scripts/layout liest die Offsets aus dieser Tabelle (eine Zeile je Monitor).
local BASES = {
    ["DP-2"] = 0,
    ["HDMI-A-2"] = 100,
    ["DP-1"] = 200,
}
-- Verstecke für weggeräumte Hintergrund-Apps (Parked, special:parked<slot>) gehören zu ihrem Monitor – sonst legt
-- Hyprland sie auf dem gerade fokussierten an: Discord (HDMI) rutschte beim Wegräumen kurz auf DP-2 und wurde
-- auf dessen Größe gezogen (Aufblitzen auf dem Hauptmonitor, Discord layoutet neu)
local PARKED = { "DP-2", "HDMI-A-2", "DP-1" }

for mon, base in pairs(BASES) do
    hl.workspace_rule({ workspace = tostring(base + 1), monitor = mon, default = true, persistent = true })
    for d = 2, 9 do
        hl.workspace_rule({ workspace = tostring(base + d), monitor = mon })
    end
end
for slot, mon in ipairs(PARKED) do
    hl.workspace_rule({ workspace = "special:parked" .. (slot - 1), monitor = mon })
end

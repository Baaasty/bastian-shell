-- Chat-Client (Discord-RPM, Klasse "discord"; Rückfall Flatpak "com.discordapp.Discord", alt Equibop/Vesktop) und Spotify:
-- Startplatz linker Monitor (HDMI-A-2), gekachelt (kein float, kein pin), nebeneinander.
-- Auf ALLEN Workspaces sichtbar macht die Shell, nicht Hyprland: shell/services/Parked.qml (_follow) und
-- Hypr.switchCmds schieben sichtbare (nicht weggeräumte) Fenster der Apps aus config/follow.json bei jedem
-- Workspace-Wechsel auf den aktiven Workspace ihres Monitors (links→rechts, Breite des rechten bleibt).
-- Warum kein pin: Hyprland lehnt das Verschieben auf Workspaces für gepinnte Fenster ab – Wegräumen/Holen über die
-- Bar-Chips (Parked, special:parked<slot>) und Alt+Shift+n liefen dann ins Leere.
-- Kommt NACH rules.lua: überschreibt dort die Discord-Regel (DP-2, „beim Rausholen mittig“).
-- Neue Fenster tiled dwindle mit force_split = 2 (general.lua): zweites Fenster landet rechts vom ersten.
-- Gilt nur beim Öffnen (monitor); schon offene Fenster bleiben, wie sie sind.

hl.window_rule({ match = { initial_class = [[(?i)(discord|com\.discordapp\.discord|equibop|vesktop)]] }, monitor = "HDMI-A-2" })
hl.window_rule({ match = { initial_class = [[(?i)(spotify|com\.spotify\.client)]] }, monitor = "HDMI-A-2" })

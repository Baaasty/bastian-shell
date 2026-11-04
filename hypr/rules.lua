-- Fensterregeln: hl.window_rule({ match = { <eigenschaft> = <regex>, … }, <wirkung> = <wert>, … }).
-- Regex = RE2 und muss den ganzen Wert treffen. Regex mit Backslash in [[…]] (sonst doppelt escapen).

-- Discord (RPM "discord", Flatpak "com.discordapp.Discord", alt Equibop/Vesktop) und Spotify
local CHAT = [[(?i)(discord|com\.discordapp\.discord|equibop|vesktop)]]
local BACKGROUND = [[(?i)(discord|com\.discordapp\.discord|equibop|vesktop|spotify)]]

-- --- Kacheln ist Standard (dwindle, general.lua): ein Fenster füllt den Schirm, ein zweites teilt ---
-- Schweben nur, wo unten ausdrücklich float steht (Dialoge, Picker, Bild im Bild, Share-Picker).
-- Dazu schwebt, was Hyprland selbst als Dialog erkennt. Per Hand: Super+Shift+V.

-- Vollbild (Videos, Spiele) hält hypridle an
hl.window_rule({ match = { class = ".*" }, idle_inhibit = "fullscreen" })

-- XWayland: Drag-Geister und leere Hilfsfenster nicht fokussieren (aus Hyprlands Beispielkonfiguration)
hl.window_rule({
    match = { class = "^$", title = "^$", xwayland = true, float = true, fullscreen = false, pin = false },
    no_focus = true,
})

-- --- Fenster packen (Super + links ziehen, binds.lua): solange es hängt, höchstens 960×600 ---
-- Feste Pixel statt Prozent: der Prozentwert hinge am Startmonitor (2K), Ziel ist meist Full HD. 960×600 = halbe
-- Full-HD-Breite, man sieht noch, welches Fenster es ist, und es bleibt über der Mindestbreite von Discord/Electron (~940).
-- max_size verkleinert nur (kleine Fenster wie Bild im Bild bleiben) und schrumpft um die Mitte; gekachelte Fenster
-- schweben beim Lösen schon mittig unter dem Zeiger, deshalb hängen sie danach genau dort.
hl.window_rule({ match = { tag = "dragging", float = true }, max_size = "960 600" })

-- --- Startplatz wie früher die KWin-Fensterregeln (nur beim Öffnen, danach frei verschiebbar) ---
-- VS Code (natives RPM meldet "code", Flatpak "com.visualstudio.code") → Mitte
hl.window_rule({
    match = { initial_class = [[(?i)(code|code-url-handler|com\.visualstudio\.code|com\.microsoft\.vscode)]] },
    monitor = "DP-2",
})
-- Chrome / Helium → rechts
hl.window_rule({ match = { initial_class = "(?i)(google-chrome|helium)" }, monitor = "DP-1" })
-- Discord ist Hintergrund-App: beim Rausholen mittig auf dem Hauptmonitor (Chat-Client: shell/services/Chat.qml)
hl.window_rule({ match = { initial_class = CHAT }, monitor = "DP-2", size = "1600 1000", center = true })
-- Discord/Spotify fordern oft „Aktivierung“ an (Nachricht, Songwechsel). Mit focus_on_activate holte Hyprland sie dann
-- aus dem Versteck (special:parked…) auf DP-2 – weggeräumt muss weggeräumt bleiben (Holen macht die Bar per Dispatch)
hl.window_rule({ match = { class = BACKGROUND }, suppress_event = "activate activatefocus" })
-- Weggeräumt (special:parked) bekämen sie keine Frames mehr – Electron drosselt dann (Call/Stream/Video ruckeln).
-- render_unfocused hält sie mit misc:render_unfocused_fps am Laufen, auch unsichtbar.
hl.window_rule({ match = { class = BACKGROUND }, render_unfocused = true })
-- Wegräumen/Holen ohne Animation: sonst gleitet das Fenster erst sichtbar über den Monitor (zum Versteck), bevor es verschwindet
hl.window_rule({ match = { class = BACKGROUND }, no_anim = true })

-- --- Steam und Spiele ---
-- Steam (RPM steam, XWayland, Klasse "steam"): Hauptfenster (Titel "Steam") auf den Spiele-Monitor, gekachelt wie alles
-- andere. Kleine Dialoge/Popups schweben von selbst, wenn Hyprland sie als Dialog erkennt (keine Regel nötig).
hl.window_rule({ match = { initial_class = "(?i)steam", title = "Steam" }, monitor = "DP-2" })
-- Spiele über Steam/Proton heißen steam_app_<id>, native Linux-Spiele haben eigene Klassen (CS2: cs2, XWayland):
-- auf DP-2 (360 Hz), als Spiel markiert und Tearing erlaubt.
--   content game: die Shell nimmt dann Bar + Arbeitsplatz-Leiste ganz weg (Windows.game), sonst blockieren ihre
--                 Overlay-Flächen Tearing und direct scanout
--   immediate:    Tearing (weniger Latenz), greift nur mit general.allow_tearing (general.lua) und im echten Vollbild
-- Vollbild nicht erzwingen: Launcher (EA, Ubisoft …) laufen unter derselben Klasse; Spiele schalten selbst um.
-- Vollbild hält hypridle an (idle_inhibit fullscreen oben).
hl.window_rule({ match = { class = "^(steam_app_.*|cs2)$" }, monitor = "DP-2", content = "game", immediate = true })

-- --- Vollbild/Maximiert: wirklich randlos (kein Glut-Rand, keine runden Ecken, kein Schatten) ---
hl.window_rule({ match = { fullscreen = true }, border_size = 0, rounding = 0, no_shadow = true })

-- --- Dialoge mittig und handlich ---
-- KDE-Dateidialog (Portal), Polkit-Passwortabfrage
hl.window_rule({
    match = { class = [[org\.freedesktop\.impl\.portal\.desktop\.kde]] },
    float = true, center = true, size = "(monitor_w*0.55) (monitor_h*0.6)",
})
hl.window_rule({ match = { class = [[org\.kde\.polkit-kde-authentication-agent-1]] }, float = true, center = true })
hl.window_rule({
    match = { title = "(Open File|Save As|Open Folder|Datei öffnen|Speichern unter|Ordner öffnen).*" },
    float = true, center = true,
})

-- --- Bild im Bild (Chrome/Firefox): klein, oben auf allen Desktops, Seitenverhältnis fest ---
hl.window_rule({
    match = { title = "(Picture.in.[Pp]icture|Bild.im.Bild)" },
    float = true, pin = true, keep_aspect_ratio = true,
    size = "(monitor_w*0.25) (monitor_h*0.25)", move = "(monitor_w*0.73) (monitor_h*0.72)",
})

-- Bildschirmfreigabe-Hinweis (Chrome „… teilt Ihren Bildschirm“) nicht im Weg und auf allen Desktops
hl.window_rule({
    match = { title = ".*(is sharing (a window|your screen)|teilt (ein Fenster|Ihren Bildschirm)).*" },
    float = true, pin = true, no_initial_focus = true,
})

-- Layer der Shell: Blur kommt über ext-background-effect (BackgroundEffect.blurRegion im QML), keine Layer-Regel
-- nötig. Öffnen-Animationen für Layer sind in look.lua aus (Animation layers).

-- Bildschirm-teilen-Auswahl (xdg-desktop-portal-hyprland) immer vorn, mittig, mit Fokus –
-- lag sonst hinter angepinnten Fenstern (Discord) und Teilen ging „nicht“.
-- Pins: siehe pins.lua
hl.window_rule({ match = { class = "hyprland-share-picker" }, float = true, pin = true, center = true, stay_focused = true })

-- Neue Auswahl (hyprland-preview-share-picker, AP 16): ein Layer-Shell-Overlay (Namespace = App-ID), kein Fenster –
-- liegt von selbst über allem (auch über angepinnten Fenstern), die Fensterregel oben greift dafür nicht
-- (sie bleibt für den Standard-Picker, falls xdph.conf mal zurückgebaut wird: scripts/share-picker off).
-- Nur die Öffnen-Animation weg (wie bei den Shell-Layern).
hl.layer_rule({ match = { namespace = [[^ch\.wysbd\.hyprland-preview-share-picker$]] }, no_anim = true })

-- --- Drop-down-Terminal (scripts/dropterm, Super+Shift+Return) ---
-- Bewusste Ausnahme von „nichts schwebt“: nur diese Kitty-Klasse (kitty --class kitty-drop) schwebt, oben mittig,
-- 80 % Breite × 45 % Höhe, im Spezial-Workspace "dropterm" (nur auf Abruf sichtbar). Das Skript setzt Größe und
-- Platz beim Einblenden zusätzlich neu (Bar-Abstand, anderer Monitor). Normale Kitty-Fenster (Klasse "kitty") bleiben gekachelt.
hl.window_rule({
    match = { class = "^kitty-drop$" },
    float = true, workspace = "special:dropterm", size = "(monitor_w*0.8) (monitor_h*0.45)", move = "(monitor_w*0.1) 56",
})

-- Xwayland Video Bridge (KDE-Helfer fürs Bildschirmteilen alter X11-Apps): läuft dauerhaft und zeigte beim Teilen ein
-- leeres schwarzes Fenster – gehört unsichtbar in einen eigenen Spezial-Workspace (nie einblenden)
hl.window_rule({ match = { class = "^(xwaylandvideobridge)$" }, workspace = "special:bridge silent", no_initial_focus = true })

-- Tastenkürzel (docs/knowledge/hotkeys.md). Kacheln first: Fenster teilen den Schirm (dwindle). Super = Windows-/„Menü“-Taste.
-- Schema (Bastian, verbindlich): Alt = Workspaces · Super = Fenster · Super+Alt = Menüs/Programme und Topbar.
-- Topbar: Super+Leertaste = Bar-Modus; Super+Alt+<Buchstabe> = Bar-Modus + derselbe Buchstabe, die häufigsten ohne Alt
-- (Super+F/T/A/E/B/I). Dazu nur Notfälle, Screenshots, Medientasten und ein paar Klassiker (Super+Enter/K/O/P/V …).
-- Jede Kombination nur einmal – bei Dubletten gewinnt in Hyprland die erste.
-- Optionen: locked = auch gesperrt, repeating = wiederholt beim Halten, release = beim Loslassen,
--           ignore_mods = Modifier egal, transparent = wird von anderen Kürzeln nicht verdeckt, mouse = Maus ziehen.
-- Format je Zeile: bind("TASTEN", "Titel", Aktion, {Optionen}) – Titel und Abschnittsnamen ("-- ---- Name ----") liest der
-- Keybind-Viewer (Super+K) und scripts/hotkeys-md direkt aus dieser Datei, darum ein Bind pro Zeile.
-- Ein Kommentar direkt über genau EINEM Bind wird dort zur Beschreibung (eine Zeile), über mehreren Binds zur reinen Notiz.
local d = require(DESKTOP .. "/hypr/lib.lua")
local bind, ipc, exec, APP = d.bind, d.ipc, d.exec, d.APP

local LOCK = DESKTOP .. "/scripts/lock"
local HYPR = DESKTOP .. "/scripts/hypr"
local WINMOVE = "python3 -I " .. DESKTOP .. "/scripts/winmove"

-- Monitor fokussieren und den Zeiger in seine Mitte (cursor.no_warps: sonst setzt Hyprland den Fokus zurück).
-- Mitten = Monitor-Position + halbe Größe (monitors.lua).
local function focus_monitor(name, x, y)
    return function()
        hl.dispatch(hl.dsp.focus({ monitor = name }))
        hl.dispatch(hl.dsp.cursor.move({ x = x, y = y }))
    end
end

-- ---------- Windows ----------
-- Fokus mit Super+Pfeilen (alle vier Richtungen), Fenster verschieben mit Super+Shift+←/→ (springt am Rand auf den Nachbarmonitor)
bind("SUPER + Left", "Focus window", hl.dsp.focus({ direction = "left" }))
bind("SUPER + Right", "Focus window", hl.dsp.focus({ direction = "right" }))
bind("SUPER + Up", "Focus window", hl.dsp.focus({ direction = "up" }))
bind("SUPER + Down", "Focus window", hl.dsp.focus({ direction = "down" }))
bind("SUPER + SHIFT + Left", "Move window", exec(WINMOVE .. " dir l"))
bind("SUPER + SHIFT + Right", "Move window", exec(WINMOVE .. " dir r"))
-- Super+Shift+↑/↓ (oder Alt+Shift+↑/↓) stufen: schwebend → normal → maximiert (Leisten der Shell bleiben) → Vollbild (scripts/winmove max)
bind("SUPER + SHIFT + Up", "Bigger: floating → tiled → maximized → fullscreen", exec(WINMOVE .. " max up"))
bind("SUPER + SHIFT + Down", "Smaller: fullscreen → maximized → tiled → floating", exec(WINMOVE .. " max down"))
bind("ALT + SHIFT + Up", "Bigger: floating → tiled → maximized → fullscreen", exec(WINMOVE .. " max up"))
bind("ALT + SHIFT + Down", "Smaller: fullscreen → maximized → tiled → floating", exec(WINMOVE .. " max down"))
-- Größe per Taste (AP 22c): → breiter, ← schmaler, ↓ höher, ↑ niedriger; gekachelt verschiebt es die Teilung,
-- schwebend die Fenstergröße. Halten wiederholt.
bind("SUPER + CTRL + Right", "Resize window: wider", hl.dsp.window.resize({ x = 80, y = 0, relative = true }), { repeating = true })
bind("SUPER + CTRL + Left", "Resize window: narrower", hl.dsp.window.resize({ x = -80, y = 0, relative = true }), { repeating = true })
bind("SUPER + CTRL + Down", "Resize window: taller", hl.dsp.window.resize({ x = 0, y = 60, relative = true }), { repeating = true })
bind("SUPER + CTRL + Up", "Resize window: shorter", hl.dsp.window.resize({ x = 0, y = -60, relative = true }), { repeating = true })
-- Fensterwechsler: Super halten + Tab. Loslassen von Super wählt (der Wechsler sieht das Loslassen nicht selbst,
-- weil Hyprland die Super-Taste für das Kürzel „Dashboard“ schluckt) – transparent: wird von Super+Tab nicht verdeckt
bind("SUPER + Tab", "Next window", ipc("switcher next"))
bind("SUPER + SHIFT + Tab", "Previous window", ipc("switcher prev"))
bind("SUPER_L", nil, ipc("switcher confirm"), { ignore_mods = true, release = true, transparent = true })
-- dasselbe mit Alt+Tab (Alt loslassen wählt). Ohne offenen Wechsler ist „confirm“ wirkungslos.
bind("ALT + Tab", "Next window", ipc("switcher next"))
bind("ALT + SHIFT + Tab", "Previous window", ipc("switcher prev"))
bind("ALT_L", nil, ipc("switcher confirm"), { ignore_mods = true, release = true, transparent = true })
-- Fenster derselben App: Super + Taste links neben der 1 (US: ` und ~, DE: ^ und °)
bind("SUPER + code:49", "Next window of the same app", ipc("switcher nextApp"))
bind("SUPER + SHIFT + code:49", "Previous window of the same app", ipc("switcher prevApp"))
bind("SUPER + SHIFT + V", "Toggle floating", hl.dsp.window.float({ action = "toggle" }))
-- Rotate the split of the current pair (horizontal / vertical)
bind("SUPER + S", "Toggle split", hl.dsp.layout("togglesplit"))
bind("ALT + F4", "Close window (quits Discord/Spotify too)", hl.dsp.window.close())
bind("SUPER + Q", "Close window (Discord/Spotify: back to the bar)", exec(d.IPC .. " parked closeActive || hyprctl dispatch 'hl.dsp.window.close()'"))
-- Click a window to kill it – for hung apps
bind("SUPER + CTRL + Escape", "Kill window", exec("hyprctl kill"))
-- Give the keyboard back after remote control / VM use
bind("SUPER + SHIFT + Escape", "Release input capture", hl.dsp.release_input_capture())

-- ---------- Mouse ----------
-- Maus: Super + links ziehen = verschieben, Super + rechts ziehen = Größe (Fenster haben keine Titelleiste).
-- Beim Ziehen schrumpft das Fenster auf höchstens 960×600 und hängt mittig unter dem Zeiger – sonst sieht man beim
-- Wechsel vom 2K- auf einen Full-HD-Monitor kaum, wohin es fällt. Gekachelte rasten beim Loslassen wie gewohnt ein.
-- Wie: Markierung „dragging“ + Regel max_size in rules.lua; general.lua binds.drag_threshold sorgt dafür, dass
-- Hyprland das Fenster erst nach ein paar Pixeln aus der Kachel löst – dann ist die Markierung schon da.
-- Reihenfolge zählt: Hyprland führt alle Binds einer Taste in Reihenfolge der Aufrufe aus.
--   davor:   Loslassen nimmt die Markierung weg, BEVOR das Ziehen endet (sonst passt das Fenster wegen max_size
--            nicht mehr in die Kachel und bliebe schwebend); ignore_mods = auch wenn Super schon los ist,
--            non_consuming = Klick geht an die App
--   danach:  Markieren – erst das Ziehen fokussiert das Fenster unter dem Zeiger, tag trifft das aktive
-- Die Helfer stehen in einer eigenen Submap mit submap_universal (gilt in allen Submaps): so zeigt sie der Keybind-Viewer nicht.
hl.define_submap("mousedrag", function()
    hl.bind("mouse:272", hl.dsp.window.tag({ tag = "-dragging" }), { ignore_mods = true, release = true, non_consuming = true, submap_universal = true })
end)
bind("SUPER + mouse:272", "Move window (drag)", hl.dsp.window.drag(), { mouse = true })
hl.define_submap("mousedrag", function()
    hl.bind("SUPER + mouse:272", hl.dsp.window.tag({ tag = "+dragging" }), { submap_universal = true })
end)
bind("SUPER + mouse:273", "Resize window (drag)", hl.dsp.window.resize(), { mouse = true })

-- ---------- Monitors ----------
-- Monitore: Super+1/2/3 Fokus auf links/Mitte/rechts, Super+Shift+1/2/3 aktuelles Fenster dorthin.
bind("SUPER + code:10", "Focus monitor 1…3", focus_monitor("HDMI-A-2", 960, 900))
bind("SUPER + code:11", "Focus monitor 1…3", focus_monitor("DP-2", 3200, 720))
bind("SUPER + code:12", "Focus monitor 1…3", focus_monitor("DP-1", 5440, 900))
bind("SUPER + SHIFT + code:10", "Move window to monitor 1…3", exec(WINMOVE .. " mon HDMI-A-2"))
bind("SUPER + SHIFT + code:11", "Move window to monitor 1…3", exec(WINMOVE .. " mon DP-2"))
bind("SUPER + SHIFT + code:12", "Move window to monitor 1…3", exec(WINMOVE .. " mon DP-1"))

-- ---------- Workspaces ----------
-- Workspaces (in der UI „Workspaces“, in der Shell intern Desktops): über alle 3 Monitore gekoppelt –
-- Workspace n = Hyprland-ws n (DP-2), 100+n (links), 200+n (rechts). Die Shell schaltet alle drei zusammen.
-- Alt+→ / Alt+←: nächster / vorheriger Workspace, Leiste zeigt kurz wo
bind("ALT + Right", "Next workspace", ipc("workbar nextDesk"))
bind("ALT + Left", "Previous workspace", ipc("workbar prevDesk"))
-- Alt+1…9 n-ter Workspace in der Leiste (Platz, nicht ws-Nummer), Alt+Shift+1…9 aktuelles Fenster dorthin schieben (code:10…18 = Zifferreihe, layoutunabhängig)
bind("ALT + code:10", "Go to workspace 1…9", ipc("workbar goDesk 1"))
bind("ALT + code:11", "Go to workspace 1…9", ipc("workbar goDesk 2"))
bind("ALT + code:12", "Go to workspace 1…9", ipc("workbar goDesk 3"))
bind("ALT + code:13", "Go to workspace 1…9", ipc("workbar goDesk 4"))
bind("ALT + code:14", "Go to workspace 1…9", ipc("workbar goDesk 5"))
bind("ALT + code:15", "Go to workspace 1…9", ipc("workbar goDesk 6"))
bind("ALT + code:16", "Go to workspace 1…9", ipc("workbar goDesk 7"))
bind("ALT + code:17", "Go to workspace 1…9", ipc("workbar goDesk 8"))
bind("ALT + code:18", "Go to workspace 1…9", ipc("workbar goDesk 9"))
bind("ALT + SHIFT + code:10", "Move window to workspace 1…9", ipc("workbar moveToDesk 1"))
bind("ALT + SHIFT + code:11", "Move window to workspace 1…9", ipc("workbar moveToDesk 2"))
bind("ALT + SHIFT + code:12", "Move window to workspace 1…9", ipc("workbar moveToDesk 3"))
bind("ALT + SHIFT + code:13", "Move window to workspace 1…9", ipc("workbar moveToDesk 4"))
bind("ALT + SHIFT + code:14", "Move window to workspace 1…9", ipc("workbar moveToDesk 5"))
bind("ALT + SHIFT + code:15", "Move window to workspace 1…9", ipc("workbar moveToDesk 6"))
bind("ALT + SHIFT + code:16", "Move window to workspace 1…9", ipc("workbar moveToDesk 7"))
bind("ALT + SHIFT + code:17", "Move window to workspace 1…9", ipc("workbar moveToDesk 8"))
bind("ALT + SHIFT + code:18", "Move window to workspace 1…9", ipc("workbar moveToDesk 9"))
-- Workspace mode: tap Alt (fires only if no other key came in between) or Alt+Esc –
-- the bottom bar takes the keyboard (1–9, ←→ or Alt+←→, Enter, Del, N, R, T, Q = quick links + Git of the tile, Esc); again = close
bind("ALT + ALT_L", "Workspace mode (tap Alt)", ipc("workbar mode"), { release = true })
bind("ALT + Escape", "Workspace mode", ipc("workbar mode"))

-- ---------- Topbar ----------
-- The chips show their letter; ←/→ or Tab picks, Enter opens, Esc or Super+Space again closes
bind("SUPER + space", "Bar mode (letter opens a popout)", ipc("barmode toggle"), { shell = true })
-- Häufige Ziele ohne Alt: Super+<Buchstabe> = Super+Leertaste, dann derselbe Buchstabe (shell/services/BarKeys.qml).
-- Popouts per Taste haben Tastaturfokus und schließen nicht durch Weghovern; nochmal = zu.
-- Dateien/Browser ohne laufende Shell: Dolphin bzw. Helium direkt (|| …). Super+W = alter Browser-Griff, bleibt.
bind("SUPER + F", "Focus", ipc("barmode popout focus"), { shell = true })
bind("SUPER + T", "Tasks", ipc("barmode popout todo"), { shell = true })
bind("SUPER + A", "Agents (Claude)", ipc("barmode popout claudehub"), { shell = true })
bind("SUPER + E", "Files", ipc("barmode popout files || " .. APP .. " org.kde.dolphin.desktop"), { shell = true })
bind("SUPER + B", "Browser here: new tab, else new window", ipc("barmode popout browser || " .. APP .. " helium.desktop"), { shell = true })
bind("SUPER + W", "Browser", ipc("barmode popout browser || " .. APP .. " helium.desktop"), { shell = true })
bind("SUPER + I", "Settings", ipc("barmode popout settings"), { shell = true })
-- Alle übrigen: Super+Alt+<Buchstabe>, Reihenfolge wie in der Bar. Server (H) ist der Reiter Server im Dev-Popout (BarKeys.aliases).
bind("SUPER + ALT + P", "Screen sharing: stop, forget", ipc("barmode popout share"), { shell = true })
bind("SUPER + ALT + M", "Music (Spotify)", ipc("barmode popout spotify"), { shell = true })
bind("SUPER + ALT + C", "Chat (Discord)", ipc("barmode popout discord"), { shell = true })
bind("SUPER + ALT + V", "Dev services", ipc("barmode popout devservices"), { shell = true })
bind("SUPER + ALT + H", "Servers (consoles, upload, files, terminal)", ipc("barmode popout servers"), { shell = true })
bind("SUPER + ALT + R", "Resources", ipc("barmode popout resources"), { shell = true })
bind("SUPER + ALT + L", "Light", ipc("barmode popout light"), { shell = true })
bind("SUPER + ALT + G", "Gear (devices)", ipc("barmode popout gear"), { shell = true })
bind("SUPER + ALT + S", "Sound mixer", ipc("barmode popout mixer"), { shell = true })
bind("SUPER + ALT + N", "Network", ipc("barmode popout net"), { shell = true })
bind("SUPER + ALT + D", "Downloads", ipc("barmode popout downloads"), { shell = true })
bind("SUPER + ALT + U", "Updates (package manager)", ipc("barmode popout updates"), { shell = true })
bind("SUPER + ALT + Y", "Tray", ipc("barmode popout tray"), { shell = true })
-- Benachrichtigungen per Tastatur: ↑↓ wählen, Enter öffnen, 1–3 Knöpfe, S später erinnern, Entf wegklicken, Esc zu
bind("SUPER + ALT + Z", "Notifications (keyboard)", ipc("barmode popout notifs"), { shell = true })
bind("SUPER + ALT + X", "Dismiss newest notification", ipc("popups dismissNewest"), { shell = true })

-- ---------- Apps & menus ----------
-- Tap Super alone – fires only if no other key was pressed in between
bind("SUPER + SUPER_L", "Dashboard", ipc("dashboard toggle"), { release = true, shell = true })
bind("SUPER + Return", "Terminal", exec(APP .. " kitty.desktop"), { shell = true })
-- Drop-down terminal (scripts/dropterm): Kitty slides in from the top, stays alive in the background (docs/knowledge/shell-features.md)
bind("SUPER + SHIFT + Return", "Drop-down terminal", exec(DESKTOP .. "/scripts/dropterm toggle"), { shell = true })
bind("SUPER + V", "Clipboard history at the cursor (Enter pastes)", ipc("clip toggle"), { shell = true })
bind("SUPER + period", "Emoji picker at the cursor (Enter inserts)", ipc("emoji toggle"), { shell = true })
-- Kürzel-Übersicht (liest diese Datei + hyprctl binds zur Laufzeit) und Paketmanager
bind("SUPER + K", "Keyboard shortcuts", ipc("keys toggle"), { shell = true })
bind("SUPER + P", "Package manager", ipc("packages toggle"), { shell = true })
-- iCloud-Schlüsselbund (scripts/passwords): Strg+U Benutzer, Strg+P/Enter Passwort, Strg+T 2FA-Code
bind("SUPER + O", "Passwords", ipc("passwords toggle"), { shell = true })
-- Window layouts: apply a saved layout, save this workspace, delete (shell menu; kdialog fallback without the shell, docs/knowledge/shell-features.md)
bind("SUPER + ALT + K", "Layout menu", ipc("layouts toggle || " .. DESKTOP .. "/scripts/layout menu"), { shell = true })
-- Discord-Kameras (docs/knowledge/discord.md): alle an/aus, Overlay mit Super+Alt+Pfeilen in eine Ecke schieben
bind("SUPER + C", "Call cameras on/off", ipc("cams toggle"), { shell = true })
bind("SUPER + ALT + Left", "Call cameras: dock left", ipc("cams move left"), { shell = true })
bind("SUPER + ALT + Right", "Call cameras: dock right", ipc("cams move right"), { shell = true })
bind("SUPER + ALT + Up", "Call cameras: dock top", ipc("cams move up"), { shell = true })
bind("SUPER + ALT + Down", "Call cameras: dock bottom", ipc("cams move down"), { shell = true })
-- Zufalls-Call (Plugin desktopBridge): Leute drin, nicht voll, kein AFK; im Call = nächster. Popout zeigt, wo du gelandet bist
bind("SUPER + ALT + J", "Random call / next call (people in, not full)", ipc("discord randomCall; " .. d.IPC .. " barmode popout discord"), { shell = true })

-- ---------- Screenshots ----------
-- Screenshot: Bereich (kopieren + speichern) · Strg+Druck: alle Monitore speichern + kopieren
bind("Print", "Screenshot region", ipc("snip region"), { shell = true })
bind("SUPER + SHIFT + S", "Screenshot region", ipc("snip region"), { shell = true })
bind("CTRL + Print", "Screenshot all monitors", ipc("snip all"), { shell = true })
bind("SUPER + R", "Screen recording", ipc("snip record"), { shell = true })
-- Snip-Extras (docs/knowledge/shell-features.md): im Snip-Modus gehen auch T (Text), C (Farbe), P (Anpinnen) – Direktkürzel nur für
-- Text und Anpinnen; die Pipette lebt nur im Snip (eine Pipette statt zwei Wege)
bind("SUPER + SHIFT + T", "Snip text (OCR)", ipc("snip text"), { shell = true })
bind("SUPER + SHIFT + P", "Pin screenshot", ipc("snip pin"), { shell = true })

-- ---------- System ----------
bind("SUPER + Escape", "Power menu", ipc("power toggle"), { shell = true })
bind("SUPER + L", "Lock screen", exec(LOCK .. " now"), { shell = true })
-- End the Hyprland session (log out, close apps)
bind("SUPER + SHIFT + M", "Log out", exec("uwsm stop"), { shell = true })
-- Emergency exit: shell off, terminal open, hint to log out
bind("CTRL + ALT + SHIFT + Q", "Panic: shell off", exec(HYPR .. " panic"))
-- Shell power menu; if the shell is not running, a dialog asks and logs out via uwsm
bind("CTRL + ALT + Delete", "Power menu (works without the shell)", exec(HYPR .. " power"), { shell = true })

-- ---------- Media keys (auch gesperrt) ----------
-- Lautstärke: bewusst KEINE Tasten – alles regelt Bastian am GoXLR, der PC-Ausgang bleibt fest auf 100 %
-- (Wächter in shell/services/Audio.qml, Schalter ~/.config/desktop/audio.json; Doku docs/setup/goxlr.md)
bind("XF86AudioMute", "Mute", exec("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"), { locked = true, shell = true })
bind("XF86AudioMicMute", "Mute microphone", exec("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"), { locked = true, shell = true })
bind("SUPER + XF86AudioMute", "Mute microphone", exec("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"), { locked = true, shell = true })
-- Medien
bind("XF86AudioPlay", "Play / pause", ipc("media playPause"), { locked = true, shell = true })
bind("XF86AudioPause", "Play / pause", ipc("media playPause"), { locked = true, shell = true })
bind("XF86AudioNext", "Next track", ipc("media next"), { locked = true, shell = true })
bind("XF86AudioPrev", "Previous track", ipc("media previous"), { locked = true, shell = true })
bind("XF86AudioStop", "Stop", ipc("media stop"), { locked = true, shell = true })
-- Helligkeit (DDC/CI über die Shell), mit Shift feiner
bind("XF86MonBrightnessUp", "Brightness up", ipc("brightness up"), { locked = true, repeating = true, shell = true })
bind("XF86MonBrightnessDown", "Brightness down", ipc("brightness down"), { locked = true, repeating = true, shell = true })
bind("SHIFT + XF86MonBrightnessUp", "Brightness up (fine)", ipc("brightness fineUp"), { locked = true, repeating = true, shell = true })
bind("SHIFT + XF86MonBrightnessDown", "Brightness down (fine)", ipc("brightness fineDown"), { locked = true, repeating = true, shell = true })
-- Power button: power menu
bind("XF86PowerOff", "Power menu", exec(HYPR .. " power"), { locked = true, shell = true })

-- ---------- Kürzel-Sperre (Submap „modal“) ----------
-- Aktiv, solange Dashboard oder Passwörter offen sind (Hypr.setModal): Fenster-Kürzel aus (Super+Q träfe das Fenster
-- dahinter), alle mit { shell = true } gehen weiter (das offene Panel schließt sich, Hypr.panelOpened), übrige Tasten
-- ans Panel. Rettungsweg, falls die Shell hängt: Not-Aus (hebt die Sperre mit auf); hängt die Sperre ohne offenes
-- Panel, setzt die Shell sie selbst zurück (Hypr.qml, Event „submap“). Ohne Titel → nicht im Keybind-Viewer.
d.modal_submap(function()
    hl.bind("CTRL + ALT + SHIFT + Q", function()
        hl.dispatch(exec(HYPR .. " panic"))
        hl.dispatch(hl.dsp.submap("reset"))
    end)
end)

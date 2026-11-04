-- ERZEUGT aus theme/palette.json (hearth) – nicht von Hand ändern.
-- Neu erzeugen: python3 -I theme/gen/hypr.py [variante]   (läuft auch in theme/gen/all.py und scripts/rice variant)

hl.config({
    general = {
        border_size = 2,
        gaps_in = 5,
        gaps_out = 10,
        -- aktiv: Akzent, inaktiv: ruhiger Ton aus der Fläche (Glas-Varianten: Akzent gedämpft + Haarlinie)
        col = {
            active_border = "rgba(DB6B4CE6)",
            inactive_border = "rgba(6A5B50FF)",
            nogroup_border = "rgba(6A5B50FF)",
            nogroup_border_active = "rgba(DB6B4CE6)",
        },
    },

    decoration = {
        rounding = 16,
        rounding_power = 2,
        active_opacity = 1.0,
        inactive_opacity = 1.0,
        dim_inactive = false,

        -- dezent und nur so weit wie nötig (Schatten kosten pro Fenster)
        shadow = {
            enabled = true,
            range = 12,
            render_power = 3,
            offset = "0 4",
            color = "rgba(0C07044C)",
            color_inactive = "rgba(0C07042E)",
        },

        -- Blur nur bei Varianten mit blur=true (hearth: aus, alles deckend). Wenige Pässe, kein Rauschen-Schnickschnack.
        blur = {
            enabled = false,
            size = 6,
            passes = 2,
            new_optimizations = true,
            xray = false,
            noise = 0.01,
            contrast = 1.0,
            brightness = 1.0,
            vibrancy = 0.15,
            vibrancy_darkness = 0.0,
            special = false,
            popups = false,
            input_methods = false,
        },
    },

    misc = {
        background_color = "rgba(2A211BFF)",
    },

    -- Kurz und ruhig: OutCubic wie motion.easing, keine Feder, kein Nachschwingen, nichts läuft dauerhaft
    animations = {
        enabled = true,
    },
})

hl.curve("desktopOut", { type = "bezier", points = { { 0.33, 1 }, { 0.68, 1 } } })
-- Verschieben: OutExpo – fast der ganze Weg in den ersten Frames (fühlt sich direkt an), dann weich einrasten
hl.curve("desktopSnap", { type = "bezier", points = { { 0.16, 1 }, { 0.3, 1 } } })
hl.animation({ leaf = "global", enabled = true, speed = 2.2, bezier = "desktopOut" })
hl.animation({ leaf = "windowsIn", enabled = true, speed = 2.4, bezier = "desktopOut", style = "popin 96%" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 1.8, bezier = "desktopOut", style = "popin 96%" })
hl.animation({ leaf = "windowsMove", enabled = true, speed = 1.7, bezier = "desktopSnap" })
hl.animation({ leaf = "fade", enabled = true, speed = 1.8, bezier = "desktopOut" })
hl.animation({ leaf = "border", enabled = true, speed = 2.2, bezier = "desktopOut" })
hl.animation({ leaf = "borderangle", enabled = false })
hl.animation({ leaf = "workspaces", enabled = true, speed = 2.4, bezier = "desktopOut", style = "fade" })
hl.animation({ leaf = "specialWorkspace", enabled = true, speed = 2.4, bezier = "desktopOut", style = "fade" })
-- Layer-Flächen (Bar, Dashboard, OSD …) animiert die Shell selbst – sonst doppelt
hl.animation({ leaf = "layers", enabled = false })
hl.animation({ leaf = "fadeLayers", enabled = false })

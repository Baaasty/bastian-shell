pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Farben und Maße – einzige Quelle ist theme/palette.json (wird live neu geladen)
Singleton {
    id: root

    property var data: ({})
    // aktive Variante = defaultTheme in palette.json (umschalten: scripts/rice variant <name>), sonst Config.variant
    readonly property string variant: (data.themes && data.themes[data.defaultTheme]) ? data.defaultTheme : Config.variant
    readonly property var t: (data.themes && data.themes[variant]) || ({})
    readonly property var layout: data.layout || ({})
    readonly property var radii: data.radius || ({})
    readonly property var motion: data.motion || ({})

    // "rgba(26, 18, 14, 0.62)" oder "#RRGGBB" -> color
    function col(value, fallback) {
        if (!value)
            return fallback;
        const m = /^rgba\(\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*,\s*([\d.]+)\s*\)$/.exec(value);
        return m ? Qt.rgba(m[1] / 255, m[2] / 255, m[3] / 255, parseFloat(m[4])) : value;
    }

    // Farbe mit Alpha auf den Grund (bg) rechnen -> deckend; deckende Farben bleiben unverändert
    function flat(c) {
        return Qt.tint(bg, c);
    }

    // Blur an/aus: pro Variante (blur) oder Rückfall data.style.blur. hearth = aus -> alles deckend.
    // Aus: Glass-Töne werden auf den Grund gerechnet (deckend); Hyprland-Blur kommt aus hypr/look.conf (theme/gen/hypr.py).
    readonly property bool blurEnabled: t.blur !== undefined ? !!t.blur : !!(data.style && data.style.blur)

    // Farben
    readonly property color bg: col(t.bg, "#2A211B")
    readonly property color bgBottom: col(t.bgBottom, "#211A15")
    // deckende Flächen: surface = Kachel/Karte, surfaceRaised = Bar/Eingaben/Hover, surfaceSunken = Vertiefung
    readonly property color surface: flat(col(t.surface, "#382D26"))
    readonly property color surfaceRaised: flat(col(t.surfaceRaised, Qt.lighter(surface, 1.18)))
    readonly property color surfaceSunken: flat(col(t.surfaceSunken, Qt.darker(surface, 1.15)))
    // Kompatibilität (Glass.qml & Co.): ohne Blur deckend
    readonly property color glass: blurEnabled ? col(t.glassTint, Qt.rgba(0.1, 0.07, 0.05, 0.62)) : flat(col(t.glassTint, surface))
    readonly property color glassStrong: blurEnabled ? col(t.glassStrong, Qt.rgba(0.08, 0.05, 0.04, 0.8)) : flat(col(t.glassStrong, surfaceRaised))
    readonly property color border: col(t.border, Qt.rgba(1, 0.91, 0.8, 0.1))
    readonly property color borderStrong: col(t.borderStrong, Qt.rgba(1, 0.91, 0.8, 0.2))
    readonly property color text: col(t.text, "#F6ECDD")
    readonly property color textMuted: col(t.textMuted, "#D2C2AE")
    readonly property color textFaint: col(t.textFaint, "#B5A591")
    readonly property color accent: col(t.accent, "#DB6B4C")
    readonly property color accentHover: col(t.accentHover, Qt.lighter(accent, 1.1))
    readonly property color accentPressed: col(t.accentPressed, Qt.darker(accent, 1.12))
    readonly property color accentText: col(t.accentText, "#F2A58A")
    readonly property color accentSoft: col(t.accentSoft, Qt.rgba(0.86, 0.42, 0.3, 0.22))
    // deckender Akzent-Ton (ausgewählte Zeile, aktiver Chip), onAccent = Text darauf
    readonly property color accentFill: col(t.accentFill, Qt.tint(surface, accentSoft))
    readonly property color onAccent: col(t.onAccent, "#FFF4EA")
    readonly property color wood: col(t.wood, "#6B4A38")
    readonly property color woodLight: col(t.woodLight, "#A07C5C")
    readonly property color success: col(t.success, "#A3B083")
    readonly property color warning: col(t.warning, "#E0AE55")
    readonly property color error: col(t.error, "#E0604F")
    readonly property color dim: col(t.dim, Qt.rgba(0.09, 0.07, 0.05, 0.74))
    readonly property color glow: col(t.glow, Qt.rgba(0.86, 0.42, 0.3, 0.55))
    // ruhiger Schlagschatten (Glass.qml), kein Leuchten
    readonly property color shadow: col(t.shadow, Qt.rgba(0.05, 0.03, 0.02, 0.34))
    // neutrale Erhebung (Chips, Knöpfe)
    readonly property color raise: Qt.alpha(text, 0.06)
    // Projektfarben: Name -> Farbe ("glut" -> "#CF4B3F"), vergeben in projects/projects.json (scripts/project)
    readonly property var projectAccents: data.projectAccents || ({})
    readonly property color innerHighlight: col(data.glass ? data.glass.innerHighlight : "", Qt.rgba(1, 0.94, 0.86, 0.06))

    // Maße
    readonly property int barHeight: layout.barHeight || 38
    readonly property int barMargin: layout.barMargin || 10
    readonly property int barRadius: layout.barRadius || 14
    readonly property int windowGap: layout.windowGap || 10
    readonly property int radiusXs: radii.xs || 6
    readonly property int radiusSm: radii.sm || 10
    readonly property int radiusMd: radii.md || 14
    readonly property int radiusLg: radii.lg || 18
    readonly property int radiusXl: radii.xl || 24
    readonly property int hitMin: layout.hitTargetMin || 32

    // Design-System light: ein Raster für alle Flächen (palette.json space/padding/controls),
    // damit Popouts, Panels und Karten gleich atmen statt jede Datei eigene Zahlen hat
    readonly property var spaces: data.space || ({})
    readonly property int space1: spaces["1"] || 4
    readonly property int space2: spaces["2"] || 8
    readonly property int space3: spaces["3"] || 12
    readonly property int space4: spaces["4"] || 16
    readonly property int space5: spaces["5"] || 20
    readonly property int space6: spaces["6"] || 24
    readonly property var pads: data.padding || ({})
    readonly property int padCard: pads.card || 12        // Hinweis-Karten, Tooltips
    readonly property int padPopout: pads.popout || 16    // Bar-Popouts, kleine Karten
    readonly property int padPanel: pads.panel || 24      // große Panels, Dashboard-Kacheln
    readonly property var controls: data.controls || ({})
    readonly property int buttonHeight: controls.button || 36
    readonly property int buttonHeightSm: controls.buttonSm || 32
    readonly property int iconButton: controls.iconButton || 32
    readonly property int rowHeight: controls.row || 34
    readonly property int rowHeightTall: controls.rowTall || 40
    // Tastenkappe (KeyCap): Fläche + Fuge darunter; md für Hinweiszeilen/Super+K, sm an Chips und in Tooltips
    readonly property int keyCapHeight: controls.keyCap || 20
    readonly property int keyCapHeightSm: controls.keyCapSm || 16
    readonly property int keyCapLip: controls.keyCapLip || 2
    // Symbolgröße in Knöpfen und Kopf-Kacheln (palette icon.button)
    readonly property int iconSize: (data.icon && data.icon.button) || 18
    readonly property color keyLip: col(t.keyLip, Qt.darker(surfaceSunken, 1.3))

    // Schriften
    readonly property string fontUi: "Inter"
    readonly property string fontMono: "JetBrainsMono Nerd Font"
    readonly property string fontIcon: "Material Symbols Rounded"
    // Standard-Textgröße (Txt.qml): type.scale.ui.size
    readonly property int fontSize: (data.type && data.type.scale && data.type.scale.ui && data.type.scale.ui.size) || 14
    // Type-Scale (type.steps): fünf Stufen statt freier Pixelwerte. Xs = Mono-Meta/kleine Kappen,
    // Sm = Hinweise/Fußzeilen/Zeitstempel, Md = Standard, Lg = Popout-/Kartentitel, Xl = Panel-Titel.
    // Uhr, große Zahlen und Icons bleiben eigene Anzeigegrößen
    readonly property var steps: (data.type && data.type.steps) || ({})
    readonly property int fontXs: steps.xs || 11
    readonly property int fontSm: steps.sm || 12
    readonly property int fontMd: steps.md || 14
    readonly property int fontLg: steps.lg || 16
    readonly property int fontXl: steps.xl || 20

    // Bewegung (ms), immer Easing.OutCubic, ruhig (kein Schwingen, kein Dauerleuchten)
    readonly property int fade: motion.fade || 180
    readonly property int slide: motion.slide || 240
    readonly property int stateChange: motion.state || 220

    FileView {
        path: Quickshell.shellDir + "/../theme/palette.json"
        blockLoading: true
        watchChanges: true
        onFileChanged: reload()
        // halb gespeicherte/kaputte palette.json: alte Farben behalten statt die Shell farblos zu machen
        onLoaded: {
            try {
                root.data = JSON.parse(text());
            } catch (e) {
                console.warn("Theme: palette.json is not valid JSON (" + e + "), keeping the previous colors");
            }
        }
    }
}

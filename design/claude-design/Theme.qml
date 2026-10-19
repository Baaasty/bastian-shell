pragma Singleton
import QtQuick

// Desktop – Theme-Singleton (Variante Ember). Werte 1:1 aus tokens.json.
// Variante wechseln: `variant` setzen, alles andere bindet sich um.
QtObject {
    id: theme
    property string variant: "ember"   // "ember" | "walnut" | "candlelight"

    readonly property var palettes: ({
        ember: {
            bg: "#120D0B", bgBottom: "#0B0806", surface: "#1A1310",
            glassTint: Qt.rgba(26/255, 18/255, 14/255, 0.62),
            glassStrong: Qt.rgba(20/255, 13/255, 10/255, 0.80),
            border: Qt.rgba(1, 232/255, 205/255, 0.10),
            borderStrong: Qt.rgba(1, 232/255, 205/255, 0.20),
            text: "#F2E7D8", textMuted: "#BCAB98", textFaint: "#948370",
            accent: "#D15A32", accentText: "#E8805A",
            accentSoft: Qt.rgba(209/255, 90/255, 50/255, 0.16),
            wood: "#5A3F2E", woodLight: "#8A6648",
            success: "#9BA67E", warning: "#D9A449", error: "#D4463A",
            warningSoft: Qt.rgba(217/255, 164/255, 73/255, 0.16),
            dim: Qt.rgba(10/255, 6/255, 4/255, 0.42)
        },
        walnut: {
            bg: "#14100D", bgBottom: "#0C0907", surface: "#1C1511",
            glassTint: Qt.rgba(48/255, 34/255, 25/255, 0.58),
            glassStrong: Qt.rgba(38/255, 27/255, 20/255, 0.78),
            border: Qt.rgba(1, 225/255, 190/255, 0.12),
            borderStrong: Qt.rgba(1, 225/255, 190/255, 0.22),
            text: "#EFE3D1", textMuted: "#B9A791", textFaint: "#978470",
            accent: "#B9502F", accentText: "#DC7A55",
            accentSoft: Qt.rgba(185/255, 80/255, 47/255, 0.18),
            wood: "#6A4A35", woodLight: "#9A7454",
            success: "#9CA27A", warning: "#DDB15A", error: "#D4463A",
            warningSoft: Qt.rgba(221/255, 177/255, 90/255, 0.16),
            dim: Qt.rgba(10/255, 6/255, 4/255, 0.42)
        },
        candlelight: {
            bg: "#1A130D", bgBottom: "#100B07", surface: "#221910",
            glassTint: Qt.rgba(64/255, 46/255, 30/255, 0.50),
            glassStrong: Qt.rgba(52/255, 37/255, 24/255, 0.72),
            border: Qt.rgba(1, 230/255, 190/255, 0.14),
            borderStrong: Qt.rgba(1, 230/255, 190/255, 0.26),
            text: "#F7EEDF", textMuted: "#C6B59E", textFaint: "#9C8B74",
            accent: "#D59A3D", accentText: "#E9B65E",
            accentSoft: Qt.rgba(213/255, 154/255, 61/255, 0.18),
            wood: "#6E4F36", woodLight: "#A07A55",
            success: "#A3A77E", warning: "#CF5B35", error: "#D4463A",
            warningSoft: Qt.rgba(207/255, 91/255, 53/255, 0.16),
            dim: Qt.rgba(10/255, 6/255, 4/255, 0.42)
        }
    })
    readonly property var p: palettes[variant]

    // Farben
    readonly property color bg: p.bg
    readonly property color surface: p.surface
    readonly property color glass: p.glassTint
    readonly property color glassStrong: p.glassStrong
    readonly property color hairline: p.border
    readonly property color hairline2: p.borderStrong
    readonly property color text: p.text
    readonly property color text2: p.textMuted
    readonly property color text3: p.textFaint
    readonly property color accent: p.accent
    readonly property color accentText: p.accentText
    readonly property color accentSoft: p.accentSoft
    readonly property color wood: p.wood
    readonly property color woodLight: p.woodLight
    readonly property color ok: p.success
    readonly property color warn: p.warning
    readonly property color warnSoft: p.warningSoft
    readonly property color error: p.error
    readonly property color dim: p.dim
    readonly property color dimStrong: Qt.rgba(8/255, 5/255, 4/255, 0.55)

    // Geometrie
    readonly property int radiusSm: 8
    readonly property int radiusMd: 12
    readonly property int radiusLg: 16
    readonly property int radiusXl: 20
    readonly property int gap: 10          // Fenster-Lücke = Bar-Margin
    readonly property int barHeight: 38
    readonly property int tileGap: 20
    readonly property int dashMargin: 80
    readonly property int hitMin: 32

    // Glas
    readonly property int blurTile: 24
    readonly property int blurTerminal: 30
    readonly property int blurPower: 18

    // Schrift
    readonly property string ui: "Inter"
    readonly property string mono: "JetBrainsMono Nerd Font"

    // Motion (ms), immer Easing.OutCubic, keine Federn
    readonly property int fade: 150
    readonly property int slide: 200
    readonly property int ring: 250
    readonly property int osdVisible: 1200
    readonly property int notifyVisible: 6000
}

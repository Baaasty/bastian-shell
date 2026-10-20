// ERZEUGT aus theme/palette.json – nicht von Hand ändern.
// Neu erzeugen: python3 theme/gen/lockscreen_theme.py
pragma Singleton
import QtQuick

QtObject {
    readonly property string variant: "hearth"
    readonly property string fontUi: "Inter"
    readonly property string fontMono: "JetBrainsMono Nerd Font"
    readonly property bool blur: false
    readonly property color bg: "#2A211B"
    readonly property color bgBottom: "#211A15"
    readonly property color surface: "#382D26"
    readonly property color surfaceRaised: "#45372E"
    readonly property color surfaceSunken: "#2F2620"
    readonly property color glassTint: "#382D26"
    readonly property color glassStrong: "#45372E"
    readonly property color border: Qt.rgba(255 / 255, 236 / 255, 214 / 255, 0.1)
    readonly property color borderStrong: Qt.rgba(255 / 255, 236 / 255, 214 / 255, 0.2)
    readonly property color text: "#F6ECDD"
    readonly property color textMuted: "#D2C2AE"
    readonly property color textFaint: "#B5A591"
    readonly property color accent: "#DB6B4C"
    readonly property color accentHover: "#E57B5C"
    readonly property color accentPressed: "#C65A3D"
    readonly property color accentText: "#F2A58A"
    readonly property color accentSoft: Qt.rgba(219 / 255, 107 / 255, 76 / 255, 0.22)
    readonly property color accentFill: "#5C392D"
    readonly property color textOnAccent: "#2B1A12"
    readonly property color wood: "#6B4A38"
    readonly property color woodLight: "#A07C5C"
    readonly property color cream: "#F6ECDD"
    readonly property color success: "#A3B083"
    readonly property color warning: "#E0AE55"
    readonly property color warningSoft: Qt.rgba(224 / 255, 174 / 255, 85 / 255, 0.18)
    readonly property color error: "#E0604F"
    readonly property color dim: Qt.rgba(24 / 255, 17 / 255, 13 / 255, 0.82)
    readonly property color glow: Qt.rgba(219 / 255, 107 / 255, 76 / 255, 0.55)
    readonly property color shadow: Qt.rgba(12 / 255, 7 / 255, 4 / 255, 0.34)
}

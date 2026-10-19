pragma Singleton
import QtQuick
import Quickshell

// Feste Einstellungen der Desktop (später ggf. aus einer JSON-Datei)
Singleton {
    // Monitor, auf dem die ganze Shell lebt (Wunsch)
    readonly property string preferredScreen: "DP-2"
    // tatsächlicher Hauptmonitor: der Wunsch-Monitor, fehlt er (abgesteckt/aus), der erste vorhandene –
    // sonst gäbe es ohne DP-2 gar keine Shell. Alle Module nehmen mainScreen / mainScreenObj / mainScreens.
    readonly property var mainScreenObj: Quickshell.screens.find(s => s.name === preferredScreen) ?? Quickshell.screens[0] ?? null
    readonly property string mainScreen: mainScreenObj?.name ?? preferredScreen
    // als Variants-Modell: [Hauptmonitor] (leer ohne Monitor)
    readonly property var mainScreens: mainScreenObj ? [mainScreenObj] : []
    // Hyprland: ein Desktop gilt für alle Monitore (wie unter KWin). Desktop d = Workspace d auf dem
    // Hauptmonitor, 100+d auf dem 1. Nebenmonitor (links), 200+d auf dem 2. (rechts). false = nur der Hauptmonitor wechselt.
    readonly property bool globalDesktops: true
    // Ersatz-Variante, falls defaultTheme in theme/palette.json fehlt (Theme.variant ist die aktive)
    readonly property string variant: "ember"
    // Repo-Wurzel (shell/ liegt eine Ebene tiefer)
    readonly property string repo: Quickshell.shellDir + "/.."

    // ab hier gelten Temperaturen als "heiß" (Amber)
    readonly property int cpuHot: 80
    readonly property int gpuHot: 80
}

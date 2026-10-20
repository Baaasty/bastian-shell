import QtQuick
import Quickshell
import qs.config
import qs.services
import qs.components

// Technik-Chip in der Bar (rechts, neben Discord): CPU %, RAM %, GPU % in ruhiger Schrift. Wird es heiß (Config.cpuHot / gpuHot),
// steht die Temperatur in Amber dahinter (ersetzt Temps.qml). Klick öffnet das Ressourcen-Popout (Reiter, Suche, Prozesse).
Chip {
    id: chip
    hintKey: BarKeys.keyFor("resources")   // Bar-Modus (Super+Leertaste)

    property var barWindow: QsWindow.window

    readonly property bool cpuHot: Cpu.temp >= Config.cpuHot
    readonly property bool gpuHot: Gpu.temp >= Config.gpuHot
    readonly property int cpuPct: Math.round(Cpu.usage * 100)
    readonly property int ramPct: Math.round(Mem.usage * 100)

    padding: 9
    active: popout.visible
    onClicked: popout.toggle()

    // sichtbar -> Cpu/Mem im kurzen Takt (sonst alle 5 s bzw. 30 s)
    Binding {
        target: Cpu
        property: "watch"
        value: chip.visible
    }
    Binding {
        target: Mem
        property: "watch"
        value: chip.visible
    }

    // ein Wert: kleine Beschriftung + Prozent (feste Breite, springt nicht); Warnton ab 90 % bzw. wenn heiß
    component Stat: Row {
        property string label
        property int pct: 0
        property int temp: -1
        property bool hot: false
        spacing: 5
        Txt {
            anchors.verticalCenter: parent.verticalCenter
            text: parent.label
            color: Theme.textFaint
            font.pixelSize: 11
            font.weight: Font.DemiBold
        }
        MonoTxt {
            anchors.verticalCenter: parent.verticalCenter
            // Zahl rechtsbündig auf 3 Stellen: Breite bleibt gleich
            text: String(parent.pct).padStart(3, " ") + "%"
            color: parent.hot || parent.pct >= 90 ? Theme.warning : Theme.textMuted
            font.pixelSize: 12
        }
        MonoTxt {
            anchors.verticalCenter: parent.verticalCenter
            visible: parent.hot
            text: parent.hot ? parent.temp + "°" : ""
            color: Theme.warning
            font.pixelSize: 12
        }
    }

    Row {
        anchors.verticalCenter: parent.verticalCenter
        spacing: 14

        Stat { label: "CPU"; pct: chip.cpuPct; temp: Cpu.temp; hot: chip.cpuHot }
        Stat { label: "RAM"; pct: chip.ramPct }
        Stat { label: "GPU"; pct: Gpu.util; temp: Gpu.temp; hot: chip.gpuHot }
    }

    ResourcesPopout {
        id: popout
        barWindow: chip.barWindow
        chip: chip
    }
}

import QtQuick
import qs.config
import qs.services
import qs.components

// CPU-/GPU-Temperatur: nur sichtbar, wenn es heiß wird (ab Config.cpuHot / gpuHot), dann in Amber.
// Im Alltag steht sie im Dashboard (System), nicht in der Bar.
Row {
    readonly property bool cpuHot: Cpu.temp >= Config.cpuHot
    readonly property bool gpuHot: Gpu.temp >= Config.gpuHot
    readonly property bool hot: cpuHot || gpuHot
    spacing: 10

    MonoTxt {
        anchors.verticalCenter: parent.verticalCenter
        visible: parent.cpuHot
        // Text nur, wenn sichtbar: sonst setzt jede neue Messung unsichtbaren Text neu und die Bar zeichnet neu
        text: parent.cpuHot ? "CPU " + Cpu.temp + "°" : ""
        font.pixelSize: 12
        color: Theme.warning
    }
    MonoTxt {
        anchors.verticalCenter: parent.verticalCenter
        visible: parent.gpuHot
        text: parent.gpuHot ? "GPU " + Gpu.temp + "°" : ""
        font.pixelSize: 12
        color: Theme.warning
    }
}

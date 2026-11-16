import QtQuick
import qs.config

// Auffächern von der Mitte: Glut-Linie, dann gleiten obere/untere Hälfte von sourceItem als Standbild weg.
// Gemeinsam für Entsperren (LockSurface) und Login (SessionReveal), damit beide gleich aussehen.
// Dauer 140 + 560 ms – Lock.qml entsperrt erst danach (unlockTimer).
Item {
    id: root

    required property Item sourceItem

    signal finished()

    function start(): void {
        anim.start();
    }

    ShaderEffectSource {
        id: top
        visible: false
        width: root.width
        height: Math.ceil(root.height / 2)
        sourceItem: root.sourceItem
        sourceRect: Qt.rect(0, 0, width, height)
        live: false
        hideSource: visible
    }
    ShaderEffectSource {
        id: bottom
        visible: false
        y: top.height
        width: root.width
        height: root.height - top.height
        sourceItem: root.sourceItem
        sourceRect: Qt.rect(0, top.height, width, height)
        live: false
        hideSource: visible
    }
    Rectangle {
        id: seam
        anchors.centerIn: parent
        width: 0
        height: 2
        radius: 1
        opacity: 0
        color: Theme.accent
    }

    SequentialAnimation {
        id: anim
        ScriptAction {
            script: {
                top.scheduleUpdate();
                bottom.scheduleUpdate();
                top.visible = true;
                bottom.visible = true;
            }
        }
        // Glut-Linie in der Mitte
        ParallelAnimation {
            NumberAnimation { target: seam; property: "opacity"; to: 1; duration: 140; easing.type: Easing.OutCubic }
            NumberAnimation { target: seam; property: "width"; to: root.width * 0.6; duration: 180; easing.type: Easing.OutCubic }
        }
        // auffächern
        ParallelAnimation {
            NumberAnimation { target: top; property: "y"; to: -top.height; duration: 560; easing.type: Easing.InOutCubic }
            NumberAnimation { target: bottom; property: "y"; to: root.height; duration: 560; easing.type: Easing.InOutCubic }
            NumberAnimation { target: seam; property: "width"; to: root.width; duration: 300; easing.type: Easing.OutCubic }
            NumberAnimation { target: seam; property: "opacity"; to: 0; duration: 420; easing.type: Easing.InCubic }
        }
        ScriptAction { script: root.finished() }
    }
}

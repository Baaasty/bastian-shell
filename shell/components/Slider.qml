import QtQuick
import qs.config

// Schieberegler: 4-px-Spur, Holz-Füllung, Creme-Knopf. Ziehen, Klicken, Mausrad.
// value wird von außen gebunden; moved(v) meldet neue Werte (während des Ziehens laufend).
Item {
    id: root

    property real from: 0
    property real to: 1
    property real value: 0
    property real stepSize: 0.05     // Mausrad-Schritt
    property real wheelAcc: 0
    property color fill: Theme.woodLight
    readonly property bool pressed: area.pressed
    signal moved(real value)

    // beim Ziehen eigener Wert, damit der Knopf nicht auf Antworten wartet
    property real dragValue: 0
    readonly property real shown: pressed ? dragValue : value
    readonly property real ratio: to > from ? Math.max(0, Math.min(1, (shown - from) / (to - from))) : 0

    implicitWidth: 160
    implicitHeight: 24
    opacity: enabled ? 1 : 0.4

    function clamp(v) {
        return Math.max(from, Math.min(to, v));
    }
    function fromX(x) {
        const w = width - knob.width;
        return clamp(from + (to - from) * Math.max(0, Math.min(1, (x - knob.width / 2) / Math.max(1, w))));
    }

    Rectangle {
        id: track
        anchors.verticalCenter: parent.verticalCenter
        x: knob.width / 2
        width: root.width - knob.width
        height: 4
        radius: 2
        color: Theme.borderStrong

        Rectangle {
            width: parent.width * root.ratio
            height: parent.height
            radius: 2
            color: root.fill
        }
    }

    Rectangle {
        id: knob
        anchors.verticalCenter: parent.verticalCenter
        x: (root.width - width) * root.ratio
        width: 16
        height: 16
        radius: 8
        color: Theme.text
        scale: area.pressed ? 1.1 : area.containsMouse ? 1.05 : 1
        Behavior on scale { NumberAnimation { duration: Theme.fade; easing.type: Easing.OutCubic } }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: root.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        preventStealing: true
        onPressed: mouse => {
            root.dragValue = root.fromX(mouse.x);
            root.moved(root.dragValue);
        }
        onPositionChanged: mouse => {
            if (!pressed)
                return;
            const v = root.fromX(mouse.x);
            if (v !== root.dragValue) {
                root.dragValue = v;
                root.moved(v);
            }
        }
        onWheel: wheel => {
            const d = wheel.angleDelta.y !== 0 ? wheel.angleDelta.y : -wheel.angleDelta.x;
            if (d === 0)
                return;
            // nach Rasten zählen (120 = eine Raste): hochauflösende Mausräder schicken pro Raste mehrere Ereignisse
            root.wheelAcc += d;
            const n = Math.trunc(root.wheelAcc / 120);
            if (n === 0)
                return;
            root.wheelAcc -= n * 120;
            root.moved(root.clamp(root.value + n * root.stepSize));
        }
    }
}

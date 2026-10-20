import QtQuick
import qs.config

// Balken-Regler (30 px, wie die Chips): Holz-Füllung, Icon links, Wert rechts im Balken (Licht-, Gear-Popout).
// Klicken/Ziehen setzt den Wert direkt (stepSize-Raster), Mausrad in wheelStep-Schritten; moved(v) wie beim Slider.
// KeyNav erkennt ihn als Schieberegler (dragValue/stepSize/moved): Enter, dann ←/→ in wheelStep-Schritten.
Rectangle {
    id: bar
    property real from: 0
    property real to: 1
    property real value: 0
    property real stepSize: 1
    property real wheelStep: stepSize   // Mausrad: feiner als Ziehen
    property real wheelAcc: 0
    property string iconName
    property string label
    property string extraIcon       // kleines Zusatz-Icon vor dem Wert (z. B. Kamera aus)
    signal moved(real value)

    // beim Ziehen eigener Wert, damit die Füllung nicht auf Antworten wartet
    property real dragValue: 0
    readonly property real shown: barArea.pressed ? dragValue : value
    readonly property real ratio: to > from ? Math.max(0, Math.min(1, (shown - from) / (to - from))) : 0

    function clamp(v: real): real {
        return Math.max(from, Math.min(to, v));
    }
    function fromX(x: real): real {
        const v = from + (to - from) * Math.max(0, Math.min(1, x / Math.max(1, width)));
        return clamp(Math.round(v / stepSize) * stepSize);
    }

    implicitWidth: 160
    implicitHeight: 30
    radius: Theme.radiusSm
    color: barArea.containsMouse && enabled ? Qt.alpha(Theme.text, 0.1) : Theme.raise
    opacity: enabled ? 1 : 0.4
    Behavior on color { ColorAnimation { duration: Theme.fade } }
    Behavior on opacity { NumberAnimation { duration: Theme.fade } }

    // Füllung: mindestens ein runder Stummel, damit auch der Minimalwert sichtbar ist
    Rectangle {
        width: bar.radius * 2 + (bar.width - bar.radius * 2) * bar.ratio
        height: parent.height
        radius: bar.radius
        color: Qt.alpha(Theme.woodLight, barArea.pressed ? 0.7 : 0.55)
        Behavior on width {
            enabled: !barArea.pressed
            NumberAnimation { duration: Theme.fade; easing.type: Easing.OutCubic }
        }
        Behavior on color { ColorAnimation { duration: Theme.fade } }
    }
    Icon {
        x: 10
        anchors.verticalCenter: parent.verticalCenter
        visible: bar.iconName !== ""
        name: bar.iconName
        size: 16
        color: Theme.text
    }
    Row {
        anchors.right: parent.right
        anchors.rightMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        spacing: 6
        Icon {
            anchors.verticalCenter: parent.verticalCenter
            visible: bar.extraIcon !== ""
            name: bar.extraIcon
            size: 14
            color: Theme.textFaint
        }
        MonoTxt {
            anchors.verticalCenter: parent.verticalCenter
            text: bar.label
            color: Theme.textMuted
            font.pixelSize: 12
        }
    }
    MouseArea {
        id: barArea
        anchors.fill: parent
        hoverEnabled: true
        preventStealing: true
        cursorShape: bar.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        onPressed: mouse => {
            bar.dragValue = bar.fromX(mouse.x);
            bar.moved(bar.dragValue);
        }
        onPositionChanged: mouse => {
            if (!pressed)
                return;
            const v = bar.fromX(mouse.x);
            if (v !== bar.dragValue) {
                bar.dragValue = v;
                bar.moved(v);
            }
        }
        onWheel: wheel => {
            const d = wheel.angleDelta.y !== 0 ? wheel.angleDelta.y : -wheel.angleDelta.x;
            if (d === 0)
                return;
            // nach Rasten zählen (120 = eine Raste): hochauflösende Mausräder schicken pro Raste mehrere Ereignisse
            bar.wheelAcc += d;
            const n = Math.trunc(bar.wheelAcc / 120);
            if (n === 0)
                return;
            bar.wheelAcc -= n * 120;
            bar.moved(bar.clamp(bar.value + n * bar.wheelStep));
        }
    }
}

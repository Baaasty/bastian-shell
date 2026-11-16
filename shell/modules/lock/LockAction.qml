import QtQuick
import qs.config
import qs.components

// Ruhiger Symbol-Knopf (wie plasma/loginscreen/components/ActionButton.qml): runder Glas-Kreis + Beschriftung
Item {
    id: btn

    property string text
    property string glyph
    // Neustart/Ausschalten: erst beim zweiten Drücken (offene Fenster gingen sonst durch einen Fehlklick verloren);
    // gleiches Verhalten wie der Login-Bildschirm
    property bool confirm: false
    property bool armed: false
    signal clicked()

    readonly property bool lit: area.containsMouse || activeFocus || armed

    function trigger(): void {
        if (confirm && !armed) {
            armed = true;
            armTimer.restart();
            return;
        }
        armed = false;
        clicked();
    }

    implicitWidth: 96
    implicitHeight: 76
    activeFocusOnTab: true
    Keys.onReturnPressed: trigger()
    Keys.onSpacePressed: trigger()
    onVisibleChanged: if (!visible) armed = false

    Timer {
        id: armTimer
        interval: 3000
        onTriggered: btn.armed = false
    }

    Column {
        anchors.centerIn: parent
        spacing: 6

        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 44
            height: 44
            radius: 22
            color: btn.lit ? Theme.accentSoft : Theme.glassStrong
            border.width: btn.armed ? 2 : 1
            border.color: btn.lit ? Theme.accent : Theme.border
            Behavior on color { ColorAnimation { duration: 120 } }
            Icon {
                anchors.centerIn: parent
                name: btn.glyph
                size: 22
                color: btn.lit ? Theme.accentText : Theme.textMuted
            }
        }
        Txt {
            anchors.horizontalCenter: parent.horizontalCenter
            text: btn.armed ? "Press again" : btn.text
            color: btn.armed ? Theme.accentText : btn.lit ? Theme.text : Theme.textFaint
            font.pixelSize: 12
            font.weight: Font.Normal
        }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: btn.trigger()
    }
}

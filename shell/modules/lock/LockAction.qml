import QtQuick
import qs.config
import qs.components

// Ruhiger Symbol-Knopf (wie plasma/…/DesktopActionButton.qml): runder Glas-Kreis + Beschriftung
Item {
    id: btn

    property string text
    property string glyph
    signal clicked()

    readonly property bool lit: area.containsMouse || activeFocus

    implicitWidth: 96
    implicitHeight: 76
    activeFocusOnTab: true
    Keys.onReturnPressed: clicked()
    Keys.onSpacePressed: clicked()

    Column {
        anchors.centerIn: parent
        spacing: 6

        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 44
            height: 44
            radius: 22
            color: btn.lit ? Theme.accentSoft : Theme.glassStrong
            border.width: 1
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
            text: btn.text
            color: btn.lit ? Theme.text : Theme.textFaint
            font.pixelSize: 12
            font.weight: Font.Normal
        }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: btn.clicked()
    }
}

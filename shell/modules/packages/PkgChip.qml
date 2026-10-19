import QtQuick
import qs.config
import qs.components

// Umschalt-Chip (Filter)
Rectangle {
    id: c

    property string text
    property string icon
    property bool on: false
    signal clicked()

    implicitWidth: row.implicitWidth + 22
    implicitHeight: 28
    radius: Theme.radiusSm
    color: on ? Theme.accentSoft : area.containsMouse ? Qt.alpha(Theme.text, 0.1) : Theme.raise
    border.width: 1
    border.color: on ? Qt.alpha(Theme.accent, 0.5) : Theme.border
    Behavior on color { ColorAnimation { duration: Theme.fade } }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 6
        Icon {
            anchors.verticalCenter: parent.verticalCenter
            visible: c.icon !== ""
            name: c.icon
            size: 15
            color: c.on ? Theme.accentText : Theme.textMuted
        }
        Txt {
            anchors.verticalCenter: parent.verticalCenter
            text: c.text
            font.pixelSize: 12
            color: c.on ? Theme.accentText : Theme.textMuted
        }
    }
    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: c.clicked()
    }
}

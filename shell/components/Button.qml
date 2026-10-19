import QtQuick
import qs.config

// Knopf: neutral oder "primary" (Glut-Ton)
Rectangle {
    id: btn

    property string text
    property string icon
    property bool primary: false
    signal clicked()

    implicitWidth: row.implicitWidth + 32
    implicitHeight: 36
    radius: Theme.radiusMd
    color: primary ? Theme.accentSoft : area.containsMouse ? Qt.alpha(Theme.text, 0.1) : Theme.raise
    border.width: 1
    border.color: primary ? Qt.alpha(Theme.accent, 0.55) : Theme.border
    Behavior on color { ColorAnimation { duration: Theme.fade } }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 8
        Icon {
            anchors.verticalCenter: parent.verticalCenter
            visible: btn.icon !== ""
            name: btn.icon
            size: 18
            color: btn.primary ? Theme.accentText : Theme.text
        }
        Txt {
            anchors.verticalCenter: parent.verticalCenter
            text: btn.text
            color: btn.primary ? Theme.accentText : Theme.text
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

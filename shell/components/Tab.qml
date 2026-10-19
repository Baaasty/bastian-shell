import QtQuick
import qs.config

// Tab in einer Tab-Leiste (Dev services, Processes, Bildschirm teilen …) – überall gleich: weiche Ecke (radiusSm),
// aktiv = Akzentfläche, Hover leise. Optional Symbol davor und Zähler dahinter (count < 0 = keiner).
Rectangle {
    id: tb

    property string text
    property string icon: ""
    property int count: -1
    property bool current: false
    signal picked()

    width: tbRow.implicitWidth + 28
    height: 32
    radius: Theme.radiusSm
    color: current ? Theme.accentFill : tbArea.containsMouse ? Theme.surfaceSunken : "transparent"
    Behavior on color { ColorAnimation { duration: Theme.fade } }

    Row {
        id: tbRow
        anchors.centerIn: parent
        spacing: 6
        Icon {
            visible: tb.icon !== ""
            anchors.verticalCenter: parent.verticalCenter
            name: tb.icon
            size: 17
            color: tb.current ? Theme.accentText : Theme.textFaint
        }
        Txt {
            anchors.verticalCenter: parent.verticalCenter
            text: tb.text
            color: tb.current ? Theme.accentText : Theme.textMuted
            font.weight: tb.current ? Font.DemiBold : Font.Normal
        }
        MonoTxt {
            anchors.verticalCenter: parent.verticalCenter
            visible: tb.count >= 0
            text: tb.count
            color: tb.current ? Theme.accentText : Theme.textFaint
            font.pixelSize: 11
        }
    }
    MouseArea {
        id: tbArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: tb.picked()
    }
}

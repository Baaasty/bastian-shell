import QtQuick
import Quickshell
import qs.config
import qs.components

Row {
    property bool showDate: true

    spacing: 10

    SystemClock {
        id: clock
        precision: SystemClock.Seconds
    }

    MonoTxt {
        anchors.verticalCenter: parent.verticalCenter
        text: Qt.formatTime(clock.date, "HH:mm:ss")
        font.pixelSize: 14
        font.weight: Font.DemiBold
        font.letterSpacing: 0.3
    }

    Txt {
        visible: parent.showDate
        anchors.verticalCenter: parent.verticalCenter
        text: Qt.locale("en_GB").toString(clock.date, "ddd d MMM")
        color: Theme.textFaint
        font.pixelSize: 12
        font.weight: Font.Normal
    }
}

import QtQuick
import qs.config

// Schalter 40 × 24 (Licht-, Gear-Popout): checked von außen binden, toggled() meldet den Klick
Rectangle {
    id: tg
    property bool checked
    signal toggled()
    implicitWidth: 40
    implicitHeight: 24
    radius: 12
    color: checked ? Theme.accent : Theme.borderStrong
    opacity: enabled ? 1 : 0.4
    Behavior on color { ColorAnimation { duration: Theme.fade } }
    Rectangle {
        y: 3
        x: tg.checked ? tg.width - width - 3 : 3
        width: 18
        height: 18
        radius: 9
        color: Theme.text
        Behavior on x { NumberAnimation { duration: Theme.stateChange; easing.type: Easing.OutCubic } }
    }
    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: tg.toggled()
    }
}

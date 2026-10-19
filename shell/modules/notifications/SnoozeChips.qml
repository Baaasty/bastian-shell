import QtQuick
import qs.config
import qs.services
import qs.components

// Auswahl „Später erinnern“: kleine Knöpfe (10 min / 1 hour / Tomorrow, Liste aus NotifRules.snoozeOptions).
// picked({ min } oder { morning: true }); cancel = optionaler Abbrechen-Knopf (nur im Panel).
Row {
    id: root

    property bool cancelable: false
    signal picked(var spec)
    signal cancelled

    spacing: 6

    Repeater {
        model: NotifRules.snoozeOptions

        Rectangle {
            required property var modelData

            width: lbl.implicitWidth + 22
            height: 26
            radius: Theme.radiusSm
            color: area.containsMouse ? Theme.accentSoft : Theme.raise
            border.width: 1
            border.color: area.containsMouse ? Qt.alpha(Theme.accent, 0.5) : Theme.border
            Behavior on color { ColorAnimation { duration: Theme.fade } }

            Txt {
                id: lbl
                anchors.centerIn: parent
                text: modelData.label
                color: area.containsMouse ? Theme.accentText : Theme.text
                font.pixelSize: 12
                font.weight: Font.Normal
            }
            MouseArea {
                id: area
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.picked(modelData.morning ? { morning: true } : { min: modelData.min })
            }
        }
    }

    Rectangle {
        visible: root.cancelable
        width: 26
        height: 26
        radius: Theme.radiusSm
        color: xArea.containsMouse ? Qt.alpha(Theme.text, 0.1) : "transparent"
        Icon {
            anchors.centerIn: parent
            name: "close"
            size: 15
            color: Theme.textFaint
        }
        MouseArea {
            id: xArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.cancelled()
        }
    }
}

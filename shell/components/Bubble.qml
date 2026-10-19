import QtQuick
import QtQuick.Layouts
import qs.config

// Status-Bubble wie im iOS-Kontrollzentrum: runder Knopf mit Icon, darunter Name und Wert.
// calm = ok (leise), sonst in tone gefüllt. clickable -> Hover, Hand-Zeiger + clicked()
ColumnLayout {
    id: bubble
    property string icon
    property string name
    property string value
    property color tone: Theme.warning      // Farbe, wenn nicht ruhig
    property bool calm: true                 // ok = leise, sonst farbig gefüllt
    property bool clickable: false
    signal clicked

    spacing: 6

    // fillWidth: die Bubble füllt ihre ganze Spalte (sonst nur so breit wie ihr Text und links in der Zelle ->
    // Kreise zweier Reihen stehen versetzt); der Inhalt sitzt per AlignHCenter mittig
    Item {
        Layout.fillHeight: true
        Layout.fillWidth: true
    }
    Rectangle {
        Layout.alignment: Qt.AlignHCenter
        implicitWidth: 58
        implicitHeight: 58
        radius: 29
        // Kreis immer; Hover + Hand-Zeiger nur bei klickbaren (MouseArea ist sonst aus)
        color: !bubble.calm ? Qt.alpha(bubble.tone, hover.containsMouse ? 0.3 : 0.2)
            : hover.containsMouse ? Theme.borderStrong : Theme.border
        border.width: 1
        border.color: bubble.calm ? Theme.border : Qt.alpha(bubble.tone, 0.45)
        Behavior on color { ColorAnimation { duration: Theme.fade } }

        Icon {
            anchors.centerIn: parent
            name: bubble.icon
            size: 24
            color: bubble.calm ? Theme.textMuted : bubble.tone
        }
        MouseArea {
            id: hover
            anchors.fill: parent
            enabled: bubble.clickable
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: bubble.clicked()
        }
    }
    Txt {
        Layout.alignment: Qt.AlignHCenter
        text: bubble.name
        color: Theme.textMuted
        font.pixelSize: 13
        font.weight: Font.Normal
    }
    MonoTxt {
        Layout.alignment: Qt.AlignHCenter
        Layout.topMargin: -4
        text: bubble.value
        color: Theme.textFaint
        font.pixelSize: 12
    }
    Item {
        Layout.fillHeight: true
    }
}

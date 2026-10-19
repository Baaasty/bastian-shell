import QtQuick
import qs.config
import qs.components

// Eine Zeile im Quicklinks-Popup: Symbol, Titel, Nebentext, optional Status-Punkt links und „Entfernen“ rechts.
Rectangle {
    id: rowItem

    property string icon: "link"
    property string title: ""
    property string sub: ""
    property bool showDot: false
    property color dotColor: Theme.textFaint
    property bool dotOn: false          // true = gefüllt (läuft), false = Ring (läuft nicht)
    property bool removable: false
    property bool confirming: false     // erster Klick auf das X: „Remove?“, zweiter entfernt
    // Tastatur (Workspace-Modus Q): markierte Zeile, Ziffer davor, „Remove?“ nach dem ersten Entf
    property bool kbMark: false
    property string hint: ""
    property bool kbConfirm: false
    signal activated()
    signal removed()

    implicitHeight: 36
    radius: Theme.radiusSm
    color: area.containsMouse || kbMark ? Theme.raise : "transparent"
    border.width: kbMark ? 2 : 0
    border.color: Theme.accent
    Behavior on color { ColorAnimation { duration: Theme.fade } }

    onConfirmingChanged: if (confirming) confirmTimer.restart()
    Timer {
        id: confirmTimer
        interval: 3000
        onTriggered: rowItem.confirming = false
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: rowItem.activated()
        onContainsMouseChanged: if (!containsMouse && !rm.containsMouse) rowItem.confirming = false
    }

    Row {
        anchors.verticalCenter: parent.verticalCenter
        x: 10
        spacing: 10

        // Ziffer (nur im Tastatur-Betrieb): 1–9 öffnet die Zeile direkt
        MonoTxt {
            visible: rowItem.hint !== ""
            anchors.verticalCenter: parent.verticalCenter
            width: 12
            text: rowItem.hint
            color: Theme.accentText
            font.pixelSize: 13
            font.weight: Font.Bold
        }
        Item {
            visible: rowItem.showDot
            anchors.verticalCenter: parent.verticalCenter
            width: 10
            height: 10
            Rectangle {
                anchors.fill: parent
                radius: 5
                color: rowItem.dotOn ? rowItem.dotColor : "transparent"
                border.width: rowItem.dotOn ? 0 : 2
                border.color: Theme.textFaint
            }
        }
        Icon {
            anchors.verticalCenter: parent.verticalCenter
            name: rowItem.icon
            size: 18
            color: Theme.textMuted
        }
        Txt {
            id: titleTxt
            anchors.verticalCenter: parent.verticalCenter
            // Rest der Zeile: links 10 + Ziffer 22 + Punkt 20 + Symbol 28 + Nebentext + Abstand 10 + rechts (Entfernen 36 oder 14)
            width: Math.min(implicitWidth, Math.max(60, rowItem.width - 10 - (rowItem.hint !== "" ? 22 : 0) - (rowItem.showDot ? 20 : 0) - 28 - subTxt.width - 10 - (rowItem.removable ? 36 : 14)))
            text: rowItem.title
        }
        Txt {
            id: subTxt
            anchors.verticalCenter: parent.verticalCenter
            width: Math.min(implicitWidth, 150)
            text: rowItem.sub
            color: Theme.textFaint
            font.pixelSize: 13
        }
    }

    // Entfernen: nur bei Hover sichtbar, zweistufig (erst „Remove?“, dann weg)
    Rectangle {
        id: rmBtn
        readonly property bool asking: rowItem.confirming || rowItem.kbConfirm
        visible: rowItem.removable && (area.containsMouse || rm.containsMouse || asking)
        anchors.right: parent.right
        anchors.rightMargin: 6
        anchors.verticalCenter: parent.verticalCenter
        width: asking ? rmTxt.implicitWidth + 16 : 26
        height: 26
        radius: 8
        color: asking ? Theme.error : rm.containsMouse ? Theme.surfaceSunken : Theme.surfaceRaised
        Icon {
            visible: !rmBtn.asking
            anchors.centerIn: parent
            name: "close"
            size: 16
            color: Theme.textMuted
        }
        Txt {
            id: rmTxt
            visible: rmBtn.asking
            anchors.centerIn: parent
            text: rowItem.kbConfirm ? "Remove? Del" : "Remove?"
            color: Theme.onAccent
            font.pixelSize: 13
            font.weight: Font.DemiBold
        }
        MouseArea {
            id: rm
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                if (rowItem.confirming) {
                    rowItem.confirming = false;
                    rowItem.removed();
                } else {
                    rowItem.confirming = true;
                }
            }
        }
    }
}

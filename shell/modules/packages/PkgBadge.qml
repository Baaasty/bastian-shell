import QtQuick
import qs.config
import qs.components

// Kleine Plakette (Quelle, Bereich, Version …)
Rectangle {
    id: bd

    property string text
    property string icon
    property color fg: Theme.textMuted
    property color bg: Theme.raise
    property bool mono: false

    implicitWidth: inner.implicitWidth + 14
    implicitHeight: 20
    radius: Theme.radii.xs || 6
    color: bg

    Row {
        id: inner
        anchors.centerIn: parent
        spacing: 4
        Icon {
            anchors.verticalCenter: parent.verticalCenter
            visible: bd.icon !== ""
            name: bd.icon
            size: 13
            color: bd.fg
        }
        Txt {
            anchors.verticalCenter: parent.verticalCenter
            visible: !bd.mono
            text: bd.text
            color: bd.fg
            font.pixelSize: 11
        }
        MonoTxt {
            anchors.verticalCenter: parent.verticalCenter
            visible: bd.mono
            text: bd.text
            color: bd.fg
            font.pixelSize: 11
        }
    }
}

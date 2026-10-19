/*
    Desktop: ruhiger Symbol-Knopf (ersetzt org.kde.breeze.components.ActionButton auf dem Lockscreen).

    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Layouts

Item {
    id: btn
    property string text
    property string glyph
    signal clicked()

    implicitWidth: 96
    implicitHeight: 76
    activeFocusOnTab: true
    Keys.onReturnPressed: clicked()
    Keys.onSpacePressed: clicked()

    readonly property bool lit: area.containsMouse || activeFocus

    ColumnLayout {
        anchors.centerIn: parent
        spacing: 6
        Rectangle {
            Layout.alignment: Qt.AlignHCenter
            implicitWidth: 44
            implicitHeight: 44
            radius: 22
            color: btn.lit ? DesktopTheme.accentSoft : DesktopTheme.glassStrong
            border.width: 1
            border.color: btn.lit ? DesktopTheme.accent : DesktopTheme.border
            Behavior on color { ColorAnimation { duration: 120 } }
            Text {
                anchors.centerIn: parent
                text: btn.glyph
                font.family: "Material Symbols Rounded"
                font.pixelSize: 22
                color: btn.lit ? DesktopTheme.accentText : DesktopTheme.textMuted
            }
        }
        Text {
            Layout.alignment: Qt.AlignHCenter
            text: btn.text
            color: btn.lit ? DesktopTheme.text : DesktopTheme.textFaint
            font.family: DesktopTheme.fontUi
            font.pixelSize: 12
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

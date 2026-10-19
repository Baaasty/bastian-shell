/*
    SPDX-FileCopyrightText: 2014 David Edmundson <davidedmundson@kde.org>
    SPDX-FileCopyrightText: 2014 Aleix Pol Gonzalez <aleixpol@blue-systems.com>

    SPDX-License-Identifier: LGPL-2.0-or-later

    Desktop: Nutzer-Kachel für den Login-Greeter (ersetzt org.kde.breeze.components.UserDelegate).
    Ein Nutzer: nur der Name, leise. Mehrere: runder Avatar (oder Initiale) mit Glut-Ring für den
    gewählten Nutzer. Das Original braucht einen Shader aus dem Breeze-Plugin – den laden wir hier nicht.
*/

import QtQuick

import org.kde.kirigami as Kirigami

Item {
    id: wrapper

    property bool isCurrent: true

    property string name
    property string userName
    property string avatarPath
    property string iconSource
    property bool needsPassword
    property var vtNumber
    property bool constrainText: true
    property real nameFontSize: 15
    property real fontSize: Kirigami.Theme.defaultFont.pointSize + 2
    // Desktop: nur Name statt Avatar (gesetzt von UserList bei einem Nutzer)
    property bool single: false
    signal clicked()

    property real faceSize: Kirigami.Units.gridUnit * 4

    opacity: isCurrent ? 1.0 : 0.6
    Behavior on opacity {
        OpacityAnimator {
            duration: Kirigami.Units.longDuration
        }
    }

    Rectangle {
        id: face
        visible: !wrapper.single
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        width: wrapper.faceSize
        height: width
        radius: width / 2
        color: DesktopTheme.glassStrong
        border.width: wrapper.isCurrent ? 2 : 1
        border.color: wrapper.isCurrent ? DesktopTheme.accent : DesktopTheme.border

        Kirigami.ShadowedImage {
            id: faceImage
            anchors.fill: parent
            anchors.margins: 3
            radius: width / 2
            source: wrapper.avatarPath
            sourceSize: Qt.size(wrapper.faceSize * 2, wrapper.faceSize * 2)
            fillMode: Image.PreserveAspectCrop
            visible: status === Image.Ready
            color: "transparent"
        }

        Text {
            anchors.centerIn: parent
            visible: !faceImage.visible
            text: (wrapper.name || wrapper.userName || "?").charAt(0).toUpperCase()
            textFormat: Text.PlainText
            color: wrapper.isCurrent ? DesktopTheme.accentText : DesktopTheme.textMuted
            font.family: DesktopTheme.fontUi
            font.pixelSize: Math.round(wrapper.faceSize * 0.4)
            font.weight: Font.Medium
        }
    }

    Text {
        id: usernameDelegate
        anchors.top: wrapper.single ? undefined : face.bottom
        anchors.topMargin: Kirigami.Units.largeSpacing
        anchors.bottom: wrapper.single ? parent.bottom : undefined
        anchors.horizontalCenter: parent.horizontalCenter

        width: wrapper.constrainText ? parent.width : implicitWidth
        text: wrapper.name
        textFormat: Text.PlainText
        color: wrapper.isCurrent ? DesktopTheme.textMuted : DesktopTheme.textFaint
        font.family: DesktopTheme.fontUi
        font.pixelSize: wrapper.nameFontSize
        font.weight: Font.Medium
        // Tastatur-Fokus sichtbar machen (nur per Tab erreichbar)
        font.underline: wrapper.activeFocus
        wrapMode: Text.WordWrap
        maximumLineCount: wrapper.constrainText ? 2 : 1
        elide: Text.ElideRight
        horizontalAlignment: Text.AlignHCenter
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: wrapper.single ? Qt.ArrowCursor : Qt.PointingHandCursor
        onClicked: wrapper.clicked()
    }

    Keys.onSpacePressed: wrapper.clicked()

    Accessible.name: name
    Accessible.role: Accessible.Button
    function accessiblePressAction() { wrapper.clicked() }
}

/*
    Desktop: ruhiger Symbol-Knopf wie auf dem Lockscreen (DesktopActionButton.qml) – ersetzt
    org.kde.breeze.components.ActionButton im Plasma-Login-Greeter.
    Main.qml (im Greeter-Binary) setzt icon.name, text, visible und onClicked; wir zeigen statt des
    Breeze-Symbols ein Material-Symbol und feste englische Beschriftungen.

    SPDX-FileCopyrightText: 2016 David Edmundson <davidedmundson@kde.org>
    SPDX-License-Identifier: LGPL-2.0-or-later
*/

import QtQuick
import QtQuick.Layouts
import QtQuick.Templates as T

T.AbstractButton {
    id: btn

    // Breeze-Symbolname (aus Main.qml) -> Material Symbol + Beschriftung
    readonly property var desktopGlyphs: ({
        "system-suspend": "bedtime",
        "system-hibernate": "mode_standby",
        "system-reboot": "restart_alt",
        "system-shutdown": "power_settings_new",
        "system-user-prompt": "person_add",
        "system-user-list": "group",
        "system-switch-user": "switch_account"
    })
    readonly property var desktopLabels: ({
        "system-suspend": "Standby",
        "system-hibernate": "Hibernate",
        "system-reboot": "Restart",
        "system-shutdown": "Shut down",
        "system-user-prompt": "Other user",
        "system-user-list": "All users",
        "system-switch-user": "Switch user"
    })
    readonly property string desktopGlyph: desktopGlyphs[icon.name] || "radio_button_unchecked"
    readonly property string desktopLabel: desktopLabels[icon.name] || text

    readonly property bool lit: hovered || activeFocus

    implicitWidth: 96
    implicitHeight: 76
    hoverEnabled: true
    focusPolicy: Qt.TabFocus

    Accessible.name: desktopLabel

    background: Item {}

    HoverHandler {
        cursorShape: Qt.PointingHandCursor
    }

    contentItem: ColumnLayout {
        spacing: 6
        Rectangle {
            Layout.alignment: Qt.AlignHCenter
            implicitWidth: 44
            implicitHeight: 44
            radius: 22
            color: btn.down || btn.lit ? DesktopTheme.accentSoft : DesktopTheme.glassStrong
            border.width: 1
            border.color: btn.lit ? DesktopTheme.accent : DesktopTheme.border
            Behavior on color { ColorAnimation { duration: 120 } }
            Text {
                anchors.centerIn: parent
                text: btn.desktopGlyph
                font.family: "Material Symbols Rounded"
                font.pixelSize: 22
                color: btn.lit ? DesktopTheme.accentText : DesktopTheme.textMuted
            }
        }
        Text {
            Layout.alignment: Qt.AlignHCenter
            text: btn.desktopLabel
            textFormat: Text.PlainText
            color: btn.lit ? DesktopTheme.text : DesktopTheme.textFaint
            font.family: DesktopTheme.fontUi
            font.pixelSize: 12
        }
    }

    Keys.onEnterPressed: clicked()
    Keys.onReturnPressed: clicked()
}

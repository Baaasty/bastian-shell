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

    // Neustart/Ausschalten erst beim zweiten Drücken – gleiches Verhalten wie der Sperrbildschirm (LockAction.qml).
    // Maus und Tasten laufen über trigger(); erst der zweite Druck löst clicked() aus, den Main.qml behandelt.
    readonly property bool desktopConfirm: icon.name === "system-reboot" || icon.name === "system-shutdown"
    property bool desktopArmed: false

    function desktopTrigger() {
        if (desktopConfirm && !desktopArmed) {
            desktopArmed = true;
            desktopArmTimer.restart();
            return;
        }
        desktopArmed = false;
        clicked();
    }

    readonly property bool lit: hovered || activeFocus || desktopArmed || desktopArea.containsMouse

    implicitWidth: 96
    implicitHeight: 76
    hoverEnabled: true
    focusPolicy: Qt.TabFocus

    Accessible.name: desktopLabel

    background: Item {}

    Timer {
        id: desktopArmTimer
        interval: 3000
        onTriggered: btn.desktopArmed = false
    }

    // fängt die Maus vor T.AbstractButton ab (sonst löste schon der erste Klick aus)
    MouseArea {
        id: desktopArea
        anchors.fill: parent
        z: 1
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: btn.desktopTrigger()
    }

    contentItem: ColumnLayout {
        spacing: 6
        Rectangle {
            Layout.alignment: Qt.AlignHCenter
            implicitWidth: 44
            implicitHeight: 44
            radius: 22
            color: btn.down || btn.lit ? DesktopTheme.accentSoft : DesktopTheme.glassStrong
            border.width: btn.desktopArmed ? 2 : 1
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
            text: btn.desktopArmed ? "Press again" : btn.desktopLabel
            textFormat: Text.PlainText
            color: btn.desktopArmed ? DesktopTheme.accentText : btn.lit ? DesktopTheme.text : DesktopTheme.textFaint
            font.family: DesktopTheme.fontUi
            font.pixelSize: 12
        }
    }

    Keys.onEnterPressed: desktopTrigger()
    Keys.onReturnPressed: desktopTrigger()
    // Leertaste selbst annehmen, sonst löst T.AbstractButton beim Loslassen aus
    Keys.onSpacePressed: event => {
        event.accepted = true;
        desktopTrigger();
    }
}

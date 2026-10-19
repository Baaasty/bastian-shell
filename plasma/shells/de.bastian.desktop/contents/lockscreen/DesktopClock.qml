/*
    Desktop: Lockscreen-Uhr im Ember-Stil (ersetzt org.kde.breeze.components.Clock).
    Große Mono-Uhr HH:MM mit kleinen Sekunden, Datum (Englisch), darunter "When you're back: …" (aus der Lockscreen-Einstellung desktopTask).

    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Layouts

import org.kde.plasma.clock as PlasmaClock

ColumnLayout {
    id: hclock

    property string task: ""

    spacing: 10

    // Stil wie Dashboard und Chrome-Tab-Seite: HH:MM groß und gefüllt,
    // Sekunden klein und leise daneben, auf derselben Grundlinie
    Row {
        Layout.alignment: Qt.AlignHCenter
        spacing: Math.round(hm.font.pixelSize * 0.13)

        Text {
            id: hm
            text: Qt.formatTime(timeSource.dateTime, "HH:mm")
            textFormat: Text.PlainText
            color: DesktopTheme.text
            font.family: DesktopTheme.fontMono
            font.features: { "tnum": 1 }
            font.pixelSize: 260
            font.weight: Font.DemiBold
            font.letterSpacing: -13 // -0.05em
        }
        Text {
            anchors.baseline: hm.baseline
            text: Qt.formatTime(timeSource.dateTime, "ss")
            textFormat: Text.PlainText
            color: DesktopTheme.textFaint
            font.family: DesktopTheme.fontMono
            font.features: { "tnum": 1 }
            font.pixelSize: Math.round(hm.font.pixelSize * 0.26)
            font.weight: Font.Medium
        }
    }

    Text {
        Layout.alignment: Qt.AlignHCenter
        text: Qt.locale("en_GB").toString(timeSource.dateTime, "dddd, d MMMM")
        textFormat: Text.PlainText
        color: DesktopTheme.textMuted
        font.family: DesktopTheme.fontUi
        font.pixelSize: 22
    }

    Text {
        Layout.alignment: Qt.AlignHCenter
        Layout.topMargin: 6
        visible: hclock.task !== ""
        textFormat: Text.PlainText
        text: "When you're back: " + hclock.task
        color: DesktopTheme.textFaint
        font.family: DesktopTheme.fontUi
        font.pixelSize: 16
    }

    PlasmaClock.Clock {
        id: timeSource
        trackSeconds: true // Desktop: Uhr mit Sekunden
    }
}

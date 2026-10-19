/*
    Desktop: Login-Uhr im Ember-Stil – ersetzt org.kde.breeze.components.Clock im Plasma-Login-Greeter.
    Gleiches Bild wie die Lockscreen-Uhr (plasma/shells/de.bastian.desktop/contents/lockscreen/DesktopClock.qml):
    große Mono-Uhr HH:MM, Sekunden klein daneben, Datum auf Englisch.
    Wie beim Lockscreen nur auf dem Hauptmonitor (LoginConfig.mainScreen); die Größe bleibt auf allen
    Monitoren gleich, damit Main.qml (im Greeter-Binary) das Layout gleich rechnet.

    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Layouts
import QtQuick.Window

import org.kde.plasma.clock as PlasmaClock

ColumnLayout {
    id: hclock

    readonly property bool desktopMain: LoginConfig.mainScreen === "" || Screen.name === LoginConfig.mainScreen
    // 260 px bei 1440p wie der Lockscreen, auf kleineren Monitoren mitskalieren
    readonly property int desktopSize: Math.round(Math.min(260, Math.max(120, Screen.height * 0.18)))

    spacing: 10

    // @desktop-shot-hook (nur scripts/loginscreen shot setzt hier eine Bildschirmfoto-Hilfe ein)

    // Stil wie Dashboard, Chrome-Tab-Seite und Lockscreen: HH:MM groß und gefüllt,
    // Sekunden klein und leise daneben, auf derselben Grundlinie
    Row {
        Layout.alignment: Qt.AlignHCenter
        spacing: Math.round(hm.font.pixelSize * 0.13)
        opacity: hclock.desktopMain ? 1 : 0

        Text {
            id: hm
            text: Qt.formatTime(timeSource.dateTime, "HH:mm")
            textFormat: Text.PlainText
            color: DesktopTheme.text
            font.family: DesktopTheme.fontMono
            font.features: { "tnum": 1 }
            font.pixelSize: hclock.desktopSize
            font.weight: Font.DemiBold
            font.letterSpacing: -Math.round(hclock.desktopSize * 0.05) // -0.05em
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
        opacity: hclock.desktopMain ? 1 : 0
        text: Qt.locale("en_GB").toString(timeSource.dateTime, "dddd, d MMMM")
        textFormat: Text.PlainText
        color: DesktopTheme.textMuted
        font.family: DesktopTheme.fontUi
        font.pixelSize: 22
    }

    PlasmaClock.Clock {
        id: timeSource
        trackSeconds: true
    }
}

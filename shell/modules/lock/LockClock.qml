import QtQuick
import QtQuick.Effects
import Quickshell
import qs.config
import qs.services
import qs.components

// Sperr-Uhr im einheitlichen Stil (wie ClockTile und Chrome-Tab-Seite, vorher plasma/…/DesktopClock.qml):
// HH:MM groß und gefüllt, Sekunden klein und leise auf derselben Grundlinie, Datum (Englisch),
// darunter „When you're back: …“ = Jetzt-Aufgabe aus dem Fokus-Dienst.
Column {
    id: lc

    // Schatten nur bei scharfem Hintergrund (Plasma: DropShadow, Radius 7, Schwarz 0,7)
    property real shadow: 1
    Behavior on shadow { NumberAnimation { duration: 800; easing.type: Easing.InOutQuad } }

    spacing: 10

    SystemClock {
        id: clock
        precision: SystemClock.Seconds
        enabled: lc.visible
    }

    layer.enabled: true
    layer.effect: MultiEffect {
        shadowEnabled: true
        shadowColor: Qt.alpha(Theme.dim, 0.7)
        shadowOpacity: lc.shadow
        shadowBlur: 0.22
        shadowVerticalOffset: 1
    }

    Row {
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: Math.round(hm.font.pixelSize * 0.13)

        MonoTxt {
            id: hm
            text: Qt.formatTime(clock.date, "HH:mm")
            font.pixelSize: 260
            font.weight: Font.DemiBold
            font.letterSpacing: -13 // -0.05em
        }
        MonoTxt {
            anchors.baseline: hm.baseline
            text: Qt.formatTime(clock.date, "ss")
            color: Theme.textFaint
            font.pixelSize: Math.round(hm.font.pixelSize * 0.26)
            font.weight: Font.Medium
        }
    }

    Txt {
        anchors.horizontalCenter: parent.horizontalCenter
        text: Qt.locale("en_GB").toString(clock.date, "dddd, d MMMM")
        color: Theme.textMuted
        font.pixelSize: 22
        font.weight: Font.Normal
    }

    // Plasma: Layout.topMargin 6 → hier über ein Abstandsstück
    Item {
        width: 1
        height: 6 - lc.spacing
        visible: task.visible
    }
    Txt {
        id: task
        anchors.horizontalCenter: parent.horizontalCenter
        visible: Focus.task !== ""
        text: "When you're back: " + Focus.task
        color: Theme.textFaint
        font.pixelSize: 16
        font.weight: Font.Normal
    }
}

import QtQuick
import Quickshell
import qs.config
import qs.services
import qs.components

// Fokus oben links. Leerlauf: "Focus · 25 min" – Mausrad wählt die Vorgabe (15/25/45/60/90 min oder
// "until 12:00"), Klick öffnet das Popout (Vorgaben, eigene Zeit, Aufgabe), Doppelklick startet sofort
// mit der Vorgabe. Läuft: Restzeit, Klick = Pause/Weiter, Rechtsklick oder ■ daneben = beenden.
// Fokus ohne Zeit: ∞ + Minuten seit Start, gedämpft (kein Glut-Ton, läuft ja unbegrenzt) – Klick = aus.
Row {
    id: root

    property var barWindow: QsWindow.window

    readonly property bool idle: Focus.mode === "idle"
    readonly property color tint: Focus.mode === "break" ? Theme.success : idle || Focus.openOn ? Theme.textMuted : Theme.accentText

    spacing: 2

    HoverHandler {
        id: hover
    }
    // am Row (Vorfahr des Chips): das Mausrad landet erst beim MouseArea des Chips und steigt dann hierher
    WheelHandler {
        enabled: root.idle
        onWheel: e => Focus.cyclePreset(e.angleDelta.y > 0 ? 1 : -1)
    }

    // Einfachklick im Leerlauf kurz zurückhalten: kommt ein zweiter Klick, ist es ein Doppelklick (= sofort starten)
    Timer {
        id: clickDelay
        interval: 220
        onTriggered: popout.open()
    }

    Chip {
        id: chip
        anchors.verticalCenter: parent.verticalCenter
        hintKey: BarKeys.keyFor("focus")   // Bar-Modus (Super+Leertaste)
        tip: "Focus · Super+F"
        active: popout.visible
        onClicked: mouse => {
            if (mouse.button === Qt.RightButton) {
                if (!root.idle)
                    Focus.stop();
                return;
            }
            if (root.idle) {
                // offen (oder gerade eben durch genau diesen Klick daneben zugegangen) -> zu lassen
                if (popout.visible || popout.justClosed())
                    popout.close();
                else
                    clickDelay.restart();
            } else if (Focus.openOn)
                Focus.stop();
            else if (Focus.mode === "focus")
                Focus.pause();
            else if (Focus.mode === "paused")
                Focus.resume();
            else
                Focus.stop();
        }
        onDoubleClicked: mouse => {
            if (mouse.button !== Qt.LeftButton || !root.idle)
                return;
            clickDelay.stop();
            popout.close();
            Focus.start();
        }

        Icon {
            anchors.verticalCenter: parent.verticalCenter
            name: Focus.openOn ? "all_inclusive" : Focus.mode === "break" ? "coffee" : Focus.mode === "paused" ? "pause" : "timer"
            size: 15
            fill: !root.idle
            color: root.idle ? Theme.textFaint : root.tint
        }
        MonoTxt {
            anchors.verticalCenter: parent.verticalCenter
            visible: !root.idle && !Focus.openOn
            text: Focus.fmt(Focus.remaining)
            color: root.tint
            font.weight: Font.DemiBold
        }
        Txt {
            anchors.verticalCenter: parent.verticalCenter
            visible: Focus.openOn
            text: "Focus · " + Focus.sinceLabel(Focus.elapsed)
            color: Theme.textMuted
        }
        Txt {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.idle
            text: "Focus · " + Focus.preset.label
            color: Theme.textMuted
        }
    }
    // Beenden: nur beim Drüberfahren, damit der Chip ruhig bleibt
    Chip {
        anchors.verticalCenter: parent.verticalCenter
        visible: !root.idle && hover.hovered
        padding: 7
        onClicked: Focus.stop()
        Icon {
            anchors.verticalCenter: parent.verticalCenter
            name: "stop"
            size: 14
            fill: true
            color: Theme.accentText
        }
    }

    FocusPopout {
        id: popout
        barWindow: root.barWindow
        chip: chip
    }
}

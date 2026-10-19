import QtQuick
import Quickshell
import qs.config
import qs.components

// Ruhiger Kamin-Bildschirm (flach, deckend, ohne Glühen) mit kleiner Uhr.
// Sparsam: kein Dauer-Animieren. Die Flammen springen in kleinen Schritten (ca. 6 Bilder/s, nur solange
// sichtbar), die Uhr wechselt einmal pro Minute und wandert dabei ein paar Pixel (gegen Einbrennen).
Item {
    id: fp

    // läuft nur, solange der Kamin sichtbar ist
    property bool active: false
    property int tick: 0

    // eine Einheit ~ 1/1000 der kleineren Bildschirmseite
    readonly property real u: Math.min(width, height) / 1000

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
        enabled: fp.active
    }

    Timer {
        interval: 160
        repeat: true
        running: fp.active
        onTriggered: fp.tick++
    }

    // kleine Verschiebung pro Minute (6 Stellen im Kreis)
    readonly property var drift: [[0, 0], [10, -6], [16, 4], [6, 12], [-8, 8], [-14, -2]]
    readonly property var d: drift[clock.date.getMinutes() % drift.length]

    // sanftes, ruhiges Auf und Ab je Flamme (Summe zweier Sinuswellen, in Schritten)
    function wob(speed: real, phase: real, amp: real): real {
        return 1 + amp * (0.65 * Math.sin(tick * speed + phase) + 0.35 * Math.sin(tick * speed * 2.3 + phase * 1.7));
    }

    Rectangle {
        anchors.fill: parent
        color: Qt.darker(Theme.bgBottom, 1.35)
    }

    Item {
        anchors.centerIn: parent
        anchors.horizontalCenterOffset: fp.d[0] * fp.u
        anchors.verticalCenterOffset: fp.d[1] * fp.u
        width: 700 * fp.u
        height: 760 * fp.u

        // ---- Uhr ----
        Column {
            id: clockCol
            anchors.horizontalCenter: parent.horizontalCenter
            y: 0
            spacing: 6 * fp.u

            MonoTxt {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Qt.formatTime(clock.date, "HH:mm")
                color: Theme.textMuted
                font.pixelSize: Math.round(150 * fp.u)
                font.weight: Font.Medium
            }
            Txt {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Qt.locale("en_GB").toString(clock.date, "dddd, d MMMM")
                color: Theme.textFaint
                font.pixelSize: Math.round(26 * fp.u)
                font.weight: Font.Normal
            }
        }

        // ---- Kamin ----
        Item {
            id: hearth
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            width: 600 * fp.u
            height: 440 * fp.u

            // Sims
            Rectangle {
                x: -40 * fp.u
                y: 0
                width: parent.width + 80 * fp.u
                height: 38 * fp.u
                radius: 12 * fp.u
                color: Theme.woodLight
            }
            // Rahmen
            Rectangle {
                y: 30 * fp.u
                width: parent.width
                height: parent.height - 30 * fp.u
                radius: 22 * fp.u
                color: Theme.wood
            }
            // Feuerraum
            Rectangle {
                id: opening
                x: 50 * fp.u
                y: 80 * fp.u
                width: parent.width - 100 * fp.u
                height: parent.height - 80 * fp.u
                radius: 26 * fp.u
                color: Qt.darker(Theme.bgBottom, 1.9)
                clip: true

                // Flammen: hinten groß (Ember), vorn kleiner (Amber), ganz vorn klein (helles Lachs)
                Flame {
                    x: opening.width * 0.5 - fw * 0.5
                    y: opening.height - 70 * fp.u - fh
                    fw: 230 * fp.u
                    fh: 270 * fp.u * fp.wob(0.19, 0.0, 0.06)
                    sway: 0.5 + 0.05 * Math.sin(fp.tick * 0.11)
                    fill: Theme.accent
                }
                Flame {
                    x: opening.width * 0.5 - 150 * fp.u - fw * 0.5
                    y: opening.height - 70 * fp.u - fh
                    fw: 150 * fp.u
                    fh: 170 * fp.u * fp.wob(0.23, 2.1, 0.07)
                    sway: 0.45 + 0.06 * Math.sin(fp.tick * 0.14 + 1)
                    fill: Theme.accent
                }
                Flame {
                    x: opening.width * 0.5 + 150 * fp.u - fw * 0.5
                    y: opening.height - 70 * fp.u - fh
                    fw: 140 * fp.u
                    fh: 150 * fp.u * fp.wob(0.21, 4.0, 0.07)
                    sway: 0.55 + 0.06 * Math.sin(fp.tick * 0.13 + 3)
                    fill: Theme.accent
                }
                Flame {
                    x: opening.width * 0.5 - fw * 0.5
                    y: opening.height - 64 * fp.u - fh
                    fw: 140 * fp.u
                    fh: 170 * fp.u * fp.wob(0.27, 1.3, 0.08)
                    sway: 0.5 + 0.07 * Math.sin(fp.tick * 0.16 + 2)
                    fill: Theme.warning
                }
                Flame {
                    x: opening.width * 0.5 - fw * 0.5
                    y: opening.height - 60 * fp.u - fh
                    fw: 70 * fp.u
                    fh: 90 * fp.u * fp.wob(0.31, 5.2, 0.09)
                    sway: 0.5 + 0.08 * Math.sin(fp.tick * 0.18 + 4)
                    fill: Theme.accentText
                }

                // Holzscheite
                Rectangle {
                    x: opening.width * 0.5 - 190 * fp.u
                    y: opening.height - 78 * fp.u
                    width: 250 * fp.u
                    height: 50 * fp.u
                    radius: height / 2
                    rotation: -7
                    color: Theme.woodLight
                }
                Rectangle {
                    x: opening.width * 0.5 - 70 * fp.u
                    y: opening.height - 80 * fp.u
                    width: 250 * fp.u
                    height: 50 * fp.u
                    radius: height / 2
                    rotation: 7
                    color: Qt.darker(Theme.woodLight, 1.25)
                }
                Rectangle {
                    x: opening.width * 0.5 - 150 * fp.u
                    y: opening.height - 46 * fp.u
                    width: 300 * fp.u
                    height: 56 * fp.u
                    radius: height / 2
                    color: Qt.darker(Theme.wood, 1.2)
                }

                // Glut: wenige Punkte, die in Schritten heller/dunkler werden
                Repeater {
                    model: [[-0.30, 0.0, 0.0], [-0.12, 0.3, 1.7], [0.06, -0.1, 3.1], [0.22, 0.2, 4.4], [0.34, -0.05, 5.8]]
                    Rectangle {
                        required property var modelData
                        x: opening.width * (0.5 + modelData[0]) - width / 2
                        y: opening.height - (50 + 14 * modelData[1] + 6) * fp.u
                        width: 14 * fp.u
                        height: width
                        radius: width / 2
                        color: Theme.accentText
                        opacity: 0.55 + 0.4 * (0.5 + 0.5 * Math.sin(fp.tick * 0.12 + modelData[2]))
                    }
                }
            }
        }
    }
}

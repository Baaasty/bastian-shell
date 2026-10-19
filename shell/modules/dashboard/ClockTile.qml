import QtQuick
import Quickshell
import qs.config
import qs.services
import qs.components

// Uhr (HH:MM groß, Sekunden klein – wie Chrome-Tab-Seite und Lockscreen) + Datum, Schriftgröße folgt der Kachelhöhe.
// Rechts unten leise das Wetter (Ort aus secrets.json): jetzt + "Morgen früh"-Urteil, 3 Tage nur bei genug Breite.
// Die Uhr hat Vorrang: Wetter passt sich an (kürzt), nie umgekehrt.
Tile {
    id: tile

    title: "Today"
    note: "Week " + isoWeek(clock.date)

    function isoWeek(d) {
        const t = new Date(Date.UTC(d.getFullYear(), d.getMonth(), d.getDate()));
        const day = t.getUTCDay() || 7;
        t.setUTCDate(t.getUTCDate() + 4 - day);
        const yearStart = new Date(Date.UTC(t.getUTCFullYear(), 0, 1));
        return Math.ceil(((t - yearStart) / 86400000 + 1) / 7);
    }

    SystemClock {
        id: clock
        precision: SystemClock.Seconds
        // nur bei offenem Dashboard ticken (beim Öffnen springt die Uhr sofort auf die aktuelle Zeit):
        // sonst wird jede Sekunde die große Uhr im unsichtbaren Fenster neu gesetzt
        enabled: !!tile.QsWindow.window && tile.QsWindow.window.visible
    }

    // Größe aus der Kachelhöhe; die Breite bremst nur bei schmalen Kacheln, und unten bleibt immer
    // Platz für die Fußzeile (Datum + zwei Wetterzeilen, ~64 px), damit nichts kollidiert
    readonly property int digits: Math.round(Math.min(height * 0.5, width * 0.26, Math.max(40, (height - 74 - 64) / 0.75)))

    // Stil wie die Chrome-Tab-Seite (theme/gen/chrome-ext/newtab.css .clock):
    // HH:MM groß und gefüllt, Sekunden klein und leise daneben, auf derselben Grundlinie
    Row {
        id: clockRow
        // schlicht oben im Kachelinhalt (unter „Today“): die Rechnung über FontMetrics schob die Uhr
        // aus der Kachel heraus; die Oberlänge der Schrift wird nur leicht ausgeglichen
        x: 0
        y: -Math.round(tile.digits * 0.12)
        spacing: Math.round(tile.digits * 0.13)

        MonoTxt {
            id: hm
            text: Qt.formatTime(clock.date, "HH:mm")
            font.pixelSize: tile.digits
            font.weight: Font.DemiBold
            font.letterSpacing: -tile.digits * 0.05
        }
        MonoTxt {
            anchors.baseline: hm.baseline
            text: Qt.formatTime(clock.date, "ss")
            color: Theme.textFaint
            font.pixelSize: Math.round(tile.digits * 0.26)
            font.weight: Font.Medium
        }
    }

    // Fußzeile: links das Datum, rechts das Wetter in zwei Zeilen (untere auf der Grundlinie des Datums)
    Item {
        id: weather

        // Platz rechts vom Datum (mit Luft dazwischen)
        readonly property real room: width - dateTxt.implicitWidth - 32
        readonly property bool hasMorning: Weather.ready && Weather.morning !== null
        readonly property bool morningOk: hasMorning && Weather.morning.ok

        anchors.fill: parent

        Txt {
            id: dateTxt
            anchors.left: parent.left
            anchors.bottom: parent.bottom
            text: Qt.locale("en_GB").toString(clock.date, "dddd, d MMMM")
            color: Theme.textMuted
            font.pixelSize: 16
            font.weight: Font.Normal
        }

        // Zeile 2: morgen früh 7–9 Uhr – Rad oder Auto
        Txt {
            id: morningTxt
            anchors.right: parent.right
            anchors.baseline: dateTxt.baseline
            width: Math.min(implicitWidth, Math.max(0, weather.room - morningIcon.width - 6))
            visible: weather.hasMorning
            text: weather.hasMorning ? "Tomorrow 7–9 · " + Weather.morning.verdict : ""
            color: Theme.textFaint
            font.pixelSize: 12
            font.weight: Font.Normal
        }
        Icon {
            id: morningIcon
            anchors.right: morningTxt.left
            anchors.rightMargin: 6
            anchors.verticalCenter: morningTxt.verticalCenter
            visible: weather.hasMorning
            name: weather.morningOk ? "two_wheeler" : "directions_car"
            size: 14
            color: weather.morningOk ? Theme.success : Theme.warning
        }

        // Zeile 1: jetzt – Symbol, Temperatur, Lage, Ort; rechts davon die 3 Tage, wenn Platz ist
        Row {
            id: nowRow
            visible: Weather.ready
            anchors.right: parent.right
            anchors.bottom: weather.hasMorning ? morningTxt.top : dateTxt.top
            anchors.bottomMargin: 6
            spacing: 8

            // feste Schätzung statt implicitWidth: sonst schaltet sich die Vorschau selbst an und aus
            readonly property real daysWidth: 210
            readonly property bool showDays: weather.room >= nowInfo.implicitWidth + daysWidth

            Row {
                id: nowInfo
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8
                Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    name: Weather.icon(Weather.code, Weather.isDay)
                    size: 18
                    color: Theme.warning
                }
                MonoTxt {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Math.round(Weather.temp) + "°"
                    font.pixelSize: 15
                    font.weight: Font.DemiBold
                }
                Txt {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Weather.label(Weather.code)
                    color: Theme.textMuted
                    font.weight: Font.Normal
                }
                Txt {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: Weather.place !== ""
                    text: "· " + Weather.place
                    color: Theme.textFaint
                    font.pixelSize: 12
                    font.weight: Font.Normal
                }
            }

            // 3-Tage-Vorschau, einzeilig: "Mon ☁ 9°"
            Row {
                id: daysRow
                anchors.verticalCenter: parent.verticalCenter
                visible: nowRow.showDays
                leftPadding: 12
                spacing: 12
                Repeater {
                    model: Weather.days
                    Row {
                        required property var modelData
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 4
                        Txt {
                            anchors.verticalCenter: parent.verticalCenter
                            text: modelData.name
                            color: Theme.textFaint
                            font.pixelSize: 12
                            font.weight: Font.Normal
                        }
                        Icon {
                            anchors.verticalCenter: parent.verticalCenter
                            name: Weather.icon(modelData.code, true)
                            size: 14
                            color: Theme.textFaint
                        }
                        MonoTxt {
                            anchors.verticalCenter: parent.verticalCenter
                            text: modelData.max + "°"
                            color: Theme.textMuted
                            font.pixelSize: 12
                        }
                    }
                }
            }
        }
    }
}

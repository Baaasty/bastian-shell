import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services
import qs.components

// Wetter jetzt + 3 Tage + "Morgen früh"-Urteil
Tile {
    title: Weather.place ? "Weather · " + Weather.place : "Weather"

    ColumnLayout {
        anchors.fill: parent
        spacing: 8

        RowLayout {
            spacing: 14
            Icon {
                name: Weather.icon(Weather.code, Weather.isDay)
                size: 36
                color: Theme.warning
            }
            Column {
                MonoTxt {
                    text: Weather.ready ? Math.round(Weather.temp) + "°" : "–"
                    font.pixelSize: 26
                    font.weight: Font.DemiBold
                }
                Txt {
                    text: Weather.ready ? Weather.label(Weather.code) + " · feels like " + Math.round(Weather.feels) + "°" : ""
                    color: Theme.textFaint
                    font.pixelSize: 12
                    font.weight: Font.Normal
                }
            }
            Item {
                Layout.fillWidth: true
            }
            Repeater {
                model: Weather.days
                Column {
                    required property var modelData
                    spacing: 3
                    Txt {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: modelData.name
                        color: Theme.textFaint
                        font.pixelSize: 12
                    }
                    Icon {
                        anchors.horizontalCenter: parent.horizontalCenter
                        name: Weather.icon(modelData.code, true)
                        size: 20
                    }
                    MonoTxt {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: modelData.max + "°"
                        color: Theme.textMuted
                        font.pixelSize: 12
                    }
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 1
            color: Theme.border
        }

        Label {
            text: "Tomorrow morning · 7–9 am"
        }
        RowLayout {
            spacing: 12
            Icon {
                name: Weather.morning && Weather.morning.ok ? "two_wheeler" : "directions_car"
                size: 22
                color: Weather.morning && Weather.morning.ok ? Theme.success : Theme.warning
            }
            Txt {
                text: Weather.morning ? Weather.morning.verdict : "–"
                font.pixelSize: 16
                font.weight: Font.DemiBold
            }
        }
        MonoTxt {
            text: Weather.morning ? Weather.morning.tMin + "–" + Weather.morning.tMax + "° · rain " + Weather.morning.rain + "% · wind " + Weather.morning.wind + " km/h" : ""
            color: Theme.textFaint
            font.pixelSize: 12
        }
        Item {
            Layout.fillHeight: true
        }
    }
}

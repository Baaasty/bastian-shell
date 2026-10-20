import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.config
import qs.services
import qs.components

// Spotify kompakt: Cover, Titel, Fortschritt (Klicken/Ziehen spult), ⏮ ⏯ ⏭
Glass {
    id: tile

    readonly property var player: Players.spotify

    // MPRIS meldet die Position nicht von selbst. Nur bei offenem Dashboard nachfragen: tile.visible bleibt
    // auch bei geschlossenem Fenster true, dann ging jede Sekunde eine D-Bus-Abfrage an Spotify ins Leere
    readonly property bool shown: !!QsWindow.window && QsWindow.window.visible
    Timer {
        interval: 1000
        repeat: true
        running: tile.player !== null && tile.player.isPlaying && tile.visible && tile.shown
        triggeredOnStart: true
        onTriggered: tile.player.positionChanged()
    }

    function fmt(sec: real): string {
        const s = Math.max(0, Math.floor(sec));
        return Math.floor(s / 60) + ":" + String(s % 60).padStart(2, "0");
    }

    // oben rechts: Spotify nach vorn holen / wegräumen
    ParkButton {
        anchors.right: parent.right
        anchors.rightMargin: 16
        anchors.top: parent.top
        anchors.topMargin: 14
        z: 2
        part: "spotify"
    }

    Rectangle {
        id: cover
        x: 20
        y: 20
        width: parent.height - 40
        height: width
        radius: Theme.radiusMd
        color: Theme.wood
        clip: true

        Image {
            anchors.fill: parent
            source: tile.player ? tile.player.trackArtUrl : ""
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            sourceSize.width: 300
        }
        Icon {
            anchors.centerIn: parent
            visible: !tile.player
            name: "music_off"
            size: 40
            color: Theme.textFaint
        }
    }

    ColumnLayout {
        anchors.left: cover.right
        anchors.leftMargin: 20
        anchors.right: parent.right
        anchors.rightMargin: 20
        anchors.top: parent.top
        anchors.topMargin: 20
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 16
        spacing: 4

        Label {
            text: "Spotify"
        }
        Txt {
            Layout.fillWidth: true
            Layout.topMargin: 4
            text: tile.player ? tile.player.trackTitle : "Nothing playing"
            font.pixelSize: 18
            font.weight: Font.DemiBold
            elide: Text.ElideRight
        }
        Txt {
            Layout.fillWidth: true
            text: tile.player ? tile.player.trackArtist : ""
            color: Theme.textMuted
            font.pixelSize: 14
            font.weight: Font.Normal
            elide: Text.ElideRight
        }
        Item {
            Layout.fillHeight: true
        }

        // Fortschritt: Klicken oder Ziehen springt an die Stelle
        Item {
            Layout.fillWidth: true
            implicitHeight: 12
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width
                height: 4
                radius: 2
                color: Theme.borderStrong
                Rectangle {
                    height: parent.height
                    radius: 2
                    color: Theme.text
                    width: tile.player && tile.player.length > 0 ? parent.width * Math.min(1, tile.player.position / tile.player.length) : 0
                }
            }
            MouseArea {
                anchors.fill: parent
                anchors.topMargin: -4
                anchors.bottomMargin: -4
                cursorShape: Qt.PointingHandCursor
                enabled: tile.player !== null && tile.player.canSeek
                function jump(x) {
                    tile.player.position = tile.player.length * Math.max(0, Math.min(1, x / width));
                }
                onPressed: mouse => jump(mouse.x)
                onPositionChanged: mouse => { if (pressed) jump(mouse.x); }
            }
        }

        // Zeit links, Steuerung Mitte, Länge rechts
        Item {
            Layout.fillWidth: true
            implicitHeight: 40
            MonoTxt {
                anchors.left: parent.left
                anchors.top: parent.top
                text: tile.player ? tile.fmt(tile.player.position) : "0:00"
                color: Theme.textFaint
                font.pixelSize: 11
            }
            MonoTxt {
                anchors.right: parent.right
                anchors.top: parent.top
                text: tile.player ? tile.fmt(tile.player.length) : "0:00"
                color: Theme.textFaint
                font.pixelSize: 11
            }
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                spacing: 14
                Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    name: "skip_previous"
                    size: 24
                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -6
                        cursorShape: Qt.PointingHandCursor
                        onClicked: if (tile.player) tile.player.previous()
                    }
                }
                Rectangle {
                    width: 38
                    height: 38
                    radius: 19
                    color: Theme.text
                    Icon {
                        anchors.centerIn: parent
                        name: tile.player && tile.player.isPlaying ? "pause" : "play_arrow"
                        fill: true
                        size: 24
                        color: Theme.bg
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: SpotifyApi.playPause()
                    }
                }
                Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    name: "skip_next"
                    size: 24
                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -6
                        cursorShape: Qt.PointingHandCursor
                        onClicked: if (tile.player) tile.player.next()
                    }
                }
            }
        }
    }
}

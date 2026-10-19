import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services
import qs.components

// Medien auf dem Sperrbildschirm (wie plasma/…/MediaControls.qml): Glaskarte mit Cover, Titel, Künstler,
// Zurück/Play/Weiter. Spieler = Players.active (spielt gerade, sonst Spotify, sonst der erste).
Item {
    id: media

    property real topPadding: 0
    readonly property var player: Players.active
    signal used()   // Klick: Ausblend-Timer neu starten

    visible: !!player
    implicitHeight: 64 + topPadding

    component Glyph: Icon {
        id: glyph
        property alias hovered: area.containsMouse
        signal clicked()
        color: !enabled ? Theme.textFaint : area.containsMouse ? Theme.accentText : Theme.textMuted
        Behavior on color { ColorAnimation { duration: 120 } }
        MouseArea {
            id: area
            anchors.fill: parent
            anchors.margins: -6
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                media.used();
                glyph.clicked();
            }
        }
    }

    Glass {
        anchors.fill: parent
        anchors.topMargin: media.topPadding
        strong: true
        radius: 16
        enabled: !!media.player && media.player.canControl

        RowLayout {
            anchors.fill: parent
            anchors.margins: 8
            anchors.rightMargin: 14
            spacing: 12

            Rectangle {
                Layout.preferredWidth: 48
                Layout.preferredHeight: 48
                radius: 10
                color: Theme.wood
                clip: true
                Image {
                    anchors.fill: parent
                    visible: status === Image.Ready
                    asynchronous: true
                    fillMode: Image.PreserveAspectCrop
                    source: media.player ? media.player.trackArtUrl : ""
                    sourceSize.height: 96
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                Txt {
                    Layout.fillWidth: true
                    text: media.player && media.player.trackTitle ? media.player.trackTitle : "Nothing playing"
                    font.pixelSize: 14
                }
                Txt {
                    Layout.fillWidth: true
                    text: media.player ? (media.player.trackArtist || media.player.identity) : ""
                    color: Theme.textMuted
                    font.pixelSize: 12
                    font.weight: Font.Normal
                }
            }

            Glyph {
                visible: !!media.player && (media.player.canGoPrevious || media.player.canGoNext)
                enabled: !!media.player && media.player.canGoPrevious
                name: "skip_previous"
                size: 22
                onClicked: media.player.previous()
            }
            Glyph {
                name: media.player && media.player.isPlaying ? "pause" : "play_arrow"
                size: 28
                color: hovered ? Theme.accentText : Theme.text
                onClicked: media.player.togglePlaying()
            }
            Glyph {
                visible: !!media.player && (media.player.canGoPrevious || media.player.canGoNext)
                enabled: !!media.player && media.player.canGoNext
                name: "skip_next"
                size: 22
                onClicked: media.player.next()
            }
        }
    }
}

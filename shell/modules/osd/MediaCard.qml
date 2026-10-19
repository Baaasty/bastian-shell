import QtQuick
import qs.config
import qs.components

// Medien-OSD-Inhalt: Cover links, Titel/Künstler in der Mitte, Aktions-Icon rechts, Fortschritt unten.
// Liegt auf der Glas-Fläche des OSD-Fensters (Blur macht das Fenster).
Item {
    id: card

    property var player: null     // Mpris-Spieler oder null
    property string icon: ""      // was gerade gedrückt wurde (play_arrow, pause, skip_next …)
    property int pulse: 0         // zählt hoch, wenn eine Taste gedrückt wurde -> Aktions-Icon hebt sich kurz hervor
    property real corner: 20      // Eckenradius der Kachel (für den Fortschrittsbalken)

    readonly property bool hasPlayer: player !== null
    readonly property string art: hasPlayer && player.trackArtUrl ? player.trackArtUrl : ""
    readonly property string title: !hasPlayer ? "Nothing playing" : (player.trackTitle || player.identity || "Unknown track")
    readonly property string artist: !hasPlayer ? "Start a player to see it here" : (player.trackArtist || "")
    readonly property real progress: hasPlayer && player.length > 0 ? Math.max(0, Math.min(1, player.position / player.length)) : -1

    // MPRIS meldet die Position nicht von selbst: nur solange das OSD sichtbar ist nachfragen
    Timer {
        interval: 500
        repeat: true
        running: card.visible && card.hasPlayer && card.player.isPlaying
        triggeredOnStart: true
        onTriggered: card.player.positionChanged()
    }

    onPulseChanged: pop.restart()

    // Cover
    Rectangle {
        id: cover
        anchors.left: parent.left
        anchors.leftMargin: 14
        anchors.top: parent.top
        anchors.topMargin: 14
        width: 64
        height: 64
        radius: Theme.radiusMd
        clip: true
        gradient: Gradient {
            GradientStop { position: 0; color: Theme.woodLight }
            GradientStop { position: 1; color: Theme.wood }
        }

        Icon {
            anchors.centerIn: parent
            visible: art.status !== Image.Ready
            name: card.hasPlayer ? "music_note" : "music_off"
            size: 30
            color: Theme.text
            opacity: 0.55
        }
        Image {
            id: art
            anchors.fill: parent
            source: card.art
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            sourceSize.width: 192
            opacity: status === Image.Ready ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: Theme.fade; easing.type: Easing.OutCubic } }
        }
        // feiner Rand ums Cover
        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: "transparent"
            border.width: 1
            border.color: Theme.border
        }
    }

    // Aktions-Icon
    Rectangle {
        id: action
        anchors.right: parent.right
        anchors.rightMargin: 18
        anchors.verticalCenter: cover.verticalCenter
        width: 44
        height: 44
        radius: width / 2
        color: Qt.alpha(Theme.accent, 0.12 + 0.2 * glow)
        border.width: 1
        border.color: Qt.alpha(Theme.accent, 0.25 + 0.45 * glow)
        visible: card.icon !== ""

        property real glow: 0
        // die letzte Taste hebt sich kurz hervor: Icon federt, Farbe läuft von Akzent zurück
        SequentialAnimation {
            id: pop
            ParallelAnimation {
                NumberAnimation { target: action; property: "scale"; from: 0.8; to: 1.12; duration: 140; easing.type: Easing.OutCubic }
                NumberAnimation { target: action; property: "glow"; to: 1; duration: 140; easing.type: Easing.OutCubic }
            }
            ParallelAnimation {
                NumberAnimation { target: action; property: "scale"; to: 1; duration: 260; easing.type: Easing.OutCubic }
                NumberAnimation { target: action; property: "glow"; to: 0; duration: 700; easing.type: Easing.OutCubic }
            }
        }

        Icon {
            anchors.centerIn: parent
            name: card.icon
            fill: true
            size: 24
            color: Qt.tint(Theme.text, Qt.alpha(Theme.accentText, action.glow))
        }
    }

    // Titel + Künstler
    Item {
        anchors.left: cover.right
        anchors.leftMargin: 16
        anchors.right: action.visible ? action.left : parent.right
        anchors.rightMargin: action.visible ? 14 : 20
        anchors.verticalCenter: cover.verticalCenter
        height: titleText.height + (artistText.visible ? artistText.height + 3 : 0)

        Txt {
            id: titleText
            anchors.left: parent.left
            anchors.right: parent.right
            text: card.title
            font.pixelSize: 17
            font.weight: Font.Bold
            color: card.hasPlayer ? Theme.text : Theme.textMuted
        }
        Txt {
            id: artistText
            visible: text !== ""
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: titleText.bottom
            anchors.topMargin: 3
            text: card.artist
            font.pixelSize: 13
            font.weight: Font.Normal
            color: Theme.textMuted
        }
    }

    // Fortschritt: dünner Balken am unteren Rand, innerhalb der Rundung
    Rectangle {
        visible: card.progress >= 0
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.leftMargin: card.corner
        anchors.rightMargin: card.corner
        anchors.bottomMargin: 7
        height: 3
        radius: 1.5
        color: Theme.borderStrong

        Rectangle {
            height: parent.height
            radius: parent.radius
            width: parent.width * Math.max(0, card.progress)
            color: Theme.accentText
            Behavior on width { NumberAnimation { duration: 450; easing.type: Easing.OutCubic } }
        }
    }
}

import QtQuick
import Quickshell.Widgets
import qs.config
import qs.services
import qs.components
import qs.modules.bar

// Eine Kamera-Kachel: deckend, runde Ecken, Name + Mic/Taub unten links (an/aus nur für alle: Schalter im Discord-Popout).
// Doppelklick holt das Chat-Fenster (Discord). Bildquelle: Datei aus scripts/cam-relay; neues Bild = anderes ?n.
// Zwei Bildpuffer: das neue Bild lädt unsichtbar hinten, erst wenn es fertig ist, kommt es nach vorn (kein Flackern). Zustände: Bild · „Waiting for video…“ (Bild fehlt/stockt) ·
// „Open the call view in <Chat>“ (Discord zeigt die Kachel gerade nicht, nur dann gibt es Bilder).
ClippingRectangle {
    id: tile

    required property string camKey
    readonly property string userId: Cams.userOf(camKey)
    readonly property bool isStream: camKey.indexOf(":stream") > 0
    readonly property var member: Discord.memberMap[userId] || ({})
    property string path: ""
    property int n: 0
    property real lastAt: 0
    property bool stale: false
    property int front: 0                 // 0 = imgA vorn, 1 = imgB vorn
    property bool gotFrame: false         // schon einmal ein Bild gezeigt (dann nie mehr „Waiting…“ beim Laden)
    readonly property bool hasImage: gotFrame
    readonly property bool live: hasImage && !stale
    readonly property bool compact: width < 260

    color: Theme.surfaceSunken
    radius: Theme.radiusLg
    border.width: member.speaking === true ? 2 : 1
    border.color: member.speaking === true ? Theme.success : Theme.border
    Behavior on border.color { ColorAnimation { duration: Theme.fade } }

    Connections {
        target: Cams
        function onFrame(key, p, count) {
            if (key !== tile.camKey)
                return;
            tile.path = p;
            tile.n = count;
            // hinteren Puffer laden; lädt er noch das vorige Bild, wird es einfach übersprungen
            const back = tile.front === 0 ? imgB : imgA;
            back.source = "file://" + p + "?" + count;
            tile.lastAt = Date.now();
            tile.stale = false;
        }
    }
    // keine neuen Bilder seit 3 s (Equibop zeigt die Kachel nicht mehr, Kamera aus, Fenster verdeckt)
    Timer {
        interval: 1000
        repeat: true
        running: tile.path !== ""
        onTriggered: tile.stale = Date.now() - tile.lastAt > 3000
    }

    Image {
        id: imgA
        anchors.fill: parent
        visible: tile.front === 0 && tile.gotFrame
        fillMode: Image.PreserveAspectFit
        asynchronous: true
        cache: false
        smooth: true
        onStatusChanged: if (status === Image.Ready && tile.front !== 0) { tile.front = 0; tile.gotFrame = true; }
    }
    Image {
        id: imgB
        anchors.fill: parent
        visible: tile.front === 1 && tile.gotFrame
        fillMode: Image.PreserveAspectFit
        asynchronous: true
        cache: false
        smooth: true
        onStatusChanged: if (status === Image.Ready && tile.front !== 1) { tile.front = 1; tile.gotFrame = true; }
    }

    // Stockt das Bild: abdunkeln
    Rectangle {
        anchors.fill: parent
        color: Qt.alpha(Theme.bg, 0.6)
        opacity: tile.hasImage && tile.stale ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.fade } }
    }

    // noch kein Bild (stockt es später, bleibt das letzte Bild abgedunkelt stehen – kein Flackern mit „Waiting…“)
    Column {
        anchors.centerIn: parent
        spacing: 8
        visible: !tile.hasImage

        DiscordAvatar {
            anchors.horizontalCenter: parent.horizontalCenter
            member: tile.member
            size: tile.compact ? 34 : 44
        }
        Txt {
            anchors.horizontalCenter: parent.horizontalCenter
            width: Math.min(implicitWidth, tile.width - 24)
            horizontalAlignment: Text.AlignHCenter
            text: Cams.tiles[tile.camKey] ? "Waiting for video…" : "Open the call view in " + Chat.title
            color: Theme.textMuted
            font.pixelSize: 12
            font.weight: Font.Normal
        }
    }

    // Doppelklick: Chat-Fenster holen (nicht, wenn es schon draußen ist)
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton
        onDoubleClicked: if (Parked.out.discord !== true) Parked.toggle("discord")
    }

    // Name + Mic/Taub unten links
    Rectangle {
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.margins: 8
        width: Math.min(info.width + 20, parent.width - 16)
        height: 24
        radius: height / 2
        color: Qt.alpha(Theme.bg, 0.86)

        Row {
            id: info
            anchors.centerIn: parent
            spacing: 5
            Icon {
                anchors.verticalCenter: parent.verticalCenter
                visible: tile.isStream
                name: "screen_share"
                size: 14
                color: Theme.textMuted
            }
            Txt {
                id: label
                anchors.verticalCenter: parent.verticalCenter
                width: Math.min(implicitWidth, tile.width - 16 - 20 - (tile.isStream ? 19 : 0) - (tile.member.deaf === true || tile.member.mute === true ? 19 : 0))
                text: tile.member.name || "…"
                font.pixelSize: 12
            }
            Icon {
                anchors.verticalCenter: parent.verticalCenter
                visible: tile.member.deaf === true || tile.member.mute === true
                name: tile.member.deaf === true ? "headset_off" : "mic_off"
                size: 14
                color: Theme.accentText
            }
        }
    }


}

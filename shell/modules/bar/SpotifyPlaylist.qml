import QtQuick
import qs.config
import qs.services
import qs.components

// Songliste einer Playlist (SpotifyApi.browse): Kopf mit Cover + Abspielen/Zufall,
// Liste lädt beim Scrollen nach. Klick auf einen Song spielt ihn im Kontext der Playlist.
Item {
    id: root

    signal back()
    signal played()

    readonly property var pl: SpotifyApi.browse
    readonly property bool restricted: !!pl.restricted

    function fmt(ms) {
        const s = Math.max(0, Math.floor((ms || 0) / 1000));
        return Math.floor(s / 60) + ":" + String(s % 60).padStart(2, "0");
    }

    // Kopf: Zurück + Brotkrumen
    Chip {
        id: backBtn
        x: 0
        y: 0
        padding: 6
        onClicked: root.back()
        Icon {
            anchors.verticalCenter: parent.verticalCenter
            name: "arrow_back"
            size: 18
            color: parent.parent.hovered ? Theme.text : Theme.textMuted
        }
    }
    Label {
        anchors.left: backBtn.right
        anchors.leftMargin: 8
        anchors.verticalCenter: backBtn.verticalCenter
        text: "Library"
    }

    Rectangle {
        id: cover
        x: 8
        y: 42
        width: 88
        height: 88
        radius: Theme.radiusMd
        color: Theme.wood
        clip: true
        Icon {
            anchors.centerIn: parent
            visible: (root.pl.image || "") === ""
            name: root.pl.liked ? "favorite" : "queue_music"
            fill: true
            size: 32
            color: Theme.textMuted
        }
        Image {
            anchors.fill: parent
            visible: (root.pl.image || "") !== ""
            source: root.pl.image || ""
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            sourceSize.width: 176
        }
    }

    Column {
        anchors.left: cover.right
        anchors.leftMargin: 14
        anchors.right: parent.right
        anchors.rightMargin: 8
        y: cover.y + 2
        spacing: 3
        Txt {
            width: parent.width
            text: root.pl.name || ""
            font.pixelSize: 16
            font.weight: Font.DemiBold
        }
        Txt {
            width: parent.width
            text: [root.pl.owner ? "by " + root.pl.owner : "", typeof root.pl.total === "number" ? root.pl.total + " songs" : ""].filter(x => x).join(" · ")
            visible: text !== ""
            color: Theme.textMuted
            font.pixelSize: 12
            font.weight: Font.Normal
        }
        Item {
            width: 1
            height: 6
        }
        Row {
            spacing: 8
            Button {
                text: "Play"
                icon: "play_arrow"
                primary: true
                onClicked: {
                    SpotifyApi.playContext(root.pl.uri, "from-start");
                    root.played();
                }
            }
            Button {
                visible: !root.restricted
                text: "Shuffle"
                icon: "shuffle"
                onClicked: {
                    SpotifyApi.playContext(root.pl.uri, "shuffle");
                    root.played();
                }
            }
        }
    }

    Rectangle {
        id: sep
        x: 8
        y: cover.y + cover.height + 12
        width: parent.width - 16
        height: 1
        color: Theme.border
    }

    readonly property string hint: !SpotifyApi.configured ? SpotifyApi.message("unconfigured")
        : root.restricted ? "Spotify only lists songs for your own playlists – playing still works"
        : SpotifyApi.browseError !== "" && SpotifyApi.browseTracks.length === 0 ? SpotifyApi.message(SpotifyApi.browseError)
        : SpotifyApi.browseLoading && SpotifyApi.browseTracks.length === 0 ? "Loading…"
        : SpotifyApi.browseTracks.length === 0 ? "No songs"
        : ""

    // eigenes Rad-Scrollen (Qt ist auf Wayland sehr zäh)
    WheelScroll {
        flick: list
    }

    ListView {
        id: list
        interactive: false
        anchors.top: sep.bottom
        anchors.topMargin: 6
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: notice.visible ? notice.top : parent.bottom
        anchors.bottomMargin: notice.visible ? 6 : 0
        visible: root.hint === ""
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        model: SpotifyApi.browseTracks

        // kurz vor dem Ende die nächste Seite holen
        function nearEnd() {
            if (contentHeight - contentY - height < 400)
                SpotifyApi.loadMore();
        }
        onContentYChanged: nearEnd()
        onCountChanged: nearEnd()
        onHeightChanged: nearEnd()

        delegate: SpotifyQueue.TrackRow {
            required property var modelData
            title: modelData.name || ""
            subtitle: modelData.artists || ""
            image: modelData.image || ""
            current: modelData.uri === SpotifyApi.playingUri
            trailing: root.fmt(modelData.duration_ms)
            onClicked: SpotifyApi.playTrack(modelData.uri, root.pl.uri)
        }

        footer: Item {
            width: list.width
            height: SpotifyApi.browseLoading ? 36 : 8
            Txt {
                anchors.centerIn: parent
                visible: SpotifyApi.browseLoading
                text: "Loading…"
                color: Theme.textFaint
                font.pixelSize: 12
                font.weight: Font.Normal
            }
        }
    }

    Txt {
        anchors.top: sep.bottom
        anchors.topMargin: 24
        anchors.horizontalCenter: parent.horizontalCenter
        width: parent.width - 32
        visible: root.hint !== ""
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.WordWrap
        text: root.hint
        color: Theme.textMuted
        font.weight: Font.Normal
    }

    Txt {
        id: notice
        anchors.bottom: parent.bottom
        x: 8
        width: parent.width - 16
        visible: SpotifyApi.notice !== ""
        text: SpotifyApi.notice
        color: Theme.warning
        font.pixelSize: 12
        font.weight: Font.Normal
    }
}

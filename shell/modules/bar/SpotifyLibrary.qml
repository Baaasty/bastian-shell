import QtQuick
import qs.config
import qs.services
import qs.components

// Bibliothek: Playlists des Nutzers (+ Lieblingssongs). Klick öffnet die Songliste (opened).
Item {
    id: root

    signal opened(var playlist)

    readonly property string hint: !SpotifyApi.configured ? SpotifyApi.message("unconfigured")
        : SpotifyApi.playlists.length > 0 ? ""
        : SpotifyApi.status === "error" && !SpotifyApi.playlistsLoading ? SpotifyApi.message(SpotifyApi.error)
        : SpotifyApi.playlistsLoading || SpotifyApi.playlistsAt === 0 ? "Loading…"
        : "No playlists"

    // eigenes Rad-Scrollen (Qt ist auf Wayland sehr zäh)
    WheelScroll {
        flick: list
    }

    ListView {
        id: list
        interactive: false
        anchors.fill: parent
        anchors.bottomMargin: notice.visible ? notice.height + 6 : 0
        visible: root.hint === ""
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        model: SpotifyApi.playlists

        delegate: SpotifyQueue.TrackRow {
            required property var modelData
            title: modelData.name || ""
            subtitle: modelData.liked ? "Saved songs"
                : modelData.own ? (modelData.total != null ? modelData.total + " songs" : "")
                : "by " + (modelData.owner || "?")
            image: modelData.image || ""
            fallbackIcon: modelData.liked ? "favorite" : "queue_music"
            current: modelData.uri === SpotifyApi.contextUri
            trailingIcon: "chevron_right"
            onClicked: root.opened(modelData)
        }
    }

    Txt {
        anchors.centerIn: parent
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

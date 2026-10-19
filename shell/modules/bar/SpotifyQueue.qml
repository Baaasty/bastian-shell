import QtQuick
import qs.config
import qs.services
import qs.components

// "Als Nächstes": Warteschlange + Songs des laufenden Kontexts (Playlist/Album). Klick spielt den Song.
Item {
    id: root

    property int queueLimit: 8     // Spotify liefert bis zu 20, oft schon die nächsten Playlist-Songs

    readonly property string contextLabel: SpotifyApi.contextName || ({
            album: "Album",
            playlist: "Playlist",
            collection: "Liked Songs",
            artist: "Artist"
        })[SpotifyApi.contextType] || ""

    // Zeilen: { kind: head|track|note, … }
    readonly property var rows: {
        const r = [];
        const q = SpotifyApi.queue.slice(0, queueLimit);
        if (q.length > 0) {
            r.push({ kind: "head", text: "Queue" });
            for (const t of q)
                r.push(Object.assign({ kind: "track", ctx: "" }, t));
        }
        if (contextLabel !== "") {
            r.push({ kind: "head", text: contextLabel });
            if (SpotifyApi.contextRestricted && SpotifyApi.contextTracks.length === 0)
                r.push({ kind: "note", text: "Spotify only lists songs for your own playlists" });
            for (const t of SpotifyApi.contextTracks)
                r.push(Object.assign({ kind: "track", ctx: SpotifyApi.contextUri }, t));
        }
        return r;
    }

    readonly property string hint: !SpotifyApi.configured ? SpotifyApi.message("unconfigured")
        : SpotifyApi.status === "error" && rows.length === 0 ? SpotifyApi.message(SpotifyApi.error)
        : SpotifyApi.status === "loading" && rows.length === 0 ? "Loading…"
        : SpotifyApi.status === "ok" && rows.length === 0 ? "Nothing up next"
        : ""

    // Song-Zeile: Cover 36 px, Titel, Artist; aktueller Song in Glut-Ton (auch von SpotifyLibrary genutzt)
    component TrackRow: Rectangle {
        id: row

        property string title
        property string subtitle
        property string image
        property string fallbackIcon: "music_note"
        property bool current: false
        property string trailing: ""
        property string trailingIcon: ""   // statt Text, z. B. chevron_right
        signal clicked()

        width: ListView.view ? ListView.view.width : implicitWidth
        height: 48
        radius: Theme.radiusSm
        color: area.containsMouse ? Theme.raise : "transparent"
        Behavior on color { ColorAnimation { duration: Theme.fade } }

        Rectangle {
            id: art
            x: 8
            anchors.verticalCenter: parent.verticalCenter
            width: 36
            height: 36
            radius: 6
            color: Theme.wood
            clip: true
            Icon {
                anchors.centerIn: parent
                visible: row.image === ""
                name: row.fallbackIcon
                fill: true
                size: 18
                color: row.current ? Theme.accentText : Theme.textMuted
            }
            Image {
                anchors.fill: parent
                visible: row.image !== ""
                source: row.image
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                sourceSize.width: 72
            }
        }

        Column {
            anchors.left: art.right
            anchors.leftMargin: 12
            anchors.right: tail.left
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2
            Txt {
                width: parent.width
                text: row.title
                color: row.current ? Theme.accentText : Theme.text
            }
            Txt {
                width: parent.width
                visible: text !== ""
                text: row.subtitle
                color: Theme.textMuted
                font.pixelSize: 12
                font.weight: Font.Normal
            }
        }

        Item {
            id: tail
            anchors.right: parent.right
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            width: row.current || row.trailingIcon !== "" ? 18 : trailText.implicitWidth
            height: 18
            Icon {
                anchors.centerIn: parent
                visible: row.current || row.trailingIcon !== ""
                name: row.current ? "graphic_eq" : row.trailingIcon
                size: 18
                color: row.current ? Theme.accentText : Theme.textFaint
            }
            MonoTxt {
                id: trailText
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                visible: !row.current && row.trailingIcon === ""
                text: row.trailing
                color: Theme.textFaint
                font.pixelSize: 12
            }
        }

        MouseArea {
            id: area
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: row.clicked()
        }
    }

    function fmt(ms) {
        const s = Math.max(0, Math.floor((ms || 0) / 1000));
        return Math.floor(s / 60) + ":" + String(s % 60).padStart(2, "0");
    }

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
        spacing: 0
        boundsBehavior: Flickable.StopAtBounds
        model: root.rows

        delegate: Item {
            id: cell
            required property var modelData
            width: list.width
            height: modelData.kind === "head" ? 30 : modelData.kind === "note" ? 26 : 48

            Label {
                visible: cell.modelData.kind === "head"
                x: 8
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 6
                width: parent.width - 16
                text: cell.modelData.text || ""
            }
            Txt {
                visible: cell.modelData.kind === "note"
                x: 8
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 16
                text: cell.modelData.text || ""
                color: Theme.textFaint
                font.pixelSize: 12
                font.weight: Font.Normal
            }
            TrackRow {
                width: cell.width
                visible: cell.modelData.kind === "track"
                title: cell.modelData.name || ""
                subtitle: cell.modelData.artists || ""
                image: cell.modelData.image || ""
                current: cell.modelData.kind === "track" && cell.modelData.uri === SpotifyApi.playingUri
                trailing: root.fmt(cell.modelData.duration_ms)
                // Warteschlangen-Song: im Kontext spielen, wenn er dazugehört (sonst geht der Kontext verloren)
                onClicked: {
                    const d = cell.modelData;
                    const inCtx = d.ctx !== "" || SpotifyApi.contextTracks.some(t => t.uri === d.uri);
                    SpotifyApi.playTrack(d.uri, inCtx ? SpotifyApi.contextUri : "");
                }
            }
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

import QtQuick
import Quickshell
import Quickshell.Services.Mpris
import Quickshell.Wayland
import qs.config
import qs.services
import qs.components
import org.kde.kirigami as Kirigami

// Spotify-Mini: ⏮ Titel · Artist ⏯ ⏭  –  Klick auf den Titel öffnet das Popout
Row {
    id: root

    property var barWindow
    // Platz, den die Bar dem Chip lässt (BarWindow: bis zur Uhr); wird es eng, fällt erst der Interpret weg,
    // dann wird der Titel gekürzt – sonst schiebt sich der Chip in Uhr und Datum
    property real maxWidth: 100000
    readonly property real textMax: maxWidth - (prevBtn.visible ? prevBtn.width : 0) - playBtn.width
        - (nextBtn.visible ? nextBtn.width : 0) - 2 * title.padding - 22 - (player !== null ? 20 : 10)
    readonly property var player: Players.spotify
    // Spotify läuft, aber nichts geladen: zuletzt gehörten Song gedimmt zeigen, Play spielt ihn per Web API weiter
    readonly property bool idle: SpotifyApi.idle
    readonly property var last: SpotifyApi.lastPlayed
    readonly property string idleHint: SpotifyApi.resuming ? "Resuming…" : SpotifyApi.resumeError || "Play to resume"

    // Spotify läuft nicht: Play startet es im Hintergrund und spielt los, sobald es da ist
    property bool starting: false
    function startAndPlay(): void {
        if (starting)
            return;
        starting = true;
        startWatch.ticks = 0;
        Launch.run("spotify");
        startWatch.start();
    }
    Timer {
        id: startWatch
        property int ticks: 0
        property bool parked: false
        interval: 500
        repeat: true
        onTriggered: {
            ticks++;
            // Fenster wegräumen, sobald es auftaucht (Spotify ist eine Hintergrund-App)
            if (!parked && Parked.out.spotify === true) {
                Parked.toggle("spotify");
                parked = true;
            }
            if (root.player && root.player.canPlay && (parked || ticks > 10)) {
                if (!root.player.isPlaying)
                    root.player.play();
                stop();
            } else if (root.player && ticks > 12) {
                // frisch gestartet lädt Spotify nichts (CanPlay bleibt false) -> über die Web API weiterspielen
                SpotifyApi.resume();
                stop();
            } else if (ticks > 40) {
                stop(); // nach 20 s aufgeben
            }
        }
        onRunningChanged: if (!running) {
            root.starting = false;
            parked = false;
        }
    }

    spacing: 0

    // Popouts sitzen wie die Benachrichtigungen mit Lücke unter der Bar (nicht am Chip)
    function placeUnderBar(popup, item) {
        const p = item.mapToItem(null, 0, 0);
        popup.anchor.rect.x = p.x;
        popup.anchor.rect.y = Theme.barMargin + Theme.barHeight + Theme.windowGap - 1;
        popup.anchor.rect.width = item.width;
        popup.anchor.rect.height = 1;
    }

    component Btn: Chip {
        property string glyph
        property bool filled: false
        padding: 6
        Icon {
            anchors.verticalCenter: parent.verticalCenter
            name: glyph
            fill: filled
            size: 18
            color: parent.parent.hovered ? Theme.text : Theme.textMuted
        }
    }

    Btn {
        id: prevBtn
        glyph: "skip_previous"
        visible: root.player !== null
        onClicked: if (root.player) root.player.previous()
    }

    Chip {
        id: title
        hintKey: BarKeys.keyFor("spotify")   // Bar-Modus (Super+Leertaste)
        active: popout.visible
        onClicked: {
            if (!root.player)
                return root.startAndPlay();
            if (popout.visible)
                return popout.close();
            root.placeUnderBar(popout, title);
            popout.visible = true;
        }

        // kleines Cover statt Noten-Symbol
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: 22
            height: 22
            radius: 5
            color: Theme.wood
            clip: true
            Image {
                anchors.fill: parent
                visible: root.player !== null
                source: root.idle ? (root.last ? root.last.image : "") : root.player ? root.player.trackArtUrl : ""
                opacity: root.idle ? 0.45 : 1
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                sourceSize.width: 44
            }
            // Spotify läuft nicht: Symbol statt Cover
            Kirigami.Icon {
                anchors.centerIn: parent
                width: 16
                height: 16
                visible: root.player === null
                // natives RPM (negativo17) bringt das Symbol „spotify“ mit; „spotify-client“ hieß es beim lpf-Paket
                source: "spotify"
                fallback: "spotify-client"
            }
        }
        Txt {
            anchors.verticalCenter: parent.verticalCenter
            width: Math.max(0, Math.min(implicitWidth, 260, root.textMax - (artistTxt.visible ? artistTxt.width : 0)))
            text: root.idle ? (root.last ? root.last.name : "Spotify")
                : root.player ? root.player.trackTitle : root.starting ? "Starting Spotify…" : "Spotify"
            color: root.player && !root.idle ? Theme.text : Theme.textMuted
        }
        Txt {
            id: artistTxt
            anchors.verticalCenter: parent.verticalCenter
            visible: root.player !== null && root.textMax >= 200
            width: Math.min(implicitWidth, 160, root.textMax * 0.4)
            text: root.idle ? root.idleHint : root.player ? root.player.trackArtist : ""
            color: root.idle ? (SpotifyApi.resumeError ? Theme.warning : Theme.textFaint) : Theme.textMuted
            font.weight: Font.Normal
        }
    }

    Btn {
        id: playBtn
        glyph: root.player && root.player.isPlaying ? "pause" : "play_arrow"
        filled: true
        onClicked: root.player ? SpotifyApi.playPause() : root.startAndPlay()
    }
    Btn {
        id: nextBtn
        glyph: "skip_next"
        visible: root.player !== null
        onClicked: if (root.player) root.player.next()
    }

    // ---------- Popout ----------
    PopupWindow {
        id: popout

        anchor.window: root.barWindow
        anchor.edges: Edges.Bottom
        anchor.gravity: Edges.Bottom
        grabFocus: true
        implicitWidth: 420
        implicitHeight: 560
        color: "transparent"
        onVisibleChanged: {
            if (root.barWindow)
                root.barWindow.openMenus += visible ? 1 : -1;
            if (visible)
                Popouts.claim("spotify");
            else
                Popouts.release("spotify");
            if (!visible)
                stack = [];
            else
                keys.forceActiveFocus();
        }

        // gewollt schließen (Esc, Chip-Klick); sonst holt PopoutGuard es zurück, wenn die Maus noch drin ist
        function close(): void {
            guard.intended = true;
            visible = false;
        }

        // nur ein Bar-Popout gleichzeitig
        Connections {
            target: Popouts
            function onCurrentChanged() {
                if (Popouts.current !== "spotify" && popout.visible)
                    popout.visible = false;
            }
        }

        // Navigation als kleiner Stack: Gerade läuft → Bibliothek → Playlist; Esc/Zurück = eine Ebene hoch
        property var stack: []
        readonly property string view: stack.length > 0 ? stack[stack.length - 1] : "now"
        function push(v) {
            stack = stack.concat([v]);
        }
        function pop() {
            stack = stack.slice(0, -1);
        }

        BackgroundEffect.blurRegion: Region {
            Region { x: 0; y: 0; width: 1; height: 1 }
            Region { item: card; radius: Theme.radiusLg }
        }

        Timer {
            interval: 1000
            repeat: true
            running: popout.visible && root.player !== null && root.player.isPlaying
            triggeredOnStart: true
            onTriggered: root.player.positionChanged()
        }

        function fmt(sec) {
            const s = Math.max(0, Math.floor(sec));
            return Math.floor(s / 60) + ":" + String(s % 60).padStart(2, "0");
        }

        Glass {
            id: card
            anchors.fill: parent
            strong: true

            // offen bis zum Weghovern; schließt der Compositor es von außen (Discord, Fenster geht auf), während die Maus drin ist -> sofort wieder da
            PopoutGuard { id: guard; popout: popout; chip: title; name: "spotify" }
            // Tastatur: Pfeile/Tab/Enter, Bar-Modus „M“ (KeyNav.qml)
            Keys.onPressed: e => nav.key(e)
            KeyNav {
                id: nav
                root: card
                scope: keys
                popout: popout
                guard: guard
                name: "spotify"
                openFn: () => {
                    if (!root.player)
                        return root.startAndPlay();
                    root.placeUnderBar(popout, title);
                    popout.visible = true;
                }
            }

            // offene Ansicht -> SpotifyApi lädt dafür nach (die Liste selbst ist schon vorgeladen, siehe SpotifyApi)
            Binding {
                target: SpotifyApi
                property: "active"
                value: popout.visible && popout.view === "now"
            }
            Binding {
                target: SpotifyApi
                property: "libraryOpen"
                value: popout.visible && popout.view === "library"
            }

            Item {
                id: keys
                focus: true
                Keys.onEscapePressed: {
                    if (popout.stack.length > 0)
                        popout.pop();
                    else
                        popout.close();
                }
            }

            // ---------- Gerade läuft ----------
            Item {
                id: nowView
                anchors.fill: parent
                visible: popout.view === "now"

                Rectangle {
                    id: cover
                    x: 16
                    y: 16
                    width: 104
                    height: 104
                    radius: Theme.radiusMd
                    color: Theme.wood
                    clip: true
                    Image {
                        anchors.fill: parent
                        source: root.idle ? (root.last ? root.last.image : "") : root.player ? root.player.trackArtUrl : ""
                        opacity: root.idle ? 0.45 : 1
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        sourceSize.width: 208
                    }
                }

                // Spotify-Fenster kurz rausholen / wieder wegräumen
                Chip {
                    anchors.top: parent.top
                    anchors.right: parent.right
                    anchors.margins: 8
                    padding: 6
                    active: Parked.out.spotify === true
                    onClicked: Parked.toggle("spotify")
                    Icon {
                        anchors.verticalCenter: parent.verticalCenter
                        name: Parked.out.spotify === true ? "close_fullscreen" : "open_in_new"
                        size: 16
                    }
                }

                Column {
                    anchors.left: cover.right
                    anchors.leftMargin: 16
                    anchors.right: parent.right
                    anchors.rightMargin: 44
                    y: 20
                    spacing: 4
                    Txt {
                        width: parent.width
                        text: root.idle ? (root.last ? root.last.name : "Nothing loaded") : root.player ? root.player.trackTitle : ""
                        color: root.idle ? Theme.textMuted : Theme.text
                        font.pixelSize: 16
                        font.weight: Font.DemiBold
                    }
                    Txt {
                        width: parent.width
                        text: root.idle ? (root.last ? root.last.artists : "") : root.player ? root.player.trackArtist : ""
                        color: Theme.textMuted
                        font.weight: Font.Normal
                    }
                    Txt {
                        width: parent.width
                        text: root.idle ? root.idleHint : root.player ? root.player.trackAlbum : ""
                        color: root.idle && SpotifyApi.resumeError ? Theme.warning : Theme.textFaint
                        font.pixelSize: 12
                        font.weight: Font.Normal
                    }
                }

                // Fortschritt: Klicken oder Ziehen springt an die Stelle
                Item {
                    id: seek
                    x: 16
                    y: 136
                    width: parent.width - 32
                    height: 14
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
                            width: root.player && root.player.length > 0 ? parent.width * Math.min(1, root.player.position / root.player.length) : 0
                        }
                    }
                    MouseArea {
                        anchors.fill: parent
                        anchors.topMargin: -4
                        anchors.bottomMargin: -4
                        cursorShape: Qt.PointingHandCursor
                        enabled: root.player !== null && root.player.canSeek
                        function jump(x) {
                            root.player.position = root.player.length * Math.max(0, Math.min(1, x / width));
                        }
                        onPressed: mouse => jump(mouse.x)
                        onPositionChanged: mouse => { if (pressed) jump(mouse.x); }
                    }
                }
                MonoTxt {
                    x: 16
                    y: 156
                    visible: !root.idle   // nichts geladen: kein „0:00 / 0:00“
                    text: root.player ? popout.fmt(root.player.position) : ""
                    color: Theme.textFaint
                    font.pixelSize: 12
                }
                MonoTxt {
                    anchors.right: parent.right
                    anchors.rightMargin: 16
                    y: 156
                    visible: !root.idle
                    text: root.player ? popout.fmt(root.player.length) : ""
                    color: Theme.textFaint
                    font.pixelSize: 12
                }
                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: 150
                    spacing: 4
                    Btn {
                        glyph: "shuffle"
                        onClicked: {
                            if (!root.player || !root.player.shuffleSupported)
                                return;
                            root.player.shuffle = !root.player.shuffle;
                            SpotifyApi.refreshSoon();   // Warteschlange neu holen
                        }
                        active: root.player !== null && root.player.shuffle
                    }
                    Btn {
                        glyph: "skip_previous"
                        onClicked: if (root.player) root.player.previous()
                    }
                    Btn {
                        glyph: root.player && root.player.isPlaying ? "pause" : "play_arrow"
                        filled: true
                        onClicked: SpotifyApi.playPause()
                    }
                    Btn {
                        glyph: "skip_next"
                        onClicked: if (root.player) root.player.next()
                    }
                    Btn {
                        glyph: root.player && root.player.loopState === MprisLoopState.Track ? "repeat_one" : "repeat"
                        active: root.player !== null && root.player.loopState !== MprisLoopState.None
                        onClicked: {
                            if (!root.player || !root.player.loopSupported)
                                return;
                            const s = root.player.loopState;
                            root.player.loopState = s === MprisLoopState.None ? MprisLoopState.Playlist : s === MprisLoopState.Playlist ? MprisLoopState.Track : MprisLoopState.None;
                        }
                    }
                }

                // ---------- Als Nächstes ----------
                Rectangle {
                    x: 16
                    y: 186
                    width: parent.width - 32
                    height: 1
                    color: Theme.border
                }
                Label {
                    x: 16
                    anchors.verticalCenter: libBtn.verticalCenter
                    text: "Up Next"
                }
                Chip {
                    id: libBtn
                    anchors.right: parent.right
                    anchors.rightMargin: 8
                    y: 196
                    padding: 8
                    onClicked: popout.push("library")
                    Icon {
                        anchors.verticalCenter: parent.verticalCenter
                        name: "library_music"
                        size: 16
                        color: parent.parent.hovered ? Theme.text : Theme.textMuted
                    }
                    Txt {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Library"
                        color: parent.parent.hovered ? Theme.text : Theme.textMuted
                        font.pixelSize: 12
                    }
                }
                SpotifyQueue {
                    x: 8
                    y: 232
                    width: parent.width - 16
                    height: parent.height - y - 8
                }
            }

            // ---------- Bibliothek ----------
            Item {
                anchors.fill: parent
                visible: popout.view === "library"

                Chip {
                    id: backBtn
                    x: 8
                    y: 8
                    padding: 6
                    onClicked: popout.pop()
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
                Chip {
                    anchors.right: parent.right
                    anchors.rightMargin: 8
                    anchors.verticalCenter: backBtn.verticalCenter
                    padding: 6
                    onClicked: SpotifyApi.loadPlaylists(true)
                    Icon {
                        anchors.verticalCenter: parent.verticalCenter
                        name: "refresh"
                        size: 16
                        color: parent.parent.hovered ? Theme.text : Theme.textMuted
                    }
                }
                SpotifyLibrary {
                    x: 8
                    y: 46
                    width: parent.width - 16
                    height: parent.height - y - 8
                    onOpened: playlist => {
                        SpotifyApi.openPlaylist(playlist);
                        popout.push("playlist");
                    }
                }
            }

            // ---------- Playlist ----------
            SpotifyPlaylist {
                x: 8
                y: 8
                width: parent.width - 16
                height: parent.height - 16
                visible: popout.view === "playlist"
                onBack: popout.pop()
                onPlayed: popout.stack = []
            }
        }
    }
}

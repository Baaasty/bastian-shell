import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.config
import qs.services
import qs.components

// OSD: Lautstärke, Helligkeit und Medientasten als Pille unten mittig (nur Hauptmonitor, keine Eingaben).
// Unter Hyprland lösen die Tasten Hyprland-Binds aus: Lautstärke per wpctl (Pille folgt Pipewire),
// Helligkeit und Medien per IPC (osd brightnessUp/Down, media playPause/next/previous/stop).
Scope {
    id: root

    property string kind: "volume"   // volume | brightness | media
    property string mediaIcon: ""    // media: was gedrückt wurde
    property real value: 0           // 0..1 (Lautstärke auch > 1)
    property bool muted: false
    property string display: ""      // welches Display gerade gezeigt wird
    property bool shown: false

    readonly property var size: isMedia ? mediaSize : (Theme.layout.osdSize || [300, 56])
    readonly property string icon: kind === "media" ? mediaIcon
        : kind === "brightness"
        ? (value < 0.34 ? "brightness_low" : value < 0.67 ? "brightness_medium" : "brightness_high")
        : (muted || value <= 0 ? "volume_off" : value < 0.5 ? "volume_down" : "volume_up")
    // media: Karte folgt dem Spieler (nach „Weiter“ kommt der neue Titel kurz danach)
    readonly property var player: Players.active
    property int mediaPulse: 0
    readonly property bool isMedia: kind === "media"
    readonly property var mediaSize: [400, 92]

    // Bei schnellen Änderungen nur die Anzeigezeit verlängern
    function show(k: string, v: real, m: bool): void {
        kind = k;
        value = v;
        muted = m;
        shown = true;
        hide.restart();
    }

    Connections {
        target: Audio
        function onChanged() {
            root.show("volume", Audio.volume, Audio.muted);
        }
    }

    Connections {
        target: Brightness
        function onChanged(display, value) {
            // Tasten ändern alle Displays nacheinander: Hauptmonitor hat Vorrang
            if (root.shown && root.kind === "brightness" && root.display === Brightness.mainDisplay && display !== Brightness.mainDisplay) {
                hide.restart();
                return;
            }
            root.display = display;
            root.show("brightness", value, false);
        }
    }

    Timer {
        id: hide
        interval: (Theme.motion.osdVisible || 1200) + (root.isMedia ? 800 : 0)
        onTriggered: root.shown = false
    }

    // zum Testen: qs ipc … call osd volume | brightness
    IpcHandler {
        target: "osd"

        function volume(): void {
            root.show("volume", Audio.volume, Audio.muted);
        }
        function brightness(): void {
            root.display = Brightness.mainDisplay;
            root.show("brightness", Brightness.brightness, false);
        }
        // Helligkeitstasten (Hyprland-Bind): alle Monitore 5 % heller/dunkler, Pille kommt über Brightness.changed
        function brightnessUp(): void {
            Brightness.step(0.05);
        }
        function brightnessDown(): void {
            Brightness.step(-0.05);
        }
    }

    // Medientasten (Hyprland-Binds, ohne playerctl): wirkt auf Players.active
    // Ohne Spieler zeigt das OSD „Nothing playing“, mit Spieler die Aktion und den Titel.
    IpcHandler {
        target: "media"

        function press(icon: string): void {
            root.mediaIcon = icon;
            root.mediaPulse++;
            root.show("media", 0, false);
        }
        function playPause(): void {
            const p = root.player;
            // Spotify frisch gestartet, nichts geladen: über die Web API weiterspielen statt „Nothing playing“
            if (p && p === Players.spotify && SpotifyApi.idle) {
                SpotifyApi.resume();
                return press("play_arrow");
            }
            if (!p || !p.canTogglePlaying)
                return press("");
            const icon = p.isPlaying ? "pause" : "play_arrow";
            p.togglePlaying();
            press(icon);
        }
        function next(): void {
            const p = root.player;
            if (!p || !p.canGoNext)
                return press(p ? "skip_next" : "");
            p.next();
            press("skip_next");
        }
        function previous(): void {
            const p = root.player;
            if (!p || !p.canGoPrevious)
                return press(p ? "skip_previous" : "");
            p.previous();
            press("skip_previous");
        }
        function stop(): void {
            const p = root.player;
            if (!p)
                return press("");
            p.stop();
            press("stop");
        }
    }

    Variants {
        model: Config.mainScreens

        PanelWindow {
            id: win

            required property var modelData

            screen: modelData
            visible: root.shown || pill.opacity > 0
            anchors.bottom: true
            margins.bottom: 96
            implicitWidth: root.size[0]
            implicitHeight: root.size[1]
            exclusionMode: ExclusionMode.Ignore
            color: "transparent"
            WlrLayershell.namespace: "dock" // "dock": ohne Öffnen-Animation (Hyprland: layerrule noanim)
            WlrLayershell.layer: WlrLayer.Top
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            // leere Maske: Klicks gehen durch
            mask: Region {}

            BackgroundEffect.blurRegion: Region {
                Region { x: 0; y: 0; width: 1; height: 1 }
                Region { item: pill; radius: pill.radius }
            }

            Glass {
                id: pill

                anchors.fill: parent
                strong: true
                radius: root.isMedia ? Theme.radiusXl : height / 2
                opacity: root.shown ? 1 : 0
                scale: root.shown ? 1 : 0.96
                Behavior on opacity { NumberAnimation { duration: Theme.slide; easing.type: Easing.OutCubic } }
                Behavior on scale { NumberAnimation { duration: Theme.slide; easing.type: Easing.OutCubic } }

                MediaCard {
                    anchors.fill: parent
                    visible: root.isMedia
                    player: root.player
                    icon: root.mediaIcon
                    pulse: root.mediaPulse
                    corner: pill.radius
                }

                Icon {
                    id: glyph
                    visible: !root.isMedia
                    anchors.left: parent.left
                    anchors.leftMargin: 22
                    anchors.verticalCenter: parent.verticalCenter
                    name: root.icon
                    size: 20
                    color: root.muted ? Theme.textFaint : Theme.text
                }

                MonoTxt {
                    id: num
                    visible: !root.isMedia
                    anchors.right: parent.right
                    anchors.rightMargin: 22
                    anchors.verticalCenter: parent.verticalCenter
                    width: 30
                    horizontalAlignment: Text.AlignRight
                    text: Math.round(root.value * 100)
                    color: root.muted ? Theme.textFaint : Theme.text
                    font.pixelSize: 14
                }

                // Balken
                Rectangle {
                    visible: !root.isMedia
                    anchors.left: glyph.right
                    anchors.leftMargin: 14
                    anchors.right: num.left
                    anchors.rightMargin: 14
                    anchors.verticalCenter: parent.verticalCenter
                    height: 4
                    radius: 2
                    color: Theme.borderStrong

                    Rectangle {
                        height: parent.height
                        radius: parent.radius
                        width: parent.width * Math.max(0, Math.min(1, root.value))
                        color: root.muted ? Theme.textFaint : Theme.text
                        Behavior on width { NumberAnimation { duration: Theme.fade; easing.type: Easing.OutCubic } }
                    }
                }
            }
        }
    }
}

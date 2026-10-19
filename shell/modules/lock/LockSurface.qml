pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.config
import qs.services
import qs.components

// Eine Sperrfläche je Monitor. Aufbau wie das Plasma-Paket (LockScreenUi.qml):
// scharfes Wallpaper + Uhr (nur Hauptmonitor); bei Eingabe Unschärfe (WallpaperFader: Blur 50, Sättigung 1,5,
// Kontrast 0,8, Helligkeit 0,7), darunter Passwort-Kästchen, Medien-Karte und Standby. Entsperren fächert
// von der Mitte auf (Glut-Linie, obere/untere Hälfte gleiten weg).
WlSessionLockSurface {
    id: surface

    required property var ctx   // Lock.qml (gemeinsamer Zustand)

    readonly property bool isMain: !!screen && screen.name === Config.mainScreen
    // Mitte des Plasma-StackViews (Höhe + 3 Rastereinheiten): daran hängen Uhr und Passwortfeld
    readonly property real mid: height / 2 + 27
    // 0 = scharf, 1 = unscharf (Feld sichtbar)
    property real factor: ctx.uiVisible ? 1 : 0
    Behavior on factor { NumberAnimation { duration: 800; easing.type: Easing.InOutQuad } }

    color: Theme.bg

    // Wallpaper wie bisher: Bild aus kscreenlockerrc (setzt scripts/wallpaper, „mitte“ auf allen Monitoren)
    property string wallpaper: Quickshell.env("HOME") + "/.local/share/wallpapers/desktop/desktop-mitte-2560x1440.jpg"
    FileView {
        path: Quickshell.env("HOME") + "/.config/kscreenlockerrc"
        printErrors: false
        onLoaded: {
            let group = "";
            for (const line of text().split("\n")) {
                if (line.startsWith("["))
                    group = line.trim();
                else if (group === "[Greeter][Wallpaper][org.kde.image][General]" && line.startsWith("Image=")) {
                    const p = line.slice(6).trim().replace(/^file:\/\//, "");
                    if (p)
                        surface.wallpaper = p;
                }
            }
        }
    }

    Item {
        id: stage

        anchors.fill: parent
        // Plasma: Einblenden über 2 × veryLongDuration
        NumberAnimation on opacity { from: 0; to: 1; duration: 800; running: true }

        // Tasten: ein Puffer für alle Monitore (Lock.qml)
        focus: true
        Keys.onPressed: event => surface.ctx.key(event)

        Image {
            id: base
            anchors.fill: parent
            source: "file://" + surface.wallpaper
            fillMode: Image.PreserveAspectCrop
            sourceSize.width: surface.width
            sourceSize.height: surface.height
            asynchronous: true
            smooth: true
        }

        // alles, was beim Entsperren aufgefächert wird (Plasma: lockScreenRoot)
        Item {
            id: content

            anchors.fill: parent

            // WallpaperFader: rendert nur, solange sich factor ändert
            MultiEffect {
                anchors.fill: parent
                visible: surface.factor > 0.001
                source: base
                autoPaddingEnabled: false
                blurEnabled: true
                blurMax: 50
                blur: surface.factor
                saturation: 0.5 * surface.factor
                contrast: -0.2 * surface.factor
            }
            // Helligkeit × 0,7 (warmes Fast-Schwarz aus der Palette)
            Rectangle {
                anchors.fill: parent
                visible: surface.factor > 0.001
                color: Qt.alpha(Theme.dim, 0.3 * surface.factor)
            }

            LockClock {
                id: clock
                visible: surface.isMain && y > 0
                anchors.horizontalCenter: parent.horizontalCenter
                // Unterkante 56 px über dem Passwortfeld
                y: Math.max(parent.height * 0.06, surface.mid - height - 56)
                shadow: surface.ctx.uiVisible ? 0 : 1
            }

            // Plasma: Meldung, Passwort, Medien, Aktionen ab Mitte + largeSpacing, 16 Rastereinheiten breit
            Column {
                id: prompts

                property real shake: 0

                x: (parent.width - width) / 2
                y: surface.mid + 8
                width: 288
                spacing: 5
                opacity: surface.ctx.uiVisible ? 1 : 0
                visible: opacity > 0
                enabled: !shakeAnim.running && !surface.ctx.unlocking
                transform: Translate { x: prompts.offset }
                Behavior on opacity { NumberAnimation { duration: 400; easing.type: Easing.InOutQuad } }

                // Meldung (kursiv), eine Zeile Platz auch ohne Text
                Item {
                    width: parent.width
                    height: Math.max(22, note.implicitHeight)

                    Txt {
                        id: note
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.WordWrap
                        elide: Text.ElideNone
                        font.pixelSize: 16
                        font.italic: true
                        font.weight: Font.Normal
                        text: {
                            const parts = [];
                            if (surface.ctx.capsLock)
                                parts.push("Caps Lock is on");
                            if (surface.ctx.notification)
                                parts.push(surface.ctx.notification);
                            return parts.join(" • ");
                        }
                        SequentialAnimation {
                            id: bounce
                            NumberAnimation { target: note; property: "scale"; from: 1; to: 1.1; duration: 200; easing.type: Easing.OutQuad }
                            NumberAnimation { target: note; property: "scale"; from: 1.1; to: 1; duration: 200; easing.type: Easing.InQuad }
                        }
                    }
                }

                // Passwort + Medien: Plasma begrenzt diesen Block auf 10 Rastereinheiten (180 px)
                Item {
                    width: parent.width
                    height: Math.max(180, block.implicitHeight)

                    Column {
                        id: block
                        width: parent.width
                        spacing: 5

                        LockPassword {
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: surface.ctx.codeLength > 0 ? implicitWidth : parent.width
                            ctx: surface.ctx
                            focused: stage.activeFocus
                        }
                        LockMedia {
                            width: parent.width
                            topPadding: 4
                            onUsed: surface.ctx.show()
                        }
                    }
                }

                // Aktionen (heute nur Standby; Ruhezustand kann der PC nicht, Benutzerwechsel gibt es unter Hyprland nicht)
                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 8
                    LockAction {
                        text: "Standby"
                        glyph: "bedtime"
                        onClicked: Quickshell.execDetached(["systemctl", "suspend"])
                    }
                }

                // Plasma RejectPasswordAnimation: 3 × hin und her (15 px), 600 ms, OutCubic
                NumberAnimation {
                    id: shakeAnim
                    target: prompts
                    property: "shake"
                    from: 0
                    to: 7
                    duration: 600
                    easing.type: Easing.OutCubic
                }
                // shake läuft als Fortschritt 0..7 über die Wendepunkte 0, -15, 15, -15, 15, -15, 15, 0
                readonly property real offset: {
                    const pts = [0, -15, 15, -15, 15, -15, 15, 0];
                    const i = Math.min(6, Math.floor(shake));
                    const f = shake - i;
                    return pts[i] + (pts[i + 1] - pts[i]) * f;
                }
            }

            MouseArea {
                id: mouse

                property bool seen: false

                anchors.fill: parent
                z: -1 // unter den Knöpfen
                hoverEnabled: true
                cursorShape: surface.ctx.uiVisible ? Qt.ArrowCursor : Qt.BlankCursor
                onPressed: {
                    stage.forceActiveFocus();
                    surface.ctx.show();
                }
                // erste Bewegung ignorieren (kommt beim Aufgehen der Fläche ohne echte Mausbewegung)
                onPositionChanged: {
                    if (seen)
                        surface.ctx.show();
                    seen = true;
                }
            }
        }

        // ---- Entsperren: obere/untere Hälfte als Standbild, darunter das scharfe Wallpaper ----
        ShaderEffectSource {
            id: top
            visible: false
            width: stage.width
            height: Math.ceil(stage.height / 2)
            sourceItem: content
            sourceRect: Qt.rect(0, 0, width, height)
            live: false
            hideSource: visible
        }
        ShaderEffectSource {
            id: bottom
            visible: false
            y: top.height
            width: stage.width
            height: stage.height - top.height
            sourceItem: content
            sourceRect: Qt.rect(0, top.height, width, height)
            live: false
            hideSource: visible
        }
        Rectangle {
            id: seam
            anchors.centerIn: parent
            width: 0
            height: 2
            radius: 1
            opacity: 0
            color: Theme.accent
        }
    }

    SequentialAnimation {
        id: unlockAnim
        ScriptAction {
            script: {
                top.scheduleUpdate();
                bottom.scheduleUpdate();
                top.visible = true;
                bottom.visible = true;
            }
        }
        // Glut-Linie in der Mitte
        ParallelAnimation {
            NumberAnimation { target: seam; property: "opacity"; to: 1; duration: 140; easing.type: Easing.OutCubic }
            NumberAnimation { target: seam; property: "width"; to: surface.width * 0.6; duration: 180; easing.type: Easing.OutCubic }
        }
        // auffächern (danach entsperrt Lock.qml, 760 ms nach dem Start)
        ParallelAnimation {
            NumberAnimation { target: top; property: "y"; to: -top.height; duration: 560; easing.type: Easing.InOutCubic }
            NumberAnimation { target: bottom; property: "y"; to: surface.height; duration: 560; easing.type: Easing.InOutCubic }
            NumberAnimation { target: seam; property: "width"; to: surface.width; duration: 300; easing.type: Easing.OutCubic }
            NumberAnimation { target: seam; property: "opacity"; to: 0; duration: 420; easing.type: Easing.InCubic }
        }
    }

    Connections {
        target: surface.ctx
        function onUnlockingChanged(): void {
            if (surface.ctx.unlocking)
                unlockAnim.start();
        }
        function onRejected(): void {
            shakeAnim.restart();
        }
        function onNotificationRepeated(): void {
            bounce.restart();
        }
    }
}

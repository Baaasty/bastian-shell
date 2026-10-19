import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.config
import qs.components
import qs.services
import qs.modules.launcher

// Dashboard (Super allein): Overlay auf dem Hauptmonitor. Esc oder Klick daneben schließt.
Scope {
    id: root

    property bool open: false
    signal closed()
    property var launcher: null
    readonly property int searchY: 56
    readonly property bool searching: launcher !== null && launcher.query !== ""

    // offen = globale Kürzel aus (Super+Q & Co. im Hintergrund), siehe Hypr.setModal
    Component.onDestruction: Hypr.setModal("dashboard", false)

    // Suche steckt im Dashboard: Menü drücken, lostippen
    onOpenChanged: {
        Hypr.setModal("dashboard", open);
        if (open)
            Updates.checkIfStale();
        else
            closed();   // Kacheln leeren ihre Eingaben (Dashboard geht jedes Mal frisch auf)
        if (!launcher)
            return;
        launcher.embedded = open;
        if (open)
            launcher.reset();
    }

    // was aus dem Dashboard ein Fenster öffnet, schließt es
    Connections {
        target: Launch
        function onLaunched() { root.open = false; }
    }

    IpcHandler {
        target: "dashboard"

        function toggle(): void {
            root.open = !root.open;
        }
        function show(): void {
            root.open = true;
        }
        function hide(): void {
            root.open = false;
        }
        function state(): string {
            return JSON.stringify({ open: root.open, launcher: root.launcher !== null, query: root.launcher ? root.launcher.query : null });
        }
    }

    Variants {
        model: Config.mainScreens

        PanelWindow {
            id: win

            required property var modelData
            property real progress: root.open ? 1 : 0

            Behavior on progress { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

            screen: modelData
            visible: progress > 0
            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }
            exclusionMode: ExclusionMode.Ignore
            color: "transparent"
            WlrLayershell.namespace: "dock" // "dock": ohne Öffnen-Animation (Hyprland: layerrule noanim)
            WlrLayershell.layer: WlrLayer.Overlay // Overlay: bekommt die Tastatur sofort
            WlrLayershell.keyboardFocus: root.open ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
            // Klick irgendwo daneben (auch auf den anderen Monitoren) schließt; der Abdunkel-Klick unten bleibt
            HyprlandFocusGrab {
                active: root.open
                windows: [win]
                onCleared: root.open = false
            }

            onVisibleChanged: if (visible) search.input.forceActiveFocus()
            Connections {
                target: root
                function onOpenChanged() { if (root.open) search.input.forceActiveFocus(); }
            }

            // Blur nur, solange die Flächen wirklich zu sehen sind: beim Ein-/Ausblenden erst ab 40 %,
            // beim Schließen sofort weg. Der ganze Hintergrund wird mitgeblurrt (leise, dazu nur leicht abgedunkelt).
            readonly property bool blurOn: root.open && progress > 0.4
            readonly property bool tileBlur: blurOn && !root.searching

            BackgroundEffect.blurRegion: Region {
                Region { x: 0; y: 0; width: 1; height: 1 }
                Region { item: win.blurOn ? backdrop : null }
                Region { item: win.blurOn ? search.card : null; radius: Theme.radiusXl }
                Region { item: win.blurOn && search.padShown ? search.pad : null; radius: Theme.radiusXl }
                Region { item: win.tileBlur ? clockTile : null; radius: Theme.radiusLg }
                Region { item: win.tileBlur ? spotifyTile : null; radius: Theme.radiusLg }
                Region { item: win.tileBlur ? systemTile : null; radius: Theme.radiusLg }
                Region { item: win.tileBlur ? discordTile : null; radius: Theme.radiusLg }
                Region { item: win.tileBlur ? focusTile : null; radius: Theme.radiusLg }
                Region { item: win.tileBlur ? notifsTile : null; radius: Theme.radiusLg }
                Region { item: win.tileBlur ? agendaTile : null; radius: Theme.radiusLg }
                Region { item: win.tileBlur ? mailTile : null; radius: Theme.radiusLg }
                Region { item: win.tileBlur ? controlsTile : null; radius: Theme.radiusLg }
                Region { item: win.tileBlur ? devTile : null; radius: Theme.radiusLg }
            }

            // Abdunkeln; Klick daneben schließt
            Rectangle {
                id: backdrop
                anchors.fill: parent
                color: Theme.dim
                opacity: win.progress
                MouseArea {
                    anchors.fill: parent
                    onClicked: root.open = false
                }
            }

            Item {
                id: content

                anchors.fill: parent
                opacity: win.progress
                transform: Translate { y: (1 - win.progress) * -12 }
                focus: true
                Keys.onEscapePressed: root.open = false
                // Suchleiste: hat beim Öffnen sofort den Fokus, Treffer klappen über den Kacheln auf
                LauncherPanel {
                    id: search
                    z: 2
                    launcher: root.launcher
                    compact: true
                    placeholder: "Just start typing…"
                    x: (parent.width - width) / 2
                    y: root.searchY
                    onDismissed: root.open = false
                    onActivated: root.open = false
                }

                // 12er-Raster: Rand 80, Lücke 20, drei Zeilen.
                // Oben kompakt (Uhr mit Wetter, Chat, Medien, Fokus), Mitte (Licht & Ton, Status, Benachrichtigungen),
                // unten Termine + Mail. CPU/RAM/GPU/Netz/Prozesse stehen im Ressourcen-Chip der Bar.
                Item {
                    id: grid

                    readonly property int gap: 20
                    readonly property var rows: [250, 380, 420]
                    readonly property real colW: (width - gap * 11) / 12

                    function cx(col) { return col * (colW + gap); }
                    function cw(span) { return span * colW + (span - 1) * gap; }
                    function ry(row) { let y = 0; for (let i = 0; i < row; i++) y += rows[i] + gap; return y; }

                    x: 80
                    y: root.searchY + search.restHeight + 24   // unter Suchfeld + Modus-Chips
                    // beim Suchen treten die Kacheln zurück
                    opacity: root.searching ? 0.12 : 1
                    Behavior on opacity { NumberAnimation { duration: Theme.fade; easing.type: Easing.OutCubic } }
                    width: parent.width - 160
                    height: ry(rows.length)

                    // Wetter steckt klein in der Uhr-Kachel (WeatherTile.qml bleibt für später liegen);
                    // StatsTile.qml liegt unbenutzt im Ordner
                    ClockTile {
                        id: clockTile
                        x: grid.cx(0); y: grid.ry(0); width: grid.cw(3); height: grid.rows[0]
                    }
                    DiscordTile {
                        id: discordTile
                        x: grid.cx(3); y: grid.ry(0); width: grid.cw(3); height: grid.rows[0]
                    }
                    SpotifyTile {
                        id: spotifyTile
                        x: grid.cx(6); y: grid.ry(0); width: grid.cw(3); height: grid.rows[0]
                    }
                    FocusTile {
                        id: focusTile
                        Connections {
                            target: root
                            function onClosed() { focusTile.reset(); }
                        }
                        x: grid.cx(9); y: grid.ry(0); width: grid.cw(3); height: grid.rows[0]
                    }
                    ControlsTile {
                        id: controlsTile
                        x: grid.cx(0); y: grid.ry(1); width: grid.cw(4); height: grid.rows[1]
                    }
                    DevTile {
                        id: devTile
                        x: grid.cx(4); y: grid.ry(1); width: grid.cw(5); height: grid.rows[1]
                    }
                    NotifsTile {
                        id: notifsTile
                        x: grid.cx(9); y: grid.ry(2); width: grid.cw(3); height: grid.rows[2]
                    }
                    SystemTile {
                        id: systemTile
                        x: grid.cx(9); y: grid.ry(1); width: grid.cw(3); height: grid.rows[1]
                    }
                    AgendaTile {
                        id: agendaTile
                        x: grid.cx(0); y: grid.ry(2); width: grid.cw(6); height: grid.rows[2]
                    }
                    MailTile {
                        id: mailTile
                        x: grid.cx(6); y: grid.ry(2); width: grid.cw(3); height: grid.rows[2]
                    }
                }
            }
        }
    }
}

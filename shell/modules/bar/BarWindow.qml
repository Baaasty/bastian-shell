import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.config
import qs.services
import qs.components

// Schwebende Bar, reserviert ihren Platz oben (exclusiveZone), ist also immer sichtbar. Nur falls doch ein
// Fenster in ihren Bereich ragt (hochgeschoben), gleitet sie weg und kommt über die obere Kante zurück
// (2-px-Streifen in Bar.qml). Echtes Vollbild/Spiel: ganz weg (Windows.bare).
// Klickbar sind nur die Chips: leere Stellen und der Rand darüber lassen Klicks durch, dort packt man
// das Fenster darunter. Nur solange sie über einem Fenster hervorgeholt ist, gehört ihr der ganze obere
// Streifen (topZone): so sieht die Shell selbst, wann die Maus wieder weg ist (früher meldete das KWin).
PanelWindow {
    id: win

    property bool revealed: false
    // Maus im oberen Streifen (per IPC bar reveal/leave oder topZone); hält die hervorgeholte Bar offen
    property bool inZone: false
    readonly property bool zoneOn: revealed && Windows.topBlocked
    property int openMenus: 0
    readonly property bool shown: !Windows.topBlocked || revealed || openMenus > 0 || hover.hovered || BarKeys.modeOn

    anchors {
        top: true
        left: true
        right: true
    }
    // + Luft für den Schatten (nur Optik; Klicks gehen per mask nur an die Chips)
    implicitHeight: Theme.barMargin + Theme.barHeight + 34
    // reserviert den Platz der Bar: Fenster (auch maximiert) fangen darunter an, die Bar bleibt immer sichtbar.
    // Nur im echten Vollbild/Spiel (Windows.bare) ist sie ganz weg und gibt den Platz wieder frei.
    exclusionMode: ExclusionMode.Normal
    exclusiveZone: Theme.barMargin + Theme.barHeight
    color: "transparent"

    // Vollbild/Spiel: ganz weg (nicht nur unsichtbar), sonst kein direct scanout/Tearing (Windows.bare)
    visible: !Windows.bare

    WlrLayershell.namespace: "dock"
    // immer Overlay: ein Ebenenwechsel erst beim Hervorholen greift nicht rechtzeitig, dann bliebe sie
    // unter Vollbild-Fenstern. Versteckt ist sie unsichtbar und ohne Klickfläche (mask), stört also nicht.
    WlrLayershell.layer: WlrLayer.Overlay
    // Tastatur nur im Bar-Modus (Super+Leertaste) und solange ein per Taste geöffnetes Popout offen ist (BarKeys.qml)
    WlrLayershell.keyboardFocus: BarKeys.wantsKeys ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    // Koordinaten selbst ausrechnen statt "item:": Region rechnet die Lage eines Items nur neu, wenn sich das
    // Item selbst bewegt – gleitet die Bar beim Hervorholen herein, bliebe die Klickfläche oben außerhalb hängen
    mask: Region {
        Region {
            width: win.zoneOn ? topZone.width : 0; height: topZone.height
        }
        Region {
            x: bar.x + leftRow.x; y: bar.y + leftRow.y
            width: win.shown ? leftRow.width : 0; height: leftRow.height
        }
        Region {
            x: bar.x + clock.x; y: bar.y + clock.y
            width: win.shown ? clock.width : 0; height: clock.height
        }
        Region {
            x: bar.x + privacy.x; y: bar.y + privacy.y
            width: win.shown && privacy.visible ? privacy.width : 0; height: privacy.height
        }
        Region {
            x: bar.x + rightZone.x; y: bar.y + rightZone.y
            width: win.shown ? rightZone.width : 0; height: rightZone.height
        }
        // ganze Bar + Streifen bis zum Popout, solange eins offen ist (Lücken zwischen den Chips eingeschlossen)
        Region {
            width: win.openMenus > 0 && win.shown ? bridge.width : 0; height: bridge.height
        }
    }

    BackgroundEffect.blurRegion: Region {
        Region { x: 0; y: 0; width: 1; height: 1 }
        Region {
            item: win.shown ? bar : null
            radius: Theme.barRadius
        }
    }

    // ---------- Bar-Modus (Super+Leertaste): Buchstabe öffnet das Popout des Chips, Esc/nochmal = zu ----------
    Item {
        id: modeKeys
        focus: BarKeys.wantsKeys
        // Einzelkürzel: das Loslassen der Kürzel-Tasten ist das Ereignis, mit dem das Popout den Fokus greifen darf
        Keys.onReleased: event => {
            if (BarKeys.armed !== "")
                BarKeys.fire();
        }
        Keys.onPressed: event => {
            if (BarKeys.armed !== "") {
                BarKeys.fire();
                event.accepted = true;
                return;
            }
            // Popout ohne Fokus-Griff: Tasten weiterreichen (KeyNav)
            if (BarKeys.fwd !== "") {
                BarKeys.forward(event);
                event.accepted = true;
                return;
            }
            event.accepted = true;
            if (!BarKeys.modeOn)
                return;
            const k = event.key;
            // Chip wählen: ←/→, Tab/Shift+Tab; Enter oder ↓ öffnet ihn
            if (k === Qt.Key_Left || k === Qt.Key_Right || k === Qt.Key_Tab || k === Qt.Key_Backtab) {
                win.stepChip(k === Qt.Key_Left || k === Qt.Key_Backtab || (event.modifiers & Qt.ShiftModifier) ? -1 : 1);
                return;
            }
            if (event.isAutoRepeat)
                return;
            if (k === Qt.Key_Escape) {
                BarKeys.closeMode();
                return;
            }
            if ((k === Qt.Key_Return || k === Qt.Key_Enter || k === Qt.Key_Down || k === Qt.Key_Space) && BarKeys.sel !== "") {
                BarKeys.fromMode = true;
                BarKeys.popout(BarKeys.sel, true);
                return;
            }
            const letter = event.text.length === 1 ? event.text : "";
            if (/^[a-zA-Z]$/.test(letter))
                BarKeys.pick(letter);
        }
    }
    // Chips mit Buchstaben (Chip.hintKey), von links nach rechts
    function modeChips(): var {
        const out = [];
        const walk = it => {
            for (const c of it.children) {
                if (!c || !c.visible)
                    continue;
                if (typeof c.hintKey === "string" && c.hintKey !== "" && c.width > 0)
                    out.push(c);
                else
                    walk(c);
            }
        };
        walk(bar);
        return out.sort((a, b) => a.mapToItem(null, 0, 0).x - b.mapToItem(null, 0, 0).x);
    }
    function stepChip(d: int): void {
        const list = modeChips();
        if (!list.length)
            return;
        const keys = list.map(c => c.hintKey);
        const i = keys.indexOf(BarKeys.keyFor(BarKeys.sel));
        const next = i < 0 ? (d > 0 ? 0 : list.length - 1) : (i + d + list.length) % list.length;
        const e = BarKeys.entries.find(x => x.key === keys[next]);
        BarKeys.sel = e ? e.name : "";
    }
    // markierter Chip (für den Ring)
    readonly property Item selChip: {
        if (!BarKeys.modeOn || BarKeys.sel === "")
            return null;
        const key = BarKeys.keyFor(BarKeys.sel);
        return modeChips().find(c => c.hintKey === key) ?? null;
    }
    Connections {
        target: BarKeys
        function onModeOnChanged() {
            win.modeGrabReady = false;
            if (BarKeys.modeOn) {
                modeGrabDelay.restart();
                modeKeys.forceActiveFocus();
            }
        }
        function onStepRequested(d) {
            if (BarKeys.modeOn)
                win.stepChip(d);
        }
        function onWantsKeysChanged() {
            if (BarKeys.wantsKeys)
                modeKeys.forceActiveFocus();
        }
    }
    // Klick außerhalb beendet den Modus (erst kurz nach dem Öffnen scharf, wie im Workspace-Modus)
    property bool modeGrabReady: false
    Timer {
        id: modeGrabDelay
        interval: 250
        onTriggered: win.modeGrabReady = BarKeys.modeOn
    }
    HyprlandFocusGrab {
        active: BarKeys.modeOn && win.modeGrabReady
        windows: [win]
        onCleared: BarKeys.closeMode()
    }

    // Maus weg -> nach kurzer Zeit wieder ausweichen
    // oberer Streifen (Bar-Abstand + Bar + Luft), nur Teil der Maske, solange die Bar hervorgeholt ist
    Item {
        id: topZone
        width: win.width
        height: Theme.barMargin + Theme.barHeight + 12
        HoverHandler {
            id: zoneHover
        }
    }

    // Brücke: ganzer Streifen von oben bis zur Oberkante der Popouts (Rand, Bar mit Lücken zwischen den Chips, windowGap).
    // Gehört sonst nicht zur Klickfläche – die Maus wäre dort „nirgends“ und das Popout ginge zu (PopoutGuard).
    // Über den Chips meldet bridgeHover nichts (die Chips nehmen das Hover), dort zählt das Hover der Bar.
    Item {
        id: bridge
        width: win.width
        height: Theme.barMargin + Theme.barHeight + Theme.windowGap + 2
        HoverHandler {
            id: bridgeHover
        }
    }
    Binding {
        target: Popouts
        property: "bridge"
        value: bridgeHover.hovered || hover.hovered
        when: win.openMenus > 0
    }
    Binding {
        target: Popouts
        property: "overBar"
        value: hover.hovered
        when: win.openMenus > 0
    }

    Timer {
        running: win.revealed && !win.inZone && !zoneHover.hovered && !hover.hovered && win.openMenus === 0
        interval: 600
        onTriggered: win.revealed = false
    }

    // dunkler Hof um die Bar, wenn ein Fenster dahinter liegt (Vollbild/maximiert): hebt sie vom Inhalt ab
    RectangularShadow {
        anchors.fill: bar
        radius: bar.radius
        offset.y: 4
        blur: 26
        spread: 2
        color: Qt.alpha(Theme.shadow, 0.7)
        opacity: Windows.topBlocked ? bar.opacity : 0
        Behavior on opacity { NumberAnimation { duration: Theme.fade } }
    }

    Glass {
        id: bar

        strong: true
        x: Theme.barMargin
        y: win.shown ? Theme.barMargin : -height - 8
        width: win.width - Theme.barMargin * 2
        height: Theme.barHeight
        radius: Theme.barRadius
        opacity: win.shown ? 1 : 0

        Behavior on y { NumberAnimation { duration: Theme.slide; easing.type: Easing.OutCubic } }
        Behavior on opacity { NumberAnimation { duration: Theme.fade; easing.type: Easing.OutCubic } }

        // liegt ein Fenster dahinter (hervorgeholt über Vollbild/maximiert): dunkler und deckender, damit man lesen kann
        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: Theme.bg
            opacity: Windows.topBlocked ? 0.72 : 0
            Behavior on opacity { NumberAnimation { duration: Theme.fade } }
        }

        HoverHandler {
            id: hover
        }

        // links: deine To-dos, Fokus, Claude-Zentrale (der nächste Termin steht im Dashboard)
        Row {
            id: leftRow

            anchors.left: parent.left
            anchors.leftMargin: 4
            anchors.verticalCenter: parent.verticalCenter
            spacing: 4

            // Fokus-Timer ganz links: hier starten, Restzeit läuft hier (rechts nicht mehr)
            TimerChip {
                anchors.verticalCenter: parent.verticalCenter
            }
            TodoChip {
                barWindow: win
            }
            // Claude-Zentrale: alle aktiven Projekte + Claude-Sitzungen (ersetzt Kontext- und Claude-Chip)
            ClaudeHubChip {
                anchors.verticalCenter: parent.verticalCenter
                barWindow: win
            }
        }

        // Mitte: Uhr
        Clock {
            id: clock

            anchors.centerIn: parent
            showDate: true
        }
        // Privatsphäre-Punkte (Mikrofon/Kamera/Teilen) als Statusanzeige links neben der Uhr: unsichtbar, wenn
        // nichts aktiv ist; auch im Fokus-Modus sichtbar (Idee i)
        PrivacyDot {
            id: privacy
            anchors.right: clock.left
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            barWindow: win
        }

        // rechts: Spotify, Discord, Temperaturen, Tray. Im Fokus still – erst beim Drüberfahren (oder solange
        // ein Popout davon offen ist) tauchen sie auf, z. B. zum Skippen oder Call verlassen.
        Item {
            id: rightZone

            readonly property bool quiet: Focus.active && !rightHover.hovered && win.openMenus === 0

            anchors.right: parent.right
            anchors.rightMargin: 4
            anchors.verticalCenter: parent.verticalCenter
            // im Fokus eine feste Fläche, damit man dort hinfahren kann, obwohl nichts zu sehen ist
            width: Focus.active ? Math.max(rightRow.width, 420) : rightRow.width
            height: Theme.barHeight

            HoverHandler {
                id: rightHover
            }

            Row {
                id: rightRow

                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6

                SpotifyChip {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: !rightZone.quiet   // immer da; ohne Spotify: Play startet es im Hintergrund
                    barWindow: win
                }
                VSep {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: !rightZone.quiet   // immer da; ohne Spotify: Play startet es im Hintergrund
                }
                DiscordChip {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: !rightZone.quiet
                }
                // Dev-Dienste + Server: Zahl, solange Dev-Server/Container laufen – Klick öffnet das Dev-Popout
                // (Reiter Services, Containers, Ports, Server = Web-Konsolen + sshs; ersetzt den Server-Chip)
                DevChip {
                    anchors.verticalCenter: parent.verticalCenter
                    quiet: rightZone.quiet
                    barWindow: win
                }
                // Technik-Chip (CPU/RAM/GPU, Hitze-Temperatur inklusive; ersetzt Temps) – Klick öffnet das Ressourcen-Popout
                ResourcesChip {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: !rightZone.quiet
                    barWindow: win
                }
                // Licht-Chip: Klick öffnet das Licht-Popout (Key Light, Hue, Kamera – wie im Dashboard)
                LightChip {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: !rightZone.quiet
                    barWindow: win
                }
                // Gear-Chip: Klick öffnet das Gear-Popout (PC-Licht, Maus, System); Akku-Warnung der Maus
                GearChip {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: !rightZone.quiet
                    barWindow: win
                }
                // Lautsprecher-Chip: Klick öffnet den Audio-Mixer (Idee g)
                AudioChip {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: !rightZone.quiet
                    barWindow: win
                }
                // Netz-Chip: Klick öffnet das Netz-Popout (Idee h)
                NetChip {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: !rightZone.quiet
                    barWindow: win
                }
                // Dateimanager (Rechtsklick: letzte Downloads, ersetzt den Downloads-Chip) und Browser
                FilesChip {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: !rightZone.quiet
                    barWindow: win
                }
                BrowserChip {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: !rightZone.quiet
                }
                // KDE-Systemeinstellungen (startet etwas statt Menü, wie Files/Browser)
                SettingsChip {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: !rightZone.quiet
                }
                // Updates (dnf + Flatpak): nur sichtbar, wenn welche da sind – Klick öffnet den Paketmanager
                UpdatesChip {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: Updates.count > 0 && !rightZone.quiet
                }
                VSep {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: !rightZone.quiet
                }
                Tray {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: !rightZone.quiet
                    barWindow: win
                }
            }
        }

        // Fokus-Fortschritt: 2-px-Glutlinie an der Unterkante
        Rectangle {
            anchors.left: parent.left
            anchors.leftMargin: Theme.barRadius
            anchors.bottom: parent.bottom
            height: 2
            radius: 1
            color: Theme.accent
            visible: Focus.mode === "focus" || Focus.mode === "paused"
            width: (parent.width - Theme.barRadius * 2) * Focus.progress
            // keine Behavior mehr: die Linie wächst jede Sekunde um ~1,7 px, die 250-ms-Animation dazu
            // ließ die Bar während eines Fokusblocks ein Viertel der Zeit mit 360 Hz neu zeichnen
        }
    }
    // Bar-Modus: kleine Zeile unter der Uhr (Buchstaben stehen an den Chips) oder kurze Meldung
    Rectangle {
        visible: (BarKeys.modeOn || BarKeys.note !== "") && win.shown
        anchors.horizontalCenter: bar.horizontalCenter
        y: bar.y + bar.height + 4
        width: modeHintTxt.implicitWidth + 24
        height: 26
        radius: Theme.radiusSm
        color: Theme.surfaceRaised
        border.width: 1
        border.color: Theme.borderStrong
        Txt {
            id: modeHintTxt
            anchors.centerIn: parent
            text: BarKeys.note !== "" ? BarKeys.note : "Letter or ←→ + Enter opens · Z notifications · Esc closes"
            color: BarKeys.note !== "" ? Theme.text : Theme.textMuted
            font.pixelSize: 12
        }
    }

    // Bar-Modus: ruhiger Glut-Rahmen um den mit ←/→ gewählten Chip
    Rectangle {
        visible: win.selChip !== null && win.shown
        readonly property point p: win.selChip ? win.selChip.mapToItem(null, 0, 0) : Qt.point(0, 0)
        x: p.x - 3
        y: p.y - 3
        width: win.selChip ? win.selChip.width + 6 : 0
        height: win.selChip ? win.selChip.height + 6 : 0
        radius: Theme.radiusSm + 3
        color: "transparent"
        border.width: 2
        border.color: Theme.accent
    }
}

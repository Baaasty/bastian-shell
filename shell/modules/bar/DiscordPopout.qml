import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.services
import qs.components

// Popout unter dem Discord-Chip (Klick öffnet, Klick daneben schließt – wie Spotify).
// Im Call: wer drin ist, wer spricht, pro Person Lautstärke/Stumm, eigene Steuerung (Mic, Taub, Verlassen).
// Ohne Call: Kanal-Auswahl – Favoriten (Stern), zuletzt genutzt, Server → Sprachkanäle; Klick = beitreten.
// Darunter die festen Chats aus secrets.json.
PopupWindow {
    id: pop

    property var barWindow
    property Item chip
    readonly property int maxMembers: 8
    readonly property int maxCardHeight: 520
    readonly property int quick: Math.round(Theme.fade * 0.6)   // Knopf-Farben (~90 ms)

    property bool hoverOpen: false
    property string expandedId: ""      // Person mit offenem Lautstärke-Menü
    property string openGuild: ""       // aufgeklappter Server in der Kanal-Auswahl
    property bool confirmLeave: false
    property bool confirmRestart: false // „Restart Discord“ im Call: erst nachfragen (beendet den Call)
    property real appear: 0             // 0..1 für Ein-/Ausblenden

    readonly property bool want: hoverOpen && !!barWindow && chip !== null
    // offen hält es die Bar sichtbar
    readonly property bool holdBar: visible && hoverOpen

    // sitzt wie die anderen Bar-Popouts mit Lücke unter der Bar, rechtsbündig zur rechten Chip-Kante:
    // die bleibt stehen, wenn der Chip breiter/schmaler wird (Köpfe, Mic-Symbol) -> kein Hin und Her
    anchor.window: barWindow
    anchor.edges: Edges.Bottom | Edges.Right
    anchor.gravity: Edges.Bottom | Edges.Left
    // feste Fenstergröße, sichtbar/klickbar ist nur die Karte (Maske) -> Höhe kann weich animieren
    implicitWidth: 432     // Platz für vier Knöpfe mit Text („Deafen“, „Stream“ ungekürzt) + Verlassen-Symbol
    implicitHeight: maxCardHeight + 8
    color: "transparent"
    visible: false
    mask: Region { item: card }

    onWantChanged: sync()
    // immer nur ein Bar-Popout: per Klick geöffnet -> anmelden, die anderen schließen sich
    onHoverOpenChanged: hoverOpen ? Popouts.claim("discord") : Popouts.release("discord")
    Connections {
        target: Popouts
        function onCurrentChanged() {
            if (Popouts.current === "" || Popouts.current === "discord")
                return;
            pop.hoverOpen = false;
            // sofort weg statt Ausblenden: solange es noch da ist, hält es den Klick-Fokus,
            // und KWin schließt das neue Popout gleich wieder
            if (pop.visible) {
                appearAnim.stop();
                pop.visible = false;
            }
        }
    }
    onHoldBarChanged: if (barWindow && barWindow.openMenus !== undefined) barWindow.openMenus += holdBar ? 1 : -1
    // wie Spotify: Klick daneben schließt
    grabFocus: true
    onVisibleChanged: {
        if (visible) {
            refreshPicker();
            return;
        }
        expandedId = "";
        confirmLeave = false;
        confirmRestart = false;
        hoverOpen = false;
        appear = 0;
    }

    function sync(): void {
        if (want) {
            if (!visible) {
                placeUnderBar(true);
                appear = 0;
                visible = true;
            }
            appearAnim.to = 1;
            appearAnim.restart();
        } else if (visible) {
            appearAnim.to = 0;
            appearAnim.restart();
        }
    }
    NumberAnimation {
        id: appearAnim
        target: pop
        property: "appear"
        duration: Theme.fade
        easing.type: Easing.OutCubic
        onFinished: if (pop.appear === 0 && !pop.want) pop.visible = false
    }

    // force: beim Öffnen immer; solange offen nur nachziehen, wenn der Chip wirklich gewandert ist (> 40 px)
    function placeUnderBar(force: bool): void {
        if (!chip)
            return;
        const right = Math.round(chip.mapToItem(null, chip.width, 0).x);
        const y = Theme.barMargin + Theme.barHeight + Theme.windowGap - 1;
        if (!force && Math.abs(anchor.rect.x + anchor.rect.width - right) <= 40)
            return;
        anchor.rect.x = right - 1;
        anchor.rect.y = y;
        anchor.rect.width = 1;
        anchor.rect.height = 1;
    }

    // PopoutGuard: vom Compositor geschlossen → wieder auf (ohne Klick-Fang)
    function reopen(): void {
        hoverOpen = true;
    }
    // sofort öffnen, z. B. Klick auf einen Kopf in der Bar (id = Person, deren Menü aufgeht)
    function openFor(id: string): void {
        hoverOpen = true;
        if (id && id !== selfId())
            expandedId = id;
    }
    function close(): void {
        guard.intended = true;
        hoverOpen = false;
    }
    function toggle(): void {
        if (hoverOpen)
            close();
        else
            openFor("");
    }

    function selfId(): string {
        const me = Discord.members.find(m => m.isSelf);
        return me ? me.id : "";
    }

    // Kanal-Auswahl: Server und Köpfe in Favoriten nur laden, wenn sie gebraucht werden
    function refreshPicker(): void {
        if (!visible || Discord.inVoice || !Discord.ready)
            return;
        Discord.loadGuilds();
        Discord.peekSaved();
        if (openGuild)
            Discord.loadChannels(openGuild);
    }
    function toggleGuild(id: string): void {
        openGuild = openGuild === id ? "" : id;
        if (openGuild)
            Discord.loadChannels(openGuild);
    }
    Connections {
        target: Discord
        function onInVoiceChanged() { pop.refreshPicker(); }
        function onReadyChanged() { pop.refreshPicker(); }
    }

    // Chip wandert, wenn sich die Bar daneben ändert (z. B. Spotify-Titel) -> mitziehen
    Timer {
        interval: 1000
        repeat: true
        running: pop.visible
        onTriggered: pop.placeUnderBar(false)
    }
    Timer {
        id: leaveReset
        interval: 3000
        onTriggered: pop.confirmLeave = false
    }
    Timer {
        id: restartReset
        interval: 4000
        onTriggered: pop.confirmRestart = false
    }

    // Dauer: "4 min", "1 h 05"
    property real now: Date.now()
    Timer {
        interval: 30000
        repeat: true
        running: pop.visible && Discord.inVoice
        triggeredOnStart: true
        onTriggered: pop.now = Date.now()
    }
    function duration(): string {
        if (!Discord.since)
            return "";
        const min = Math.max(0, Math.floor((now - Discord.since) / 60000));
        if (min < 1)
            return "just now";
        if (min < 60)
            return min + " min";
        return Math.floor(min / 60) + " h " + String(min % 60).padStart(2, "0");
    }

    BackgroundEffect.blurRegion: Region {
        Region { x: 0; y: 0; width: 1; height: 1 }
        // beim Schließen sofort weg, beim Öffnen erst ab 40 % – sonst steht beim Ausblenden ein Blur-Kasten
        Region { item: pop.want && pop.appear > 0.4 ? card : null; radius: Theme.radiusLg }
    }

    // ---------- Bausteine ----------

    component StateIcon: Icon {
        anchors.verticalCenter: parent ? parent.verticalCenter : undefined
        size: 15
        color: Theme.textFaint
    }

    // kleiner Symbol-Knopf (Kopfzeile, Personen-Menü, Stern)
    component IconChip: Chip {
        id: ic
        property string glyph
        property color tint: Theme.textMuted
        padding: 6
        Icon {
            anchors.verticalCenter: parent.verticalCenter
            name: ic.glyph
            fill: ic.active
            size: 16
            color: ic.tint
            Behavior on color { ColorAnimation { duration: pop.quick } }
        }
    }

    // Knopf mit fester Breite (Spalten), Text darf wechseln ohne Sprung; Farben zügig (~90 ms)
    // Knöpfe im Call: der gemeinsame Button; lit = eingeschaltet (Mikro stumm, Kamera an …), danger = Auflegen bestätigen
    component CtlBtn: Button {
        // vier gleich breite Spalten in der festen Popout-Breite: wenig Polster, damit „Deafen“/„Stream“ ganz passen
        compact: true
        property bool lit: false
        property bool danger: false
        kind: danger ? "danger" : primary ? "primary" : lit ? "on" : "secondary"
    }

    // Abschnitt, der weich auf- und zuklappt (Höhe + Deckkraft); gap = Abstand nach oben (klappt mit)
    component Reveal: Item {
        id: rv
        property bool shown: true
        property int gap: 12
        property int spacing: 8
        default property alias content: inner.data
        width: parent ? parent.width : 0
        implicitHeight: shown ? inner.implicitHeight + gap : 0
        height: implicitHeight
        opacity: shown ? 1 : 0
        visible: height > 0.5 || shown
        clip: true
        Behavior on implicitHeight { NumberAnimation { duration: Theme.fade; easing.type: Easing.OutCubic } }
        Behavior on opacity { NumberAnimation { duration: Theme.fade; easing.type: Easing.OutCubic } }
        Column {
            id: inner
            y: rv.gap
            width: rv.width
            spacing: rv.spacing
        }
    }

    // Sprachkanal-Zeile: Klick = beitreten, Stern = Favorit; Köpfe = wer gerade drin ist
    component ChannelRow: Rectangle {
        id: cr
        property var ch: ({})
        property var people: []
        property string guildId: ""
        property string guildName: ""
        property bool showGuild: false
        property int indent: 0
        readonly property bool fav: Discord.isFavorite(ch.id || "")
        width: parent ? parent.width : 0
        height: 34
        radius: Theme.radiusMd
        color: crArea.containsMouse ? Theme.raise : "transparent"
        Behavior on color { ColorAnimation { duration: pop.quick } }

        MouseArea {
            id: crArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: Discord.join(Object.assign({}, cr.ch, { guildId: cr.guildId, guildName: cr.guildName }), false)
        }
        Icon {
            id: kind
            x: 8 + cr.indent
            anchors.verticalCenter: parent.verticalCenter
            name: cr.ch.type === 13 ? "podium" : "volume_up"
            size: 16
            color: cr.people.length > 0 ? Theme.success : Theme.textFaint
        }
        Row {
            anchors.left: kind.right
            anchors.leftMargin: 8
            anchors.right: heads.left
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6
            clip: true
            Txt {
                id: crName
                anchors.verticalCenter: parent.verticalCenter
                width: Math.min(implicitWidth, parent.width)
                text: cr.ch.name || "?"
                color: cr.people.length > 0 ? Theme.text : Theme.textMuted
                font.weight: Font.Normal
            }
            Txt {
                anchors.verticalCenter: parent.verticalCenter
                visible: cr.showGuild && cr.guildName !== ""
                width: Math.max(0, Math.min(implicitWidth, parent.width - crName.width - 6))
                text: cr.guildName
                color: Theme.textFaint
                font.pixelSize: Theme.fontSm
                font.weight: Font.Normal
            }
        }
        Row {
            id: heads
            anchors.right: star.left
            anchors.rightMargin: 2
            anchors.verticalCenter: parent.verticalCenter
            spacing: -6
            Repeater {
                model: cr.people.slice(0, 3)
                DiscordAvatar {
                    required property var modelData
                    anchors.verticalCenter: parent ? parent.verticalCenter : undefined
                    member: modelData
                    size: 16
                    edge: Theme.bg
                }
            }
            MonoTxt {
                anchors.verticalCenter: parent.verticalCenter
                visible: cr.people.length > 3
                leftPadding: 8
                text: "+" + (cr.people.length - 3)
                color: Theme.textMuted
                font.pixelSize: Theme.fontXs
            }
        }
        IconChip {
            id: star
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            glyph: "star"
            active: cr.fav
            tint: cr.fav ? Theme.warning : Theme.textFaint
            onClicked: Discord.toggleFavorite(Object.assign({}, cr.ch, { guildId: cr.guildId, guildName: cr.guildName }))
        }
    }

    // ---------- Karte ----------
    Glass {
        id: card
        // offen bis zum Weghovern (PopoutGuard.qml)
        PopoutGuard { id: guard; popout: pop; chip: pop.chip; name: "discord" }
        // Tastatur: Pfeile/Tab/Enter, Bar-Modus (Super+Leertaste, KeyNav.qml)
        Keys.onPressed: e => nav.key(e)
        KeyNav { id: nav; root: card; scope: null; popout: pop; guard: guard; name: "discord"; openFn: () => pop.openFor("") }
        width: parent.width
        height: Math.min(pop.maxCardHeight, flick.y + body.implicitHeight + 16)
        strong: true
        opacity: pop.appear
        transform: Translate { y: (1 - pop.appear) * -6 }

        HoverHandler {
            id: hover
        }
        WheelScroll {
            flick: flick
        }

        // ---------- Kopf: Titel · Dauer · Rausholen ----------
        Item {
            id: head
            x: 16
            y: 14
            width: parent.width - 32
            height: Theme.iconButton
            PopoutTitle {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                icon: Discord.inVoice ? "headset_mic" : "forum"
                text: Discord.inVoice ? "Voice" : "Discord"
                maxTextWidth: dur.x - Theme.space3 - Theme.iconButton - Theme.space3
            }
            MonoTxt {
                id: dur
                anchors.right: tools.left
                anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                opacity: Discord.inVoice ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: Theme.fade; easing.type: Easing.OutCubic } }
                text: pop.duration()
                color: Theme.textFaint
                font.pixelSize: Theme.fontSm
            }
            Row {
                id: tools
                anchors.right: parent.right
                anchors.rightMargin: -6
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2
                // Kameras an/aus: alle Kameras im Call (auch deine) zusammen im Overlay (nur mit Plugin desktopBridge)
                IconChip {
                    visible: Cams.connected
                    glyph: Cams.show ? "videocam" : "videocam_off"
                    active: Cams.show
                    tint: Cams.show ? Theme.accentText : Theme.textMuted
                    onClicked: Cams.toggleShow()
                }
                IconChip {
                    glyph: Parked.out.discord === true ? "close_fullscreen" : "open_in_new"
                    active: Parked.out.discord === true
                    onClicked: Parked.toggle("discord")
                }
            }
        }

        Flickable {
            id: flick
            x: 16
            y: head.y + head.height
            width: parent.width - 32
            height: parent.height - y - 12
            contentHeight: body.implicitHeight
            interactive: false
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            // kürzer geworden -> nicht ins Leere gescrollt bleiben
            onContentHeightChanged: if (contentY > Math.max(0, contentHeight - height)) contentY = Math.max(0, contentHeight - height)

            Column {
                id: body
                width: flick.width
                spacing: 0

                // ================= Equicord weg (meist nach einem Discord-Update) =================
                // statt still wegfallender Cam/Stream-Knöpfe: sagen, was los ist, und mit einem Knopf heilen
                Reveal {
                    id: eqBox
                    shown: Discord.pluginMissing || Discord.restarting
                    gap: 4

                    Rectangle {
                        width: parent.width
                        height: eqText.implicitHeight + 20
                        radius: Theme.radiusMd
                        color: Theme.surfaceSunken
                        border.width: 1
                        border.color: Qt.alpha(Theme.accent, 0.45)

                        Icon {
                            id: eqIcon
                            x: 10
                            y: 10
                            name: Discord.restarting ? "autorenew" : "extension_off"
                            size: 18
                            color: Theme.accentText
                        }
                        Txt {
                            id: eqText
                            anchors.left: eqIcon.right
                            anchors.leftMargin: 8
                            anchors.right: parent.right
                            anchors.rightMargin: 10
                            y: 10
                            wrapMode: Text.WordWrap
                            font.pixelSize: Theme.fontSm
                            font.weight: Font.Normal
                            color: Theme.text
                            text: Discord.restarting ? "Restarting Discord with Equicord…"
                                : Discord.pluginMissingReason === "update"
                                    ? "Equicord gone after a Discord update – Cam, Stream and camera tiles are off."
                                    : "Equicord isn’t responding – Cam, Stream and camera tiles are off."
                        }
                    }
                    // im Call zweimal drücken: der Neustart beendet den Call
                    CtlBtn {
                        visible: !Discord.restarting
                        width: parent.width
                        icon: "restart_alt"
                        text: pop.confirmRestart ? "Restart now? Leaves the call" : "Restart Discord"
                        primary: true
                        onClicked: {
                            if (Discord.inVoice && !pop.confirmRestart) {
                                pop.confirmRestart = true;
                                restartReset.restart();
                                return;
                            }
                            pop.confirmRestart = false;
                            Discord.restartDiscord();
                        }
                    }
                }

                // ================= Call =================
                Reveal {
                    shown: Discord.inVoice
                    gap: Discord.pluginMissing || Discord.restarting ? 12 : 4

                    Row {
                        spacing: 8
                        Icon {
                            anchors.verticalCenter: parent.verticalCenter
                            name: "volume_up"
                            size: 16
                            color: Theme.success
                        }
                        Txt {
                            anchors.verticalCenter: parent.verticalCenter
                            width: Math.min(implicitWidth, body.width - 24)
                            text: Discord.guildName ? Discord.guildName + " · " + Discord.channelName : Discord.channelName
                            font.pixelSize: Theme.fontMd
                        }
                    }

                    Column {
                        width: parent.width
                        spacing: 4

                        Repeater {
                            model: Discord.memberIds.slice(0, pop.maxMembers)

                            Column {
                                id: person
                                required property string modelData
                                readonly property var m: Discord.memberMap[modelData] || ({})
                                readonly property bool me: m.isSelf === true
                                readonly property bool open: pop.expandedId === modelData && !me
                                width: body.width

                                // Zeile: Klick öffnet das Menü (nicht bei dir selbst)
                                Rectangle {
                                    width: parent.width
                                    height: 38
                                    radius: Theme.radiusMd
                                    color: person.open || (rowArea.containsMouse && !person.me) ? Theme.raise : "transparent"
                                    Behavior on color { ColorAnimation { duration: pop.quick } }

                                    DiscordAvatar {
                                        id: avatar
                                        x: 3
                                        anchors.verticalCenter: parent.verticalCenter
                                        member: person.m
                                        size: 26
                                    }

                                    Txt {
                                        anchors.left: avatar.right
                                        anchors.leftMargin: 8
                                        anchors.right: icons.left
                                        anchors.rightMargin: 8
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: person.me ? "You" : (person.m.name || "")
                                        color: person.m.speaking === true ? Theme.text : Theme.textMuted
                                        font.weight: Font.Normal
                                    }

                                    // Andere: nur Auffälliges. Du: Mic, Kopfhörer, Cam immer (Cam nur Anzeige).
                                    Row {
                                        id: icons
                                        anchors.right: parent.right
                                        anchors.rightMargin: 8
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: 6

                                        readonly property bool mute: person.me ? Discord.self.mute : person.m.mute === true
                                        readonly property bool deaf: person.me ? Discord.self.deaf : person.m.deaf === true
                                        // Kamera: true/false nur, wenn Discord es meldet; sonst unbekannt -> kein Symbol
                                        readonly property var video: person.me ? Discord.self.video : person.m.video
                                        readonly property int volume: person.m.volume === undefined ? 100 : person.m.volume

                                        MonoTxt {
                                            anchors.verticalCenter: parent.verticalCenter
                                            visible: !person.me && icons.volume !== 100 && person.m.localMute !== true
                                            text: icons.volume + " %"
                                            color: Theme.textFaint
                                            font.pixelSize: Theme.fontXs
                                        }
                                        StateIcon {
                                            visible: person.m.localMute === true
                                            name: "volume_off"
                                            color: Theme.accentText
                                        }
                                        StateIcon {
                                            id: strIcon
                                            visible: person.m.stream === true
                                            name: "screen_share"
                                            fill: Cams.isPinned(person.modelData + ":stream")
                                            color: fill ? Theme.accentText : Theme.success
                                        }
                                        StateIcon {
                                            id: camIcon
                                            visible: icons.video === true || (person.me && icons.video === false)
                                            name: icons.video === true ? "videocam" : "videocam_off"
                                            fill: Cams.isPinned(person.modelData)
                                            color: fill ? Theme.accentText : icons.video === true ? Theme.success : Theme.textFaint
                                        }
                                        StateIcon {
                                            visible: person.me || (icons.mute && !icons.deaf)
                                            name: icons.mute ? "mic_off" : "mic"
                                            color: icons.mute && person.me ? Theme.accentText : Theme.textFaint
                                        }
                                        StateIcon {
                                            visible: person.me || icons.deaf
                                            name: icons.deaf ? "headset_off" : "headset"
                                            color: icons.deaf && person.me ? Theme.accentText : Theme.textFaint
                                        }
                                    }

                                    MouseArea {
                                        id: rowArea
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        enabled: !person.me
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: pop.expandedId = person.open ? "" : person.modelData
                                    }
                                }

                                // Menü: Stumm (nur für dich) + Lautstärke 0–200 %
                                Reveal {
                                    shown: person.open
                                    gap: 4

                                    Rectangle {
                                        width: parent.width
                                        height: 40
                                        radius: Theme.radiusMd
                                        color: Theme.raise

                                        Row {
                                            visible: Discord.canControl
                                            anchors.fill: parent
                                            anchors.leftMargin: 4
                                            anchors.rightMargin: 10
                                            spacing: 6

                                            IconChip {
                                                anchors.verticalCenter: parent.verticalCenter
                                                glyph: person.m.localMute === true ? "volume_off" : "volume_up"
                                                active: person.m.localMute === true
                                                tint: person.m.localMute === true ? Theme.accentText : Theme.textMuted
                                                onClicked: Discord.setUserMute(person.modelData, person.m.localMute !== true)
                                            }
                                            Slider {
                                                id: vol
                                                anchors.verticalCenter: parent.verticalCenter
                                                width: parent.width - 34 - 48 - 12
                                                from: 0
                                                to: 200
                                                stepSize: 5
                                                value: person.m.volume === undefined ? 100 : person.m.volume
                                                enabled: person.m.localMute !== true
                                                onMoved: v => Discord.setUserVolume(person.modelData, v)
                                            }
                                            MonoTxt {
                                                anchors.verticalCenter: parent.verticalCenter
                                                width: 48
                                                horizontalAlignment: Text.AlignRight
                                                text: Math.round(vol.shown) + " %"
                                                color: Theme.textMuted
                                                font.pixelSize: Theme.fontSm
                                            }
                                        }
                                        Txt {
                                            visible: !Discord.canControl
                                            anchors.fill: parent
                                            anchors.leftMargin: 12
                                            anchors.rightMargin: 12
                                            text: "Controls aren’t authorized – re-link below."
                                            color: Theme.textFaint
                                            font.pixelSize: Theme.fontSm
                                            font.weight: Font.Normal
                                        }
                                    }
                                }
                            }
                        }

                        Txt {
                            visible: Discord.memberIds.length > pop.maxMembers
                            leftPadding: 6
                            text: "+ " + (Discord.memberIds.length - pop.maxMembers) + " more"
                            color: Theme.textFaint
                            font.pixelSize: Theme.fontSm
                            font.weight: Font.Normal
                        }
                    }

                    // eigene Steuerung: gleich breite Spalten (Kamera/Bildschirm nur mit Plugin), Verlassen als
                    // schmales Symbol rechts – Texte wechseln ohne Sprung
                    Item {
                        id: ctl
                        readonly property int cols: Discord.viaPlugin ? 4 : 2
                        readonly property real colW: (width - height - cols * 6) / cols
                        width: parent.width
                        height: 36

                        CtlBtn {
                            visible: Discord.canControl
                            x: 0
                            width: ctl.colW
                            icon: Discord.self.mute ? "mic_off" : "mic"
                            text: Discord.self.mute ? "Muted" : "Mic"
                            lit: Discord.self.mute === true
                            onClicked: Discord.setMute(!Discord.self.mute)
                        }
                        CtlBtn {
                            visible: Discord.canControl
                            x: ctl.colW + 6
                            width: ctl.colW
                            icon: Discord.self.deaf ? "headset_off" : "headset"
                            text: "Deafen"
                            lit: Discord.self.deaf === true
                            onClicked: Discord.setDeaf(!Discord.self.deaf)
                        }
                        CtlBtn {
                            visible: Discord.canControl && Discord.viaPlugin
                            x: (ctl.colW + 6) * 2
                            width: ctl.colW
                            icon: Discord.self.video ? "videocam" : "videocam_off"
                            text: "Cam"
                            lit: Discord.self.video === true
                            onClicked: Discord.setVideo(!Discord.self.video)
                        }
                        CtlBtn {
                            visible: Discord.canControl && Discord.viaPlugin
                            x: (ctl.colW + 6) * 3
                            width: ctl.colW
                            icon: Discord.self.stream ? "stop_screen_share" : "screen_share"
                            text: Discord.self.stream ? "Live" : "Stream"
                            lit: Discord.self.stream === true
                            onClicked: {
                                const start = !Discord.self.stream;
                                // Teilen startet: Popout sauber zu, bevor die Auswahl kommt (die hat Vorrang)
                                if (start)
                                    pop.close();
                                Discord.setStream(start);
                            }
                        }
                        CtlBtn {
                            visible: !Discord.canControl
                            x: 0
                            width: (ctl.colW + 6) * ctl.cols - 6
                            icon: "lock_open"
                            text: "Enable Controls"
                            onClicked: Discord.reauth()
                        }
                        // zweimal klicken, damit man nicht aus Versehen rausfliegt: beim ersten Mal wird der Knopf breit
                        // und fragt „Leave?“ (ein Haken sah aus wie „erledigt“ – man blieb im Call, ohne es zu merken)
                        CtlBtn {
                            z: 1
                            x: ctl.width - width
                            width: pop.confirmLeave ? ctl.colW + 6 + ctl.height : ctl.height
                            Behavior on width { NumberAnimation { duration: pop.quick; easing.type: Easing.OutCubic } }
                            icon: "call_end"
                            text: pop.confirmLeave ? "Leave?" : ""
                            danger: pop.confirmLeave
                            onClicked: {
                                if (!pop.confirmLeave) {
                                    pop.confirmLeave = true;
                                    leaveReset.restart();
                                    return;
                                }
                                pop.confirmLeave = false;
                                Discord.leave();
                            }
                        }
                    }
                }

                // ================= Rückfrage: schon in einem anderen Call =================
                Reveal {
                    id: askBox
                    shown: Discord.switchAsk !== null
                    property var ask: Discord.switchAsk || askBox.last
                    property var last: ({})
                    onAskChanged: if (Discord.switchAsk) last = Discord.switchAsk

                    Txt {
                        width: parent.width
                        wrapMode: Text.WordWrap
                        text: "You’re already in a call. Switch to “" + (askBox.ask.name || "?") + "”?"
                        color: Theme.text
                        font.weight: Font.Normal
                    }
                    Item {
                        width: parent.width
                        height: 36
                        CtlBtn {
                            width: (parent.width - 6) / 2
                            icon: "swap_horiz"
                            text: "Switch"
                            primary: true
                            onClicked: Discord.join(Discord.switchAsk, true)
                        }
                        CtlBtn {
                            x: (parent.width + 6) / 2
                            width: (parent.width - 6) / 2
                            text: "Cancel"
                            onClicked: Discord.switchAsk = null
                        }
                    }
                }

                // ================= Fehler (kurz) =================
                Reveal {
                    id: errBox
                    shown: Discord.lastError !== ""
                    gap: 10
                    property string last: ""
                    Connections {
                        target: Discord
                        function onLastErrorChanged() { if (Discord.lastError) errBox.last = Discord.lastError; }
                    }
                    Txt {
                        width: parent.width
                        wrapMode: Text.WordWrap
                        text: errBox.last
                        color: Theme.accentText
                        font.pixelSize: Theme.fontSm
                        font.weight: Font.Normal
                    }
                }

                // ================= Zustand (nicht verbunden) =================
                Reveal {
                    shown: !Discord.inVoice && !Discord.ready
                    gap: 4

                    Txt {
                        width: parent.width
                        wrapMode: Text.WordWrap
                        color: Theme.textMuted
                        font.weight: Font.Normal
                        text: {
                            switch (Discord.state) {
                            case "unconfigured":
                                return "Call info isn’t set up yet. Create your own Discord app once and link it.";
                            case "offline":
                                return Chat.title + " isn’t running.";
                            case "unsupported":
                                return Chat.title + " has no call API (only activity status). Call info needs the Desktop plugin – see docs/knowledge/discord.md.";
                            case "authorizing":
                                return "Click “Authorize” in Discord to link the desktop.";
                            case "denied":
                            case "error":
                                return "Not linked: " + (Discord.message || "unknown error");
                            default:
                                return "Connecting to " + Chat.title + "…";
                            }
                        }
                    }
                    // Anleitung (nur ohne Einrichtung)
                    Chip {
                        visible: Discord.state === "unconfigured"
                        padding: 6
                        onClicked: Launch.cmd(["xdg-open", Quickshell.shellDir + "/../docs/setup/discord.md"])
                        Icon {
                            anchors.verticalCenter: parent.verticalCenter
                            name: "menu_book"
                            size: 16
                        }
                        MonoTxt {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "docs/setup/discord.md"
                            color: Theme.textMuted
                            font.pixelSize: Theme.fontSm
                        }
                    }
                    CtlBtn {
                        visible: Discord.state === "denied" || Discord.state === "error"
                        width: parent.width
                        icon: "link"
                        text: "Link Again"
                        onClicked: Discord.retry()
                    }
                }

                // ================= Kanal-Auswahl (ohne Call) =================
                Reveal {
                    id: picker
                    shown: !Discord.inVoice && Discord.ready
                    gap: 4
                    spacing: 2

                    readonly property var recentOnly: Discord.recents.filter(r => !Discord.isFavorite(r.id))

                    // Favoriten
                    Reveal {
                        shown: Discord.favorites.length > 0
                        gap: 4
                        spacing: 2
                        Label {
                            text: "Favorites"
                            bottomPadding: 4
                        }
                        Repeater {
                            model: Discord.favorites
                            ChannelRow {
                                required property var modelData
                                ch: modelData
                                guildId: modelData.guildId || ""
                                guildName: modelData.guildName || ""
                                showGuild: true
                                people: (Discord.peeks[modelData.id] || {}).members || []
                            }
                        }
                    }

                    // zuletzt genutzt (ohne Favoriten)
                    Reveal {
                        shown: picker.recentOnly.length > 0
                        gap: 10
                        spacing: 2
                        Label {
                            text: "Recent"
                            bottomPadding: 4
                        }
                        Repeater {
                            model: picker.recentOnly
                            ChannelRow {
                                required property var modelData
                                ch: modelData
                                guildId: modelData.guildId || ""
                                guildName: modelData.guildName || ""
                                showGuild: true
                                people: (Discord.peeks[modelData.id] || {}).members || []
                            }
                        }
                    }

                    // Server → Sprachkanäle (erst beim Aufklappen geladen)
                    Reveal {
                        gap: Discord.favorites.length > 0 || picker.recentOnly.length > 0 ? 10 : 0
                        spacing: 2
                        Label {
                            text: "Servers"
                            bottomPadding: 4
                        }
                        Txt {
                            visible: Discord.guilds.length === 0
                            leftPadding: 4
                            text: Discord.guildsLoading ? "Loading servers…" : "No servers found"
                            color: Theme.textFaint
                            font.pixelSize: Theme.fontSm
                            font.weight: Font.Normal
                        }
                        Repeater {
                            model: Discord.guilds

                            Column {
                                id: guild
                                required property var modelData
                                readonly property bool open: pop.openGuild === modelData.id
                                readonly property var info: Discord.channels[modelData.id] || ({ loading: false, list: [] })
                                width: body.width

                                Rectangle {
                                    width: parent.width
                                    height: 36
                                    radius: Theme.radiusMd
                                    color: guild.open || gArea.containsMouse ? Theme.raise : "transparent"
                                    Behavior on color { ColorAnimation { duration: pop.quick } }

                                    DiscordAvatar {
                                        id: gIcon
                                        x: 3
                                        anchors.verticalCenter: parent.verticalCenter
                                        member: ({ name: guild.modelData.name, avatarUrl: guild.modelData.iconUrl })
                                        size: 22
                                    }
                                    Txt {
                                        anchors.left: gIcon.right
                                        anchors.leftMargin: 8
                                        anchors.right: chev.left
                                        anchors.rightMargin: 8
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: guild.modelData.name
                                        color: guild.open ? Theme.text : Theme.textMuted
                                    }
                                    Icon {
                                        id: chev
                                        anchors.right: parent.right
                                        anchors.rightMargin: 8
                                        anchors.verticalCenter: parent.verticalCenter
                                        name: "expand_more"
                                        size: 18
                                        color: Theme.textFaint
                                        rotation: guild.open ? 180 : 0
                                        Behavior on rotation { NumberAnimation { duration: Theme.fade; easing.type: Easing.OutCubic } }
                                    }
                                    MouseArea {
                                        id: gArea
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: pop.toggleGuild(guild.modelData.id)
                                    }
                                }

                                Reveal {
                                    shown: guild.open
                                    gap: 2
                                    spacing: 0
                                    Repeater {
                                        model: guild.open ? guild.info.list : []
                                        ChannelRow {
                                            required property var modelData
                                            ch: modelData
                                            guildId: guild.modelData.id
                                            guildName: guild.modelData.name
                                            indent: 12
                                            people: modelData.members || []
                                        }
                                    }
                                    Txt {
                                        visible: guild.info.list.length === 0
                                        leftPadding: 36
                                        height: 30
                                        text: guild.info.loading ? "Loading channels…" : "No voice channels"
                                        color: Theme.textFaint
                                        font.pixelSize: Theme.fontSm
                                        font.weight: Font.Normal
                                    }
                                }
                            }
                        }
                    }
                }

                // ================= Chats (secrets.json) =================
                Reveal {
                    shown: Discord.dms.length > 0
                    gap: 14

                    Rectangle {
                        width: parent.width
                        height: 1
                        color: Theme.border
                    }
                    Label {
                        text: "Chats"
                    }
                    Flow {
                        width: parent.width
                        spacing: 6

                        Repeater {
                            model: Discord.dms

                            Chip {
                                required property var modelData
                                padding: 8
                                color: hovered ? Qt.alpha(Theme.text, 0.1) : Theme.raise
                                onClicked: Discord.openChat(modelData.id)
                                Icon {
                                    anchors.verticalCenter: parent.verticalCenter
                                    name: "chat_bubble"
                                    size: 15
                                }
                                Txt {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: Math.min(implicitWidth, 140)
                                    text: modelData.name
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

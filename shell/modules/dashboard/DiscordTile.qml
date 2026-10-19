import QtQuick
import Quickshell
import qs.config
import qs.services
import qs.components
import qs.modules.bar

// Discord kompakt (Logik wie im Bar-Popout, nur ruhiger):
// Im Call: Kanal + Dauer, Köpfe mit Sprech-Ring, eigene Steuerung (Mic, Taub, Verlassen).
// Ohne Call: Favoriten + zuletzt genutzte Sprachkanäle (Klick = beitreten), darunter die festen Chats.
// Nicht eingerichtet/offline: leiser Hinweis, Chats gehen trotzdem (Deep-Link).
Tile {
    id: tile

    // Dashboard offen = Fenster sichtbar (Item.visible bleibt auch bei verstecktem Fenster true)
    readonly property bool shown: QsWindow.window ? QsWindow.window.visible : visible
    readonly property int headCell: 62
    readonly property int maxHeads: 14          // zwei Reihen
    readonly property int quick: Math.round(Theme.fade * 0.6)
    property bool confirmLeave: false

    // Favoriten zuerst, dann zuletzt genutzt (ohne Doppelte)
    readonly property var saved: Discord.favorites.map(c => Object.assign({ fav: true }, c))
        .concat(Discord.recents.filter(r => !Discord.isFavorite(r.id)).map(c => Object.assign({ fav: false }, c)))

    title: Chat.title
    note: Discord.lastError !== "" ? Discord.lastError : Discord.inVoice ? duration() : ""
    actions: ParkButton {
        part: "discord"
    }

    // ---------- Dauer: "4 min", "1 h 05" ----------
    property real now: Date.now()
    Timer {
        interval: 30000
        repeat: true
        running: tile.shown && Discord.inVoice
        triggeredOnStart: true
        onTriggered: tile.now = Date.now()
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

    // wer gerade in den gemerkten Kanälen ist – nur solange das Dashboard offen ist (Bridge cacht 30 s)
    Timer {
        interval: 30000
        repeat: true
        running: tile.shown && Discord.ready && !Discord.inVoice
        triggeredOnStart: true
        onTriggered: Discord.peekSaved()
    }
    Timer {
        id: leaveReset
        interval: 3000
        onTriggered: tile.confirmLeave = false
    }
    onShownChanged: if (!shown) confirmLeave = false

    // ---------- Bausteine ----------

    // weich ein-/ausblenden statt hart umschalten
    component Pane: Item {
        property bool open: false
        anchors.fill: parent
        opacity: open ? 1 : 0
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: Theme.fade; easing.type: Easing.OutCubic } }
    }

    // Sprachkanal: Klick = beitreten; Köpfe = wer gerade drin ist
    component ChannelChip: Chip {
        id: cc
        property var ch: ({})
        readonly property var people: (Discord.peeks[ch.id] || {}).members || []
        height: 34
        padding: 10
        color: hovered ? Qt.alpha(Theme.text, 0.1) : Theme.raise
        border.width: 1
        border.color: Theme.border
        onClicked: Discord.join(ch, false)

        Icon {
            anchors.verticalCenter: parent.verticalCenter
            name: cc.ch.fav ? "star" : "history"
            fill: cc.ch.fav === true
            size: 15
            color: cc.people.length > 0 ? Theme.success : Theme.textFaint
        }
        Row {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6
            Txt {
                anchors.verticalCenter: parent.verticalCenter
                width: Math.min(implicitWidth, 150)
                text: cc.ch.name || "?"
                color: cc.people.length > 0 ? Theme.text : Theme.textMuted
            }
            Txt {
                anchors.verticalCenter: parent.verticalCenter
                visible: text !== ""
                width: Math.min(implicitWidth, 90)
                text: cc.ch.guildName || ""
                color: Theme.textFaint
                font.pixelSize: 12
                font.weight: Font.Normal
            }
        }
        Row {
            anchors.verticalCenter: parent.verticalCenter
            visible: cc.people.length > 0
            spacing: -6
            Repeater {
                model: cc.people.slice(0, 3)
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
                visible: cc.people.length > 3
                leftPadding: 8
                text: "+" + (cc.people.length - 3)
                color: Theme.textMuted
                font.pixelSize: 11
            }
        }
    }

    // ================= Call =================
    Pane {
        id: call
        open: Discord.inVoice

        readonly property int shownHeads: Discord.memberIds.length > tile.maxHeads ? tile.maxHeads - 1 : tile.maxHeads

        Row {
            id: chan
            width: parent.width
            height: 26
            spacing: 8
            Icon {
                anchors.verticalCenter: parent.verticalCenter
                name: "volume_up"
                size: 18
                color: Theme.success
            }
            Txt {
                id: chanName
                anchors.verticalCenter: parent.verticalCenter
                width: Math.min(implicitWidth, chan.width - 26)
                text: Discord.channelName
                font.pixelSize: 16
                font.weight: Font.DemiBold
            }
            Txt {
                anchors.verticalCenter: parent.verticalCenter
                visible: Discord.guildName !== ""
                width: Math.max(0, Math.min(implicitWidth, chan.width - 26 - chanName.width - 8))
                text: Discord.guildName
                color: Theme.textFaint
                font.weight: Font.Normal
            }
        }

        // Köpfe: grüner Ring = spricht; kleines Abzeichen bei stumm/taub
        Flow {
            anchors.top: chan.bottom
            anchors.topMargin: 14
            anchors.bottom: ctl.top
            anchors.bottomMargin: 12
            width: parent.width
            spacing: 10
            clip: true

            Repeater {
                model: Discord.memberIds.slice(0, call.shownHeads)

                Column {
                    id: person
                    required property string modelData
                    readonly property var m: Discord.memberMap[modelData] || ({})
                    readonly property bool me: m.isSelf === true
                    readonly property bool mute: me ? Discord.self.mute === true : m.mute === true
                    readonly property bool deaf: me ? Discord.self.deaf === true : m.deaf === true
                    width: tile.headCell
                    spacing: 2

                    Item {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: face.implicitWidth
                        height: face.implicitHeight
                        DiscordAvatar {
                            id: face
                            member: person.m
                            size: 40
                        }
                        Rectangle {
                            visible: person.mute || person.deaf || person.m.localMute === true
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            width: 18
                            height: 18
                            radius: 9
                            color: Theme.surface
                            border.width: 1
                            border.color: Theme.border
                            Icon {
                                anchors.centerIn: parent
                                name: person.deaf ? "headset_off" : person.mute ? "mic_off" : "volume_off"
                                size: 12
                                color: person.me ? Theme.accentText : Theme.textFaint
                            }
                        }
                    }
                    Txt {
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        text: person.me ? "You" : (person.m.name || "")
                        color: person.m.speaking === true ? Theme.text : Theme.textMuted
                        font.pixelSize: 12
                        font.weight: Font.Normal
                    }
                }
            }
            // mehr als zwei Reihen: Rest als "+n"
            Item {
                visible: Discord.memberIds.length > tile.maxHeads
                width: tile.headCell
                height: 46
                Rectangle {
                    anchors.centerIn: parent
                    width: 40
                    height: 40
                    radius: 20
                    color: Theme.raise
                    border.width: 1
                    border.color: Theme.border
                    MonoTxt {
                        anchors.centerIn: parent
                        text: "+" + (Discord.memberIds.length - call.shownHeads)
                        color: Theme.textMuted
                        font.pixelSize: 12
                    }
                }
            }
        }

        // eigene Steuerung: drei gleich breite Spalten
        Item {
            id: ctl
            readonly property real colW: (width - 16) / 3
            anchors.bottom: parent.bottom
            width: parent.width
            height: 36

            Button {
                visible: Discord.canControl
                width: ctl.colW
                icon: Discord.self.mute ? "mic_off" : "mic"
                text: Discord.self.mute ? "Muted" : "Mic"
                primary: Discord.self.mute === true
                onClicked: Discord.setMute(!Discord.self.mute)
            }
            Button {
                visible: Discord.canControl
                x: ctl.colW + 8
                width: ctl.colW
                icon: Discord.self.deaf ? "headset_off" : "headset"
                text: "Deafen"
                primary: Discord.self.deaf === true
                onClicked: Discord.setDeaf(!Discord.self.deaf)
            }
            Button {
                visible: !Discord.canControl
                width: ctl.colW * 2 + 8
                icon: "lock_open"
                text: "Unlock controls"
                onClicked: Discord.reauth()
            }
            // zweimal klicken, damit man nicht aus Versehen rausfliegt
            Button {
                x: (ctl.colW + 8) * 2
                width: ctl.colW
                icon: "call_end"
                text: tile.confirmLeave ? "Sure?" : "Leave"
                primary: tile.confirmLeave
                onClicked: {
                    if (!tile.confirmLeave) {
                        tile.confirmLeave = true;
                        leaveReset.restart();
                        return;
                    }
                    tile.confirmLeave = false;
                    Discord.leave();
                }
            }
        }
    }

    // ================= Ohne Call =================
    Pane {
        open: !Discord.inVoice

        // ---- verbunden: gemerkte Sprachkanäle ----
        Item {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: chats.visible ? chats.top : parent.bottom
            anchors.bottomMargin: chats.visible ? 16 : 0
            visible: Discord.ready

            Label {
                id: chLabel
                text: "Voice channels"
            }

            Flow {
                anchors.top: chLabel.bottom
                anchors.topMargin: 10
                anchors.bottom: parent.bottom
                width: parent.width
                spacing: 6
                clip: true
                visible: Discord.switchAsk === null

                Repeater {
                    model: tile.saved
                    ChannelChip {
                        required property var modelData
                        ch: modelData
                    }
                }
                Txt {
                    visible: tile.saved.length === 0
                    width: parent.width
                    wrapMode: Text.WordWrap
                    text: "Nothing saved yet. Star channels in the Discord popout to keep them here."
                    color: Theme.textFaint
                    font.weight: Font.Normal
                }
            }

            // schon in einem anderen Call -> nachfragen statt einfach wechseln
            Column {
                anchors.top: chLabel.bottom
                anchors.topMargin: 10
                width: parent.width
                spacing: 10
                visible: Discord.switchAsk !== null

                Txt {
                    width: parent.width
                    wrapMode: Text.WordWrap
                    text: "You’re already in a call. Switch to “" + ((Discord.switchAsk || {}).name || "?") + "”?"
                    font.weight: Font.Normal
                }
                Row {
                    spacing: 8
                    Button {
                        icon: "swap_horiz"
                        text: "Switch"
                        primary: true
                        onClicked: Discord.join(Discord.switchAsk, true)
                    }
                    Button {
                        text: "Cancel"
                        onClicked: Discord.switchAsk = null
                    }
                }
            }
        }

        // ---- nicht verbunden: leiser Hinweis ----
        Column {
            anchors.left: parent.left
            anchors.right: parent.right
            visible: !Discord.ready
            spacing: 10

            Row {
                width: parent.width
                spacing: 10
                Icon {
                    id: hintIcon
                    name: Discord.state === "offline" ? "cloud_off" : Discord.state === "unconfigured" ? "settings" : "link"
                    size: 18
                    color: Theme.textFaint
                }
                Txt {
                    width: parent.width - hintIcon.width - 10
                    wrapMode: Text.WordWrap
                    color: Theme.textMuted
                    font.weight: Font.Normal
                    text: {
                        switch (Discord.state) {
                        case "unconfigured":
                            return "Call info isn’t set up yet. Create your own Discord app once and pair it.";
                        case "offline":
                            return Chat.title + " isn’t running.";
                        case "unsupported":
                            return Chat.title + " has no call API. Call info needs the Desktop plugin (docs/knowledge/discord.md).";
                        case "authorizing":
                            return "Click “Authorize” in Discord to pair the desktop.";
                        case "denied":
                        case "error":
                            return "Not paired: " + (Discord.message || "unknown error");
                        default:
                            return "Connecting to " + Chat.title + "…";
                        }
                    }
                }
            }
            // Anleitung (nur ohne Einrichtung)
            Chip {
                visible: Discord.state === "unconfigured"
                padding: 8
                color: hovered ? Qt.alpha(Theme.text, 0.1) : Theme.raise
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
                    font.pixelSize: 12
                }
            }
            Button {
                visible: Discord.state === "denied" || Discord.state === "error"
                icon: "link"
                text: "Pair again"
                onClicked: Discord.retry()
            }
        }

        // ---- feste Chats (secrets.json): gehen auch ohne Kopplung (Deep-Link) ----
        Column {
            id: chats
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            visible: Discord.dms.length > 0
            spacing: 10

            Rectangle {
                width: parent.width
                height: 1
                color: Theme.border
            }
            Label {
                text: "Chats"
            }
            // höchstens zwei Reihen
            Flow {
                width: parent.width
                height: Math.min(implicitHeight, 34 * 2 + 6)
                spacing: 6
                clip: true

                Repeater {
                    model: Discord.dms

                    Chip {
                        required property var modelData
                        height: 34
                        padding: 10
                        color: hovered ? Qt.alpha(Theme.text, 0.1) : Theme.raise
                        border.width: 1
                        border.color: Theme.border
                        onClicked: {
                            Discord.openChat(modelData.id);
                            // holt das Discord-Fenster raus -> Dashboard macht Platz
                            Launch.launched();
                        }
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

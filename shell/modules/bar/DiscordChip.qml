import QtQuick
import Quickshell
import QtQuick.Effects
import qs.config
import qs.services
import qs.components

// Chat-Client (Discord, Chat.qml) als Einbettung: Klick öffnet das Popout (Call, Steuerung, Chats, Rausholen) – wie bei Spotify.
// Im Call: Köpfe der Leute (grüner Ring = spricht), ab 4 überlappend, dazu "+n". Dein Mic-Status steht nur im Popout.
// Leute, deren Kamera im Kamera-Overlay läuft, fehlen hier (sie sind ja im Overlay zu sehen).
Chip {
    id: chip
    hintKey: BarKeys.keyFor("discord")   // Bar-Modus (Super+Leertaste)

    property var barWindow: QsWindow.window

    // wer gerade im Kamera-Overlay zu sehen ist, braucht keinen Kopf in der Bar (mehr Platz)
    readonly property var ids: Discord.inVoice ? Discord.memberIds.filter(id => Cams.paused || !Cams.isPinned(id)) : []
    readonly property int total: ids.length
    readonly property int maxHeads: 5
    // bei mehr als 5: vier Köpfe + "+n"
    readonly property var heads: ids.slice(0, total > maxHeads ? maxHeads - 1 : maxHeads)
    readonly property int more: total - heads.length
    readonly property bool overlap: total >= 4

    padding: 7
    active: Parked.out.discord === true || popout.visible
    // Klick irgendwo auf den Chip = Popout auf/zu (Lautstärke pro Person, Kameras an/aus im Popout)
    onClicked: popout.toggle()

    // Discord-Logo – immer, egal welcher Client (Discord-RPM/Flatpak, alt Equibop) läuft oder ob er weggeräumt ist. Einfarbig in Theme-Farbe.
    Image {
        id: logo
        anchors.verticalCenter: parent.verticalCenter
        width: 18
        height: 18
        source: Qt.resolvedUrl("../../assets/discord.png")
        sourceSize.width: 72
        sourceSize.height: 72
        smooth: true
        opacity: Parked.out.discord === true || Discord.inVoice ? 1 : 0.8
        layer.enabled: true
        layer.effect: MultiEffect {
            colorization: 1.0
            colorizationColor: Parked.out.discord === true || Discord.inVoice ? Theme.text : Theme.textMuted
        }
    }

    Row {
        id: faces
        anchors.verticalCenter: parent.verticalCenter
        visible: chip.total > 0
        spacing: 4

        Row {
            id: stack
            anchors.verticalCenter: parent.verticalCenter
            spacing: chip.overlap ? -8 : 2

            Repeater {
                model: chip.heads

                DiscordAvatar {
                    required property string modelData
                    readonly property string uid: modelData
                    anchors.verticalCenter: parent ? parent.verticalCenter : undefined
                    member: Discord.memberMap[modelData] || ({})
                    size: 20
                    badge: true
                    fade: false   // Ring sofort wie in Discord, spart Neuzeichnen (siehe DiscordAvatar)
                    // beim Überlappen trennt ein dunkler Rand die Köpfe
                    edge: chip.overlap ? Theme.bg : "transparent"
                }
            }
        }
        MonoTxt {
            anchors.verticalCenter: parent.verticalCenter
            visible: chip.more > 0
            text: "+" + chip.more
            color: Theme.textMuted
            font.pixelSize: 12
        }
    }

    DiscordPopout {
        id: popout
        barWindow: chip.barWindow
        chip: chip
    }
}

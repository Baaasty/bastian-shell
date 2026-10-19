import QtQuick
import qs.config
import qs.services

// Ein GoXLR-Kanalpegel zum Ansehen. Gemeinsam für GoxlrPanel (Dashboard) und Sound-Popout.
// key = Kanalname wie in GoXLR.levelChannels (System, Music, Chat, Mic, Game, Sample, Headphones). Unsichtbar, wenn der Kanal fehlt.
// Zwei Formen:
//  - nameW = 0 (Standard, Dashboard-Raster): Name links + Prozent rechts, darunter ein schmaler Balken
//  - nameW > 0 (Sound-Popout, eine Zeile): Name (nameW breit) · Balken · Prozent (pctW breit, rechtsbündig) –
//    gleich gebaut wie die Routing-Zeilen und App-Regler darüber/darunter
Item {
    id: lv

    property string key
    property int nameW: 0
    property int pctW: 48
    readonly property bool inline: nameW > 0
    readonly property var level: GoXLR.levels.find(l => l.key === key) || null
    readonly property bool muted: !!level && level.muted

    visible: GoXLR.online && level !== null
    implicitWidth: 160
    implicitHeight: visible ? (inline ? 30 : 32) : 0
    height: implicitHeight

    Txt {
        anchors.left: parent.left
        width: lv.inline ? lv.nameW : undefined
        anchors.right: lv.inline ? undefined : pct.left
        anchors.rightMargin: 6
        height: lv.inline ? parent.height : 18
        text: lv.level ? lv.level.label : ""
        color: lv.muted ? Theme.warning : Theme.textMuted
        font.pixelSize: lv.inline ? 13 : 12
        font.weight: Font.Normal
    }
    MonoTxt {
        id: pct
        anchors.right: parent.right
        width: lv.inline ? lv.pctW : implicitWidth
        height: lv.inline ? parent.height : 18
        horizontalAlignment: Text.AlignRight
        verticalAlignment: Text.AlignVCenter
        text: !lv.level ? "" : lv.muted ? "mute" : lv.level.pct + "%"
        color: lv.muted ? Theme.warning : lv.inline ? Theme.textMuted : Theme.textFaint
        font.pixelSize: lv.inline ? 12 : 11
    }
    Rectangle {
        x: lv.inline ? lv.nameW + 12 : 0
        y: lv.inline ? Math.round((parent.height - height) / 2) : parent.height - 4 - height
        width: lv.inline ? Math.max(0, parent.width - x - lv.pctW - 12) : parent.width
        height: 4
        radius: 2
        color: Theme.borderStrong
        Rectangle {
            width: parent.width * Math.max(0, Math.min(1, lv.level ? lv.level.pct / 100 : 0))
            height: parent.height
            radius: 2
            color: lv.muted ? Theme.warning : Theme.woodLight
        }
    }
}

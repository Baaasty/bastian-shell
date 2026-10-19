import QtQuick
import qs.config
import qs.services
import qs.components

// Eine Zeile Git/CI für Tooltip und Popup (Idee o): Branch · Änderungen · ahead/behind · CI.
// Unsichtbar, solange es keine Daten gibt (kein Projekt, kein Git-Ordner).
Row {
    id: tip

    property var proj: null
    property int textSize: 14
    readonly property var g: proj ? GitInfo.git[proj.id] : undefined
    readonly property var c: proj ? GitInfo.ci[proj.id] : undefined
    readonly property bool hasCi: !!c && !(c.state === "none" && c.status === "")   // Repo ohne CI: nichts zeigen
    readonly property string ciText: !c ? "" : c.state === "ok" ? "CI passing" : c.state === "fail" ? "CI failing" : c.state === "running" ? "CI running" : "CI: no result"
    readonly property color ciColor: !c ? Theme.textFaint : c.state === "ok" ? Theme.success : c.state === "fail" ? Theme.error : Theme.textMuted

    visible: !!g && g.branch !== ""
    spacing: 7

    Icon {
        anchors.verticalCenter: parent.verticalCenter
        name: "fork_right"
        size: tip.textSize + 3
        color: Theme.textMuted
    }
    Txt {
        anchors.verticalCenter: parent.verticalCenter
        text: tip.g ? tip.g.branch : ""
        color: Theme.text
        font.pixelSize: tip.textSize
    }
    Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        visible: !!tip.g && tip.g.changes > 0
        width: 8
        height: 8
        radius: 4
        color: Theme.warning
    }
    Txt {
        anchors.verticalCenter: parent.verticalCenter
        text: !tip.g ? "" : tip.g.changes > 0 ? tip.g.changes + (tip.g.changes === 1 ? " change" : " changes") : "clean"
        color: Theme.textMuted
        font.pixelSize: tip.textSize
    }
    Txt {
        anchors.verticalCenter: parent.verticalCenter
        visible: !!tip.g && (tip.g.ahead > 0 || tip.g.behind > 0)
        text: tip.g ? (tip.g.ahead > 0 ? "↑" + tip.g.ahead : "") + (tip.g.ahead > 0 && tip.g.behind > 0 ? " " : "") + (tip.g.behind > 0 ? "↓" + tip.g.behind : "") : ""
        color: Theme.textMuted
        font.pixelSize: tip.textSize
    }
    Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        visible: tip.hasCi
        width: 8
        height: 8
        radius: 4
        color: tip.c && tip.c.state === "running" ? "transparent" : tip.ciColor
        border.width: tip.c && tip.c.state === "running" ? 2 : 0
        border.color: Theme.textFaint
    }
    Txt {
        anchors.verticalCenter: parent.verticalCenter
        visible: tip.hasCi
        text: tip.ciText
        color: tip.ciColor
        font.pixelSize: tip.textSize
    }
}

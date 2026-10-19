import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services
import qs.components

// Coding: Kennzahlen von heute (Claude-Code, Zeilen, Commits), darunter
// Claude-5-h-Fenster und die letzten 7 Tage (Zeilen + Commits je Tag).
// Hover über einen früheren Tag: Kennzahlen oben zeigen diesen Tag.
Tile {
    id: tile
    title: "Coding"

    // gehoverter früherer Tag (heute = Live-Werte)
    readonly property var hd: week.hd && week.hovered !== DevStats.week.length - 1 ? week.hd : null
    // Claude-Zähler des Tages: { tokens, input, output, cacheCreate, cacheRead, requests }
    readonly property var cl: hd ? hd.claude : (DevStats.usageOk ? DevStats : null)
    readonly property bool codeOk: hd !== null || DevStats.codeOk
    readonly property int added: hd ? hd.added : DevStats.added
    readonly property int removed: hd ? hd.removed : DevStats.removed
    readonly property int commits: hd ? hd.count : DevStats.commits

    // Spalte: große Zahl, Beschriftung, Zusatzwert – zentriert, gleich breit
    component Stat: Item {
        id: stat
        property string value
        property string caption
        property string sub
        default property alias extra: big.data

        Layout.fillWidth: true
        Layout.preferredWidth: 1
        implicitHeight: col.implicitHeight

        ColumnLayout {
            id: col
            anchors.horizontalCenter: parent.horizontalCenter
            width: Math.min(implicitWidth, stat.width)
            spacing: 4
            Item {
                id: big
                Layout.alignment: Qt.AlignHCenter
                implicitWidth: Math.max(num.implicitWidth, ...Array.from(big.children, c => c === num ? 0 : c.implicitWidth))
                implicitHeight: 28
                MonoTxt {
                    id: num
                    anchors.centerIn: parent
                    visible: stat.value !== ""
                    text: stat.value
                    color: Theme.text
                    font.pixelSize: 22
                    font.weight: Font.DemiBold
                }
            }
            Txt {
                Layout.alignment: Qt.AlignHCenter
                text: stat.caption
                color: Theme.textMuted
                font.pixelSize: 13
                font.weight: Font.Normal
            }
            MonoTxt {
                Layout.alignment: Qt.AlignHCenter
                Layout.maximumWidth: stat.width
                text: stat.sub || " "
                color: Theme.textFaint
                font.pixelSize: 12
                elide: Text.ElideRight
            }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 18

        // Kennzahlen
        RowLayout {
            Layout.fillWidth: true
            spacing: 16

            Stat {
                value: tile.cl ? DevStats.fmtTokens(tile.cl.tokens) : "–"
                caption: "Claude tokens"
                sub: tile.cl ? "≈ " + DevStats.fmtLiters(DevStats.litersOf(tile.cl)) + " water" : ""
            }
            Stat {
                value: tile.cl ? String(tile.cl.requests) : "–"
                caption: "Claude requests"
                sub: tile.cl && tile.cl.requests > 0 ? "avg " + DevStats.fmtTokens(tile.cl.tokens / tile.cl.requests) + " per request" : ""
            }
            Stat {
                caption: "Lines"
                sub: tile.codeOk ? "net " + (tile.added >= tile.removed ? "+" : "−") + Math.abs(tile.added - tile.removed) : ""
                Row {
                    anchors.centerIn: parent
                    spacing: 8
                    MonoTxt {
                        text: tile.codeOk ? "+" + tile.added : "–"
                        color: tile.codeOk ? Theme.success : Theme.text
                        font.pixelSize: 22
                        font.weight: Font.DemiBold
                    }
                    MonoTxt {
                        visible: tile.codeOk
                        text: "−" + tile.removed
                        color: Theme.accentText
                        font.pixelSize: 22
                        font.weight: Font.DemiBold
                    }
                }
            }
            Stat {
                value: tile.codeOk ? String(tile.commits) : "–"
                caption: tile.commits === 1 ? "Commit" : "Commits"
                sub: tile.hd ? "" : DevStats.topRepo
            }
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 1
            color: Theme.border
        }

        // unten: 5-h-Fenster | Woche
        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 48

            // Claude-5-h-Fenster
            ColumnLayout {
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                Layout.alignment: Qt.AlignVCenter
                spacing: 10

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 9
                    Icon {
                        name: "hourglass_bottom"
                        size: 16
                        color: Theme.textFaint
                    }
                    Txt {
                        Layout.fillWidth: true
                        text: "Claude · 5-hour window"
                        color: Theme.textMuted
                        font.pixelSize: 13
                        font.weight: Font.Normal
                    }
                    MonoTxt {
                        text: DevStats.windowActive ? "Resets in " + DevStats.fmtDur(DevStats.resetIn) : "available"
                        color: DevStats.windowActive ? Theme.text : Theme.textFaint
                        font.pixelSize: 13
                    }
                }
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 8
                    radius: 4
                    color: Theme.borderStrong
                    Rectangle {
                        width: parent.width * DevStats.windowProgress
                        height: parent.height
                        radius: 4
                        color: Theme.woodLight
                        Behavior on width { NumberAnimation { duration: Theme.stateChange; easing.type: Easing.OutCubic } }
                    }
                }
                RowLayout {
                    Layout.fillWidth: true
                    MonoTxt {
                        Layout.fillWidth: true
                        text: DevStats.windowActive ? DevStats.fmtTokens(DevStats.windowTokens) + " tokens in window" : "no window open"
                        color: Theme.textFaint
                        font.pixelSize: 12
                    }
                    MonoTxt {
                        visible: DevStats.windowActive
                        text: Qt.formatTime(new Date(DevStats.windowStart), "HH:mm") + " – " + Qt.formatTime(new Date(DevStats.windowReset), "HH:mm")
                        color: Theme.textFaint
                        font.pixelSize: 12
                    }
                }
            }

            // letzte 7 Tage: Balken = geänderte Zeilen (+ unten, − oben), Zahl darüber = Commits
            Item {
                id: week
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                Layout.fillHeight: true

                property int hovered: -1
                readonly property var hd: hovered >= 0 && hovered < DevStats.week.length ? DevStats.week[hovered] : null

                Txt {
                    id: weekHead
                    anchors.left: parent.left
                    text: week.hd ? week.hd.label : "Last 7 days"
                    color: Theme.textMuted
                    font.pixelSize: 13
                    font.weight: Font.Normal
                }
                // Hover: der Tag, sonst die Woche
                MonoTxt {
                    anchors.right: parent.right
                    anchors.verticalCenter: weekHead.verticalCenter
                    readonly property int c: week.hd ? week.hd.count : DevStats.weekCommits
                    text: c + (c === 1 ? " Commit" : " Commits") + " · +" + (week.hd ? week.hd.added : DevStats.weekAdded) + " −" + (week.hd ? week.hd.removed : DevStats.weekRemoved)
                    color: week.hd ? Theme.textMuted : Theme.textFaint
                    font.pixelSize: 12
                }

                Row {
                    id: bars
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: weekHead.bottom
                    anchors.topMargin: 6
                    anchors.bottom: parent.bottom
                    readonly property real colW: width / 7

                    Repeater {
                        model: DevStats.week
                        Item {
                            id: col
                            required property var modelData
                            required property int index
                            readonly property bool today: index === DevStats.week.length - 1
                            readonly property bool lit: today || week.hovered === index
                            readonly property int lines: modelData.added + modelData.removed
                            width: bars.colW
                            height: bars.height

                            Txt {
                                id: day
                                anchors.horizontalCenter: parent.horizontalCenter
                                anchors.bottom: parent.bottom
                                text: col.modelData.label
                                color: col.today ? Theme.accentText : (col.lit ? Theme.text : Theme.textMuted)
                                font.pixelSize: 13
                                font.weight: col.today ? Font.DemiBold : Font.Normal
                            }
                            Item {
                                id: bar
                                readonly property real maxH: parent.height - day.height - num.height - 10
                                anchors.horizontalCenter: parent.horizontalCenter
                                anchors.bottom: day.top
                                anchors.bottomMargin: 6
                                width: Math.min(22, bars.colW - 14)
                                height: DevStats.weekLinesMax > 0 && col.lines > 0 ? Math.max(6, maxH * col.lines / DevStats.weekLinesMax) : 2
                                Behavior on height { NumberAnimation { duration: Theme.stateChange; easing.type: Easing.OutCubic } }

                                // leerer Tag: flacher Strich
                                Rectangle {
                                    anchors.fill: parent
                                    visible: col.lines === 0
                                    radius: 1
                                    color: Theme.borderStrong
                                }
                                // gelöscht (oben)
                                Rectangle {
                                    visible: col.modelData.removed > 0
                                    anchors.top: parent.top
                                    width: parent.width
                                    height: Math.max(2, (parent.height - 2) * col.modelData.removed / Math.max(1, col.lines))
                                    radius: 3
                                    color: Qt.alpha(Theme.accentText, col.lit ? 0.85 : 0.4)
                                    Behavior on color { ColorAnimation { duration: Theme.fade } }
                                }
                                // hinzugefügt (unten)
                                Rectangle {
                                    visible: col.modelData.added > 0
                                    anchors.bottom: parent.bottom
                                    width: parent.width
                                    height: Math.max(2, (parent.height - (col.modelData.removed > 0 ? 2 : 0)) * col.modelData.added / Math.max(1, col.lines))
                                    radius: 3
                                    color: Qt.alpha(Theme.success, col.lit ? 0.85 : 0.4)
                                    Behavior on color { ColorAnimation { duration: Theme.fade } }
                                }
                            }
                            MonoTxt {
                                id: num
                                anchors.horizontalCenter: parent.horizontalCenter
                                anchors.bottom: bar.top
                                anchors.bottomMargin: 4
                                visible: col.modelData.count > 0
                                text: col.modelData.count
                                color: col.lit ? Theme.text : Theme.textFaint
                                font.pixelSize: 12
                            }
                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                onContainsMouseChanged: {
                                    if (containsMouse)
                                        week.hovered = col.index;
                                    else if (week.hovered === col.index)
                                        week.hovered = -1;
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

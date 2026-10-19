import QtQuick
import Quickshell
import qs.config
import qs.services
import qs.components

// Zeit pro Projekt, Woche Mo–So (Doku docs/PROJECTTIME.md): oben eine Säule je Tag (heute im Akzent, Überfahren zeigt
// die Projekte des Tages), darunter die Projekte der Woche mit Balken und Stunden. ‹ › blättert wochenweise.
// Daten: ProjectTime.week (scripts/projecttime week --json), frisch beim Zeigen und jede Minute, solange sichtbar.
Tile {
    id: tile

    readonly property bool shown: QsWindow.window ? QsWindow.window.visible : visible
    readonly property var w: ProjectTime.week
    readonly property var weekDays: w ? w.days : []
    readonly property var projs: w ? w.projects : []
    readonly property real maxDay: Math.max(3600, ...weekDays.map(d => d.total))
    readonly property real maxProj: Math.max(1, ...projs.map(p => p.sec))
    readonly property int maxRows: Math.max(1, Math.floor((tile.height - 50 - 24 - chart.height - 18) / 30))
    property int hoverDay: -1

    title: "Project time"
    note: w ? (ProjectTime.weekOffset === 0 ? "This week" : ProjectTime.weekOffset === -1 ? "Last week" : label(w.from) + " – " + label(w.to))
        + "  ·  " + ProjectTime.fmt(w.total) : ""

    function label(iso: string): string {
        return Qt.formatDate(new Date(iso + "T12:00:00"), "d MMM");
    }

    onShownChanged: if (shown) ProjectTime.refreshWeek()
    Component.onCompleted: if (shown) ProjectTime.refreshWeek()
    Timer {
        interval: 60000
        repeat: true
        running: tile.shown
        onTriggered: ProjectTime.refreshWeek()
    }

    actions: [
        Chip {
            padding: 4
            onClicked: ProjectTime.shiftWeek(-1)
            Icon {
                name: "chevron_left"
                size: 18
                color: parent.parent.hovered ? Theme.text : Theme.textMuted
            }
        },
        Chip {
            padding: 4
            opacity: ProjectTime.weekOffset < 0 ? 1 : 0.35
            onClicked: ProjectTime.shiftWeek(1)
            Icon {
                name: "chevron_right"
                size: 18
                color: parent.parent.hovered ? Theme.text : Theme.textMuted
            }
        }
    ]

    // ---------- Säulen je Tag ----------
    Item {
        id: chart
        width: parent.width
        height: 96

        Row {
            id: cols
            anchors.fill: parent
            spacing: 6
            Repeater {
                model: tile.weekDays
                Item {
                    id: col
                    required property var modelData
                    required property int index
                    readonly property bool isToday: modelData.day === tile.w.today
                    readonly property bool future: modelData.day > tile.w.today
                    width: (cols.width - 6 * 6) / 7
                    height: cols.height

                    MonoTxt {
                        id: val
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: bar.y - height - 2
                        text: col.modelData.total >= 60 ? ProjectTime.hm(col.modelData.total) : ""
                        color: col.isToday ? Theme.text : Theme.textFaint
                        font.pixelSize: 11
                    }
                    // Grundlinie (leise), Säule darauf
                    Rectangle {
                        y: day.y - 6
                        width: parent.width
                        height: 1
                        color: Theme.border
                    }
                    Rectangle {
                        id: bar
                        readonly property real full: day.y - 6 - 16
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: Math.min(28, parent.width - 6)
                        height: col.modelData.total > 0 ? Math.max(4, full * col.modelData.total / tile.maxDay) : 0
                        y: day.y - 6 - height
                        radius: 4
                        color: col.isToday ? Theme.accent : tile.hoverDay === col.index ? Theme.woodLight : Qt.alpha(Theme.woodLight, 0.6)
                        Behavior on height { NumberAnimation { duration: Theme.stateChange; easing.type: Easing.OutCubic } }
                        Behavior on color { ColorAnimation { duration: Theme.fade } }
                        // untere Ecken eckig: Säule steht auf der Grundlinie
                        Rectangle {
                            anchors.bottom: parent.bottom
                            width: parent.width
                            height: Math.min(parent.height, 4)
                            color: parent.color
                        }
                    }
                    Txt {
                        id: day
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.bottom
                        text: Qt.formatDate(new Date(col.modelData.day + "T12:00:00"), "ddd")
                        color: col.isToday ? Theme.accentText : col.future ? Qt.alpha(Theme.textFaint, 0.6) : Theme.textFaint
                        font.pixelSize: 12
                        font.weight: col.isToday ? Font.DemiBold : Font.Normal
                    }
                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        onContainsMouseChanged: tile.hoverDay = containsMouse ? col.index : (tile.hoverDay === col.index ? -1 : tile.hoverDay)
                    }
                }
            }
        }
    }

    // ---------- Projekte der Woche (oder des überfahrenen Tages) ----------
    readonly property var rows: {
        if (hoverDay >= 0 && weekDays[hoverDay]) {
            const p = weekDays[hoverDay].projects || {};
            return Object.keys(p).map(id => ({ id: id, name: ProjectTime.nameOf(id), sec: p[id] })).sort((a, b) => b.sec - a.sec);
        }
        return projs;
    }
    readonly property real rowMax: hoverDay >= 0 ? Math.max(1, ...rows.map(r => r.sec)) : maxProj

    Column {
        y: chart.height + 18
        width: parent.width
        spacing: 8

        Txt {
            visible: tile.hoverDay >= 0
            width: parent.width
            text: tile.weekDays[tile.hoverDay] ? Qt.formatDate(new Date(tile.weekDays[tile.hoverDay].day + "T12:00:00"), "dddd, d MMMM") : ""
            color: Theme.textMuted
            font.pixelSize: 12
            font.weight: Font.Normal
        }

        Repeater {
            model: tile.rows.slice(0, tile.maxRows)
            Item {
                id: row
                required property var modelData
                width: parent.width
                height: 22

                Rectangle {
                    id: dot
                    anchors.verticalCenter: parent.verticalCenter
                    width: 8
                    height: 8
                    radius: 4
                    color: ProjectTime.colorOf(row.modelData.id)
                }
                Txt {
                    id: name
                    x: 16
                    width: Math.min(150, parent.width * 0.36)
                    anchors.verticalCenter: parent.verticalCenter
                    text: row.modelData.name
                    font.pixelSize: 13
                }
                Rectangle {
                    id: track
                    anchors.left: name.right
                    anchors.leftMargin: 10
                    anchors.right: hours.left
                    anchors.rightMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    height: 6
                    radius: 3
                    color: Theme.surfaceSunken
                    Rectangle {
                        width: Math.max(6, parent.width * row.modelData.sec / tile.rowMax)
                        height: parent.height
                        radius: parent.radius
                        color: Qt.alpha(ProjectTime.colorOf(row.modelData.id), 0.8)
                        Behavior on width { NumberAnimation { duration: Theme.stateChange; easing.type: Easing.OutCubic } }
                    }
                }
                MonoTxt {
                    id: hours
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    width: 44
                    horizontalAlignment: Text.AlignRight
                    text: ProjectTime.hm(row.modelData.sec)
                    color: Theme.textMuted
                    font.pixelSize: 12
                }
            }
        }
        Txt {
            visible: tile.rows.length > tile.maxRows
            text: "+ " + (tile.rows.length - tile.maxRows) + " more"
            color: Theme.textFaint
            font.pixelSize: 12
            font.weight: Font.Normal
        }
        // leer: freundlich erklären, wann gezählt wird
        Txt {
            visible: tile.w !== null && tile.rows.length === 0
            width: parent.width
            wrapMode: Text.WordWrap
            text: tile.hoverDay >= 0 ? "No project time that day." : "No project time yet. It counts by itself while a project workspace is open and you're at the desk."
            color: Theme.textFaint
            font.pixelSize: 13
            font.weight: Font.Normal
        }
    }
}

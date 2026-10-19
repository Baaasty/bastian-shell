import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services
import qs.components

// Stats: große Zahl = heute, darunter dieses Jahr („auf Wrapped schwitzen“).
// Oben die Lieblinge Hörzeit (lokal + stats.fm) und Callzeit, unten Bildschirmzeit und Claude.
// GitHub ist raus: Commits zeigt die Coding-Kachel daneben, Hotlinks sind raus (globale Links stehen jetzt in projects/projects.json → global.links).
// Jede Zelle hat dasselbe Raster (Zahl · Symbol + Name · Vergleich · leiser Zusatz), linksbündig,
// alle Zeilen mit fester Höhe, damit sie über beide Spalten fluchten. Ein Zeitformat: "2 h 24" / "26 min".
// Breit (≥ 640 px): 4 Werte nebeneinander, schmal: 2 × 2.
Tile {
    id: tile

    title: "Stats"
    note: Stats.sfmOk ? (Stats.sfmStale ? "stats.fm · offline" : "via stats.fm") : ""

    readonly property bool compact: width < 640

    component Stat: Item {
        id: stat
        property string value
        property string caption
        property string icon
        property string sub              // Zeile 2: Vergleichswert ("303 h 12 this year")
        property string extra            // Zeile 3: leiser Zusatz, darf leer sein
        property string hint             // ersetzt Zeile 3 beim Drüberfahren (statt Tooltip)
        property bool live: false        // läuft gerade: Glut-Punkt statt Symbol, gleiche Stelle
        // Breite des Inhalts (längste Zeile) und die gemeinsame Breite der Spalte (setzt die Kachel):
        // der Block sitzt mittig in seiner Zelle -> gleiche Abstände nach außen, Zeilen der Spalte bündig
        // (Zusatz und Hinweis werden beide gemessen, sonst springt der Block beim Drüberfahren)
        readonly property real blockW: Math.max(valueTxt.implicitWidth, captionRow.implicitWidth,
            subTxt.implicitWidth, extraMetrics.advanceWidth, hintMetrics.advanceWidth)

        TextMetrics {
            id: extraMetrics
            font: extraTxt.font
            text: stat.extra
        }
        TextMetrics {
            id: hintMetrics
            font: extraTxt.font
            text: stat.hint
        }
        property real colW: blockW

        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.preferredWidth: 1
        Layout.preferredHeight: 1

        HoverHandler {
            id: hover
        }

        Column {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            width: Math.min(stat.width, stat.colW)
            spacing: 2

            MonoTxt {
                id: valueTxt
                width: parent.width
                height: 30
                text: stat.value
                color: Theme.text
                font.pixelSize: 22
                font.weight: Font.DemiBold
            }
            Row {
                id: captionRow
                height: 20
                spacing: 6
                // feste Breite: Symbol und Laufpunkt sitzen bei allen Zellen an derselben Stelle
                Item {
                    width: 14
                    height: parent.height
                    Icon {
                        anchors.centerIn: parent
                        visible: !stat.live
                        name: stat.icon
                        size: 14
                        color: Theme.textFaint
                    }
                    Rectangle {
                        anchors.centerIn: parent
                        visible: stat.live
                        width: 6
                        height: 6
                        radius: 3
                        color: Theme.accent
                    }
                }
                Txt {
                    height: parent.height
                    text: stat.caption
                    color: Theme.textMuted
                    font.pixelSize: 13
                    font.weight: Font.Normal
                }
            }
            Item {
                width: 1
                height: 4
            }
            Txt {
                id: subTxt
                width: parent.width
                height: 17
                text: stat.sub
                color: Theme.textMuted
                font.pixelSize: 12
                font.weight: Font.Normal
            }
            Txt {
                id: extraTxt
                width: parent.width
                height: 17
                text: hover.hovered && stat.hint !== "" ? stat.hint : stat.extra
                color: Theme.textFaint
                font.pixelSize: 12
                font.weight: Font.Normal
            }
        }
    }

    readonly property string since: Stats.fullYear ? "" : "counted since " + Stats.fmtDay(Stats.firstDay)

    GridLayout {
        anchors.fill: parent
        columns: tile.compact ? 2 : 4
        columnSpacing: 20
        rowSpacing: 4

        Stat {
            id: sListen
            colW: tile.compact ? Math.max(blockW, sScreen.blockW) : blockW
            icon: "headphones"
            caption: "Listening"
            live: Stats.livePlaying
            value: Stats.loaded ? Stats.fmtDur(Stats.listenToday) : "–"
            sub: Stats.loaded ? Stats.fmtDur(Stats.listenYear) + " this year" : ""
            // Jahres-Nr. 1 von stats.fm, sonst der lokale Top-Song der Woche
            extra: Stats.sfmOk && Stats.sfmTopArtist !== "" ? "#1 " + Stats.sfmTopArtist + " · " + Stats.fmtDur(Stats.sfmTopArtistMs)
                : Stats.topSong !== "" ? "Top: " + Stats.topSong : ""
            hint: Stats.sfmOk ? Stats.sfmTodayStreams + " streams today · " + Stats.sfmYearStreams + " this year"
                : tile.since !== "" ? tile.since : ""
        }
        Stat {
            id: sCalls
            colW: tile.compact ? Math.max(blockW, sClaude.blockW) : blockW
            icon: "call"
            caption: Stats.inCall ? "In a call" : "Calls"
            live: Stats.inCall
            value: Stats.loaded ? Stats.fmtDur(Stats.discordToday) : "–"
            sub: Stats.loaded ? Stats.fmtDur(Stats.discordYear) + " this year" : ""
            extra: Stats.callsToday + (Stats.callsToday === 1 ? " call today" : " calls today")
            hint: tile.since
        }
        Stat {
            id: sScreen
            colW: tile.compact ? Math.max(blockW, sListen.blockW) : blockW
            icon: "desktop_windows"
            caption: "Screen time"
            value: Stats.fmtDur(Focus.screenMs)
            // Schnitt der letzten 7 Tage; solange es keinen Vortag gibt, zählt heute
            sub: "Ø " + Stats.fmtDur((Stats.screenAvgMin > 0 ? Stats.screenAvgMin * 60000 : Focus.screenMs)) + " / day"
            extra: Focus.focusMin > 0 ? Stats.fmtDur(Focus.focusMs) + " focused" : ""
            hint: "idle time left out"
        }
        Stat {
            id: sClaude
            colW: tile.compact ? Math.max(blockW, sCalls.blockW) : blockW
            icon: "smart_toy"
            caption: "Claude active"
            value: DevStats.usageOk ? Stats.fmtDur(DevStats.activeMs) : "–"
            sub: !DevStats.usageOk ? "" : DevStats.sessions + (DevStats.sessions === 1 ? " session" : " sessions")
                + " · " + DevStats.agents + (DevStats.agents === 1 ? " agent" : " agents")
            extra: DevStats.usageOk && DevStats.claudeProject !== "" ? "mostly " + DevStats.claudeProject : ""
        }
    }
}

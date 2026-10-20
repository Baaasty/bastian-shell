import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import qs.services
import qs.components

// Projekt-Kennzahlen im Quicklinks-Popup (unter der Git-Zeile), nur fürs Hauptprojekt des Workspaces:
//   Zeit heute · Woche · gesamt (ProjectTime) · eigene Commits heute · Woche · gesamt, +/− der eigenen Commits von heute
//   · Codezeilen der drei größten Sprachen. Rechnet scripts/projectstats nur beim Öffnen (LOC dort per HEAD gecacht).
// Spalten stehen untereinander: die Wörter today/week/total nur in der Zeitzeile, die Commits darunter gelten genauso.
Column {
    id: st

    property var proj: null
    property bool active: false              // Popup offen → einmal frisch rechnen
    property var cache: ({})                 // Projekt-ID → letzte Antwort (beim nächsten Öffnen sofort da, kein Springen)
    readonly property var s: proj ? cache[proj.id] : undefined
    readonly property string dir: proj && proj.paths && proj.paths.length ? GitInfo.home(proj.paths[0]) : ""

    // Zeit: Dateien von heute hinken bis zu 15 s nach – heute live aus ProjectTime, Woche/gesamt damit nachgezogen
    readonly property int liveDay: proj ? (ProjectTime.total[proj.id] || 0) : 0
    function timeOf(k: string): string {
        if (!s || !s.time)
            return "…";
        return ProjectTime.short(Math.max(0, s.time[k] - s.time.today) + liveDay);
    }
    function num(k: string): string {
        return !s ? "…" : s.commits ? String(s.commits[k]) : "–";
    }
    // 12400 → „12.4k“, 300 → „300“
    function kilo(n: int): string {
        return n >= 100000 ? Math.round(n / 1000) + "k" : n >= 1000 ? (n / 1000).toFixed(1).replace(/\.0$/, "") + "k" : String(n);
    }
    readonly property string locText: !s ? "…" : !s.loc || !s.loc.length ? "no code" : s.loc.slice(0, 3).map(l => kilo(l.lines) + " " + l.lang).join(" · ")

    function refresh(): void {
        if (!proj || !dir || proc.running)
            return;
        proc.forId = proj.id;
        proc.command = [Quickshell.shellDir + "/../scripts/projectstats", dir, "--project", proj.id];
        proc.running = true;
    }
    onActiveChanged: if (active) refresh()
    onProjChanged: if (active) refresh()

    Process {
        id: proc
        property string forId: ""
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const c = Object.assign({}, st.cache);
                    c[proc.forId] = JSON.parse(text);
                    st.cache = c;
                } catch (e) {}
            }
        }
    }

    visible: !!proj && dir !== ""
    spacing: 4

    Grid {
        columns: 4
        columnSpacing: 14
        rowSpacing: 4
        verticalItemAlignment: Grid.AlignVCenter

        Icon {
            name: "schedule"
            size: 16
            color: Theme.textMuted
        }
        Repeater {
            model: [["today", "today"], ["week", "week"], ["all", "total"]]
            Row {
                required property var modelData
                spacing: 5
                MonoTxt {
                    id: timeNum
                    text: st.timeOf(modelData[0])
                    color: Theme.textMuted
                }
                Txt {
                    anchors.baseline: timeNum.baseline
                    text: modelData[1]
                    color: Theme.textFaint
                    font.pixelSize: 12
                    font.weight: Font.Normal
                }
            }
        }

        Icon {
            name: "commit"
            size: 16
            color: Theme.textMuted
        }
        Row {
            spacing: 8
            MonoTxt {
                text: st.num("today")
                color: Theme.textMuted
            }
            // +/− der eigenen Commits von heute (Uncommittetes zählt die Git-Zeile oben als „N changes“)
            MonoTxt {
                visible: !!st.s && !!st.s.changes && (st.s.changes.added > 0 || st.s.changes.deleted > 0)
                text: st.s && st.s.changes ? "+" + st.kilo(st.s.changes.added) : ""
                color: Theme.success
                font.pixelSize: 12
            }
            MonoTxt {
                visible: !!st.s && !!st.s.changes && (st.s.changes.added > 0 || st.s.changes.deleted > 0)
                text: st.s && st.s.changes ? "−" + st.kilo(st.s.changes.deleted) : ""
                color: Theme.error
                font.pixelSize: 12
            }
        }
        MonoTxt {
            text: st.num("week")
            color: Theme.textMuted
        }
        Row {
            spacing: 5
            MonoTxt {
                id: allCommits
                text: st.num("all")
                color: Theme.textMuted
            }
            Txt {
                anchors.baseline: allCommits.baseline
                text: "commits"
                color: Theme.textFaint
                font.pixelSize: 12
                font.weight: Font.Normal
            }
        }
    }

    Row {
        spacing: 14
        Icon {
            anchors.verticalCenter: parent.verticalCenter
            name: "code"
            size: 16
            color: Theme.textMuted
        }
        MonoTxt {
            anchors.verticalCenter: parent.verticalCenter
            width: Math.min(implicitWidth, st.width - 30)
            elide: Text.ElideRight
            text: st.locText
            color: Theme.textMuted
            font.pixelSize: 12
        }
    }
}

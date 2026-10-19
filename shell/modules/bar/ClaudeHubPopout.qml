import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.services
import qs.components

// Popout der Claude-Zentrale: eine Karte pro aktivem Projekt (Projektfarbe, Branch, Änderungen,
// Claude-Sitzungen mit Aufgabenliste und Subagents). Klick auf den Kopf = VS-Code-Fenster des Projekts nach vorn.
// Eine Karte ist aufgeklappt: Roadmap-Fortschritt, eigene Aufgaben, Ideen und ein Feld zum schnellen Notieren
// (Tab wechselt Aufgabe → Idee → Claude). Modus „Claude“: Enter startet eine Claude-Sitzung im Hintergrund
// (ClaudeTasks/scripts/claude-task); sie steht als „background“-Zeile unter den Sitzungen, fertig = Ergebnis per Klick.
// „status“ an einer Sitzung (beim Drüberfahren): „Wie weit bist du?“ an einen Abzweig der Sitzung (ClaudeAsks/
// scripts/claude-ask, die Sitzung selbst bleibt unberührt); Antwort als kleine Karte darunter, 10 min lang.
// Wie Todo/Spotify/Discord: Klick daneben schließt, nur ein Bar-Popout gleichzeitig.
PopupWindow {
    id: pop

    property var barWindow
    property Item chip
    property string expanded: ""
    // Kartenliste nur bei echten Änderungen neu, sonst verliert das Textfeld beim Tippen den Fokus
    property var names: []
    readonly property int maxCardHeight: 720
    readonly property int maxAgents: 5
    // fertige Agents nur auf Wunsch (laufende stehen immer da); bleibt beim Schließen erhalten
    property bool showDone: false
    // Hintergrund-Aufgabe, deren Ergebnis gerade aufgeklappt ist ("" = keins)
    property string openTask: ""
    // Statusantwort, die gerade ganz aufgeklappt ist ("" = alle gekürzt)
    property string openAsk: ""
    // per Meldung (qs ipc) geöffnet: ohne frischen Klick verweigert KWin den Fokus-Grab und das Popup
    // geht sofort wieder zu. Dann ohne Grab neu öffnen ("pinned") und schließen, sobald die Maus die
    // Karte wieder verlässt (oder per Chip/anderem Popout).
    property bool pinned: false
    property real _ipcOpenAt: 0
    // gemeinsamer Ember-Puls für laufende Agents: Zeilen werden beim Nachladen neu gebaut,
    // so springt der Puls dabei nicht
    // über Breathe (~12 Bilder/s) statt Dauer-Animation: die zeichnete das Popout mit Bildschirmrate neu
    readonly property real pulse: pulseTimer.value
    Breathe {
        id: pulseTimer
        running: pop.visible && (ClaudeHub.agentsRunning > 0 || ClaudeTasks.running > 0 || ClaudeAsks.running > 0)
        to: 0.3
    }

    anchor.window: barWindow
    anchor.edges: Edges.Bottom | Edges.Left
    anchor.gravity: Edges.Bottom | Edges.Right
    grabFocus: !pinned
    // feste Fenstergröße, sichtbar/klickbar ist nur die Karte (Maske): ändert sich die Fensterhöhe,
    // streckt KWin kurz das alte Bild (Einklappen sah „gestaucht“ aus) – so animiert nur die Karte
    implicitWidth: 460
    implicitHeight: maxCardHeight
    color: "transparent"
    visible: false
    mask: Region { item: card }

    function syncNames(): void {
        const n = ClaudeHub.projects.map(p => p.name);
        if (n.join("\n") !== names.join("\n"))
            names = n;
        if (expanded && !n.includes(expanded))
            expanded = "";
    }
    Connections {
        target: ClaudeHub
        function onProjectsChanged() { pop.syncNames(); }
    }
    Component.onCompleted: syncNames()

    // Klick auf die Meldung „Claude task done“ (qs ipc … claudehub showTask <id>): Ergebnis zeigen
    Connections {
        target: ClaudeTasks
        function onShowRequested(id) {
            const hit = ClaudeHub.projects.find(p => p.bgTasks.some(t => t.id === id));
            if (!hit)
                return;
            if (!pop.visible) {
                pop.placeUnderBar();
                pop._ipcOpenAt = Date.now();
                pop.visible = true;
            }
            pop.expanded = hit.name;
            pop.openTask = id;
            ClaudeTasks.seen(id);
        }
    }

    // qs ipc … claudehub open <projekt>: Popout zeigen (ohne Klick: wie bei der Meldung ohne Fokus-Grab)
    Connections {
        target: ClaudeHub
        function onOpenRequested(name) {
            if (!pop.visible) {
                pop._ipcOpenAt = Date.now();
                pop.toggle();
            }
            if (name && ClaudeHub.projects.some(p => p.name === name))
                pop.expanded = name;
        }
    }

    // Popouts sitzen mit Lücke unter der Bar, linksbündig zum Chip
    function placeUnderBar(): void {
        if (!chip)
            return;
        anchor.rect.x = Math.round(chip.mapToItem(null, 0, 0).x);
        anchor.rect.y = Theme.barMargin + Theme.barHeight + Theme.windowGap - 1;
        anchor.rect.width = 1;
        anchor.rect.height = 1;
    }
    function toggle(): void {
        if (!visible) {
            placeUnderBar();
            // aufgeklappt: was dich braucht, sonst das aktuelle Projekt, sonst das erste
            const list = ClaudeHub.projects;
            const pick = list.find(p => p.needs > 0) ?? list.find(p => p.current) ?? list[0];
            expanded = pick ? pick.name : "";
        }
        visible = !visible;
    }

    onVisibleChanged: {
        if (!visible && !pinned && Date.now() - _ipcOpenAt < 300) {
            pinned = true;
            reopen.start();
        } else if (!visible && pinned && !reopen.running) {
            pinned = false;
        }
        if (barWindow)
            barWindow.openMenus += visible ? 1 : -1;
        if (visible)
            Popouts.claim("claudehub");
        else
            Popouts.release("claudehub");
        ClaudeHub.watching = visible;
        if (visible)
            flick.contentY = 0;
    }
    Timer {
        id: reopen
        interval: 30
        onTriggered: {
            pop._ipcOpenAt = 0;
            pop.visible = true;
            // Maus kommt nie vorbei -> nach 10 s von selbst zu
            pinnedLeave.interval = 10000;
            pinnedLeave.restart();
        }
    }
    // ohne Grab: Maus war auf der Karte und ist weg -> kurz warten, dann zu (zuerst länger, s. reopen)
    Timer {
        id: pinnedLeave
        interval: 1200
        onTriggered: if (pop.pinned && !popHover.hovered) pop.visible = false
    }
    // nur ein Bar-Popout gleichzeitig
    Connections {
        target: Popouts
        function onCurrentChanged() {
            if (Popouts.current !== "claudehub" && pop.visible)
                pop.visible = false;
        }
    }

    BackgroundEffect.blurRegion: Region {
        Region { x: 0; y: 0; width: 1; height: 1 }
        Region { item: card; radius: Theme.radiusLg }
    }

    // ---------- Bausteine ----------

    // kleiner Symbol-Knopf
    component IconBtn: Rectangle {
        id: ib
        property string glyph
        property color tint: Theme.textFaint
        property bool fill: false
        signal clicked()
        width: 26
        height: 26
        radius: Theme.radiusSm
        color: ibArea.containsMouse ? Theme.raise : "transparent"
        Behavior on color { ColorAnimation { duration: Theme.fade } }
        Icon {
            anchors.centerIn: parent
            name: ib.glyph
            size: 16
            fill: ib.fill
            color: ibArea.containsMouse ? Theme.text : ib.tint
        }
        MouseArea {
            id: ibArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: ib.clicked()
        }
    }

    // ein Subagent: Puls-Punkt (läuft) bzw. ✓ (fertig) · Beschreibung · seit wann / wie lange her
    component AgentRow: Item {
        id: ar
        property var a
        readonly property bool run: a.state === "running"
        height: 18

        Item {
            id: mark
            width: 12
            height: parent.height
            Rectangle {
                anchors.centerIn: parent
                visible: ar.run
                width: 6
                height: 6
                radius: 3
                color: Theme.accent
                opacity: pop.pulse
            }
            Icon {
                anchors.centerIn: parent
                visible: !ar.run
                name: "check"
                size: 13
                color: Theme.textFaint
            }
        }
        Txt {
            id: desc
            anchors.left: mark.right
            anchors.leftMargin: 7
            anchors.verticalCenter: parent.verticalCenter
            width: Math.min(implicitWidth, ar.width - mark.width - 7 - when.implicitWidth - 6)
            text: ar.a.description
            color: ar.run ? Theme.textMuted : Theme.textFaint
            font.pixelSize: 12
            font.weight: Font.Normal
        }
        MonoTxt {
            id: when
            anchors.left: desc.right
            anchors.leftMargin: 6
            anchors.verticalCenter: parent.verticalCenter
            color: Theme.textFaint
            opacity: ar.run ? 1 : 0.8
            font.pixelSize: 11
            text: {
                const t = ClaudeHub.ago(ar.run ? ar.a.since : ar.a.updated);
                return "· " + (ar.run || t === "just now" ? t : t + " ago");
            }
        }
    }

    // „status“-Knopf: fragt einen Abzweig der Sitzung „Wie weit bist du?“; währenddessen „asking…“ (Glut-Puls)
    component AskBtn: Rectangle {
        id: ab
        property string sid
        property string cwd
        property bool hovered: false
        readonly property var ask: ClaudeAsks.forSession(sid)
        readonly property bool asking: ClaudeAsks.active(ask)
        visible: sid !== "" && (hovered || asking)
        width: abRow.implicitWidth + 12
        height: 20
        radius: Theme.radiusSm
        color: abArea.containsMouse && !asking ? Theme.raise : "transparent"
        Behavior on color { ColorAnimation { duration: Theme.fade } }
        Row {
            id: abRow
            x: 6
            anchors.verticalCenter: parent.verticalCenter
            spacing: 4
            opacity: ab.asking ? pop.pulse : 1
            Icon {
                anchors.verticalCenter: parent.verticalCenter
                name: "help"
                size: 13
                color: ab.asking ? Theme.accentText : abArea.containsMouse ? Theme.text : Theme.textFaint
            }
            Txt {
                anchors.verticalCenter: parent.verticalCenter
                text: ab.asking ? "asking…" : "status"
                font.pixelSize: 11
                font.weight: Font.Normal
                color: ab.asking ? Theme.accentText : abArea.containsMouse ? Theme.text : Theme.textFaint
            }
        }
        MouseArea {
            id: abArea
            anchors.fill: parent
            hoverEnabled: true
            enabled: !ab.asking
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                ClaudeAsks.ask(ab.sid, ab.cwd);
                pop.openAsk = "";
            }
        }
    }

    // Antwort auf „status“: gekürzt (4 Zeilen), Klick klappt ganz auf; Copy, Schließen
    component AskCard: Rectangle {
        id: ac
        property var a
        readonly property bool full: a !== null && pop.openAsk === a.id
        readonly property bool failed: a !== null && a.state !== "done"
        // Markdown leicht vereinfachen: **fett** weg, Spiegelstriche als •
        readonly property string plain: a && a.result ? String(a.result).replace(/\*\*/g, "").replace(/^\s*[-*]\s+/gm, "• ") : ""
        property bool copied: false
        visible: a !== null && !ClaudeAsks.active(a)
        height: visible ? acCol.implicitHeight + 16 : 0
        radius: Theme.radiusSm
        color: Theme.surfaceSunken
        border.width: 1
        border.color: Theme.border

        Column {
            id: acCol
            x: 10
            y: 8
            width: parent.width - 20
            spacing: 5
            Item {
                width: acCol.width
                height: 20
                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 6
                    Icon {
                        anchors.verticalCenter: parent.verticalCenter
                        name: ac.failed ? "error" : "summarize"
                        size: 13
                        color: ac.failed ? Theme.textFaint : Theme.accentText
                    }
                    MonoTxt {
                        anchors.verticalCenter: parent.verticalCenter
                        font.pixelSize: 11
                        color: Theme.textFaint
                        text: {
                            if (!ac.a)
                                return "";
                            const t = ClaudeHub.ago(ac.a.finished);
                            const when = t === "just now" ? t : t + " ago";
                            const took = ac.a.finished && ac.a.started ? " · " + ClaudeHub.fmtDuration(ac.a.finished - ac.a.started) : "";
                            return (ac.a.state === "done" ? "status" : ac.a.state === "stopped" ? "status · stopped" : "status · failed") + " · " + when + took;
                        }
                    }
                }
                Row {
                    anchors.right: parent.right
                    anchors.rightMargin: -6
                    anchors.verticalCenter: parent.verticalCenter
                    IconBtn {
                        visible: ac.plain !== ""
                        glyph: ac.copied ? "check" : "content_copy"
                        onClicked: {
                            Clipboard.copyText(String(ac.a.result || ""));
                            ac.copied = true;
                            acCopied.restart();
                        }
                    }
                    IconBtn {
                        visible: ac.plain !== ""
                        glyph: ac.full ? "expand_less" : "expand_more"
                        onClicked: pop.openAsk = ac.full ? "" : ac.a.id
                    }
                    IconBtn {
                        glyph: "close"
                        onClicked: {
                            if (ac.full)
                                pop.openAsk = "";
                            ClaudeAsks.remove(ac.a.id);
                        }
                    }
                }
            }
            Txt {
                width: acCol.width
                wrapMode: Text.Wrap
                maximumLineCount: ac.full ? 30 : 4
                verticalAlignment: Text.AlignTop
                text: ac.plain !== "" ? ac.plain + (ac.a.cut ? " …" : "") : (ac.a && ac.a.error ? "No answer · " + ac.a.error : "No answer")
                color: ac.plain !== "" ? Theme.text : Theme.textFaint
                font.pixelSize: 12
                font.weight: Font.Normal
                lineHeight: 1.15
                TapHandler {
                    enabled: ac.plain !== ""
                    onTapped: pop.openAsk = ac.full ? "" : ac.a.id
                }
                HoverHandler {
                    enabled: ac.plain !== ""
                    cursorShape: Qt.PointingHandCursor
                }
            }
        }
        Timer {
            id: acCopied
            interval: 1600
            onTriggered: ac.copied = false
        }
    }

    // eine Claude-Sitzung: Status · seit wann, darunter Claudes Aufgabenliste ("3/7 · Bar umbauen")
    component SessionRow: Column {
        id: sr
        property var s
        readonly property bool hot: s.needsYou
        readonly property var tasks: s.tasks && s.tasks.total > 0 ? s.tasks : null
        readonly property var agents: s.agents || []
        readonly property int doneCount: agents.filter(a => a.state !== "running").length
        readonly property var shown: pop.showDone ? agents : agents.filter(a => a.state === "running")
        readonly property var ask: ClaudeAsks.forSession(s.id)
        width: parent ? parent.width : 0
        spacing: 3

        Item {
            width: sr.width
            height: 18
            HoverHandler {
                id: srHover
            }
            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8
                Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    name: "auto_awesome"
                    size: 14
                    fill: sr.hot
                    color: sr.hot ? Theme.accentText : sr.s.state === "working" ? Theme.textMuted : Theme.textFaint
                }
                Txt {
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.min(implicitWidth, sr.width - 24 - (mapBtn.visible ? mapBtn.width + 6 : 0) - (srAsk.visible ? srAsk.width + 4 : 0))
                    color: sr.hot ? Theme.accentText : sr.s.state === "working" ? Theme.textMuted : Theme.textFaint
                    font.weight: sr.hot ? Font.Medium : Font.Normal
                    text: {
                        const st = sr.s.state === "waiting" ? "needs you" : sr.s.state === "done" ? (sr.hot ? "done · your turn" : "done") : "working";
                        const n = sr.s.agentsRunning || 0;
                        return st + " · " + ClaudeHub.ago(sr.s.since) + (n > 0 ? " · " + n + (n === 1 ? " agent" : " agents") : "");
                    }
                }
            }
            // „Wie weit bist du?“ (beim Drüberfahren; während der Frage „asking…“)
            AskBtn {
                id: srAsk
                anchors.right: mapBtn.visible ? mapBtn.left : parent.right
                anchors.rightMargin: mapBtn.visible ? 4 : 0
                anchors.verticalCenter: parent.verticalCenter
                sid: sr.s.id
                cwd: sr.s.cwd || ""
                hovered: srHover.hovered
            }
            // Agent-Map dieser Sitzung (Baum aller Subagents, auch älterer)
            Rectangle {
                id: mapBtn
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                visible: (sr.s.agentsTotal || 0) > 0
                width: mapRow.implicitWidth + 12
                height: 20
                radius: Theme.radiusSm
                color: mapArea.containsMouse ? Theme.raise : "transparent"
                Behavior on color { ColorAnimation { duration: Theme.fade } }
                Row {
                    id: mapRow
                    x: 6
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 4
                    Icon {
                        anchors.verticalCenter: parent.verticalCenter
                        name: "account_tree"
                        size: 13
                        color: mapArea.containsMouse ? Theme.text : Theme.textFaint
                    }
                    Txt {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "map"
                        font.pixelSize: 11
                        font.weight: Font.Normal
                        color: mapArea.containsMouse ? Theme.text : Theme.textFaint
                    }
                }
                MouseArea {
                    id: mapArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        pop.visible = false;
                        ClaudeHub.openMap(sr.s.id);
                    }
                }
            }
        }
        Row {
            visible: sr.tasks !== null
            leftPadding: 22
            spacing: 8
            // kleiner Fortschrittsbalken
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 36
                height: 4
                radius: 2
                color: Theme.raise
                Rectangle {
                    width: sr.tasks ? parent.width * sr.tasks.done / sr.tasks.total : 0
                    height: parent.height
                    radius: 2
                    color: Theme.woodLight
                }
            }
            MonoTxt {
                anchors.verticalCenter: parent.verticalCenter
                text: sr.tasks ? sr.tasks.done + "/" + sr.tasks.total : ""
                color: Theme.textMuted
                font.pixelSize: 12
            }
            Txt {
                anchors.verticalCenter: parent.verticalCenter
                width: Math.min(implicitWidth, sr.width - 120)
                visible: text !== ""
                text: sr.tasks ? (sr.tasks.current || (sr.tasks.done === sr.tasks.total ? "all done" : "")) : ""
                color: Theme.textMuted
                font.weight: Font.Normal
            }
        }
        // Subagents dieser Sitzung: laufende immer, fertige per Klick; höchstens maxAgents + "+n more"
        Column {
            visible: sr.agents.length > 0
            leftPadding: 22
            topPadding: 1
            spacing: 1
            Repeater {
                model: sr.shown.slice(0, pop.maxAgents)
                AgentRow {
                    required property var modelData
                    a: modelData
                    width: sr.width - 22
                }
            }
            Txt {
                visible: sr.shown.length > pop.maxAgents
                leftPadding: 19
                text: "+" + (sr.shown.length - pop.maxAgents) + " more"
                color: Theme.textFaint
                font.pixelSize: 12
                font.weight: Font.Normal
            }
            // Schalter: fertige Agents ein-/ausblenden
            Txt {
                id: doneToggle
                visible: sr.doneCount > 0
                leftPadding: 19
                text: (pop.showDone ? "hide finished" : "✓ " + sr.doneCount + " finished") + (doneHover.hovered ? (pop.showDone ? "" : " · show") : "")
                color: doneHover.hovered ? Theme.textMuted : Theme.textFaint
                font.pixelSize: 12
                font.weight: Font.Normal
                HoverHandler {
                    id: doneHover
                    cursorShape: Qt.PointingHandCursor
                }
                TapHandler {
                    onTapped: pop.showDone = !pop.showDone
                }
            }
        }
        // Antwort auf „status“
        AskCard {
            x: 22
            width: sr.width - 22
            a: sr.ask
        }
    }

    // kleiner Text-Knopf mit Symbol ("Open in VS Code")
    component PillBtn: Rectangle {
        id: pb
        property string glyph
        property string label
        signal clicked()
        width: pbRow.implicitWidth + 14
        height: 24
        radius: Theme.radiusSm
        color: pbArea.containsMouse ? Theme.raise : "transparent"
        border.width: 1
        border.color: Theme.border
        Behavior on color { ColorAnimation { duration: Theme.fade } }
        Row {
            id: pbRow
            x: 7
            anchors.verticalCenter: parent.verticalCenter
            spacing: 5
            Icon {
                anchors.verticalCenter: parent.verticalCenter
                name: pb.glyph
                size: 13
                color: pbArea.containsMouse ? Theme.text : Theme.textMuted
            }
            Txt {
                anchors.verticalCenter: parent.verticalCenter
                text: pb.label
                font.pixelSize: 12
                font.weight: Font.Normal
                color: pbArea.containsMouse ? Theme.text : Theme.textMuted
            }
        }
        MouseArea {
            id: pbArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: pb.clicked()
        }
    }

    // Hintergrund-Aufgabe („Ask Claude…“): Status · seit wann, darunter der Aufgabentext;
    // fertig: Klick klappt das Ergebnis auf (Open in VS Code / Resume-Befehl kopieren)
    component TaskRow: Column {
        id: tr
        property var t
        property var project
        readonly property bool run: ClaudeTasks.active(t)
        readonly property bool hot: t.needsYou
        readonly property bool waiting: run && t.waiting === true
        readonly property bool shown: pop.openTask === t.id && !run
        property bool copied: false
        width: parent ? parent.width : 0
        spacing: 3

        function toggleResult(): void {
            if (tr.run)
                return;
            pop.openTask = tr.shown ? "" : tr.t.id;
            pop.expanded = tr.project ? tr.project.name : pop.expanded;
            ClaudeTasks.seen(tr.t.id);
        }

        Item {
            width: tr.width
            height: 18
            HoverHandler {
                id: trHover
                cursorShape: tr.run ? Qt.ArrowCursor : Qt.PointingHandCursor
            }
            TapHandler {
                enabled: !tr.run
                onTapped: tr.toggleResult()
            }
            Item {
                id: trMark
                width: 14
                height: parent.height
                Rectangle {
                    anchors.centerIn: parent
                    visible: tr.run
                    width: 7
                    height: 7
                    radius: 3.5
                    color: tr.waiting ? Theme.accentText : Theme.accent
                    opacity: tr.waiting ? 1 : pop.pulse
                }
                Icon {
                    anchors.centerIn: parent
                    visible: !tr.run
                    name: tr.t.state === "done" ? "check" : tr.t.state === "failed" ? "error" : "stop_circle"
                    size: 14
                    fill: tr.hot
                    color: tr.hot ? (tr.t.state === "failed" ? Theme.error : Theme.accentText) : Theme.textFaint
                }
            }
            Txt {
                anchors.left: trMark.right
                anchors.leftMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                width: Math.min(implicitWidth, tr.width - 22 - trBtns.width - 6)
                color: tr.hot || tr.waiting ? Theme.accentText : tr.run ? Theme.textMuted : Theme.textFaint
                font.weight: tr.hot || tr.waiting ? Font.Medium : Font.Normal
                text: {
                    const t = tr.t;
                    const steps = t.steps > 0 ? " · " + t.steps + (t.steps === 1 ? " step" : " steps") : "";
                    if (t.state === "starting")
                        return "background · starting";
                    if (t.state === "running")
                        return "background · " + (tr.waiting ? "needs you" : "running") + " · " + ClaudeHub.ago(t.started) + steps;
                    const ago = ClaudeHub.ago(t.finished);
                    const when = ago === "just now" ? ago : ago + " ago";
                    const st = t.state === "done" ? (tr.hot ? "done · your turn" : "done") : t.state === "failed" ? "failed" : t.state === "lost" ? "interrupted" : "stopped";
                    return "background · " + st + " · " + when;
                }
            }
            Row {
                id: trBtns
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                AskBtn {
                    anchors.verticalCenter: parent.verticalCenter
                    sid: tr.t.session || ""
                    cwd: tr.t.cwd || ""
                    hovered: trHover.hovered && tr.t.state === "running"
                }
                IconBtn {
                    visible: tr.run && trHover.hovered
                    glyph: "stop"
                    onClicked: ClaudeTasks.stop(tr.t.id)
                }
                IconBtn {
                    visible: !tr.run
                    glyph: tr.shown ? "expand_less" : "expand_more"
                    tint: Theme.textFaint
                    onClicked: tr.toggleResult()
                }
                IconBtn {
                    visible: !tr.run && trHover.hovered
                    glyph: "close"
                    onClicked: {
                        if (pop.openTask === tr.t.id)
                            pop.openTask = "";
                        ClaudeTasks.remove(tr.t.id);
                    }
                }
            }
        }
        Txt {
            width: tr.width
            leftPadding: 22
            text: tr.t.title || ""
            color: tr.run ? Theme.textMuted : Theme.textFaint
            font.weight: Font.Normal
        }
        // Antwort auf „status“
        AskCard {
            x: 22
            width: tr.width - 22
            a: ClaudeAsks.forSession(tr.t.session || "")
        }

        // Ergebnis: letzte Antwort (gekürzt), Kennzahlen, Weitermachen
        Rectangle {
            visible: tr.shown
            x: 22
            width: tr.width - 22
            height: visible ? resCol.implicitHeight + 18 : 0
            radius: Theme.radiusSm
            color: Theme.surfaceSunken
            border.width: 1
            border.color: Theme.border

            Column {
                id: resCol
                x: 10
                y: 9
                width: parent.width - 20
                spacing: 8
                Txt {
                    width: resCol.width
                    wrapMode: Text.Wrap
                    maximumLineCount: 14
                    verticalAlignment: Text.AlignTop
                    text: tr.t.result ? tr.t.result + (tr.t.cut ? " …" : "") : (tr.t.error ? "No answer · " + tr.t.error : "No answer")
                    color: tr.t.result ? Theme.text : Theme.textFaint
                    font.pixelSize: 12
                    font.weight: Font.Normal
                    lineHeight: 1.15
                }
                MonoTxt {
                    visible: text !== ""
                    width: resCol.width
                    font.pixelSize: 11
                    color: Theme.textFaint
                    text: {
                        const t = tr.t;
                        const parts = [];
                        if (t.steps > 0)
                            parts.push(t.steps + (t.steps === 1 ? " step" : " steps"));
                        if (t.finished && t.started)
                            parts.push(ClaudeHub.fmtDuration(t.finished - t.started));
                        if (t.cost)
                            parts.push("$" + Number(t.cost).toFixed(2));
                        if (t.denials > 0)
                            parts.push(t.denials + " denied");
                        return parts.join(" · ");
                    }
                }
                Row {
                    spacing: 6
                    // Projekt nach vorn + Sitzung im Claude-Tab von VS Code öffnen
                    PillBtn {
                        glyph: "arrow_outward"
                        label: "Continue in VS Code"
                        onClicked: {
                            ClaudeHub.continueInCode(tr.project, tr.t);
                            pop.visible = false;
                        }
                    }
                    // oder im Terminal weitermachen
                    PillBtn {
                        visible: (tr.t.session || "") !== ""
                        glyph: tr.copied ? "check" : "content_copy"
                        label: tr.copied ? "Copied" : "Copy resume"
                        onClicked: {
                            const dir = "'" + String(tr.t.cwd || "").replace(/'/g, "'\\''") + "'";
                            Clipboard.copyText("cd " + dir + " && claude --resume " + tr.t.session);
                            tr.copied = true;
                            copiedReset.restart();
                        }
                    }
                }
            }
        }
        Timer {
            id: copiedReset
            interval: 1600
            onTriggered: tr.copied = false
        }
    }

    // Zeile in den eigenen Aufgaben/Ideen: Knopf links, Text, Aktionen beim Drüberfahren
    component NoteRow: Rectangle {
        id: nr
        property string text
        property string glyph: ""
        property bool check: false        // runder Abhak-Knopf statt Symbol
        property string actionGlyph: ""   // zweite Aktion (z. B. Idee -> Aufgabe)
        property string action2Glyph: ""  // dritte Aktion (Idee -> Roadmap)
        signal toggled()
        signal action()
        signal action2()
        signal removed()
        width: parent ? parent.width : 0
        height: 30
        radius: Theme.radiusSm
        color: nrHover.hovered ? Theme.raise : "transparent"
        HoverHandler {
            id: nrHover
        }
        Row {
            x: 6
            anchors.verticalCenter: parent.verticalCenter
            spacing: 10
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                visible: nr.check
                width: 16
                height: 16
                radius: 8
                color: "transparent"
                border.width: 1.5
                border.color: Theme.borderStrong
                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -6
                    cursorShape: Qt.PointingHandCursor
                    onClicked: nr.toggled()
                }
            }
            Icon {
                anchors.verticalCenter: parent.verticalCenter
                visible: !nr.check
                name: nr.glyph
                size: 15
                color: Theme.textFaint
            }
            Txt {
                anchors.verticalCenter: parent.verticalCenter
                // Platz für die Knöpfe rechts (je 26 px), damit nichts darunter liegt
                width: nr.width - 40 - 26 * (1 + (nr.actionGlyph !== "" ? 1 : 0) + (nr.action2Glyph !== "" ? 1 : 0))
                text: nr.text
                color: Theme.text
                font.weight: Font.Normal
            }
        }
        Row {
            anchors.right: parent.right
            anchors.rightMargin: 2
            anchors.verticalCenter: parent.verticalCenter
            visible: nrHover.hovered
            IconBtn {
                visible: nr.actionGlyph !== ""
                glyph: nr.actionGlyph
                onClicked: nr.action()
            }
            IconBtn {
                visible: nr.action2Glyph !== ""
                glyph: nr.action2Glyph
                onClicked: nr.action2()
            }
            IconBtn {
                glyph: "close"
                onClicked: nr.removed()
            }
        }
    }

    // eine Projekt-Karte
    component ProjectCard: Rectangle {
        id: pc
        required property string modelData
        readonly property var p: ClaudeHub.projects.find(x => x.name === modelData) ?? null
        readonly property bool open: pop.expanded === modelData
        readonly property var info: p ? p.info : null
        // Branch/Änderungen: aus dem Scan, fürs aktuelle Projekt notfalls aus Context
        readonly property string branch: info ? info.branch : (p && p.current ? Context.branch : "")
        readonly property int changes: info ? info.changes : (p && p.current ? Context.changes : -1)
        readonly property var roadmap: info && info.roadmap && info.roadmap.total > 0 ? info.roadmap : null
        // eigene Aufgaben/Ideen pro Projekt (Repo), getrennt von den Desktop-To-dos und von Claudes Roadmap
        readonly property string listKey: "project:" + modelData
        readonly property var todos: Todos.openItems(listKey)
        // Ideen: bei Repo-Projekten aus docs/BACKLOG.md (scripts/backlog), sonst lokal
        readonly property string projPath: p ? p.path : ""
        readonly property var ideas: Todos.ideasFor(listKey, projPath)
        readonly property bool inBacklog: Todos.usesBacklog(projPath)
        readonly property var strayIdeas: Todos.strayIdeas(listKey, projPath)
        readonly property var docsChanged: Todos.backlogChanged(projPath)
        readonly property int maxTodos: 5
        // Eingabe-Modus: "task" → "idea" → "claude" (Tab); Claude nur mit echtem Projektordner
        property string mode: "task"
        readonly property bool canAsk: p !== null && p.path !== "" && !p.path.endsWith(".code-workspace")
        function nextMode(): void {
            mode = mode === "task" ? "idea" : mode === "idea" && canAsk ? "claude" : "task";
        }

        width: col.width
        height: inner.implicitHeight + 24
        visible: p !== null
        radius: Theme.radiusMd
        color: open ? Theme.raise : cardHover.hovered ? Qt.alpha(Theme.text, 0.03) : "transparent"
        border.width: 1
        border.color: p && p.needs > 0 ? Qt.alpha(Theme.accent, 0.35) : open ? Theme.border : "transparent"
        Behavior on color { ColorAnimation { duration: Theme.fade } }

        HoverHandler {
            id: cardHover
        }
        // BACKLOG.md frisch halten, solange die Karte offen ist (Bastian bearbeitet sie auch von Hand)
        Timer {
            interval: 20000
            repeat: true
            running: pc.open && pop.visible && pc.projPath !== ""
            triggeredOnStart: true
            onTriggered: Todos.loadBacklog(pc.projPath)
        }
        // zugeklappt: Klick irgendwo auf die Karte klappt sie auf
        MouseArea {
            anchors.fill: parent
            enabled: !pc.open
            cursorShape: Qt.PointingHandCursor
            onClicked: pop.expanded = pc.modelData
        }

        function focusInput(): void {
            if (open)
                input.forceActiveFocus();
        }
        onOpenChanged: if (open && pop.visible) Qt.callLater(focusInput)
        Connections {
            target: pop
            function onVisibleChanged() {
                if (pop.visible && pc.open)
                    Qt.callLater(pc.focusInput);
            }
        }

        Column {
            id: inner
            x: 12
            y: 12
            width: pc.width - 24
            spacing: 8

            // Kopf: Farbpunkt, Name, Branch · Änderungen; Klick = VS Code nach vorn
            Item {
                width: inner.width
                height: 26

                Rectangle {
                    id: head
                    anchors.left: parent.left
                    anchors.leftMargin: -6
                    anchors.verticalCenter: parent.verticalCenter
                    width: headRow.implicitWidth + 12
                    height: 28
                    radius: Theme.radiusSm
                    color: headArea.containsMouse ? Theme.raise : "transparent"
                    Behavior on color { ColorAnimation { duration: Theme.fade } }

                    Row {
                        id: headRow
                        x: 6
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 9
                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 9
                            height: 9
                            radius: 4.5
                            color: pc.p ? pc.p.color : Theme.woodLight
                        }
                        Txt {
                            anchors.verticalCenter: parent.verticalCenter
                            width: Math.min(implicitWidth, 200)
                            text: pc.modelData
                            font.pixelSize: 14
                            color: Theme.text
                        }
                        Icon {
                            anchors.verticalCenter: parent.verticalCenter
                            name: "arrow_outward"
                            size: 14
                            color: Theme.textFaint
                            opacity: headArea.containsMouse ? 1 : 0
                            Behavior on opacity { NumberAnimation { duration: Theme.fade } }
                        }
                    }
                    MouseArea {
                        id: headArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (pc.p)
                                ClaudeHub.activate(pc.p);
                            pop.visible = false;
                        }
                    }
                }

                MonoTxt {
                    anchors.left: head.right
                    anchors.leftMargin: 4
                    anchors.right: chevron.left
                    anchors.rightMargin: 6
                    anchors.verticalCenter: parent.verticalCenter
                    horizontalAlignment: Text.AlignRight
                    elide: Text.ElideMiddle
                    font.pixelSize: 12
                    color: Theme.textFaint
                    text: {
                        const parts = [];
                        if (pc.branch)
                            parts.push(pc.branch);
                        if (pc.changes >= 0 && (pc.info || (pc.p && pc.p.current && Context.path)))
                            parts.push(pc.changes === 0 ? "clean" : pc.changes === 1 ? "1 change" : pc.changes + " changes");
                        return parts.join(" · ");
                    }
                }
                IconBtn {
                    id: chevron
                    anchors.right: parent.right
                    anchors.rightMargin: -4
                    anchors.verticalCenter: parent.verticalCenter
                    glyph: pc.open ? "expand_less" : "expand_more"
                    onClicked: pop.expanded = pc.open ? "" : pc.modelData
                }
            }

            // Claude-Sitzungen
            Column {
                width: inner.width
                spacing: 6
                Repeater {
                    model: pc.p ? pc.p.sessions : []
                    SessionRow {
                        required property var modelData
                        s: modelData
                    }
                }
                // Hintergrund-Aufgaben („Ask Claude…“)
                Repeater {
                    model: pc.p ? pc.p.bgTasks : []
                    TaskRow {
                        required property var modelData
                        t: modelData
                        project: pc.p
                    }
                }
                Txt {
                    visible: pc.p !== null && pc.p.sessions.length === 0 && pc.p.bgTasks.length === 0
                    text: "No Claude session · VS Code open"
                    color: Theme.textFaint
                    font.weight: Font.Normal
                }
            }

            // ---------- aufgeklappt ----------

            // Roadmap: Fortschritt + nächster offener Punkt; Klick = Datei in VS Code
            Rectangle {
                visible: pc.open && pc.roadmap !== null
                width: inner.width
                height: rmCol.implicitHeight + 16
                radius: Theme.radiusSm
                color: rmArea.containsMouse ? Theme.raise : "transparent"
                border.width: 1
                border.color: Theme.border
                Behavior on color { ColorAnimation { duration: Theme.fade } }

                Column {
                    id: rmCol
                    x: 10
                    y: 8
                    width: parent.width - 20
                    spacing: 5
                    Row {
                        spacing: 10
                        Icon {
                            anchors.verticalCenter: parent.verticalCenter
                            name: "map"
                            size: 15
                            color: Theme.textFaint
                        }
                        Txt {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Roadmap"
                            color: Theme.textMuted
                        }
                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 120
                            height: 4
                            radius: 2
                            color: Theme.raise
                            Rectangle {
                                width: pc.roadmap ? parent.width * pc.roadmap.done / pc.roadmap.total : 0
                                height: parent.height
                                radius: 2
                                color: pc.p ? pc.p.color : Theme.woodLight
                                opacity: 0.85
                            }
                        }
                        MonoTxt {
                            anchors.verticalCenter: parent.verticalCenter
                            text: pc.roadmap ? pc.roadmap.done + "/" + pc.roadmap.total : ""
                            color: Theme.textMuted
                            font.pixelSize: 12
                        }
                    }
                    Txt {
                        width: rmCol.width
                        leftPadding: 25
                        visible: pc.roadmap !== null && pc.roadmap.next !== ""
                        text: pc.roadmap ? "Next: " + pc.roadmap.next : ""
                        color: Theme.textFaint
                        font.weight: Font.Normal
                    }
                }
                MouseArea {
                    id: rmArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        ClaudeHub.openRoadmap(pc.p);
                        pop.visible = false;
                    }
                }
            }

            // eigene Aufgaben (Liste "<Projekt>" = Projekt-Desktop)
            Column {
                visible: pc.open && pc.todos.length > 0
                width: inner.width
                spacing: 0
                Label {
                    leftPadding: 4
                    bottomPadding: 4
                    text: "Tasks"
                }
                Repeater {
                    model: pc.todos.slice(0, pc.maxTodos)
                    NoteRow {
                        required property var modelData
                        check: true
                        text: modelData.text
                        onToggled: Todos.toggle(pc.listKey, modelData.id)
                        onRemoved: Todos.remove(pc.listKey, modelData.id)
                    }
                }
                Txt {
                    visible: pc.todos.length > pc.maxTodos
                    leftPadding: 32
                    text: "+" + (pc.todos.length - pc.maxTodos) + " more"
                    color: Theme.textFaint
                    font.weight: Font.Normal
                }
            }

            // Ideen (Brainstorming): Haken-Symbol = wird eigene Aufgabe, Karte = in die Roadmap (nur BACKLOG.md)
            Column {
                visible: pc.open && (pc.ideas.length > 0 || pc.strayIdeas.length > 0 || pc.docsChanged.length > 0)
                width: inner.width
                spacing: 0
                Item {
                    width: inner.width
                    height: ideasLabel.implicitHeight
                    Label {
                        id: ideasLabel
                        leftPadding: 4
                        bottomPadding: 4
                        text: "Ideas"
                    }
                    // wohin die Ideen gehen; geändert (noch nicht committet) = dezent markiert, Klick öffnet die Datei
                    MonoTxt {
                        anchors.right: parent.right
                        anchors.rightMargin: 6
                        anchors.left: ideasLabel.right
                        anchors.leftMargin: 12
                        anchors.top: parent.top
                        visible: pc.inBacklog
                        horizontalAlignment: Text.AlignRight
                        elide: Text.ElideLeft
                        font.pixelSize: 11
                        color: blArea.containsMouse ? Theme.textMuted : Theme.textFaint
                        text: pc.docsChanged.length ? pc.docsChanged.join(" · ") + " changed" : "docs/BACKLOG.md"
                        MouseArea {
                            id: blArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                const b = Todos.backlogs[pc.projPath];
                                if (b && b.file) {
                                    Launch.code([b.file]);
                                    pop.visible = false;
                                }
                            }
                        }
                    }
                }
                Repeater {
                    model: pc.ideas
                    NoteRow {
                        required property var modelData
                        glyph: "lightbulb"
                        actionGlyph: "add_task"
                        action2Glyph: pc.inBacklog ? "map" : ""
                        text: modelData.text
                        onAction: Todos.promoteIdeaFor(pc.listKey, pc.projPath, modelData.id)
                        onAction2: Todos.toRoadmap(pc.projPath, modelData.id)
                        onRemoved: Todos.removeIdeaFor(pc.listKey, pc.projPath, modelData.id)
                    }
                }
                // alte lokale Ideen: nicht automatisch verschieben, nur anbieten
                Item {
                    visible: pc.strayIdeas.length > 0
                    width: inner.width
                    height: 30
                    Txt {
                        x: 6
                        anchors.verticalCenter: parent.verticalCenter
                        text: (pc.strayIdeas.length === 1 ? "1 local idea" : pc.strayIdeas.length + " local ideas") + " – move to BACKLOG?"
                        color: Theme.textFaint
                        font.weight: Font.Normal
                    }
                    PillBtn {
                        anchors.right: parent.right
                        anchors.rightMargin: 2
                        anchors.verticalCenter: parent.verticalCenter
                        glyph: "drive_file_move"
                        label: "Move"
                        onClicked: Todos.moveIdeasToBacklog(pc.listKey, pc.projPath)
                    }
                }
            }

            // schnell notieren: Enter = speichern, Tab = Aufgabe → Idee → Claude (startet im Hintergrund)
            Rectangle {
                visible: pc.open
                width: inner.width
                height: 36
                radius: Theme.radiusMd
                color: Theme.surfaceSunken
                border.width: 1
                border.color: input.activeFocus ? Qt.alpha(Theme.accent, pc.mode === "claude" ? 0.75 : 0.5) : Theme.border
                Behavior on border.color { ColorAnimation { duration: Theme.fade } }

                IconBtn {
                    id: modeBtn
                    x: 5
                    anchors.verticalCenter: parent.verticalCenter
                    glyph: pc.mode === "claude" ? "auto_awesome" : pc.mode === "idea" ? "lightbulb" : "add_task"
                    tint: pc.mode === "claude" ? Theme.accentText : Theme.textMuted
                    fill: pc.mode === "claude"
                    onClicked: {
                        pc.nextMode();
                        input.forceActiveFocus();
                    }
                }
                TextInput {
                    id: input
                    anchors.left: modeBtn.right
                    anchors.leftMargin: 6
                    anchors.right: parent.right
                    anchors.rightMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    color: Theme.text
                    selectionColor: Theme.accentSoft
                    selectedTextColor: Theme.text
                    font.family: Theme.fontUi
                    font.pixelSize: 14
                    clip: true
                    function submit(): void {
                        if (pc.mode === "claude") {
                            if (!pc.canAsk || text.trim() === "")
                                return;
                            ClaudeTasks.start(pc.p.path, text);
                        } else if (pc.mode === "idea")
                            Todos.addIdeaFor(pc.listKey, pc.projPath, text);
                        else
                            Todos.add(pc.listKey, text);
                        text = "";
                    }
                    Keys.onReturnPressed: submit()
                    Keys.onEnterPressed: submit()
                    Keys.onTabPressed: pc.nextMode()
                    Keys.onEscapePressed: pop.visible = false
                    Txt {
                        anchors.fill: parent
                        visible: input.text === ""
                        text: pc.mode === "claude" ? "✦ Ask Claude… runs in the background  (Tab: task)"
                            : pc.mode === "idea" ? "New idea for " + pc.modelData + (pc.inBacklog ? " → BACKLOG.md" : "…") + "  (Tab: " + (pc.canAsk ? "Claude)" : "task)")
                            : "New task for " + pc.modelData + "…  (Tab: idea)"
                        color: Theme.textFaint
                        font.weight: Font.Normal
                    }
                }
            }
        }
    }

    // Agent-Map (eigenes Overlay mittig auf dem Hauptmonitor, öffnet über ClaudeHub.openMap)
    AgentMap {}

    // ---------- Karte ----------

    Glass {
        id: card
        width: parent.width
        height: Math.min(pop.maxCardHeight, col.implicitHeight + 24)
        strong: true

        Behavior on height { NumberAnimation { duration: Theme.fade; easing.type: Easing.OutCubic } }

        // Tastatur: Pfeile/Tab/Enter, Bar-Modus „A“ (KeyNav.qml)
        Keys.onPressed: e => nav.key(e)
        KeyNav { id: nav; root: card; popout: pop; name: "claudehub"; openFn: () => pop.toggle() }

        HoverHandler {
            id: popHover
            onHoveredChanged: {
                if (hovered)
                    pinnedLeave.stop();
                else if (pop.pinned) {
                    pinnedLeave.interval = 1200;
                    pinnedLeave.restart();
                }
            }
        }

        Flickable {
            id: flick
            anchors.fill: parent
            anchors.margins: 12
            contentHeight: col.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            interactive: contentHeight > height

            Column {
                id: col
                width: flick.width
                spacing: 6

                Item {
                    width: col.width
                    height: 24
                    Label {
                        anchors.left: parent.left
                        anchors.leftMargin: 6
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Projects"
                    }
                    Txt {
                        anchors.right: parent.right
                        anchors.rightMargin: 6
                        anchors.verticalCenter: parent.verticalCenter
                        font.pixelSize: 12
                        color: ClaudeHub.needsCount > 0 ? Theme.accentText : Theme.textFaint
                        text: ClaudeHub.needsCount > 0 ? (ClaudeHub.needsCount === 1 ? "1 needs you" : ClaudeHub.needsCount + " need you")
                            : ClaudeHub.workingCount > 0 ? "Claude is working" : "all quiet"
                    }
                }

                Repeater {
                    model: pop.names
                    ProjectCard {}
                }
            }
        }
    }
}

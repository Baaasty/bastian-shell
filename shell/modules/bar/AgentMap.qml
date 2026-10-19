import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.config
import qs.services
import qs.components

// Agent-Map einer Claude-Sitzung (wie die „Agent map“ der Claude-Code-Extension): links der Knoten der
// Hauptsitzung (Titel · Modell · Tokens im Kontext), rechts per dünnen Linien verbunden alle Subagents
// (Beschreibung · Laufzeit · Tokens), laufende oben mit leisem Glut-Puls, fertige gedämpft.
// Klick auf einen Agent = Detailansicht im selben Fenster (Esc/Zurück = wieder Baum).
// Geöffnet über ClaudeHub.openMap(sid) (Knopf „map“ im Popout der Claude-Zentrale), mittig auf dem
// Hauptmonitor als Overlay; Esc, Klick daneben oder × schließt. Tastatur nur, solange sie offen ist.
// Daten: scripts/claude-agents --session <id> (alle Agents der Sitzung, alle 3 s solange offen).
Scope {
    id: root

    readonly property string sid: ClaudeHub.mapSession
    readonly property bool open: sid !== ""
    // frische Daten aus dem Skript; bis dahin der Stand aus ClaudeHub
    property var data: null
    property string _text: ""
    property string selected: ""
    property real now: Date.now()

    readonly property var found: open ? ClaudeHub.findSession(sid) : null
    readonly property var project: found ? found.project : null
    readonly property var hub: found ? found.session : null
    readonly property var agents: data ? (data.agents || []) : (hub ? hub.agents : [])
    readonly property var running: agents.filter(a => a.state === "running")
    readonly property var finished: agents.filter(a => a.state !== "running")
    readonly property var current: selected ? (agents.find(a => a.id === selected) ?? null) : null
    readonly property string title: (data && data.title) || (hub && hub.title) || "Claude session"
    readonly property string model: (data && data.model) || (hub && hub.model) || ""
    readonly property real context: (data && data.context) || (hub && hub.context) || 0

    readonly property int cardWidth: 880
    readonly property int maxBody: 560

    // gemeinsamer Glut-Puls für laufende Agents – über Breathe (~12 Bilder/s) statt Dauer-Animation,
    // die das Fenster mit voller Bildrate (360 Hz) neu zeichnen ließ
    readonly property real pulse: pulseAnim.value
    Breathe {
        id: pulseAnim
        running: root.open && root.running.length > 0
        to: 0.3
    }

    function close(): void {
        ClaudeHub.closeMap();
    }
    function load(): void {
        if (!sid || proc.running)
            return;
        proc.command = [Quickshell.shellDir + "/../scripts/claude-agents", "--session", sid];
        proc.running = true;
    }
    // Laufzeit: laufende live bis jetzt, fertige erste bis letzte Zeile
    function runtime(a: var): real {
        return a.state === "running" ? Math.max(0, now - (a.since || now)) : (a.duration || 0);
    }
    function clock(ms: real): string {
        return ms ? Qt.formatDateTime(new Date(ms), "HH:mm") : "";
    }

    onSidChanged: {
        data = null;
        _text = "";
        selected = "";
        now = Date.now();
        load();
    }

    Process {
        id: proc
        stdout: StdioCollector {
            onStreamFinished: {
                const t = text.trim();
                if (t === root._text)
                    return;
                try {
                    const d = JSON.parse(t);
                    if (d[root.sid]) {
                        root.data = d[root.sid];
                        root._text = t;
                    }
                } catch (e) {}
            }
        }
    }
    Timer {
        interval: 3000
        repeat: true
        running: root.open
        onTriggered: root.load()
    }
    // Laufzeit der laufenden Agents mitzählen
    Timer {
        interval: 1000
        repeat: true
        running: root.open && root.running.length > 0
        onTriggered: root.now = Date.now()
    }

    // ---------- Bausteine ----------

    // kleiner Symbol-Knopf
    component IconBtn: Rectangle {
        id: ib
        property string glyph
        signal clicked()
        width: 30
        height: 30
        radius: Theme.radiusSm
        color: ibArea.containsMouse ? Theme.raise : "transparent"
        Behavior on color { ColorAnimation { duration: Theme.fade } }
        Icon {
            anchors.centerIn: parent
            name: ib.glyph
            size: 18
            color: ibArea.containsMouse ? Theme.text : Theme.textFaint
        }
        MouseArea {
            id: ibArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: ib.clicked()
        }
    }

    // Puls-Punkt (läuft) bzw. ✓ (fertig)
    component StateMark: Item {
        id: sm
        property bool run
        property int dot: 7
        width: 14
        height: 14
        Rectangle {
            anchors.centerIn: parent
            visible: sm.run
            width: sm.dot
            height: sm.dot
            radius: sm.dot / 2
            color: Theme.accent
            opacity: root.pulse
        }
        Icon {
            anchors.centerIn: parent
            visible: !sm.run
            name: "check"
            size: 14
            color: Theme.textFaint
        }
    }

    // ein Agent-Knoten rechts im Baum
    component AgentNode: Rectangle {
        id: an
        required property var modelData
        readonly property var a: modelData
        readonly property bool run: a.state === "running"
        width: parent ? parent.width : 0
        height: 54
        radius: Theme.radiusMd
        color: anArea.containsMouse ? Qt.alpha(Theme.text, 0.09) : run ? Theme.raise : Qt.alpha(Theme.text, 0.03)
        border.width: 1
        border.color: run ? Qt.alpha(Theme.accent, 0.3) : Theme.border
        Behavior on color { ColorAnimation { duration: Theme.fade } }

        StateMark {
            id: mark
            x: 12
            anchors.verticalCenter: parent.verticalCenter
            run: an.run
        }
        Column {
            anchors.left: mark.right
            anchors.leftMargin: 10
            anchors.right: arrow.left
            anchors.rightMargin: 6
            anchors.verticalCenter: parent.verticalCenter
            spacing: 3
            Txt {
                width: parent.width
                text: an.a.description
                color: an.run ? Theme.text : Theme.textMuted
                font.weight: an.run ? Font.Medium : Font.Normal
            }
            MonoTxt {
                width: parent.width
                elide: Text.ElideRight
                font.pixelSize: 11
                color: Theme.textFaint
                text: [an.a.type, ClaudeHub.fmtDuration(root.runtime(an.a)), ClaudeHub.fmtTokens(an.a.tokens || 0) + " tokens"]
                    .filter(x => x).join(" · ")
            }
        }
        Icon {
            id: arrow
            anchors.right: parent.right
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            name: "chevron_right"
            size: 16
            color: Theme.textFaint
            opacity: anArea.containsMouse ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: Theme.fade } }
        }
        MouseArea {
            id: anArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.selected = an.a.id
        }
    }

    // Schlüssel/Wert-Zeile in der Detailansicht
    component Fact: Row {
        id: fact
        property string key
        property string value
        property bool mono: true
        spacing: 0
        Txt {
            width: 110
            text: fact.key
            color: Theme.textFaint
            font.weight: Font.Normal
        }
        MonoTxt {
            visible: fact.mono
            text: fact.value
            color: Theme.text
        }
        Txt {
            visible: !fact.mono
            text: fact.value
            color: Theme.text
            font.weight: Font.Normal
        }
    }

    Variants {
        model: Config.mainScreens

        PanelWindow {
            id: win

            required property var modelData

            property real progress: root.open ? 1 : 0
            Behavior on progress { NumberAnimation { duration: root.open ? 150 : 110; easing.type: Easing.OutCubic } }

            screen: modelData
            visible: root.open || progress > 0
            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }
            exclusionMode: ExclusionMode.Ignore
            color: "transparent"
            WlrLayershell.namespace: "dock" // "dock": ohne Öffnen-Animation (Hyprland: layerrule noanim)
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: root.open ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

            BackgroundEffect.blurRegion: Region {
                Region { x: 0; y: 0; width: 1; height: 1 }
                Region { item: root.open ? card : null; radius: Theme.radiusXl }
            }

            onVisibleChanged: if (visible) keys.forceActiveFocus()
            Connections {
                target: root
                function onOpenChanged() {
                    if (root.open)
                        keys.forceActiveFocus();
                }
            }

            // ---------- Fenster ----------

            Rectangle {
                anchors.fill: parent
                opacity: win.progress
                color: Theme.dim
                MouseArea {
                    anchors.fill: parent
                    onClicked: root.close()
                }
            }

            FocusScope {
                id: keys
                anchors.fill: parent
                focus: true
                Keys.onEscapePressed: {
                    if (root.selected)
                        root.selected = "";
                    else
                        root.close();
                }
                Keys.onPressed: event => {
                    if (root.selected && (event.key === Qt.Key_Backspace || event.key === Qt.Key_Left)) {
                        root.selected = "";
                        event.accepted = true;
                    }
                }

                Glass {
                    id: card
                    strong: true
                    radius: Theme.radiusXl
                    width: root.cardWidth
                    height: head.height + 1 + body.height
                    x: (parent.width - width) / 2
                    y: Math.round((parent.height - height) / 2 - 40) + (1 - win.progress) * 14
                    opacity: win.progress
                    scale: 0.98 + 0.02 * win.progress
                    Behavior on height { NumberAnimation { duration: Theme.slide; easing.type: Easing.OutCubic } }

                    // Klicks auf der Karte schließen nicht
                    MouseArea {
                        anchors.fill: parent
                    }

                    // Kopf: Projekt · Sitzung · Zähler · ×
                    Item {
                        id: head
                        width: parent.width
                        height: 56

                        Row {
                            x: 22
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 10
                            Icon {
                                anchors.verticalCenter: parent.verticalCenter
                                name: "account_tree"
                                size: 18
                                color: Theme.textFaint
                            }
                            Label {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "Agent map"
                            }
                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter
                                visible: root.project !== null
                                width: 8
                                height: 8
                                radius: 4
                                color: root.project ? root.project.color : Theme.woodLight
                            }
                            Txt {
                                anchors.verticalCenter: parent.verticalCenter
                                visible: root.project !== null
                                text: root.project ? root.project.name : ""
                                color: Theme.textMuted
                            }
                        }
                        Row {
                            anchors.right: parent.right
                            anchors.rightMargin: 14
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 12
                            MonoTxt {
                                anchors.verticalCenter: parent.verticalCenter
                                font.pixelSize: 12
                                color: Theme.textFaint
                                text: root.running.length + " running · " + root.finished.length + " finished"
                            }
                            IconBtn {
                                anchors.verticalCenter: parent.verticalCenter
                                glyph: "close"
                                onClicked: root.close()
                            }
                        }
                    }
                    Rectangle {
                        id: sep
                        anchors.top: head.bottom
                        x: 20
                        width: parent.width - 40
                        height: 1
                        color: Theme.border
                    }

                    Item {
                        id: body
                        anchors.top: sep.bottom
                        width: parent.width
                        height: root.current ? detail.implicitHeight + 40
                            : Math.min(root.maxBody, Math.max(sessionNode.height, agentsCol.implicitHeight) + 40)

                        // ---------- Baum ----------
                        Item {
                            id: tree
                            anchors.fill: parent
                            visible: opacity > 0
                            opacity: root.current ? 0 : 1
                            Behavior on opacity { NumberAnimation { duration: Theme.fade } }

                            readonly property int agentsX: 22 + sessionNode.width + 96

                            // dünne Linien Sitzung -> Agents (unter den Knoten)
                            Canvas {
                                id: lines
                                anchors.fill: parent
                                onPaint: {
                                    const ctx = getContext("2d");
                                    ctx.reset();
                                    ctx.beginPath();
                                    ctx.rect(0, flick.y, width, flick.height);
                                    ctx.clip();
                                    const sx = sessionNode.x + sessionNode.width;
                                    const sy = sessionNode.y + sessionNode.height / 2;
                                    const draw = (rep, hot) => {
                                        for (let i = 0; i < rep.count; i++) {
                                            const it = rep.itemAt(i);
                                            if (!it)
                                                continue;
                                            const p = it.mapToItem(lines, 0, it.height / 2);
                                            // nur Knoten im sichtbaren Ausschnitt (sonst bündeln sich die Linien am Rand)
                                            if (p.y < flick.y - 4 || p.y > flick.y + flick.height + 4)
                                                continue;
                                            const dx = (p.x - sx) / 2;
                                            ctx.beginPath();
                                            ctx.moveTo(sx, sy);
                                            ctx.bezierCurveTo(sx + dx, sy, p.x - dx, p.y, p.x, p.y);
                                            ctx.strokeStyle = hot ? Qt.alpha(Theme.accent, 0.55) : Theme.borderStrong;
                                            ctx.lineWidth = 1;
                                            ctx.stroke();
                                        }
                                    };
                                    // fertige zuerst, laufende obendrauf
                                    draw(doneRep, false);
                                    draw(runRep, true);
                                    // Anschlusspunkt an der Sitzung
                                    if (runRep.count + doneRep.count > 0) {
                                        ctx.beginPath();
                                        ctx.arc(sx, sy, 2.5, 0, Math.PI * 2);
                                        ctx.fillStyle = root.running.length > 0 ? Theme.accent : Theme.woodLight;
                                        ctx.fill();
                                    }
                                }
                                Connections {
                                    target: flick
                                    function onContentYChanged() { lines.requestPaint(); }
                                    function onHeightChanged() { lines.requestPaint(); }
                                }
                                Connections {
                                    target: agentsCol
                                    function onImplicitHeightChanged() { lines.requestPaint(); }
                                }
                                Connections {
                                    target: sessionNode
                                    function onYChanged() { lines.requestPaint(); }
                                    function onHeightChanged() { lines.requestPaint(); }
                                }
                                onWidthChanged: requestPaint()
                                onHeightChanged: requestPaint()
                                onVisibleChanged: if (visible) requestPaint()
                                // neue Daten: erst nach dem Neu-Layout der Spalte zeichnen
                                Connections {
                                    target: root
                                    function onAgentsChanged() { repaintLater.restart(); }
                                }
                                Timer {
                                    id: repaintLater
                                    interval: 60
                                    onTriggered: lines.requestPaint()
                                }
                            }

                            // Hauptsitzung links, mittig zur sichtbaren Agent-Spalte
                            Rectangle {
                                id: sessionNode
                                x: 22
                                y: flick.y + Math.max(0, (Math.min(flick.height, agentsCol.implicitHeight) - height) / 2)
                                width: 280
                                height: sCol.implicitHeight + 28
                                radius: Theme.radiusLg
                                color: Theme.raise
                                border.width: 1
                                border.color: root.hub && root.hub.state === "working" ? Qt.alpha(Theme.accent, 0.35) : Theme.borderStrong

                                Column {
                                    id: sCol
                                    x: 16
                                    y: 14
                                    width: parent.width - 32
                                    spacing: 6
                                    Row {
                                        spacing: 8
                                        Icon {
                                            anchors.verticalCenter: parent.verticalCenter
                                            name: "auto_awesome"
                                            size: 15
                                            fill: root.hub !== null && root.hub.state === "working"
                                            color: root.hub && root.hub.state === "working" ? Theme.accentText : Theme.textFaint
                                        }
                                        Txt {
                                            anchors.verticalCenter: parent.verticalCenter
                                            font.pixelSize: 12
                                            font.weight: Font.Normal
                                            color: Theme.textFaint
                                            text: !root.hub ? "session" : root.hub.state === "waiting" ? "needs you"
                                                : root.hub.state === "working" ? "working · " + ClaudeHub.ago(root.hub.since) : "done"
                                        }
                                    }
                                    Txt {
                                        width: parent.width
                                        text: root.title
                                        color: Theme.text
                                        font.pixelSize: 15
                                        wrapMode: Text.Wrap
                                        maximumLineCount: 3
                                    }
                                    MonoTxt {
                                        width: parent.width
                                        elide: Text.ElideRight
                                        font.pixelSize: 12
                                        color: Theme.textMuted
                                        text: [ClaudeHub.prettyModel(root.model), root.context ? ClaudeHub.fmtTokens(root.context) + " in context" : ""]
                                            .filter(x => x).join(" · ")
                                    }
                                }
                            }

                            Flickable {
                                id: flick
                                x: tree.agentsX
                                y: 20
                                width: parent.width - x - 22
                                height: parent.height - 40
                                contentHeight: agentsCol.implicitHeight
                                clip: true
                                boundsBehavior: Flickable.StopAtBounds
                                interactive: false

                                Column {
                                    id: agentsCol
                                    width: flick.width
                                    spacing: 6

                                    Label {
                                        visible: root.running.length > 0
                                        leftPadding: 4
                                        text: "Running"
                                    }
                                    Repeater {
                                        id: runRep
                                        model: root.running
                                        AgentNode {}
                                        onItemAdded: Qt.callLater(lines.requestPaint)
                                        onItemRemoved: Qt.callLater(lines.requestPaint)
                                    }
                                    Item {
                                        visible: root.running.length > 0 && root.finished.length > 0
                                        width: 1
                                        height: 6
                                    }
                                    Label {
                                        visible: root.finished.length > 0
                                        leftPadding: 4
                                        text: "Finished"
                                    }
                                    Repeater {
                                        id: doneRep
                                        model: root.finished
                                        AgentNode {}
                                        onItemAdded: Qt.callLater(lines.requestPaint)
                                        onItemRemoved: Qt.callLater(lines.requestPaint)
                                    }
                                    Txt {
                                        visible: root.agents.length === 0
                                        height: 54
                                        leftPadding: 4
                                        text: "No agents in this session yet"
                                        color: Theme.textFaint
                                        font.weight: Font.Normal
                                    }
                                }
                            }
                            WheelScroll {
                                flick: flick
                            }
                        }

                        // ---------- Detail ----------
                        Column {
                            id: detail
                            x: 28
                            y: 20
                            width: parent.width - 56
                            spacing: 14
                            visible: opacity > 0
                            opacity: root.current ? 1 : 0
                            Behavior on opacity { NumberAnimation { duration: Theme.fade } }

                            // Zurück zum Baum
                            Rectangle {
                                width: backRow.implicitWidth + 16
                                height: 28
                                x: -8
                                radius: Theme.radiusSm
                                color: backArea.containsMouse ? Theme.raise : "transparent"
                                Behavior on color { ColorAnimation { duration: Theme.fade } }
                                Row {
                                    id: backRow
                                    x: 8
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 6
                                    Icon {
                                        anchors.verticalCenter: parent.verticalCenter
                                        name: "arrow_back"
                                        size: 16
                                        color: backArea.containsMouse ? Theme.text : Theme.textFaint
                                    }
                                    Txt {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: "All agents"
                                        color: backArea.containsMouse ? Theme.text : Theme.textMuted
                                        font.weight: Font.Normal
                                    }
                                }
                                MouseArea {
                                    id: backArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.selected = ""
                                }
                            }

                            Row {
                                spacing: 12
                                width: detail.width
                                StateMark {
                                    anchors.verticalCenter: parent.verticalCenter
                                    run: root.current !== null && root.current.state === "running"
                                    dot: 9
                                }
                                Txt {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: detail.width - 30
                                    text: root.current ? root.current.description : ""
                                    font.pixelSize: 18
                                    wrapMode: Text.Wrap
                                    maximumLineCount: 2
                                }
                            }

                            Column {
                                spacing: 8
                                Fact {
                                    key: "Status"
                                    mono: false
                                    value: !root.current ? "" : root.current.state === "running" ? "running" : "finished"
                                }
                                Fact {
                                    key: "Type"
                                    value: root.current ? (root.current.type || "agent") : ""
                                }
                                Fact {
                                    key: "Started"
                                    value: root.current ? root.clock(root.current.since) + "  ·  " + ClaudeHub.ago(root.current.since)
                                        + (ClaudeHub.ago(root.current.since) === "just now" ? "" : " ago") : ""
                                }
                                Fact {
                                    key: "Runtime"
                                    value: root.current ? ClaudeHub.fmtDuration(root.runtime(root.current)) : ""
                                }
                                Fact {
                                    key: "Tokens"
                                    value: root.current ? ClaudeHub.fmtTokens(root.current.tokens || 0) + " in context" : ""
                                }
                                Fact {
                                    key: "Agent ID"
                                    value: root.current ? root.current.id : ""
                                }
                            }

                            Row {
                                spacing: 10
                                topPadding: 4
                                Button {
                                    visible: root.current !== null && (root.current.file || "") !== ""
                                    icon: "description"
                                    text: "Open transcript"
                                    onClicked: {
                                        Launch.code([root.current.file]);
                                        root.close();
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

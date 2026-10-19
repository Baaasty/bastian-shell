import QtQuick
import qs.config
import qs.services
import qs.components

// Eine Rückfrage von Claude Code: Erlaubnis (Allow / Always allow / Deny) oder Frage (Optionen).
// Zeigt nur einen Snapshot des Eintrags, damit das Ausblenden nicht auf schon Weggeräumtes zugreift.
// Kopf (Projektpunkt + Name) holt das VS-Code-Fenster des Projekts nach vorn, × gibt an VS Code zurück.
Glass {
    id: card

    property string entryId
    property bool isClosing: false
    property real now: Date.now()
    signal finished()
    signal touched()

    // Snapshot
    property var e: ({})
    // Bindung statt Snapshot: zieht nach, falls projects.json/Palette erst später geladen sind
    readonly property color dot: ClaudeGate.colorFor(e)
    readonly property bool isQuestion: e.kind === "question"
    readonly property var questions: e.questions || []

    // Antworten wie die VS-Code-Frage-UI: Option(en), „Other“ = eigener Text, Notiz pro Frage
    property var picks: ({})      // frage → [labels]
    property var others: ({})     // frage → eigener Text (auch Text-/Zahlfragen)
    property var notes: ({})      // frage → Notiz (→ annotations.notes)
    property var openFields: ({}) // "other:<frage>" / "note:<frage>" → true
    property int tab: 0           // mehrere Fragen: Reiter wie in VS Code
    readonly property bool tabbed: questions.length > 1
    // ein Textfeld der Karte hat die Tastatur (Attention lässt sie dann nicht zurückfallen)
    property bool typing: false
    signal keysBack()

    // nur eine Frage mit Einfachauswahl und nichts Getipptes: Klick auf eine Option schickt sofort
    readonly property bool oneShot: questions.length === 1 && !questions[0].multiSelect && kindOf(questions[0]) === "choice"
        && !openFields["other:" + questions[0].question] && !openFields["note:" + questions[0].question]
        && !textOf(others, questions[0]) && !textOf(notes, questions[0]) && !(picks[questions[0].question] || []).length

    readonly property int answeredCount: questions.filter(q => answerOf(q) !== null).length
    readonly property bool allAnswered: questions.length > 0 && answeredCount === questions.length
    // nicht sauber übermittelbar → „Answer in VS Code“ statt etwas Falsches zu senden
    readonly property string blocker: hardProblem()
    // vom Nutzer behebbar (z. B. Zahl außerhalb des Bereichs) → Send aus, Hinweis
    readonly property string hint: questions.map(q => softProblem(q)).find(s => s !== "") || ""
    readonly property bool canSend: allAnswered && blocker === "" && hint === ""

    // ---------- Erlaubnis: nichts erlauben, was man nicht gesehen hat ----------
    // Die Karte zeigt den Befehl auf 4 Zeilen; ein gefährlicher Teil am Ende eines langen Befehls wäre
    // vor „Allow“ unsichtbar. Darum: gekürzt → erst „show all“, dann Allow/Always (auch per Enter).
    property bool showAll: false
    readonly property string detailText: String(e.detail || "")
    // schon claude-gate hat gekürzt (ältere Version: short() → genau 200/300/400/600 Zeichen mit „…“;
    // neuere melden cut/detailLen): dann sieht man den vollen Befehl nur in VS Code
    readonly property bool gateCut: e.cut === true
        || (e.detailLen === undefined && detailText.endsWith("…") && [200, 300, 400, 600].includes(detailText.length))
    readonly property bool clipped: detailMeasure.lineCount > 4
    readonly property bool canAllow: isQuestion || (!gateCut && (!clipped || showAll))

    // Layout (setzt Attention.relayout)
    property bool inView: true
    readonly property bool shown: inView && !isClosing
    readonly property bool blurOn: visible && opacity >= 0.4

    height: body.implicitHeight + 28
    visible: shown || exitAnim.running
    opacity: 0
    strong: true
    border.color: Qt.alpha(Theme.accent, 0.38)

    Component.onCompleted: {
        e = ClaudeGate.byId(entryId) || {};
        if (shown)
            enterAnim.start();
    }
    // hinter „+ n more“ versteckt und schon erledigt: gleich weg
    onIsClosingChanged: if (isClosing && !shown && !exitAnim.running) card.finished()
    onShownChanged: {
        if (shown) {
            exitAnim.stop();
            enterAnim.start();
        } else {
            enterAnim.stop();
            if (opacity > 0)
                exitAnim.start();
            else if (isClosing)
                card.finished();
        }
    }

    ParallelAnimation {
        id: enterAnim
        NumberAnimation { target: card; property: "opacity"; to: 1; duration: Theme.slide; easing.type: Easing.OutCubic }
        NumberAnimation { target: slide; property: "y"; from: -8; to: 0; duration: Theme.slide; easing.type: Easing.OutCubic }
    }
    ParallelAnimation {
        id: exitAnim
        NumberAnimation { target: card; property: "opacity"; to: 0; duration: Theme.fade; easing.type: Easing.InCubic }
        NumberAnimation { target: slide; property: "y"; to: -6; duration: Theme.fade; easing.type: Easing.InCubic }
        onFinished: if (card.isClosing) card.finished()
    }
    transform: Translate { id: slide }

    function age(): string {
        const s = Math.max(0, Math.round((now - (e.created || now)) / 1000));
        return s < 60 ? s + "s" : Math.floor(s / 60) + "m";
    }

    function title(): string {
        if (isQuestion)
            return "";
        if (e.note)
            return e.note;
        const verbs = {
            Bash: "Run command?",
            Edit: "Edit file?",
            MultiEdit: "Edit file?",
            Write: "Write file?",
            Read: "Read file?",
            NotebookEdit: "Edit notebook?",
            WebFetch: "Fetch page?",
            WebSearch: "Search the web?",
            ExitPlanMode: "Start with this plan?"
        };
        return verbs[e.tool] || ("Use " + (e.toolLabel || e.tool) + "?");
    }

    function decide(d: var): void {
        if (isClosing)
            return;
        ClaudeGate.decide(entryId, d);
    }
    // ---------- Fragen ----------
    function kindOf(q: var): string {
        return q ? (q.kind || "choice") : "choice";
    }
    function textOf(map: var, q: var): string {
        return q ? String(map[q.question] || "").trim() : "";
    }
    function supported(q: var): bool {
        const k = kindOf(q);
        return (k === "choice" && (q.options || []).length > 0) || k === "text" || k === "number";
    }
    // Antwort im Format von claude-gate decide: Label | eigener Text | [labels…, eigener Text] | null
    function answerOf(q: var): var {
        const o = textOf(others, q);
        if (kindOf(q) !== "choice")
            return o || null;
        const p = picks[q.question] || [];
        if (q.multiSelect) {
            const l = p.slice();
            if (o)
                l.push(o);
            return l.length ? l : null;
        }
        return o || p[0] || null;
    }
    // Grenzen wie Claude Code (Antwort 32768, Notiz 8192, zusammen 32768 Zeichen) mit etwas Abstand
    function hardProblem(): string {
        let total = 0;
        for (const q of questions) {
            if (!supported(q))
                return "This question type only works in VS Code";
            const o = textOf(others, q), n = textOf(notes, q);
            if (o.length > 30000)
                return "Your text is too long for the card";
            if (n.length > 8000)
                return "Your note is too long for the card";
            total += o.length + n.length;
        }
        return total > 30000 ? "Your answers are too long for the card" : "";
    }
    function softProblem(q: var): string {
        if (kindOf(q) !== "number")
            return "";
        const o = textOf(others, q);
        if (!o)
            return "";
        const v = Number(o);
        const range = (q.min !== undefined && q.max !== undefined) ? " between " + q.min + " and " + q.max : "";
        if (!/^-?\d+(\.\d+)?$/.test(o) || (q.min !== undefined && v < q.min) || (q.max !== undefined && v > q.max))
            return "Enter a number" + range;
        return "";
    }

    function setMap(name: string, q: var, value: var): void {
        const m = Object.assign({}, card[name]);
        m[q.question] = value;
        card[name] = m;
    }
    function setOther(q: var, text: string): void {
        if (String(others[q.question] || "") === text)
            return;
        setMap("others", q, text);
        // Einfachauswahl: eigener Text ersetzt die Option (wie „Other“ in VS Code)
        if (!q.multiSelect && text.trim() && (picks[q.question] || []).length)
            setMap("picks", q, []);
    }
    function setNote(q: var, text: string): void {
        if (String(notes[q.question] || "") !== text)
            setMap("notes", q, text);
    }
    function isOpen(kind: string, q: var): bool {
        return !!openFields[kind + ":" + q.question];
    }
    function openField(kind: string, q: var): void {
        const f = Object.assign({}, openFields);
        f[kind + ":" + q.question] = true;
        openFields = f;
    }
    // Esc = zurück: Feld zu, Text weg, Tastatur wieder an die Karte (Enter/Esc)
    function closeField(kind: string, q: var): void {
        const f = Object.assign({}, openFields);
        delete f[kind + ":" + q.question];
        openFields = f;
        if (kind === "other")
            setOther(q, "");
        else
            setNote(q, "");
        card.keysBack();
    }

    function pick(q: var, label: string): void {
        if (oneShot) {
            decide({ behavior: "allow", answers: { [q.question]: label } });
            return;
        }
        const cur = (picks[q.question] || []).slice();
        if (q.multiSelect) {
            const i = cur.indexOf(label);
            if (i >= 0)
                cur.splice(i, 1);
            else
                cur.push(label);
            setMap("picks", q, cur);
        } else {
            const on = cur[0] !== label;
            setMap("picks", q, on ? [label] : []);
            if (on && textOf(others, q)) {
                const f = Object.assign({}, openFields);
                delete f["other:" + q.question];
                openFields = f;
                setMap("others", q, "");
            }
            // mehrere Fragen: weiter zur nächsten offenen (außer es soll noch eine Notiz dazu)
            if (on && tabbed && !isOpen("note", q))
                Qt.callLater(card.nextTab);
        }
    }
    function nextTab(): void {
        for (let k = 1; k <= questions.length; k++) {
            const i = (tab + k) % questions.length;
            if (answerOf(questions[i]) === null) {
                tab = i;
                return;
            }
        }
    }
    function send(): void {
        if (!canSend)
            return;
        const answers = {}, n = {};
        for (const q of questions) {
            answers[q.question] = answerOf(q);
            if (textOf(notes, q))
                n[q.question] = textOf(notes, q);
        }
        decide({ behavior: "allow", answers: answers, notes: n });
    }
    // Enter (nach Klick in die Karte oder im Textfeld)
    function primaryAction(): void {
        if (!isQuestion) {
            // Enter auf gekürztem Befehl klappt erst auf (nie blind erlauben)
            if (canAllow)
                decide({ behavior: "allow" });
            else if (clipped && !gateCut)
                showAll = true;
        } else if (canSend)
            send();
        else if (tabbed && answerOf(questions[tab]) !== null)
            nextTab();
    }
    function inVsCode(): void {
        ClaudeGate.open(card.e);
        card.decide({ behavior: "pass" });
    }

    HoverHandler {
        id: hover
    }
    // jeder Klick in die Karte holt die Tastatur (Enter/Esc), ohne den Klick zu schlucken
    MouseArea {
        z: 100
        anchors.fill: parent
        propagateComposedEvents: true
        onPressed: mouse => {
            card.touched();
            mouse.accepted = false;
        }
    }

    Column {
        id: body
        x: 16
        y: 14
        width: parent.width - 32
        spacing: 10

        // Kopf: Projekt · Tool, rechts Wartezeit + Glut
        Item {
            width: parent.width
            height: 20

            Row {
                id: head
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 8
                    height: 8
                    radius: 4
                    color: card.dot
                }
                Txt {
                    anchors.verticalCenter: parent.verticalCenter
                    text: card.e.project || "Claude"
                    color: headArea.containsMouse ? Theme.text : Theme.textMuted
                    font.pixelSize: 12
                    font.weight: Font.DemiBold
                    Behavior on color { ColorAnimation { duration: Theme.fade } }
                }
                Txt {
                    anchors.verticalCenter: parent.verticalCenter
                    text: (card.isQuestion ? "question" : (card.e.toolLabel || card.e.tool || "")) + (card.e.agent ? " · subagent" : "")
                    color: Theme.textFaint
                    font.pixelSize: 12
                    font.weight: Font.Normal
                    width: Math.min(implicitWidth, card.width - 200)
                }
            }
            MouseArea {
                id: headArea
                x: 0
                width: head.width + 8
                height: parent.height
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: ClaudeGate.open(card.e)
            }

            Row {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8

                MonoTxt {
                    anchors.verticalCenter: parent.verticalCenter
                    text: card.age()
                    color: Theme.textFaint
                    font.pixelSize: 11
                    visible: !hover.hovered
                }
                // Glut: atmet leise, solange Claude wartet
                Rectangle {
                    id: ember
                    anchors.verticalCenter: parent.verticalCenter
                    width: 7
                    height: 7
                    radius: 3.5
                    color: Theme.accent
                    visible: !hover.hovered
                    // Atmen über Breathe (~12 Bilder/s): die frühere Dauer-Animation zeichnete die Karte
                    // mit voller Bildrate neu, solange sie wartet (~4–5 % CPU nur für diesen Punkt)
                    opacity: emberPulse.value
                    Breathe {
                        id: emberPulse
                        running: card.shown && ember.visible
                    }
                }
                // × = zurück an VS Code (Dialog dort bleibt)
                Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: hover.hovered
                    name: "close"
                    size: 16
                    color: closeArea.containsMouse ? Theme.text : Theme.textFaint
                    MouseArea {
                        id: closeArea
                        anchors.fill: parent
                        anchors.margins: -6
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: card.decide({ behavior: "pass" })
                    }
                }
            }
        }

        // ---------- Erlaubnis ----------
        Txt {
            width: parent.width
            visible: !card.isQuestion
            text: card.title()
            font.pixelSize: 14
            font.weight: Font.DemiBold
        }
        Rectangle {
            width: parent.width
            visible: !card.isQuestion && card.detailText !== ""
            height: detailFlick.height + 16
            radius: Theme.radiusSm
            color: Theme.raise
            border.width: 1
            border.color: card.canAllow ? Theme.border : Qt.alpha(Theme.warning, 0.5)

            // misst die volle Zeilenzahl (gleiche Breite/Schrift, ohne Zeilenlimit)
            Text {
                id: detailMeasure
                visible: false
                width: detail.width
                text: card.detailText
                textFormat: Text.PlainText
                wrapMode: Text.WrapAnywhere
                font: detail.font
                lineHeight: detail.lineHeight
            }
            // aufgeklappt: ganzer Text, scrollbar (höchstens ~16 Zeilen hoch)
            Flickable {
                id: detailFlick
                x: 10
                y: 8
                width: parent.width - 20
                height: Math.min(detail.implicitHeight, 300)
                contentWidth: width
                contentHeight: detail.implicitHeight
                clip: true
                interactive: false
                boundsBehavior: Flickable.StopAtBounds

                Text {
                    id: detail
                    width: detailFlick.width
                    text: card.detailText
                    textFormat: Text.PlainText
                    wrapMode: Text.WrapAnywhere
                    maximumLineCount: card.showAll ? 100000 : 4
                    elide: Text.ElideRight
                    color: Theme.text
                    font.family: card.e.mono === false ? Theme.fontUi : Theme.fontMono
                    font.pixelSize: 12
                    lineHeight: 1.15
                }
            }
            WheelScroll {
                flick: detailFlick
                step: 80
            }
        }
        // gekürzt: deutlich sagen und aufklappen lassen; Allow/Always erst danach
        Txt {
            width: parent.width
            visible: !card.isQuestion && (card.clipped || card.gateCut)
            wrapMode: Text.WordWrap
            maximumLineCount: 3
            text: card.gateCut ? "Command cut off before the end – review the full command in VS Code"
                : card.showAll ? "Showing all " + detailMeasure.lineCount + " lines · " + card.detailText.length + " chars · show less"
                : "Truncated: +" + (detailMeasure.lineCount - 4) + " lines (" + card.detailText.length + " chars) – show all to allow"
            color: card.canAllow ? Theme.textFaint : Theme.warning
            font.pixelSize: 12
            font.weight: Font.Normal
            TapHandler {
                enabled: card.clipped && !card.gateCut
                onTapped: card.showAll = !card.showAll
            }
            HoverHandler {
                enabled: card.clipped && !card.gateCut
                cursorShape: Qt.PointingHandCursor
            }
        }
        Row {
            visible: !card.isQuestion
            spacing: 8
            topPadding: 2

            // gekürzt und nicht aufgeklappt: Allow/Always sichtbar, aber aus (Hinweis darüber)
            Button {
                height: 32
                primary: card.canAllow
                opacity: card.canAllow ? 1 : 0.4
                text: "Allow"
                onClicked: if (card.canAllow) card.decide({ behavior: "allow" })
            }
            Button {
                id: always
                height: 32
                // vom Skript gekürzt: hier gar nicht anbieten (Platz für „Review in VS Code“)
                visible: card.e.canAlways === true && !card.gateCut
                opacity: card.canAllow ? 1 : 0.4
                text: "Always allow"
                onClicked: if (card.canAllow) card.decide({ behavior: "allow", always: true })
            }
            // vom Skript gekürzt: Ansehen geht nur in VS Code
            Button {
                height: 32
                visible: card.gateCut
                text: "Review in VS Code"
                onClicked: card.inVsCode()
            }
            Button {
                height: 32
                text: "Deny"
                onClicked: card.decide({ behavior: "deny" })
            }
        }
        // was „Always allow“ merkt (z. B. Bash(git push:*))
        Txt {
            width: parent.width
            visible: !card.isQuestion && card.e.canAlways === true && !!card.e.alwaysNote
            text: "always: " + (card.e.alwaysNote || "")
            color: Theme.textFaint
            font.pixelSize: 11
            font.weight: Font.Normal
        }

        // ---------- Frage(n) ----------
        // mehrere Fragen: Reiter (✓ = beantwortet), Senden erst, wenn alle beantwortet sind
        Row {
            id: tabs
            visible: card.isQuestion && card.tabbed
            spacing: 6

            Repeater {
                model: tabs.visible ? card.questions : []

                Rectangle {
                    id: tabPill
                    required property var modelData
                    required property int index
                    readonly property bool cur: card.tab === index
                    readonly property bool done: card.answerOf(modelData) !== null && card.softProblem(modelData) === ""

                    height: 24
                    width: tabRow.implicitWidth + 20
                    radius: height / 2
                    color: cur ? Theme.accentSoft : tabArea.containsMouse ? Qt.alpha(Theme.text, 0.1) : Theme.raise
                    border.width: 1
                    border.color: cur ? Qt.alpha(Theme.accent, 0.55) : Theme.border
                    Behavior on color { ColorAnimation { duration: Theme.fade } }

                    Row {
                        id: tabRow
                        anchors.centerIn: parent
                        spacing: 4
                        Icon {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: tabPill.done
                            name: "check"
                            size: 13
                            color: tabPill.cur ? Theme.accentText : Theme.success
                        }
                        Txt {
                            anchors.verticalCenter: parent.verticalCenter
                            text: tabPill.modelData.header || ("Q" + (tabPill.index + 1))
                            width: Math.min(implicitWidth, (body.width - 6 * (card.questions.length - 1)) / card.questions.length - 38)
                            color: tabPill.cur ? Theme.accentText : Theme.textMuted
                            font.pixelSize: 12
                        }
                    }
                    MouseArea {
                        id: tabArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: card.tab = tabPill.index
                    }
                }
            }
        }

        Repeater {
            model: card.isQuestion ? card.questions : []

            Column {
                id: qcol
                required property var modelData
                required property int index
                readonly property var q: modelData
                readonly property string kind: card.kindOf(q)
                readonly property bool choice: kind === "choice" && (q.options || []).length > 0
                readonly property bool otherOpen: card.isOpen("other", q) || card.textOf(card.others, q) !== ""
                readonly property bool noteOpen: card.isOpen("note", q) || card.textOf(card.notes, q) !== ""

                width: body.width
                spacing: 6
                visible: !card.tabbed || card.tab === index

                Label {
                    visible: !!qcol.q.header && !card.tabbed
                    text: qcol.q.header + (qcol.q.multiSelect ? "  ·  pick any" : "")
                    font.pixelSize: 11
                }
                Text {
                    width: parent.width
                    text: qcol.q.question
                    textFormat: Text.PlainText
                    wrapMode: Text.WordWrap
                    maximumLineCount: 4
                    elide: Text.ElideRight
                    color: Theme.text
                    font.family: Theme.fontUi
                    font.pixelSize: 14
                    font.weight: Font.DemiBold
                    lineHeight: 1.15
                }
                Txt {
                    visible: card.tabbed && qcol.q.multiSelect
                    text: "pick any"
                    color: Theme.textFaint
                    font.pixelSize: 11
                    font.weight: Font.Normal
                }

                Repeater {
                    model: qcol.choice ? qcol.q.options : []

                    Rectangle {
                        id: opt
                        required property var modelData
                        readonly property bool picked: (card.picks[qcol.q.question] || []).includes(modelData.label)

                        width: qcol.width
                        height: optCol.implicitHeight + 14
                        radius: Theme.radiusMd
                        color: picked ? Theme.accentSoft : optArea.containsMouse ? Qt.alpha(Theme.text, 0.1) : Theme.raise
                        border.width: 1
                        border.color: picked ? Qt.alpha(Theme.accent, 0.55) : Theme.border
                        Behavior on color { ColorAnimation { duration: Theme.fade } }

                        Icon {
                            id: tick
                            x: 10
                            anchors.verticalCenter: parent.verticalCenter
                            visible: qcol.q.multiSelect
                            name: opt.picked ? "check_box" : "check_box_outline_blank"
                            fill: opt.picked
                            size: 16
                            color: opt.picked ? Theme.accentText : Theme.textFaint
                        }
                        Column {
                            id: optCol
                            x: tick.visible ? 34 : 12
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - x - 12
                            spacing: 1

                            Txt {
                                width: parent.width
                                text: opt.modelData.label
                                color: opt.picked ? Theme.accentText : Theme.text
                            }
                            Text {
                                width: parent.width
                                visible: text !== ""
                                text: opt.modelData.description || ""
                                textFormat: Text.PlainText
                                wrapMode: Text.WordWrap
                                maximumLineCount: 2
                                elide: Text.ElideRight
                                color: Theme.textFaint
                                font.family: Theme.fontUi
                                font.pixelSize: 12
                            }
                        }
                        MouseArea {
                            id: optArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: card.pick(qcol.q, opt.modelData.label)
                        }
                    }
                }

                // eigener Text: bei „Other…“ und bei Text-/Zahlfragen
                AnswerField {
                    width: qcol.width
                    visible: (qcol.choice && qcol.otherOpen) || qcol.kind === "text" || qcol.kind === "number"
                    autoFocus: qcol.choice && qcol.visible
                    icon: qcol.choice ? "edit" : ""
                    placeholder: qcol.kind === "number"
                        ? "Number" + (qcol.q.min !== undefined && qcol.q.max !== undefined ? " (" + qcol.q.min + "–" + qcol.q.max + ")" : "") + (qcol.q.unit ? " " + qcol.q.unit : "")
                        : qcol.choice ? (qcol.q.multiSelect ? "Something else…" : "Your own answer…") : (qcol.q.placeholder || "Your answer…")
                    text: card.others[qcol.q.question] || ""
                    marked: card.textOf(card.others, qcol.q) !== ""
                    invalid: card.softProblem(qcol.q) !== ""
                    onTextChanged: card.setOther(qcol.q, text)
                    onTypingChanged: card.typing = typing
                    onAccepted: {
                        if (qcol.choice && card.textOf(card.others, qcol.q) === "")
                            card.closeField("other", qcol.q);
                        else
                            card.primaryAction();
                    }
                    onCancelled: {
                        if (qcol.choice)
                            card.closeField("other", qcol.q);
                        else {
                            card.setOther(qcol.q, "");
                            card.keysBack();
                        }
                    }
                }
                // „Other…“ (eigener Text statt/zusätzlich zur Auswahl) + „+ note“ (Notiz zur Auswahl)
                Item {
                    width: qcol.width
                    height: 30
                    visible: qcol.choice && (!qcol.otherOpen || !qcol.noteOpen)

                    Rectangle {
                        id: otherBtn
                        visible: !qcol.otherOpen
                        width: noteBtn.visible ? parent.width - noteBtn.width - 6 : parent.width
                        height: parent.height
                        radius: Theme.radiusMd
                        color: otherArea.containsMouse ? Qt.alpha(Theme.text, 0.1) : "transparent"
                        border.width: 1
                        border.color: Theme.border
                        Behavior on color { ColorAnimation { duration: Theme.fade } }

                        Row {
                            x: qcol.q.multiSelect ? 10 : 12
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 8
                            Icon {
                                anchors.verticalCenter: parent.verticalCenter
                                name: "edit"
                                size: 15
                                color: Theme.textFaint
                            }
                            Txt {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "Other…"
                                color: otherArea.containsMouse ? Theme.textMuted : Theme.textFaint
                                font.weight: Font.Normal
                            }
                        }
                        MouseArea {
                            id: otherArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: card.openField("other", qcol.q)
                        }
                    }
                    Rectangle {
                        id: noteBtn
                        anchors.right: parent.right
                        visible: !qcol.noteOpen
                        width: noteRow.implicitWidth + 22
                        height: parent.height
                        radius: Theme.radiusMd
                        color: noteArea.containsMouse ? Qt.alpha(Theme.text, 0.1) : "transparent"
                        border.width: 1
                        border.color: Theme.border
                        Behavior on color { ColorAnimation { duration: Theme.fade } }

                        Row {
                            id: noteRow
                            anchors.centerIn: parent
                            spacing: 4
                            Icon {
                                anchors.verticalCenter: parent.verticalCenter
                                name: "add"
                                size: 15
                                color: Theme.textFaint
                            }
                            Txt {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "note"
                                color: noteArea.containsMouse ? Theme.textMuted : Theme.textFaint
                                font.weight: Font.Normal
                            }
                        }
                        MouseArea {
                            id: noteArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: card.openField("note", qcol.q)
                        }
                    }
                }

                // Notiz zur Auswahl (geht als annotations.notes an Claude)
                AnswerField {
                    width: qcol.width
                    visible: qcol.choice && qcol.noteOpen
                    autoFocus: qcol.visible
                    icon: "sticky_note_2"
                    placeholder: "Note for Claude…"
                    text: card.notes[qcol.q.question] || ""
                    onTextChanged: card.setNote(qcol.q, text)
                    onTypingChanged: card.typing = typing
                    onAccepted: card.primaryAction()
                    onCancelled: card.closeField("note", qcol.q)
                }
            }
        }

        // Fehlerfall/Hinweis
        Txt {
            width: parent.width
            visible: card.isQuestion && (card.blocker !== "" || card.hint !== "")
            text: card.blocker || card.hint
            color: card.blocker ? Theme.warning : Theme.textFaint
            wrapMode: Text.WordWrap
            font.pixelSize: 12
            font.weight: Font.Normal
        }
        Row {
            visible: card.isQuestion && (!card.oneShot || card.blocker !== "")
            spacing: 8
            topPadding: 2

            Button {
                height: 32
                visible: card.blocker === ""
                primary: card.canSend
                opacity: card.canSend ? 1 : 0.4
                text: card.tabbed && !card.allAnswered ? "Send (" + card.answeredCount + "/" + card.questions.length + ")" : "Send"
                onClicked: card.send()
            }
            Button {
                height: 32
                primary: card.blocker !== ""
                text: card.blocker !== "" ? "Answer in VS Code" : "In VS Code"
                onClicked: card.inVsCode()
            }
        }
    }
}

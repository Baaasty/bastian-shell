import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.services
import qs.components

// To-dos-Popout unter dem Chip oben links (TodoChip.qml), Tastatur: Bar-Modus „O“ / `barmode popout todo`.
// Oben das Eingabefeld „Gedanken parken“ (hat beim Öffnen den Fokus): tippen + Enter = Gedanke in die Inbox
// (Notes.qml, ~/Notes/inbox.md), „t …“/„! …“ = gleich eine Aufgabe. Darunter die Inbox zum Abarbeiten – je Gedanke
// abhaken, zur Aufgabe machen, ins Projekt-Backlog (docs/BACKLOG.md, scripts/backlog), löschen (zweimal drücken) –
// und die To-dos des Desktops + General wie bisher. ↑/↓/Tab/Enter über KeyNav, tippen springt zurück ins Feld.
// Doku: docs/knowledge/shell-features.md („Gedanken parken & To-dos“)
PopupWindow {
    id: pop

    property var barWindow
    property Item chip
    readonly property int maxCardH: 680
    property string flashText: ""
    property bool flashError: false
    property string _lastText: ""    // zuletzt abgeschickt (kommt bei Fehler ins Feld zurück)

    // Ziel für „ins Backlog“: Projekt des Desktops (Projekt-Desktops heißen wie das Projekt), sonst das VS-Code-Projekt
    readonly property var project: {
        const repo = p => !!p && !p.endsWith(".code-workspace");
        const d = Projects.list.find(x => x.name === Todos.current && repo(x.path));
        if (d)
            return { name: d.name, path: d.path };
        if (Context.valid && repo(Context.path))
            return { name: Context.project, path: Context.path };
        return null;
    }
    readonly property string todoTarget: Notes.todoList === "current" ? Todos.current : Notes.todoList

    anchor.window: barWindow
    anchor.edges: Edges.Bottom
    anchor.gravity: Edges.Bottom
    grabFocus: true
    implicitWidth: 480
    implicitHeight: Math.min(maxCardH, 12 + head.implicitHeight + 10 + body.implicitHeight + 12)
    color: "transparent"
    visible: false

    // ---------- Öffnen / Schließen ----------
    // wie die Benachrichtigungen mit Lücke unter der Bar (nicht am Chip)
    function placeUnderBar(): void {
        if (!chip)
            return;
        const p = chip.mapToItem(null, 0, 0);
        anchor.rect.x = p.x;
        anchor.rect.y = Theme.barMargin + Theme.barHeight + Theme.windowGap - 1;
        anchor.rect.width = chip.width;
        anchor.rect.height = 1;
    }
    function open(): void {
        if (visible)
            return;
        placeUnderBar();
        visible = true;
    }
    // gewollt schließen (Esc, Chip, Weghovern); schließt der Compositor es, holt PopoutGuard es zurück
    function close(): void {
        guard.intended = true;
        visible = false;
    }
    function toggle(): void {
        if (visible)
            close();
        else
            open();
    }

    onVisibleChanged: {
        if (barWindow)
            barWindow.openMenus += visible ? 1 : -1;
        if (visible) {
            Popouts.claim("todo");
            flick.contentY = 0;
            input.forceActiveFocus();
        } else {
            Popouts.release("todo");
            flashText = "";
        }
    }
    // nur ein Bar-Popout gleichzeitig
    Connections {
        target: Popouts
        function onCurrentChanged() {
            if (Popouts.current !== "todo" && pop.visible)
                pop.visible = false;
        }
    }

    // ---------- Rückmeldung nach Enter ----------
    function flash(text: string, error: bool): void {
        flashText = text;
        flashError = error;
        flashTimer.restart();
    }
    Timer {
        id: flashTimer
        interval: 1600
        onTriggered: pop.flashText = ""
    }
    Connections {
        target: Notes
        function onSaved(todo) {
            pop.flash(todo ? "Added to " + pop.todoTarget : "Parked", false);
        }
        function onFailed() {
            pop.flash("Could not save", true);
            if (input.text === "")
                input.text = pop._lastText;
        }
    }
    function submit(): void {
        const t = input.text;
        if (t.trim() === "")
            return;
        _lastText = t;
        if (Notes.add(t))
            input.text = "";
    }

    // Aktion per Tastatur: danach dieselbe Stelle markieren (die Zeile darunter rückt nach)
    function act(fn: var): void {
        const list = nav.targets();
        const i = nav.ringOn ? nav.indexOf(list) : -1;
        fn();
        if (i >= 0)
            Qt.callLater(() => {
                const l = nav.targets();
                if (l.length)
                    nav.select(l[Math.min(i, l.length - 1)]);
            });
    }
    // vor KeyNav (preKey): Buchstaben gehen ins Feld (Gedanke weiterschreiben). Ohne Fokus-Griff (Super+T ohne
    // Tasten-Ereignis) reicht die Bar die Tasten nur an KeyNav weiter – dann hier auch Rücktaste und Enter fürs Feld.
    function key(e: var): bool {
        if (input.activeFocus && pop.grabFocus)
            return false;   // das Feld hat die Tasten selbst
        const plain = !(e.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier));
        const onInput = nav.current === input || input.activeFocus;
        if (plain && e.text.length === 1 && e.text > " " && e.key !== Qt.Key_Delete) {
            input.forceActiveFocus();
            input.insert(input.cursorPosition, e.text);
            if (!onInput)
                nav.start();
            return true;
        }
        if (!onInput)
            return false;
        if (e.key === Qt.Key_Space && input.text !== "") {
            input.insert(input.cursorPosition, " ");
            return true;
        }
        if (e.key === Qt.Key_Backspace) {
            if (input.cursorPosition > 0)
                input.remove(input.cursorPosition - 1, input.cursorPosition);
            return true;
        }
        if ((e.key === Qt.Key_Return || e.key === Qt.Key_Enter) && input.text.trim() !== "") {
            pop.submit();
            return true;
        }
        return false;
    }

    // „2026-10-18“ + „20:15“ -> „Today · 20:15“ / „Yesterday · …“ / „18 Oct · …“
    function when(e: var): string {
        if (!e.date)
            return "";
        const now = new Date();
        const y = new Date(now.getFullYear(), now.getMonth(), now.getDate() - 1);
        const d = e.date === Qt.formatDate(now, "yyyy-MM-dd") ? "Today" : e.date === Qt.formatDate(y, "yyyy-MM-dd") ? "Yesterday" : Qt.formatDate(new Date(e.date + "T00:00:00"), "d MMM");
        return d + (e.time ? " · " + e.time : "");
    }

    BackgroundEffect.blurRegion: Region {
        Region { x: 0; y: 0; width: 1; height: 1 }
        Region { item: card; radius: Theme.radiusLg }
    }

    // ---------- Bausteine ----------
    // kleiner Knopf in einer Gedanken-Zeile; label erscheint beim Zeigen/Markieren unter dem Text
    component ActBtn: Rectangle {
        id: ab
        property string icon
        property string label
        property bool asking: false
        signal clicked
        readonly property Item area: abArea
        readonly property bool lit: abArea.containsMouse || (nav.ringOn && nav.current === abArea)
        width: asking ? askTxt.implicitWidth + 20 : 28
        height: 28
        radius: Theme.radiusSm
        color: asking ? Qt.alpha(Theme.error, 0.16) : lit ? Theme.raise : "transparent"
        Behavior on width { NumberAnimation { duration: Theme.fade; easing.type: Easing.OutCubic } }
        Icon {
            anchors.centerIn: parent
            visible: !ab.asking
            name: ab.icon
            size: 17
            color: ab.lit ? Theme.text : Theme.textFaint
        }
        Txt {
            id: askTxt
            anchors.centerIn: parent
            visible: ab.asking
            text: "Delete?"
            color: Theme.error
            font.pixelSize: 12
        }
        MouseArea {
            id: abArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: ab.clicked()
        }
    }

    component ThoughtRow: Rectangle {
        id: tr
        required property var modelData
        property bool asking: false
        // Erklärung des gerade gezeigten/markierten Knopfs, sonst Zeitpunkt
        readonly property string hint: tickLit ? "Done" : aTodo.lit ? aTodo.label : aIdea.lit ? aIdea.label : aDel.lit ? aDel.label : ""
        readonly property bool tickLit: tickArea.containsMouse || (nav.ringOn && nav.current === tickArea)
        readonly property bool kbHere: nav.ringOn && [tickArea, aTodo.area, aIdea.area, aDel.area].includes(nav.current)

        width: body.width
        height: Math.max(48, inner.implicitHeight + 16)
        radius: Theme.radiusSm
        color: trHover.hovered || kbHere ? Theme.raise : "transparent"
        Behavior on color { ColorAnimation { duration: Theme.fade } }
        HoverHandler {
            id: trHover
        }
        Timer {
            id: askReset
            interval: 4000
            onTriggered: tr.asking = false
        }

        // abhaken = erledigt (bleibt als „- [x]“ in der Datei)
        Rectangle {
            id: tick
            x: 8
            y: 10
            width: 18
            height: 18
            radius: 9
            color: tr.tickLit ? Theme.accentSoft : "transparent"
            border.width: 1.5
            border.color: tr.tickLit ? Theme.accent : Theme.borderStrong
            Icon {
                anchors.centerIn: parent
                visible: tr.tickLit
                name: "check"
                size: 13
                color: Theme.accentText
            }
            MouseArea {
                id: tickArea
                anchors.fill: parent
                anchors.margins: -6
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: pop.act(() => Notes.done(tr.modelData))
            }
        }
        Column {
            id: inner
            x: 36
            y: 8
            width: tr.width - x - acts.width - 12
            spacing: 2
            Txt {
                width: parent.width
                text: tr.modelData.text
                wrapMode: Text.Wrap
                maximumLineCount: 4
                font.weight: Font.Normal
            }
            Txt {
                width: parent.width
                visible: text !== ""
                text: tr.hint !== "" ? tr.hint : pop.when(tr.modelData)
                color: tr.hint !== "" ? Theme.accentText : Theme.textFaint
                font.pixelSize: 12
                font.weight: Font.Normal
            }
        }
        Row {
            id: acts
            anchors.right: parent.right
            anchors.rightMargin: 4
            y: 5
            spacing: 2
            // leise, bis man auf die Zeile zeigt – aber immer da (sonst findet die Tastatur sie nicht)
            opacity: trHover.hovered || tr.kbHere ? 1 : 0.5
            Behavior on opacity { NumberAnimation { duration: Theme.fade } }
            ActBtn {
                id: aTodo
                icon: "add_task"
                label: "Make it a task · " + pop.todoTarget
                onClicked: pop.act(() => Notes.toTodo(tr.modelData))
            }
            ActBtn {
                id: aIdea
                visible: pop.project !== null
                icon: "lightbulb"
                label: pop.project ? "Idea for the " + pop.project.name + " backlog" : ""
                onClicked: pop.act(() => Notes.toBacklog(tr.modelData, pop.project.path))
            }
            // löschen erst beim zweiten Drücken (Rückfrage im Knopf, verfällt nach 4 s)
            ActBtn {
                id: aDel
                icon: "delete"
                asking: tr.asking
                label: tr.asking ? "Press again to delete for good" : "Delete"
                onClicked: {
                    if (!tr.asking) {
                        tr.asking = true;
                        askReset.restart();
                        return;
                    }
                    tr.asking = false;
                    pop.act(() => Notes.remove(tr.modelData));
                }
            }
        }
    }

    component TodoList: Column {
        id: list
        property string name
        width: body.width
        spacing: 2

        Repeater {
            model: Todos.items(list.name)
            Rectangle {
                id: item
                required property var modelData
                width: list.width
                height: 34
                radius: Theme.radiusSm
                color: itemHover.hovered ? Theme.raise : "transparent"
                HoverHandler {
                    id: itemHover
                }
                Row {
                    x: 8
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 10
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 18
                        height: 18
                        radius: 9
                        color: item.modelData.done ? Theme.accentSoft : "transparent"
                        border.width: 1.5
                        border.color: item.modelData.done ? Theme.accent : Theme.borderStrong
                        Icon {
                            anchors.centerIn: parent
                            visible: item.modelData.done
                            name: "check"
                            size: 13
                            color: Theme.accentText
                        }
                        MouseArea {
                            anchors.fill: parent
                            anchors.margins: -6
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Todos.toggle(list.name, item.modelData.id)
                        }
                    }
                    Txt {
                        anchors.verticalCenter: parent.verticalCenter
                        width: list.width - 80
                        text: item.modelData.text
                        color: item.modelData.done ? Theme.textFaint : Theme.text
                        font.strikeout: item.modelData.done
                        font.weight: Font.Normal
                    }
                }
                Icon {
                    anchors.right: parent.right
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    visible: itemHover.hovered
                    name: "close"
                    size: 15
                    color: Theme.textFaint
                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -6
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Todos.remove(list.name, item.modelData.id)
                    }
                }
            }
        }
        Txt {
            visible: Todos.items(list.name).length === 0
            leftPadding: 8
            text: "All done"
            color: Theme.textFaint
            font.weight: Font.Normal
        }
    }

    component Divider: Rectangle {
        width: body.width
        height: 1
        color: Theme.border
    }

    // ---------- Karte ----------
    Glass {
        id: card
        anchors.fill: parent
        strong: true
        // offen bis zum Weghovern (PopoutGuard.qml)
        PopoutGuard { id: guard; popout: pop; chip: pop.chip; name: "todo" }
        Keys.onPressed: e => nav.key(e)
        KeyNav {
            id: nav
            root: card
            popout: pop
            guard: guard
            name: "todo"
            openFn: () => pop.open()
            preKey: e => pop.key(e)
        }

        // Gedanken parken: Feld bleibt oben stehen, die Listen scrollen darunter
        Column {
            id: head
            x: 12
            y: 12
            width: parent.width - 24
            spacing: 6

            Rectangle {
                width: head.width
                height: 42
                radius: Theme.radiusMd
                color: Theme.surfaceSunken
                border.width: 1
                border.color: input.activeFocus ? Qt.alpha(Theme.accent, 0.5) : Theme.border
                Behavior on border.color { ColorAnimation { duration: Theme.fade } }
                Icon {
                    id: pen
                    x: 12
                    anchors.verticalCenter: parent.verticalCenter
                    name: "edit_note"
                    size: 18
                    color: input.activeFocus ? Theme.accentText : Theme.textFaint
                }
                TextInput {
                    id: input
                    anchors.left: pen.right
                    anchors.leftMargin: 10
                    anchors.right: parent.right
                    anchors.rightMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    color: Theme.text
                    selectionColor: Theme.accentSoft
                    selectedTextColor: Theme.text
                    font.family: Theme.fontUi
                    font.pixelSize: Theme.fontSize
                    clip: true
                    Keys.onReturnPressed: pop.submit()
                    Keys.onEnterPressed: pop.submit()
                    Keys.onEscapePressed: pop.close()
                    Txt {
                        anchors.fill: parent
                        visible: input.text === "" && input.preeditText === ""
                        text: "Park a thought…"
                        color: Theme.textFaint
                        font.weight: Font.Normal
                    }
                }
            }
            Item {
                width: head.width
                height: 16
                Txt {
                    x: 4
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - flashTxt.implicitWidth - 16
                    text: "Enter park · t … = task · ↓ work through · Esc close"
                    color: Theme.textFaint
                    font.pixelSize: 12
                    font.weight: Font.Normal
                }
                Txt {
                    id: flashTxt
                    anchors.right: parent.right
                    anchors.rightMargin: 4
                    anchors.verticalCenter: parent.verticalCenter
                    text: pop.flashText
                    color: pop.flashError ? Theme.error : Theme.accentText
                    font.pixelSize: 12
                }
            }
        }

        Flickable {
            id: flick
            x: 12
            y: head.y + head.height + 10
            width: parent.width - 24
            height: Math.max(0, parent.height - y - 12)
            contentWidth: width
            contentHeight: body.implicitHeight
            interactive: false
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            Column {
                id: body
                width: flick.width
                spacing: 8

                // Inbox: geparkte Gedanken, neueste oben
                Item {
                    visible: Notes.openCount > 0
                    width: body.width
                    height: 18
                    Label {
                        x: 8
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Inbox"
                    }
                    MonoTxt {
                        anchors.right: parent.right
                        anchors.rightMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        text: Notes.openCount
                        color: Theme.textFaint
                        font.pixelSize: 12
                    }
                }
                Column {
                    visible: Notes.openCount > 0
                    width: body.width
                    spacing: 2
                    Repeater {
                        model: Notes.items
                        ThoughtRow {}
                    }
                }
                Divider {
                    visible: Notes.openCount > 0
                }

                Label {
                    leftPadding: 8
                    text: Todos.current
                }
                TodoList {
                    name: Todos.current
                }

                Divider {
                    visible: Todos.current !== Todos.general
                }
                Label {
                    leftPadding: 8
                    visible: Todos.current !== Todos.general
                    text: Todos.general
                }
                TodoList {
                    visible: Todos.current !== Todos.general
                    name: Todos.general
                }
            }
        }
        WheelScroll {
            flick: flick
            step: 108
        }
        // dünner Rollbalken (nur Anzeige)
        Rectangle {
            visible: flick.contentHeight > flick.height
            x: flick.x + flick.width + 4
            y: flick.y + flick.height * flick.visibleArea.yPosition
            width: 3
            height: Math.max(24, flick.height * flick.visibleArea.heightRatio)
            radius: 2
            color: Theme.borderStrong
        }
    }
}

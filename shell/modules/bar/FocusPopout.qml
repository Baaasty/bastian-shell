import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.services
import qs.components

// Popout unter dem Fokus-Chip (Klick im Leerlauf): oben „Focus without timer“ (an bis zum Ausschalten), Vorgaben, zuletzt benutzte eigene Zeiten,
// Eingabe für eigene Dauer/Uhrzeit ("40", "1h30", "1:30", "until 14:30"), Aufgabe, Start.
// Enter startet, Esc schließt, Klick daneben schließt. Per Tastatur (Super+F, Super+Leertaste F) steht die Markierung auf dem
// Schalter ohne Zeit (Enter = an/aus), mit der Maus hat das Zeitfeld den Fokus (gleich tippen).
PopupWindow {
    id: pop

    property var barWindow
    property Item chip
    readonly property int maxCardHeight: 480
    readonly property int quick: Math.round(Theme.fade * 0.6)
    property real appear: 0             // 0..1, nur beim Öffnen (einmalig, keine Dauer-Animation)
    property real _closedAt: 0

    // Live-Vorschau der Eingabe
    readonly property var parsed: Focus.parseTime(timeField.input.text)
    readonly property bool custom: timeField.input.text.trim() !== ""
    property string error: ""

    // sitzt wie die anderen Bar-Popouts mit Lücke unter der Bar, linksbündig zum Chip
    anchor.window: barWindow
    anchor.edges: Edges.Bottom | Edges.Left
    anchor.gravity: Edges.Bottom | Edges.Right
    grabFocus: true
    // feste Fenstergröße, sichtbar/klickbar ist nur die Karte (Maske) -> Höhe kann weich animieren
    implicitWidth: 360
    implicitHeight: maxCardHeight
    color: "transparent"
    visible: false
    mask: Region { item: card }

    function placeUnderBar(): void {
        if (!chip)
            return;
        anchor.rect.x = Math.round(chip.mapToItem(null, 0, 0).x);
        anchor.rect.y = Theme.barMargin + Theme.barHeight + Theme.windowGap - 1;
        anchor.rect.width = 1;
        anchor.rect.height = 1;
    }
    function open(): void {
        if (visible)
            return;
        placeUnderBar();
        timeField.input.text = "";
        taskField.input.text = Focus.task;
        error = "";
        appear = 0;
        visible = true;
        appearAnim.restart();
    }
    function close(): void {
        guard.intended = true;
        visible = false;
    }
    // Klick auf den Chip bei offenem Popout: KWin schließt es schon beim Drücken (Klick daneben),
    // der Klick selbst soll es dann nicht gleich wieder öffnen
    function justClosed(): bool {
        return Date.now() - _closedAt < 400;
    }
    function toggle(): void {
        if (visible || justClosed())
            close();
        else
            open();
    }

    // Aufgabe übernehmen (nur wenn geändert), dann starten
    function applyTask(): void {
        if (taskField.input.text.trim() !== Focus.task)
            Focus.setTask(taskField.input.text);
    }
    function startPreset(min: int): void {
        applyTask();
        Focus.start(min);
    }
    function startKey(key: string): void {
        applyTask();
        const err = Focus.startText(key);
        if (err) {
            error = err;
            return;
        }
    }
    // Fokus ohne Zeit an/aus; danach zu (wie beim Start eines Blocks)
    function toggleOpen(): void {
        if (Focus.openOn) {
            Focus.stop();
        } else {
            applyTask();
            Focus.startOpen();
        }
        close();
    }
    // Enter / Start-Knopf: eigene Eingabe, sonst die gewählte Vorgabe
    function go(): void {
        if (custom) {
            startKey(timeField.input.text);
            return;
        }
        applyTask();
        Focus.start();
    }

    onVisibleChanged: {
        if (barWindow && barWindow.openMenus !== undefined)
            barWindow.openMenus += visible ? 1 : -1;
        if (visible) {
            Popouts.claim("focus");
            // per Tastatur: kein Feld fokussieren, damit KeyNav beim ersten Ziel (Fokus ohne Zeit) startet
            if (nav.byKeys)
                card.forceActiveFocus();
            else
                timeField.input.forceActiveFocus();
        } else {
            Popouts.release("focus");
            _closedAt = Date.now();
            appearAnim.stop();
        }
    }
    // nur ein Bar-Popout gleichzeitig
    Connections {
        target: Popouts
        function onCurrentChanged() {
            if (Popouts.current !== "focus" && pop.visible)
                pop.visible = false;
        }
    }
    // neue Eingabe -> alter Hinweis weg
    Connections {
        target: timeField.input
        function onTextChanged() { pop.error = ""; }
    }
    // anderswo gestartet (Kürzel, Dashboard, Launcher) -> zu
    Connections {
        target: Focus
        function onModeChanged() {
            if (Focus.mode !== "idle" && pop.visible)
                pop.visible = false;
        }
    }

    NumberAnimation {
        id: appearAnim
        target: pop
        property: "appear"
        from: 0
        to: 1
        duration: Theme.fade
        easing.type: Easing.OutCubic
    }

    BackgroundEffect.blurRegion: Region {
        Region { x: 0; y: 0; width: 1; height: 1 }
        // erst ab 40 % – sonst steht beim Einblenden kurz ein leerer Blur-Kasten
        Region { item: pop.appear > 0.4 ? card : null; radius: Theme.radiusLg }
    }

    // ---------- Bausteine ----------

    // kleiner Auswahl-Chip (Vorgabe / zuletzt benutzt)
    component Pick: Rectangle {
        id: pk
        property string text
        property bool current: false
        property bool removable: false
        signal picked()
        signal removed()
        width: pkRow.implicitWidth + 22
        height: 30
        radius: Theme.radiusSm
        color: current ? Theme.accentSoft : pkArea.containsMouse ? Qt.alpha(Theme.text, 0.1) : Theme.raise
        border.width: 1
        border.color: current ? Qt.alpha(Theme.accent, 0.55) : Theme.border
        Behavior on color { ColorAnimation { duration: pop.quick } }
        MouseArea {
            id: pkArea
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.MiddleButton
            cursorShape: Qt.PointingHandCursor
            // Mittelklick vergisst einen zuletzt benutzten Wert
            onClicked: mouse => mouse && mouse.button === Qt.MiddleButton ? (pk.removable && pk.removed()) : pk.picked()
        }
        Row {
            id: pkRow
            anchors.centerIn: parent
            spacing: 4
            Txt {
                anchors.verticalCenter: parent.verticalCenter
                text: pk.text
                color: pk.current ? Theme.accentText : Theme.text
                font.pixelSize: Theme.fontSm
                font.weight: Font.Normal
            }
            // x zum Vergessen, nur beim Drüberfahren (Platz bleibt reserviert, damit nichts springt)
            Icon {
                anchors.verticalCenter: parent.verticalCenter
                visible: pk.removable
                opacity: pkArea.containsMouse ? 1 : 0
                name: "close"
                size: 13
                color: Theme.textFaint
                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -4
                    enabled: pkArea.containsMouse
                    cursorShape: Qt.PointingHandCursor
                    onClicked: pk.removed()
                }
            }
        }
    }

    // Eingabefeld mit Symbol und Platzhalter
    component Field: Rectangle {
        id: fld
        property alias input: ti
        property string glyph
        property string placeholder
        property bool bad: false
        height: 40
        radius: Theme.radiusMd
        color: Theme.raise
        border.width: 1
        border.color: bad ? Qt.alpha(Theme.error, 0.6) : ti.activeFocus ? Qt.alpha(Theme.accent, 0.5) : Theme.border
        Behavior on border.color { ColorAnimation { duration: pop.quick } }
        Icon {
            id: glyphIcon
            x: 11
            anchors.verticalCenter: parent.verticalCenter
            name: fld.glyph
            size: 17
            color: Theme.textFaint
        }
        TextInput {
            id: ti
            anchors.left: glyphIcon.right
            anchors.leftMargin: 9
            anchors.right: parent.right
            anchors.rightMargin: 11
            anchors.verticalCenter: parent.verticalCenter
            color: Theme.text
            selectionColor: Theme.accentSoft
            selectedTextColor: Theme.text
            font.family: Theme.fontUi
            font.pixelSize: Theme.fontMd
            clip: true
            Keys.onReturnPressed: pop.go()
            Keys.onEnterPressed: pop.go()
            Keys.onEscapePressed: pop.close()
            Txt {
                anchors.fill: parent
                visible: ti.text === ""
                text: fld.placeholder
                color: Theme.textFaint
                font.pixelSize: Theme.fontMd
                font.weight: Font.Normal
            }
        }
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.NoButton
            cursorShape: Qt.IBeamCursor
        }
    }

    // ---------- Karte ----------

    Glass {
        id: card
        // offen bis zum Weghovern (PopoutGuard.qml)
        PopoutGuard { id: guard; popout: pop; chip: pop.chip; name: "focus" }
        // Tastatur: Pfeile/Tab/Enter, Bar-Modus (Super+Leertaste, KeyNav.qml)
        Keys.onPressed: e => nav.key(e)
        KeyNav { id: nav; root: card; scope: null; popout: pop; guard: guard; name: "focus" }
        width: parent.width
        height: Math.min(pop.maxCardHeight, col.implicitHeight + 28)
        strong: true
        opacity: pop.appear
        transform: Translate { y: (1 - pop.appear) * -6 }

        Behavior on height { NumberAnimation { duration: Theme.fade; easing.type: Easing.OutCubic } }

        Column {
            id: col
            x: 14
            y: 14
            width: parent.width - 28
            spacing: 10

            // Kopf: Titel · heute
            Item {
                width: col.width
                height: Theme.iconButton
                PopoutTitle {
                    anchors.left: parent.left
                    anchors.leftMargin: Theme.space1
                    anchors.verticalCenter: parent.verticalCenter
                    icon: "timer"
                    text: "Focus"
                }
                Txt {
                    anchors.right: parent.right
                    anchors.rightMargin: 4
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Today " + Focus.focusMin + " / " + Focus.goalMin + " min · block " + Focus.block + "/" + Focus.blocksPerRound
                    color: Theme.textFaint
                    font.pixelSize: Theme.fontSm
                    font.weight: Font.Normal
                }
            }

            // Fokus ohne Zeit: erstes Ziel, an bis zum Ausschalten
            Rectangle {
                id: openRow
                width: col.width
                height: 48
                radius: Theme.radiusMd
                color: Focus.openOn ? Theme.accentSoft : openArea.containsMouse ? Qt.alpha(Theme.text, 0.1) : Theme.raise
                border.width: 1
                border.color: Focus.openOn ? Qt.alpha(Theme.accent, 0.55) : Theme.border
                Behavior on color { ColorAnimation { duration: pop.quick } }
                Icon {
                    id: openIcon
                    x: 12
                    anchors.verticalCenter: parent.verticalCenter
                    name: "all_inclusive"
                    size: 18
                    fill: Focus.openOn
                    color: Focus.openOn ? Theme.accentText : Theme.textMuted
                }
                Column {
                    anchors.left: openIcon.right
                    anchors.leftMargin: 10
                    anchors.right: openSwitch.left
                    anchors.rightMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 1
                    Txt {
                        width: parent.width
                        text: "Focus without timer"
                        color: Focus.openOn ? Theme.accentText : Theme.text
                        font.pixelSize: Theme.fontMd
                        elide: Text.ElideRight
                    }
                    Txt {
                        width: parent.width
                        text: Focus.openOn ? "On for " + Focus.sinceLabel(Focus.elapsed) + " · Enter turns it off" : "On until you turn it off"
                        color: Theme.textFaint
                        font.pixelSize: Theme.fontSm
                        font.weight: Font.Normal
                        elide: Text.ElideRight
                    }
                }
                ToggleSwitch {
                    id: openSwitch
                    // nur Anzeige: die ganze Zeile ist das Ziel (Klick, Enter)
                    property bool kbSkip: true
                    anchors.right: parent.right
                    anchors.rightMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    checked: Focus.openOn
                }
                MouseArea {
                    id: openArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: pop.toggleOpen()
                }
            }

            // eigene Zeit
            Field {
                id: timeField
                glyph: "schedule"
                placeholder: "40 · 1h30 · until 14:30"
                width: col.width
                bad: pop.error !== "" || (pop.custom && !pop.parsed.ok && pop.parsed.error !== "")
            }
            // Vorschau bzw. Hinweis darunter
            Txt {
                width: col.width
                leftPadding: 4
                visible: pop.custom || pop.error !== ""
                text: pop.error !== "" ? pop.error
                    : pop.parsed.ok ? pop.parsed.label + (pop.parsed.kind === "dur" ? " · ends " + Qt.formatTime(new Date(pop.parsed.endsAt), "HH:mm") : " · " + Focus.durLabel(pop.parsed.min))
                    : pop.parsed.error
                color: pop.error !== "" || !pop.parsed.ok ? Theme.error : Theme.textMuted
                font.pixelSize: Theme.fontSm
                font.weight: Font.Normal
            }

            // Vorgaben: feste Längen, dann "until …" (zweite Zeile)
            Flow {
                width: col.width
                spacing: 6
                Repeater {
                    model: Focus.presets.filter(p => !p.label.startsWith("until"))
                    Pick {
                        required property var modelData
                        text: modelData.label
                        current: !pop.custom && Focus.preset.label === modelData.label
                        onPicked: pop.startPreset(modelData.min)
                    }
                }
            }
            Flow {
                width: col.width
                spacing: 6
                Repeater {
                    model: Focus.presets.filter(p => p.label.startsWith("until"))
                    Pick {
                        required property var modelData
                        text: modelData.label
                        current: !pop.custom && Focus.preset.label === modelData.label
                        // genau bis zur Uhrzeit (startPreset(min) endete bis zu ~1 min später, s. Focus.start)
                        onPicked: {
                            pop.applyTask();
                            if (!Focus.startUntil(modelData.until))
                                pop.startPreset(modelData.min);
                        }
                    }
                }
            }

            // zuletzt benutzte eigene Werte
            Column {
                width: col.width
                spacing: 6
                visible: Focus.recentChoices.length > 0
                Txt {
                    leftPadding: 4
                    text: "Recent"
                    color: Theme.textFaint
                    font.pixelSize: Theme.fontSm
                    font.weight: Font.Normal
                }
                Flow {
                    width: col.width
                    spacing: 6
                    Repeater {
                        model: Focus.recentChoices
                        Pick {
                            required property var modelData
                            text: modelData.text
                            removable: true
                            onPicked: pop.startKey(modelData.text)
                            onRemoved: Focus.forget(modelData.text)
                        }
                    }
                }
            }

            // Aufgabe
            Field {
                id: taskField
                width: col.width
                glyph: "edit_note"
                placeholder: "What are you working on?"
            }

            // Start
            Item {
                width: col.width
                height: Math.max(36, focusHints.implicitHeight)
                Item {
                    anchors.left: parent.left
                    anchors.leftMargin: Theme.space1
                    anchors.right: startBtn.left
                    anchors.rightMargin: Theme.space2
                    height: parent.height
                    KeyHintRow {
                        id: focusHints
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width
                        gap: Theme.space3
                        hints: [["Enter", "start"], ["Esc", "close"]]
                    }
                }
                Button {
                    id: startBtn
                    anchors.right: parent.right
                    primary: true
                    icon: "play_arrow"
                    text: "Start · " + (pop.custom ? (pop.parsed.ok ? pop.parsed.label : "…") : Focus.preset.label)
                    opacity: !pop.custom || pop.parsed.ok ? 1 : 0.5
                    onClicked: pop.go()
                }
            }
        }
    }
}

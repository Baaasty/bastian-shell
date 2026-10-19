import QtQuick
import qs.config
import qs.components

// Karte des Layout-Menüs: Kopf, Suche (ab 7 Layouts oder sobald getippt wird), Liste, „Save this desktop as…“.
// Zeilen wie im Workspace-/Tray-Menü (34 px, Chip). Tastatur: ↑↓ wählen · ↵ anwenden · Entf löschen (Rückfrage
// in der Zeile) · Strg+S speichern · Esc zurück/zu. Daten + Aktionen kommen aus Layouts.qml (lm).
Glass {
    id: card

    required property var lm
    readonly property bool searchShown: lm.items.length > 6 || lm.query !== ""
    readonly property int rowH: 34
    readonly property int maxRows: 8

    function focusInput(): void {
        if (lm.naming)
            nameInput.forceActiveFocus();
        else
            input.forceActiveFocus();
    }
    function beginName(): void {
        nameInput.text = lm.suggest;
        nameInput.selectAll();
        nameInput.forceActiveFocus();
    }
    function showSel(): void {
        if (lm.sel < list.count)
            list.positionViewAtIndex(lm.sel, ListView.Contain);
    }

    width: 460
    height: col.implicitHeight + 28
    strong: true
    radius: Theme.radiusLg

    Connections {
        target: card.lm
        function onNamingChanged() {
            if (card.lm.naming)
                card.beginName();
            else
                card.focusInput();
        }
        function onSelChanged() {
            card.showSel();
        }
    }

    WheelScroll {
        flick: list
        step: 108
    }

    // Klicks auf der Karte nicht an den Hintergrund (der schließt) durchreichen
    MouseArea {
        anchors.fill: parent
        onPressed: card.focusInput()
    }

    Column {
        id: col
        x: 14
        y: 14
        width: parent.width - 28

        // ---------- Kopf ----------
        Item {
            width: col.width
            height: 34

            Row {
                anchors.verticalCenter: parent.verticalCenter
                x: 6
                spacing: 10
                Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    name: "view_quilt"
                    size: 20
                    color: Theme.accentText
                }
                Txt {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Layouts"
                    font.pixelSize: 16
                    font.weight: Font.DemiBold
                }
                MonoTxt {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.verticalCenterOffset: 1
                    text: card.lm.query.trim() ? card.lm.rows.length + " / " + card.lm.items.length : (card.lm.items.length || "")
                    font.pixelSize: 12
                    color: Theme.textFaint
                }
            }
            Txt {
                anchors.right: parent.right
                anchors.rightMargin: 6
                anchors.verticalCenter: parent.verticalCenter
                text: card.lm.desk ? "Desktop " + card.lm.desk : ""
                color: Theme.textFaint
                font.pixelSize: 12
                font.weight: Font.Normal
            }
        }

        Item {
            width: 1
            height: 8
        }

        // ---------- Suche (bleibt immer im Baum: hält den Tastaturfokus, auch wenn sie eingeklappt ist) ----------
        Rectangle {
            id: sf
            width: col.width
            height: card.searchShown ? 42 : 0
            opacity: card.searchShown ? 1 : 0
            clip: true
            radius: Theme.radiusMd
            color: Theme.raise
            border.width: card.searchShown ? 1 : 0
            border.color: input.activeFocus ? Qt.alpha(Theme.accent, 0.5) : Theme.border
            Behavior on border.color { ColorAnimation { duration: Theme.fade } }

            Icon {
                id: sIcon
                anchors.left: parent.left
                anchors.leftMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                name: "search"
                size: 19
                color: Theme.textFaint
            }
            TextInput {
                id: input
                anchors.left: sIcon.right
                anchors.leftMargin: 10
                anchors.right: parent.right
                anchors.rightMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                clip: true
                focus: true
                text: card.lm.query
                onTextChanged: card.lm.query = text
                Connections {
                    target: card.lm
                    function onQueryChanged() {
                        if (input.text !== card.lm.query)
                            input.text = card.lm.query;
                    }
                }
                color: Theme.text
                selectionColor: Theme.accentSoft
                font.family: Theme.fontUi
                font.pixelSize: 15

                Keys.onEscapePressed: {
                    if (card.lm.deleting)
                        card.lm.deleting = "";
                    else if (card.lm.query !== "")
                        card.lm.query = "";
                    else
                        card.lm.close();
                }
                function activate(): void {
                    if (card.lm.deleting)
                        card.lm.confirmDelete();
                    else if (card.lm.sel >= card.lm.saveIndex)
                        card.lm.startSave();
                    else
                        card.lm.restore(card.lm.cur);
                }
                Keys.onReturnPressed: activate()
                Keys.onEnterPressed: activate()
                Keys.onDownPressed: card.lm.moveSel(1)
                Keys.onUpPressed: card.lm.moveSel(-1)
                Keys.onPressed: event => {
                    if (event.key === Qt.Key_Delete && card.lm.cur) {
                        card.lm.askDelete(card.lm.cur);
                        event.accepted = true;
                    } else if (event.key === Qt.Key_PageDown) {
                        card.lm.moveSel(card.maxRows);
                        event.accepted = true;
                    } else if (event.key === Qt.Key_PageUp) {
                        card.lm.moveSel(-card.maxRows);
                        event.accepted = true;
                    } else if (event.key === Qt.Key_Home && card.lm.query === "") {
                        card.lm.moveSel(-9999);
                        event.accepted = true;
                    } else if (event.key === Qt.Key_End && card.lm.query === "") {
                        card.lm.moveSel(9999);
                        event.accepted = true;
                    } else if (event.key === Qt.Key_S && (event.modifiers & Qt.ControlModifier)) {
                        card.lm.startSave();
                        event.accepted = true;
                    }
                }

                Txt {
                    anchors.fill: parent
                    visible: input.text === ""
                    text: "Search…"
                    color: Theme.textFaint
                    font.pixelSize: 15
                    font.weight: Font.Normal
                }
            }
        }

        Item {
            width: 1
            height: card.searchShown ? 8 : 0
        }

        // ---------- Layouts ----------
        ListView {
            id: list
            width: col.width
            height: count ? Math.min(count, card.maxRows) * (card.rowH + spacing) - spacing : 0
            clip: true
            spacing: 2
            boundsBehavior: Flickable.StopAtBounds
            interactive: false   // Mausrad macht WheelScroll
            model: card.lm.rows
            currentIndex: card.lm.sel < count ? card.lm.sel : -1
            highlightFollowsCurrentItem: false

            delegate: Item {
                id: row

                required property var modelData
                required property int index
                readonly property bool selected: card.lm.sel === index
                readonly property bool asking: card.lm.deleting === modelData.name

                width: list.width
                height: card.rowH

                Chip {
                    id: chip
                    visible: !row.asking
                    anchors.fill: parent
                    alignLeft: true
                    active: row.selected
                    onClicked: mouse => {
                        if (mouse.button !== Qt.LeftButton)
                            return;
                        card.lm.sel = row.index;
                        card.lm.restore(row.modelData);
                    }

                    Icon {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 18
                        name: row.modelData.broken ? "error" : row.modelData.project ? "folder_code" : "view_quilt"
                        size: 18
                        color: row.modelData.broken ? Theme.warning : row.selected ? Theme.accentText : Theme.textMuted
                    }
                    Txt {
                        anchors.verticalCenter: parent.verticalCenter
                        width: Math.max(0, row.width - (chip.padding + 4) * 2 - 28 - info.width - 12)
                        text: row.modelData.name
                        color: Theme.text
                        font.weight: Font.Normal
                    }
                }

                // rechts: Fensterzahl bzw. beim Überfahren „löschen“
                Item {
                    id: info
                    visible: !row.asking
                    anchors.right: parent.right
                    anchors.rightMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.max(countTxt.implicitWidth, 24)
                    height: parent.height

                    Txt {
                        id: countTxt
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        visible: !(chip.hovered || delArea.containsMouse)
                        text: row.modelData.broken ? "unreadable" : row.modelData.windows + (row.modelData.windows === 1 ? " window" : " windows")
                        color: Theme.textFaint
                        font.pixelSize: 12
                        font.weight: Font.Normal
                    }
                    Icon {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        visible: chip.hovered || delArea.containsMouse
                        name: "delete"
                        size: 17
                        color: delArea.containsMouse ? Theme.error : Theme.textFaint
                        MouseArea {
                            id: delArea
                            anchors.fill: parent
                            anchors.margins: -7
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                card.lm.sel = row.index;
                                card.lm.askDelete(row.modelData);
                                card.focusInput();
                            }
                        }
                    }
                }

                // Lösch-Rückfrage in der Zeile
                Rectangle {
                    visible: row.asking
                    anchors.fill: parent
                    radius: Theme.radiusSm
                    color: Theme.surfaceSunken
                    border.width: 1
                    border.color: Qt.alpha(Theme.error, 0.45)

                    Icon {
                        id: warnIcon
                        anchors.left: parent.left
                        anchors.leftMargin: 14
                        anchors.verticalCenter: parent.verticalCenter
                        name: "delete"
                        size: 17
                        color: Theme.error
                    }
                    Txt {
                        anchors.left: warnIcon.right
                        anchors.leftMargin: 10
                        anchors.right: askBtns.left
                        anchors.rightMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Delete “" + row.modelData.name + "”?"
                        font.weight: Font.Normal
                    }
                    Row {
                        id: askBtns
                        anchors.right: parent.right
                        anchors.rightMargin: 4
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 4
                        Rectangle {
                            width: keepTxt.implicitWidth + 22
                            height: 26
                            radius: Theme.radiusSm
                            color: keepArea.containsMouse ? Theme.raise : "transparent"
                            border.width: 1
                            border.color: Theme.border
                            Txt {
                                id: keepTxt
                                anchors.centerIn: parent
                                text: "Keep"
                                font.pixelSize: 12
                            }
                            MouseArea {
                                id: keepArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    card.lm.deleting = "";
                                    card.focusInput();
                                }
                            }
                        }
                        Rectangle {
                            width: delTxt.implicitWidth + 22
                            height: 26
                            radius: Theme.radiusSm
                            color: okDel.containsMouse ? Qt.alpha(Theme.error, 0.22) : Qt.alpha(Theme.error, 0.14)
                            border.width: 1
                            border.color: Qt.alpha(Theme.error, 0.5)
                            Txt {
                                id: delTxt
                                anchors.centerIn: parent
                                text: "Delete"
                                color: Theme.error
                                font.pixelSize: 12
                            }
                            MouseArea {
                                id: okDel
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    card.lm.confirmDelete();
                                    card.focusInput();
                                }
                            }
                        }
                    }
                }
            }
        }

        // ---------- leer / keine Treffer ----------
        Column {
            visible: card.lm.items.length === 0
            width: col.width
            topPadding: 14
            bottomPadding: 14
            spacing: 6
            Icon {
                anchors.horizontalCenter: parent.horizontalCenter
                name: card.lm.loadState.startsWith("error") ? "error" : card.lm.loadState === "loading" ? "hourglass_top" : "view_quilt"
                size: 30
                color: card.lm.loadState.startsWith("error") ? Theme.error : Theme.textFaint
            }
            Txt {
                anchors.horizontalCenter: parent.horizontalCenter
                width: Math.min(implicitWidth, col.width - 40)
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
                text: card.lm.loadState.startsWith("error") ? card.lm.loadState.slice(6) : card.lm.loadState === "loading" ? "Loading…" : "No layouts yet"
                color: Theme.textMuted
            }
            Txt {
                visible: card.lm.loadState === "ready"
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Arrange this desktop, then save it below."
                color: Theme.textFaint
                font.pixelSize: 12
                font.weight: Font.Normal
            }
        }
        Txt {
            visible: card.lm.items.length > 0 && list.count === 0
            width: col.width
            height: card.rowH
            leftPadding: 14
            text: "No layout matches “" + card.lm.query.trim() + "”"
            color: Theme.textFaint
            font.weight: Font.Normal
        }

        // Trenner
        Item {
            width: col.width
            height: 9
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                x: 8
                width: parent.width - 16
                height: 1
                color: Theme.border
            }
        }

        // ---------- Speichern ----------
        Chip {
            id: saveRow
            visible: !card.lm.naming
            width: col.width
            height: card.rowH
            alignLeft: true
            active: card.lm.sel >= card.lm.saveIndex
            onClicked: mouse => {
                if (mouse.button === Qt.LeftButton)
                    card.lm.startSave();
            }
            Icon {
                anchors.verticalCenter: parent.verticalCenter
                width: 18
                name: "add"
                size: 18
                color: Theme.accentText
            }
            Txt {
                anchors.verticalCenter: parent.verticalCenter
                text: card.lm.desk ? "Save desktop " + card.lm.desk + " as…" : "Save this desktop as…"
                font.weight: Font.Normal
            }
        }

        Column {
            visible: card.lm.naming
            width: col.width
            spacing: 6

            Rectangle {
                width: col.width
                height: 42
                radius: Theme.radiusMd
                color: Theme.surfaceRaised
                border.width: 1
                border.color: card.lm.saveError ? Theme.error : nameInput.activeFocus ? Qt.alpha(Theme.accent, 0.6) : Theme.border
                Behavior on border.color { ColorAnimation { duration: Theme.fade } }

                Icon {
                    id: nIcon
                    anchors.left: parent.left
                    anchors.leftMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    name: card.lm.saving ? "hourglass_top" : "save"
                    size: 18
                    color: Theme.accentText
                }
                TextInput {
                    id: nameInput
                    anchors.left: nIcon.right
                    anchors.leftMargin: 10
                    anchors.right: parent.right
                    anchors.rightMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    clip: true
                    readOnly: card.lm.saving
                    color: Theme.text
                    selectionColor: Theme.accentSoft
                    font.family: Theme.fontUi
                    font.pixelSize: 15
                    onTextChanged: {
                        card.lm.overwrite = "";
                        card.lm.saveError = "";
                    }
                    Keys.onEscapePressed: {
                        if (card.lm.overwrite)
                            card.lm.overwrite = "";
                        else
                            card.lm.cancelSave();
                    }
                    Keys.onReturnPressed: card.lm.submitSave(text)
                    Keys.onEnterPressed: card.lm.submitSave(text)

                    Txt {
                        anchors.fill: parent
                        visible: nameInput.text === ""
                        text: "Layout name"
                        color: Theme.textFaint
                        font.pixelSize: 15
                        font.weight: Font.Normal
                    }
                }
            }
            Row {
                x: 4
                spacing: 6
                Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: card.lm.saveError !== "" || card.lm.overwrite !== ""
                    name: card.lm.saveError ? "error" : "warning"
                    size: 15
                    color: card.lm.saveError ? Theme.error : Theme.warning
                }
                Txt {
                    anchors.verticalCenter: parent.verticalCenter
                    width: col.width - 30
                    wrapMode: Text.WordWrap
                    elide: Text.ElideNone
                    text: card.lm.saveError ? card.lm.saveError
                        : card.lm.overwrite ? "“" + card.lm.overwrite + "” already exists · ↵ overwrite · Esc keep"
                        : card.lm.saving ? "Saving…"
                        : "A project name (e.g. desktop) links the layout to that project"
                    color: card.lm.saveError ? Theme.error : card.lm.overwrite ? Theme.warning : Theme.textFaint
                    font.pixelSize: 12
                    font.weight: Font.Normal
                }
            }
        }

        Item {
            width: 1
            height: 8
        }

        // ---------- Fußzeile: Rückmeldung oder Tasten ----------
        Txt {
            x: 6
            width: col.width - 12
            text: card.lm.status !== "" ? card.lm.status
                : card.lm.naming ? "↵ save  ·  Esc back"
                : card.lm.deleting ? "↵ delete  ·  Esc keep"
                : "↵ apply  ·  Del delete  ·  Ctrl+S save  ·  Esc close"
            color: card.lm.status !== "" ? (card.lm.statusError ? Theme.error : Theme.textMuted) : Theme.textFaint
            font.pixelSize: 11
            font.weight: Font.Normal
        }
    }
}

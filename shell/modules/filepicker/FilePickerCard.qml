import QtQuick
import qs.config
import qs.components
import qs.services

// Karte des Datei-Wählers: Kopf, Brotkrumen + Suche, Favoriten/Projekte links, Liste rechts, unten Name (Speichern)
// + Knöpfe. Fokus liegt in der Suche (Tippen filtert) bzw. beim Speichern im Namensfeld (Tab wechselt).
// Daten + Aktionen: FilePickerPanel.qml (fp). Mehrfachauswahl (fp.multi): Tab/Klick markiert, Strg+A alle Dateien.
Glass {
    id: card

    required property var fp
    readonly property bool saving: fp.mode === "save"
    readonly property bool folders: fp.mode === "folder"
    property string error: ""
    readonly property int rowH: 34

    function reset(): void {
        error = "";
        nameInput.text = FilePicker.fileName;
        selectStem();
        focusInput();
    }
    function focusInput(): void {
        if (saving)
            nameInput.forceActiveFocus();
        else
            input.forceActiveFocus();
    }
    function selectStem(): void {
        const i = nameInput.text.lastIndexOf(".");
        nameInput.select(0, i > 0 ? i : nameInput.text.length);
    }
    function setName(name: string, focus: bool): void {
        nameInput.text = name;
        if (focus) {
            nameInput.forceActiveFocus();
            selectStem();
        }
    }
    function setError(msg: string): void {
        error = msg;
    }
    function doSave(): void {
        error = fp.save(nameInput.text);
    }
    function primary(): void {
        if (saving)
            doSave();
        else if (folders)
            fp.chooseFolder(fp.dir);
        else if (fp.multi)
            fp.takeMarked();
        else if (fp.cur && !fp.cur.isDir)
            FilePicker.finish(fp.cur.path);
    }
    function showSel(): void {
        if (fp.sel < list.count)
            list.positionViewAtIndex(fp.sel, ListView.Contain);
    }
    // gemeinsame Tasten (Suche + Namensfeld); true = erledigt
    function commonKey(event: var): bool {
        const ctrl = event.modifiers & Qt.ControlModifier;
        if (fp.confirm !== "") {
            if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                doSave();
                return true;
            }
            if (event.key === Qt.Key_Escape) {
                fp.confirm = "";
                return true;
            }
        }
        if (event.key === Qt.Key_Down) {
            fp.moveSel(1);
        } else if (event.key === Qt.Key_Up && (event.modifiers & Qt.AltModifier)) {
            fp.up();
        } else if (event.key === Qt.Key_Up) {
            fp.moveSel(-1);
        } else if (event.key === Qt.Key_PageDown) {
            fp.moveSel(10);
        } else if (event.key === Qt.Key_PageUp) {
            fp.moveSel(-10);
        } else if (event.key === Qt.Key_H && ctrl) {
            fp.toggleHidden();
        } else if (fp.multi && event.key === Qt.Key_A && ctrl) {
            fp.markAll();
        } else if (fp.multi && (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab)) {
            // Tab: markieren und weiter (wie fzf), Shift+Tab: markieren und zurück
            fp.toggleMark(fp.cur);
            fp.moveSel(event.key === Qt.Key_Backtab ? -1 : 1);
        } else if (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) {
            if (!saving)
                return true;
            if (nameInput.activeFocus)
                input.forceActiveFocus();
            else
                nameInput.forceActiveFocus();
        } else {
            return false;
        }
        return true;
    }

    radius: Theme.radiusXl
    strong: true
    border.color: Theme.borderStrong

    Connections {
        target: card.fp
        function onSelChanged() {
            card.showSel();
        }
        function onConfirmChanged() {
            if (card.fp.confirm !== "")
                card.error = "";
        }
    }

    // Klicks auf der Karte nicht an den Hintergrund (der bricht ab) durchreichen
    MouseArea {
        anchors.fill: parent
        onPressed: card.focusInput()
    }

    // ================================================================ Kopf
    Item {
        id: head
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 20
        height: 34

        Row {
            anchors.verticalCenter: parent.verticalCenter
            x: 2
            spacing: 10
            Icon {
                anchors.verticalCenter: parent.verticalCenter
                name: card.saving ? "save" : card.folders ? "folder_open" : "file_open"
                size: 22
                color: Theme.accentText
            }
            Txt {
                anchors.verticalCenter: parent.verticalCenter
                text: FilePicker.title
                font.pixelSize: Theme.fontXl
                font.weight: Font.DemiBold
            }
        }
        Chip {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            height: 32
            active: card.fp.showHidden
            onClicked: {
                card.fp.toggleHidden();
                card.focusInput();
            }
            Icon {
                anchors.verticalCenter: parent.verticalCenter
                name: card.fp.showHidden ? "visibility" : "visibility_off"
                size: 17
                color: card.fp.showHidden ? Theme.accentText : Theme.textMuted
            }
            Txt {
                anchors.verticalCenter: parent.verticalCenter
                text: "Hidden files"
                font.pixelSize: Theme.fontSm
                color: card.fp.showHidden ? Theme.text : Theme.textMuted
            }
        }
    }

    // ================================================================ Brotkrumen + Suche
    Item {
        id: pathBar
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: head.bottom
        anchors.leftMargin: 20
        anchors.rightMargin: 20
        anchors.topMargin: 12
        height: 42

        // Pfad (zu lang: Anfang wird abgeschnitten, das Ende bleibt sichtbar)
        Rectangle {
            id: crumbBox
            anchors.left: parent.left
            anchors.right: sf.left
            anchors.rightMargin: 10
            height: parent.height
            radius: Theme.radiusMd
            color: Theme.surfaceSunken
            clip: true

            Chip {
                id: upBtn
                anchors.left: parent.left
                anchors.leftMargin: 4
                anchors.verticalCenter: parent.verticalCenter
                width: 32
                height: 32
                enabled: card.fp.dir !== "/" && card.fp.dir !== ""
                opacity: enabled ? 1 : 0.4
                onClicked: {
                    card.fp.up();
                    card.focusInput();
                }
                Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    name: "arrow_upward"
                    size: 18
                }
            }
            Item {
                id: crumbView
                anchors.left: upBtn.right
                anchors.leftMargin: 4
                anchors.right: parent.right
                anchors.rightMargin: 6
                height: parent.height
                clip: true

                Row {
                    id: crumbRow
                    x: Math.min(0, crumbView.width - width)
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 0
                    Repeater {
                        model: card.fp.crumbs
                        Row {
                            id: crumb
                            required property var modelData
                            required property int index
                            readonly property bool last: index === card.fp.crumbs.length - 1
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 0
                            Icon {
                                visible: crumb.index > 0
                                anchors.verticalCenter: parent.verticalCenter
                                name: "chevron_right"
                                size: 16
                                color: Theme.textFaint
                            }
                            Chip {
                                anchors.verticalCenter: parent.verticalCenter
                                height: 30
                                padding: 8
                                active: crumb.last
                                onClicked: {
                                    card.fp.go(crumb.modelData.path);
                                    card.focusInput();
                                }
                                Icon {
                                    visible: crumb.modelData.icon !== ""
                                    anchors.verticalCenter: parent.verticalCenter
                                    name: crumb.modelData.icon
                                    size: 16
                                    color: crumb.last ? Theme.accentText : Theme.textMuted
                                }
                                Txt {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: crumb.modelData.label
                                    color: crumb.last ? Theme.text : Theme.textMuted
                                    font.pixelSize: Theme.fontSm
                                    font.weight: crumb.last ? Font.Medium : Font.Normal
                                }
                            }
                        }
                    }
                }
            }
        }

        // Suche
        Rectangle {
            id: sf
            anchors.right: parent.right
            width: Math.min(300, parent.width * 0.36)
            height: parent.height
            radius: Theme.radiusMd
            color: Theme.raise
            border.width: 1
            border.color: input.activeFocus ? Qt.alpha(Theme.accent, 0.5) : Theme.border
            Behavior on border.color { ColorAnimation { duration: Theme.fade } }

            Icon {
                id: sIcon
                anchors.left: parent.left
                anchors.leftMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                name: card.fp.pathQuery ? "subdirectory_arrow_right" : "search"
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
                focus: !card.saving
                text: card.fp.query
                onTextChanged: card.fp.query = text
                Connections {
                    target: card.fp
                    function onQueryChanged() {
                        if (input.text !== card.fp.query)
                            input.text = card.fp.query;
                    }
                }
                color: Theme.text
                selectionColor: Theme.accentSoft
                font.family: Theme.fontUi
                font.pixelSize: Theme.fontMd

                Keys.onPressed: event => {
                    if (card.commonKey(event)) {
                        event.accepted = true;
                        return;
                    }
                    const ctrl = event.modifiers & Qt.ControlModifier;
                    if (event.key === Qt.Key_Escape) {
                        if (card.fp.query !== "")
                            card.fp.query = "";
                        else
                            FilePicker.cancel();
                        event.accepted = true;
                    } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                        // Strg+↵: im Ordner-Modus den markierten (sonst den aktuellen) Ordner nehmen
                        if (ctrl && card.folders)
                            card.fp.chooseFolder(card.fp.cur && card.fp.cur.isDir ? card.fp.cur.path : card.fp.dir);
                        else if (ctrl && card.saving)
                            card.doSave();
                        else
                            card.fp.activate();
                        event.accepted = true;
                    } else if (event.key === Qt.Key_Backspace && input.text === "") {
                        card.fp.up();
                        event.accepted = true;
                    }
                }

                Txt {
                    anchors.fill: parent
                    visible: input.text === ""
                    text: "Search…"
                    color: Theme.textFaint
                    font.pixelSize: Theme.fontMd
                    font.weight: Font.Normal
                }
            }
        }
    }

    // ================================================================ Seitenleiste: Favoriten + Projekte
    Item {
        id: side
        anchors.left: parent.left
        anchors.top: pathBar.bottom
        anchors.bottom: foot.top
        anchors.leftMargin: 14
        anchors.topMargin: 12
        anchors.bottomMargin: 12
        width: 196

        WheelScroll {
            flick: sideFlick
            step: 108
        }

        Flickable {
            id: sideFlick
            anchors.fill: parent
            clip: true
            contentHeight: sideCol.implicitHeight
            boundsBehavior: Flickable.StopAtBounds
            interactive: false

            Column {
                id: sideCol
                width: sideFlick.width
                spacing: 2

                Repeater {
                    model: card.fp.favorites
                    Chip {
                        id: fav
                        required property var modelData
                        width: sideCol.width
                        height: 32
                        alignLeft: true
                        active: card.fp.dir === modelData.path
                        onClicked: {
                            card.fp.goChecked(fav.modelData.path);
                            card.focusInput();
                        }
                        Icon {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 18
                            name: fav.modelData.icon
                            size: 17
                            color: fav.active ? Theme.accentText : Theme.textMuted
                        }
                        Txt {
                            anchors.verticalCenter: parent.verticalCenter
                            width: sideCol.width - 60
                            text: fav.modelData.label
                            color: fav.active ? Theme.text : Theme.textMuted
                            font.weight: Font.Normal
                        }
                    }
                }

                Txt {
                    visible: card.fp.projects.length > 0
                    width: sideCol.width
                    height: 30
                    leftPadding: 14
                    verticalAlignment: Text.AlignBottom
                    bottomPadding: 6
                    text: "Projects"
                    color: Theme.textFaint
                    font.pixelSize: Theme.fontXs
                    font.weight: Font.DemiBold
                    font.capitalization: Font.AllUppercase
                    font.letterSpacing: 0.6
                }

                Repeater {
                    model: card.fp.projects
                    Chip {
                        id: proj
                        required property var modelData
                        width: sideCol.width
                        height: 32
                        alignLeft: true
                        active: card.fp.dir === modelData.path
                        onClicked: {
                            card.fp.goChecked(proj.modelData.path);
                            card.focusInput();
                        }
                        Item {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 18
                            height: 18
                            Rectangle {
                                anchors.centerIn: parent
                                width: 9
                                height: 9
                                radius: 4.5
                                color: proj.modelData.color
                            }
                        }
                        Txt {
                            anchors.verticalCenter: parent.verticalCenter
                            width: sideCol.width - 60
                            text: proj.modelData.label
                            color: proj.active ? Theme.text : Theme.textMuted
                            font.weight: Font.Normal
                        }
                    }
                }
            }
        }
    }

    Rectangle {
        id: sideSep
        anchors.left: side.right
        anchors.leftMargin: 10
        anchors.top: side.top
        anchors.bottom: side.bottom
        width: 1
        color: Theme.border
    }

    // ================================================================ Liste
    Item {
        id: body
        anchors.left: sideSep.right
        anchors.leftMargin: 10
        anchors.right: parent.right
        anchors.rightMargin: 14
        anchors.top: side.top
        anchors.bottom: side.bottom

        // Hinweis (Ordner fehlt) / getippter Pfad
        Txt {
            id: noteLine
            anchors.left: parent.left
            anchors.right: parent.right
            height: visible ? 28 : 0
            visible: card.fp.notice !== "" || card.fp.pathQuery
            leftPadding: 12
            text: card.fp.pathQuery ? "↵ go to " + card.fp.query.trim() : card.fp.notice
            color: card.fp.pathQuery ? Theme.textMuted : Theme.warning
            font.pixelSize: Theme.fontSm
            font.weight: Font.Normal
        }

        WheelScroll {
            flick: list
            step: 136
        }

        ListView {
            id: list
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: noteLine.bottom
            anchors.bottom: parent.bottom
            clip: true
            spacing: 2
            boundsBehavior: Flickable.StopAtBounds
            interactive: false
            model: card.fp.rows
            currentIndex: card.fp.sel
            highlightFollowsCurrentItem: false
            reuseItems: true

            delegate: FileRow {
                id: fr
                width: list.width
                height: card.rowH
                fp: card.fp
                onPicked: {
                    card.fp.sel = fr.index;
                    if (card.fp.multi && !fr.modelData.isDir)
                        card.fp.toggleMark(fr.modelData);
                    if (card.saving && !fr.modelData.isDir)
                        card.setName(fr.modelData.name, false);
                    card.focusInput();
                }
                onMarkToggled: {
                    card.fp.sel = fr.index;
                    card.fp.toggleMark(fr.modelData);
                    card.focusInput();
                }
                onOpened: {
                    const e = fr.modelData;
                    // Mehrfachauswahl: Doppelklick auf eine Datei markiert nur (der erste Klick hat schon umgeschaltet)
                    if (card.fp.multi && !e.isDir) {
                        card.focusInput();
                        return;
                    }
                    card.fp.sel = fr.index;
                    card.fp.enter(e);
                    if (card.saving && !e.isDir)
                        card.doSave();
                    card.focusInput();
                }
            }

            Column {
                anchors.centerIn: parent
                spacing: 8
                visible: list.count === 0 && !card.fp.pathQuery
                Icon {
                    anchors.horizontalCenter: parent.horizontalCenter
                    name: card.fp.loading ? "hourglass_top" : card.fp.query.trim() ? "search_off" : "folder_open"
                    size: 32
                    color: Theme.textFaint
                }
                Txt {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: card.fp.loading ? "Loading…"
                        : card.fp.query.trim() ? "Nothing matches “" + card.fp.query.trim() + "”"
                        : card.folders ? "No folders here" : "Empty folder"
                    color: Theme.textFaint
                    font.weight: Font.Normal
                }
                Txt {
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: !card.fp.loading && !card.fp.showHidden && !card.fp.query.trim()
                    text: "Ctrl+H shows hidden files"
                    color: Theme.textFaint
                    font.pixelSize: Theme.fontSm
                    font.weight: Font.Normal
                    opacity: 0.8
                }
            }
        }
    }

    // ================================================================ Fuß: Name (Speichern), Rückfrage, Knöpfe, Tasten
    Column {
        id: foot
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 20
        spacing: 10

        Rectangle {
            width: parent.width
            height: 1
            color: Theme.border
        }

        // Dateiname + Format
        Item {
            visible: card.saving
            width: parent.width
            height: 42

            Txt {
                id: nameLbl
                anchors.verticalCenter: parent.verticalCenter
                text: "Name"
                color: Theme.textFaint
                font.pixelSize: Theme.fontSm
                font.weight: Font.Normal
            }
            Rectangle {
                anchors.left: nameLbl.right
                anchors.leftMargin: 12
                anchors.right: fmtRow.left
                anchors.rightMargin: 10
                height: parent.height
                radius: Theme.radiusMd
                color: Theme.surfaceRaised
                border.width: 1
                border.color: card.error ? Theme.error : nameInput.activeFocus ? Qt.alpha(Theme.accent, 0.6) : Theme.border
                Behavior on border.color { ColorAnimation { duration: Theme.fade } }

                TextInput {
                    id: nameInput
                    anchors.fill: parent
                    anchors.leftMargin: 14
                    anchors.rightMargin: 14
                    verticalAlignment: TextInput.AlignVCenter
                    clip: true
                    focus: card.saving
                    color: Theme.text
                    selectionColor: Theme.accentSoft
                    font.family: Theme.fontUi
                    font.pixelSize: Theme.fontMd
                    onTextChanged: {
                        card.error = "";
                        card.fp.confirm = "";
                        const e = card.fp.extOf(text);
                        if (card.fp.filters.includes(e))
                            card.fp.ext = e;
                    }
                    Keys.onPressed: event => {
                        if (card.commonKey(event)) {
                            event.accepted = true;
                            return;
                        }
                        if (event.key === Qt.Key_Escape) {
                            FilePicker.cancel();
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                            card.doSave();
                            event.accepted = true;
                        }
                    }
                    Txt {
                        anchors.fill: parent
                        visible: nameInput.text === ""
                        text: "File name"
                        color: Theme.textFaint
                        font.pixelSize: Theme.fontMd
                        font.weight: Font.Normal
                    }
                }
            }
            // Format (Endung) umschalten
            Row {
                id: fmtRow
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 4
                Repeater {
                    model: card.fp.filters
                    Chip {
                        id: fmt
                        required property string modelData
                        height: 32
                        active: card.fp.ext === modelData
                        onClicked: {
                            card.fp.ext = fmt.modelData;
                            if (nameInput.text.trim())
                                nameInput.text = card.fp.withExt(nameInput.text.trim(), fmt.modelData);
                            nameInput.forceActiveFocus();
                            card.selectStem();
                        }
                        MonoTxt {
                            anchors.verticalCenter: parent.verticalCenter
                            text: fmt.modelData.toUpperCase()
                            font.pixelSize: Theme.fontSm
                            color: fmt.active ? Theme.accentText : Theme.textMuted
                        }
                    }
                }
            }
        }

        // Zeile: Hinweis/Rückfrage links, Knöpfe rechts (wächst, wenn die Tastenzeile umbricht)
        Item {
            width: parent.width
            height: Math.max(Theme.buttonHeight, infoCol.visible ? infoCol.implicitHeight : 0)

            // Überschreiben?
            Row {
                visible: card.fp.confirm !== ""
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8
                Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    name: "warning"
                    size: 18
                    color: Theme.warning
                }
                Txt {
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.min(implicitWidth, btns.x - 40)
                    text: "“" + card.fp.baseName(card.fp.confirm) + "” already exists · replace it?"
                    color: Theme.warning
                    font.weight: Font.Normal
                }
            }
            // Fehler / Ziel / Tasten
            Column {
                id: infoCol
                visible: card.fp.confirm === ""
                anchors.left: parent.left
                anchors.right: btns.left
                anchors.rightMargin: 16
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2
                Txt {
                    width: parent.width
                    visible: card.error !== "" || card.folders || card.fp.multi
                    text: card.error !== "" ? card.error
                        : card.fp.multi ? (card.fp.markedPaths.length === 0 ? "Nothing marked · Tab or click marks"
                            : card.fp.markedPaths.length + " marked · " + card.fp.markedPaths.map(p => card.fp.baseName(p)).join(", "))
                        : card.fp.dir.replace(card.fp.home, "~")
                    color: card.error !== "" ? Theme.error : card.fp.multi && card.fp.markedPaths.length ? Theme.accentText : Theme.textMuted
                    font.pixelSize: Theme.fontSm
                    font.weight: Font.Normal
                    elide: Text.ElideMiddle
                }
                // Tastenzeile (kleine Kappen); schmale Spalte neben den Knöpfen → bricht um
                KeyHintRow {
                        id: fpHints
                        width: parent.width
                        small: true
                        gap: Theme.space3
                        hints: card.saving ? [["↵", "save"], ["Tab", "list"], ["Alt+↑", "up"], ["Ctrl+H", "hidden"], ["Esc", "cancel"]]
                            : card.folders ? [["↵", "open"], ["Ctrl+↵", "choose marked"], ["⌫", "up"], ["Ctrl+H", "hidden"], ["Esc", "cancel"]]
                            : card.fp.multi ? [["Tab", "mark"], ["Ctrl+A", "all files"], ["↵", "open folder / take"], ["⌫", "up"], ["Ctrl+H", "hidden"], ["Esc", "cancel"]]
                            : [["↵", "open"], ["⌫", "up"], ["Ctrl+H", "hidden"], ["Esc", "cancel"]]
                }
            }

            Row {
                id: btns
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 10

                Button {
                    text: card.fp.confirm !== "" ? "Keep" : "Cancel"
                    onClicked: {
                        if (card.fp.confirm !== "") {
                            card.fp.confirm = "";
                            card.focusInput();
                        } else {
                            FilePicker.cancel();
                        }
                    }
                }
                Button {
                    readonly property bool can: card.saving || card.folders ? card.fp.dir !== ""
                        : card.fp.multi && card.fp.markedPaths.length > 0 ? true
                        : (card.fp.cur !== null && !card.fp.cur.isDir)
                    // lange Namen („Choose “Ordner”“) gekürzt
                    width: Math.min(260, implicitWidth)
                    primary: true
                    enabled: can
                    text: card.fp.confirm !== "" ? "Replace"
                        : card.saving ? "Save"
                        : card.folders ? "Choose “" + card.fp.baseName(card.fp.dir || "/") + "”"
                        : card.fp.multi ? (FilePicker.action || "Choose") + (card.fp.markedPaths.length > 1 ? " " + card.fp.markedPaths.length + " items"
                            : card.fp.markedPaths.length === 1 ? " “" + card.fp.baseName(card.fp.markedPaths[0]) + "”"
                            : card.fp.cur && !card.fp.cur.isDir ? " “" + card.fp.cur.name + "”" : "")
                        : "Open"
                    onClicked: card.primary()
                }
            }
        }
    }
}

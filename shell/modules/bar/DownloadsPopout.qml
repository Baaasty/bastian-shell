import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.services
import qs.components

// Downloads-Popout unter dem Downloads-Chip (Klick öffnet, Klick daneben / Esc schließt).
// Die letzten Downloads (Downloads.count, Standard 12) nach Zeit; Suchfeld durchsucht den ganzen Ordner.
// Zeile klicken = öffnen (xdg-open über Launch), Ordner-Knopf = im Dateimanager zeigen, ziehen = Datei in eine App legen
// (text/uri-list). „Clean up“ legt Einträge älter als N Tage nach Rückfrage in den Papierkorb (gio trash).
// Doku: docs/knowledge/shell-features.md
PopupWindow {
    id: pop

    property var barWindow
    property Item chip
    readonly property int cardW: 420
    readonly property int maxCardH: 620
    readonly property int quick: Math.round(Theme.fade * 0.6)
    property real appear: 0
    property real _closedAt: 0
    property string query: ""
    property bool asking: false              // Rückfrage „Clean up“ offen
    property int days: Downloads.cleanupDays
    readonly property var dayChoices: [7, 14, 30, 90]
    readonly property var old: asking ? Downloads.oldItems(days) : []

    readonly property var shown: {
        const q = query.trim().toLowerCase();
        if (q === "")
            return Downloads.recent;
        const toks = q.split(/\s+/);
        return Downloads.items.filter(i => toks.every(t => i.name.toLowerCase().includes(t))).slice(0, 50);
    }

    anchor.window: barWindow
    anchor.edges: Edges.Bottom | Edges.Right
    anchor.gravity: Edges.Bottom | Edges.Left
    grabFocus: true
    implicitWidth: cardW
    implicitHeight: maxCardH + 8
    color: "transparent"
    visible: false
    mask: Region { item: card }

    // ---------- Öffnen / Schließen ----------
    function placeUnderBar(): void {
        if (!chip)
            return;
        // rechtsbündig unter dem Chip, aber nie über den Bildschirmrand
        const right = Math.round(chip.mapToItem(null, chip.width, 0).x);
        anchor.rect.x = Math.max(right, cardW + Theme.barMargin) - 1;
        anchor.rect.y = Theme.barMargin + Theme.barHeight + Theme.windowGap - 1;
        anchor.rect.width = 1;
        anchor.rect.height = 1;
    }
    function open(): void {
        openWith(true);
    }
    // grab = false nur für den IPC-Test (ohne vorherigen Klick lässt der Compositor keinen Klick-Fang zu)
    function openWith(grab: bool): void {
        if (visible)
            return;
        grabFocus = grab;
        placeUnderBar();
        query = "";
        ti.text = "";
        asking = false;
        days = Downloads.cleanupDays;
        appear = 0;
        visible = true;
        appearAnim.restart();
    }
    function close(): void {
        guard.intended = true;
        visible = false;
    }
    function toggle(): void {
        if (visible || Date.now() - _closedAt < 400)
            close();
        else
            open();
    }
    function openItem(it: var): void {
        if (it.loading)
            return;
        Downloads.open(it.path);
    }

    onVisibleChanged: {
        if (barWindow && barWindow.openMenus !== undefined)
            barWindow.openMenus += visible ? 1 : -1;
        if (visible) {
            Popouts.claim("downloads");
            Downloads.seen();
            ti.forceActiveFocus();
        } else {
            Popouts.release("downloads");
            _closedAt = Date.now();
            appearAnim.stop();
            asking = false;
        }
    }
    Connections {
        target: Popouts
        function onCurrentChanged() {
            if (Popouts.current !== "downloads" && pop.visible)
                pop.visible = false;
        }
    }
    Binding {
        target: Downloads
        property: "active"
        value: pop.visible
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
        Region { item: pop.appear > 0.4 ? card : null; radius: Theme.radiusLg }
    }

    // ---------- Bausteine ----------
    component Btn: Rectangle {
        id: bt
        property string text
        property string icon
        property string tone: "plain"                  // plain | primary
        signal clicked()
        width: btRow.implicitWidth + 28
        height: 32
        radius: height / 2
        opacity: enabled ? 1 : 0.45
        color: tone === "primary" ? Theme.accentFill : btArea.containsMouse ? Theme.surface : Theme.surfaceSunken
        Behavior on color { ColorAnimation { duration: pop.quick } }
        Row {
            id: btRow
            anchors.centerIn: parent
            spacing: 6
            Icon {
                anchors.verticalCenter: parent.verticalCenter
                visible: bt.icon !== ""
                name: bt.icon
                size: 16
                color: bt.tone === "primary" ? Theme.accentText : Theme.textMuted
            }
            Txt {
                anchors.verticalCenter: parent.verticalCenter
                text: bt.text
                font.pixelSize: 13
                color: bt.tone === "primary" ? Theme.accentText : Theme.text
            }
        }
        MouseArea {
            id: btArea
            anchors.fill: parent
            enabled: bt.enabled
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: bt.clicked()
        }
    }

    // eine Download-Zeile: Typ-Symbol, Name, Größe · Alter; Hover zeigt „im Ordner zeigen“
    component DlRow: Rectangle {
        id: row
        required property var modelData
        readonly property var it: modelData
        readonly property bool hot: hov.hovered || drag.active
        width: list.width
        height: 52
        radius: Theme.radiusMd
        color: hot && !it.loading ? Theme.surfaceRaised : "transparent"
        Behavior on color { ColorAnimation { duration: pop.quick } }

        HoverHandler {
            id: hov
            cursorShape: row.it.loading ? Qt.ArrowCursor : drag.active ? Qt.ClosedHandCursor : Qt.PointingHandCursor
            // Vorschaubild fürs Ziehen schon beim Drüberfahren vorbereiten
            onHoveredChanged: {
                if (hovered && !row.it.loading)
                    tile.grabToImage(r => dragProxy.Drag.imageSource = r.url);
            }
        }
        TapHandler {
            enabled: !row.it.loading
            onTapped: pop.openItem(row.it)
        }
        // Ziehen: Datei als text/uri-list an die App darunter (Browser-Upload, Discord, Dateimanager …)
        DragHandler {
            id: drag
            target: null
            enabled: !row.it.loading
        }
        Item {
            id: dragProxy
            Drag.active: drag.active
            Drag.dragType: Drag.Automatic
            Drag.supportedActions: Qt.CopyAction
            Drag.proposedAction: Qt.CopyAction
            Drag.mimeData: ({ "text/uri-list": Downloads.uri(row.it.path) + "\r\n" })
            Drag.hotSpot.x: 17
            Drag.hotSpot.y: 17
        }

        Rectangle {
            id: tile
            x: 10
            anchors.verticalCenter: parent.verticalCenter
            width: 34
            height: 34
            radius: Theme.radiusSm
            color: Theme.surfaceSunken
            Icon {
                anchors.centerIn: parent
                name: row.it.loading ? "downloading" : Downloads.glyph(row.it)
                size: 19
                color: row.it.loading ? Theme.accentText : Theme.woodLight
            }
        }
        Column {
            anchors.left: tile.right
            anchors.leftMargin: 12
            anchors.right: showBtn.left
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            spacing: 1
            Txt {
                width: parent.width
                text: row.it.name
                elide: Text.ElideMiddle
                color: row.it.loading ? Theme.textMuted : Theme.text
            }
            Txt {
                width: parent.width
                text: row.it.loading ? "Downloading… " + Downloads.fmtSize(row.it.size)
                    : (row.it.dir ? "Folder" : Downloads.fmtSize(row.it.size)) + " · " + Downloads.fmtAge(row.it.mtime)
                color: row.it.loading ? Theme.accentText : Theme.textFaint
                font.pixelSize: 12
                font.weight: Font.Normal
            }
        }
        // im Dateimanager zeigen
        Rectangle {
            id: showBtn
            anchors.right: parent.right
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            width: 32
            height: 32
            radius: Theme.radiusSm
            visible: row.hot || showArea.containsMouse
            color: showArea.containsMouse ? Theme.surface : "transparent"
            Icon {
                anchors.centerIn: parent
                name: "folder_open"
                size: 18
                color: showArea.containsMouse ? Theme.text : Theme.textMuted
            }
            MouseArea {
                id: showArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    Downloads.showInFolder(row.it.path);
                }
            }
        }
    }

    // ---------- Karte ----------
    Glass {
        id: card
        // offen bis zum Weghovern (PopoutGuard.qml)
        PopoutGuard { id: guard; popout: pop; chip: pop.chip; name: "downloads" }
        // Tastatur: Pfeile/Tab/Enter, Bar-Modus (Super+B, KeyNav.qml)
        Keys.onPressed: e => nav.key(e)
        KeyNav { id: nav; root: card; scope: null; popout: pop; guard: guard; name: "downloads" }
        width: pop.cardW
        height: footer.y + footer.height + 16
        strong: true
        opacity: pop.appear
        transform: Translate { y: (1 - pop.appear) * -6 }

        // Kopfzeile: Titel + Suchfeld
        Item {
            id: head
            x: 20
            y: 18
            width: parent.width - 40
            height: 36
            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8
                Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    name: "download"
                    size: 22
                    color: Theme.accentText
                }
                Txt {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Downloads"
                    font.pixelSize: 18
                    font.weight: Font.DemiBold
                }
            }
            Rectangle {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: 190
                height: 36
                radius: Theme.radiusMd
                color: Theme.surfaceSunken
                border.width: 1
                border.color: ti.activeFocus ? Qt.alpha(Theme.accent, 0.5) : "transparent"
                Behavior on border.color { ColorAnimation { duration: pop.quick } }
                Icon {
                    id: searchIcon
                    x: 12
                    anchors.verticalCenter: parent.verticalCenter
                    name: "search"
                    size: 17
                    color: Theme.textFaint
                }
                TextInput {
                    id: ti
                    anchors.left: searchIcon.right
                    anchors.leftMargin: 8
                    anchors.right: parent.right
                    anchors.rightMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    color: Theme.text
                    selectionColor: Theme.accentSoft
                    selectedTextColor: Theme.text
                    font.family: Theme.fontUi
                    font.pixelSize: 14
                    clip: true
                    onTextChanged: pop.query = text
                    Keys.onEscapePressed: {
                        if (pop.asking)
                            pop.asking = false;
                        else if (text !== "")
                            text = "";
                        else
                            pop.close();
                    }
                    // Enter öffnet den obersten Treffer
                    Keys.onReturnPressed: {
                        if (pop.shown.length)
                            pop.openItem(pop.shown[0]);
                    }
                    Txt {
                        anchors.fill: parent
                        visible: ti.text === ""
                        text: "Search…"
                        color: Theme.textFaint
                        font.weight: Font.Normal
                    }
                }
            }
        }

        // Liste
        Flickable {
            id: list
            x: 12
            y: head.y + head.height + 12
            width: card.width - 24
            height: Math.max(120, Math.min(rows.implicitHeight, pop.maxCardH - y - 64 - (pop.asking ? askBox.height + 10 : 0)))
            contentWidth: width
            contentHeight: rows.implicitHeight
            interactive: false
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            Column {
                id: rows
                width: list.width
                spacing: 2
                Repeater {
                    model: pop.shown
                    DlRow {}
                }
            }
        }
        // Leer-Hinweis mittig in der Liste (nicht im Flickable: dessen Inhalt ist leer 0 px hoch -> Text saß oben auf dem Kopf)
        Txt {
            anchors.centerIn: list
            visible: pop.shown.length === 0
            text: !Downloads.ready ? "Reading…" : pop.query !== "" ? "No match" : "No downloads yet"
            color: Theme.textFaint
            font.weight: Font.Normal
        }
        WheelScroll {
            flick: list
            step: 108
        }
        // dünner Rollbalken (nur Anzeige)
        Rectangle {
            visible: list.contentHeight > list.height
            x: list.x + list.width - 2
            y: list.y + list.height * list.visibleArea.yPosition
            width: 3
            height: Math.max(24, list.height * list.visibleArea.heightRatio)
            radius: 2
            color: Theme.borderStrong
        }

        // Rückfrage „Clean up“
        Rectangle {
            id: askBox
            visible: pop.asking
            x: 20
            y: list.y + list.height + 10
            width: card.width - 40
            height: visible ? askCol.implicitHeight + 24 : 0
            radius: Theme.radiusMd
            color: Theme.surfaceRaised
            Column {
                id: askCol
                x: 14
                y: 12
                width: parent.width - 28
                spacing: 10
                Txt {
                    width: parent.width
                    text: "Move old downloads to the trash?"
                    font.weight: Font.DemiBold
                }
                // Alter wählen
                Row {
                    spacing: 6
                    Txt {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Older than"
                        color: Theme.textMuted
                        font.pixelSize: 13
                        font.weight: Font.Normal
                        rightPadding: 4
                    }
                    Repeater {
                        model: pop.dayChoices
                        Rectangle {
                            required property int modelData
                            readonly property bool on: pop.days === modelData
                            anchors.verticalCenter: parent.verticalCenter
                            width: dayTxt.implicitWidth + 20
                            height: 26
                            radius: 13
                            color: on ? Theme.accentFill : dayArea.containsMouse ? Theme.surface : Theme.surfaceSunken
                            border.width: 1
                            border.color: on ? Qt.alpha(Theme.accent, 0.55) : "transparent"
                            Txt {
                                id: dayTxt
                                anchors.centerIn: parent
                                text: parent.modelData + " days"
                                font.pixelSize: 12
                                color: parent.on ? Theme.accentText : Theme.textMuted
                            }
                            MouseArea {
                                id: dayArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: pop.days = parent.modelData
                            }
                        }
                    }
                }
                Txt {
                    width: parent.width
                    text: pop.old.length === 0 ? "Nothing that old – all clean."
                        : pop.old.length + (pop.old.length === 1 ? " item" : " items") + " · "
                          + Downloads.fmtSize(pop.old.reduce((s, i) => s + (i.dir ? 0 : i.size), 0))
                          + " · can be restored from the trash"
                    color: Theme.textFaint
                    font.pixelSize: 12
                    font.weight: Font.Normal
                    wrapMode: Text.WordWrap
                    elide: Text.ElideNone
                }
                Row {
                    anchors.right: parent.right
                    spacing: 8
                    Btn {
                        text: "Cancel"
                        onClicked: pop.asking = false
                    }
                    Btn {
                        tone: "primary"
                        icon: "delete"
                        text: "Move to trash"
                        enabled: pop.old.length > 0 && !Downloads.trashing
                        onClicked: {
                            Downloads.trashOld(pop.days);
                            pop.asking = false;
                        }
                    }
                }
            }
        }

        // Fuß: Ordner öffnen · Aufräumen · Rückmeldung
        Item {
            id: footer
            x: 20
            y: (pop.asking ? askBox.y + askBox.height : list.y + list.height) + 12
            width: card.width - 40
            height: 32
            Btn {
                id: folderBtn
                icon: "folder_open"
                text: "Open folder"
                onClicked: {
                    Downloads.openFolder();
                }
            }
            Txt {
                anchors.left: folderBtn.right
                anchors.leftMargin: 10
                anchors.right: cleanBtn.left
                anchors.rightMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                text: Downloads.note !== "" ? Downloads.note
                    : pop.query !== "" ? pop.shown.length + " found" : Downloads.items.length + " in folder"
                color: Downloads.note !== "" ? Theme.accentText : Theme.textFaint
                horizontalAlignment: Text.AlignHCenter
                font.pixelSize: 12
                font.weight: Font.Normal
            }
            Btn {
                id: cleanBtn
                anchors.right: parent.right
                icon: "delete_sweep"
                text: "Clean up"
                enabled: !Downloads.trashing
                onClicked: pop.asking = !pop.asking
            }
        }
    }
}

import QtQuick
import qs.config
import qs.components

// Das Fenster: links Quellen (mit Update-Zählern), rechts Suche + Liste, unten Log-Leiste
Glass {
    id: panel

    required property var pk
    readonly property alias search: input

    function focusSearch(): void {
        input.forceActiveFocus();
    }

    readonly property string dataPage: pk.page === "terra" ? "vendors" : pk.page
    readonly property string loadSt: pk.loadState[pk.view === "repos" ? pk.page + ":repos" : dataPage] || ""
    readonly property bool loading: pk.page !== "updates" && loadSt === "loading"
    readonly property string subtitle: {
        const p = pk.page;
        if (pk.view === "repos")
            return (p === "system" ? "dnf repositories" : "Flatpak remotes") + " · " + pk.rows.length;
        if (p === "updates")
            return pk.updBusy ? "Checking for updates…" : pk.updTotal === 0 ? "Everything is up to date" : pk.updTotal + " updates waiting";
        if (p === "system")
            return (pk.lists.system ? pk.lists.system.length + " installed" : "") + (pk.updSystem ? " · " + pk.updSystem + " updates" : "");
        if (p === "copr")
            return (pk.lists.copr ? pk.lists.copr.length + " repos" : "") + (pk.updCopr ? " · " + pk.updCopr + " updates" : "");
        if (p === "flatpak")
            return (pk.lists.flatpak ? pk.lists.flatpak.length + " apps" : "") + (pk.updFlatpak ? " · " + pk.updFlatpak + " updates" : "");
        if (p === "appimage")
            return "Scanned: ~/Applications · ~/.local/bin · ~/Downloads · ~/AppImages";
        if (p === "terra")
            return "Community repo · not reviewed by Fedora";
        if (p === "vendors")
            return "Official repos of software vendors · you confirm every command first";
        if (p === "devtools")
            return "Language tools: pipx · npm global · cargo · go";
        return "Own and company repos · .rpm files";
    }
    readonly property string placeholder: pk.view === "repos" ? "Filter repos…" : ({
        updates: "Filter updates…",
        system: "Search RPM packages (installed + available)…",
        copr: "Filter repos · Enter searches COPR…",
        flatpak: "Search Flatpak apps…",
        appimage: "Filter AppImages…",
        terra: "Filter…",
        vendors: "Filter vendors…",
        devtools: "Filter tools…",
        local: "Filter repos · or paste a .repo URL to add one…"
    })[pk.page]

    radius: Theme.radiusXl
    strong: true

    // ================================================================ Seitenleiste
    Item {
        id: side
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: 232

        PopoutTitle {
            x: 24
            y: 26
            icon: "inventory_2"
            text: "Packages"
            textSize: Theme.fontXl
        }

        Column {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            y: 70
            spacing: 2

            Repeater {
                model: panel.pk.pages

                Item {
                    id: slot
                    required property var modelData
                    required property int index
                    readonly property bool showGroup: !!modelData.group && (index === 0 || panel.pk.pages[index - 1].group !== modelData.group)
                    width: parent.width
                    height: (showGroup ? 26 : 0) + 42

                Label {
                    visible: slot.showGroup
                    x: 14
                    y: 8
                    text: slot.modelData.group
                    font.pixelSize: Theme.fontXs
                }

                Rectangle {
                    id: item
                    readonly property var modelData: slot.modelData
                    readonly property bool on: panel.pk.page === modelData.id
                    readonly property int n: panel.pk.countFor(modelData.id)

                    y: slot.showGroup ? 26 : 0
                    width: parent.width
                    height: 40
                    radius: Theme.radiusMd
                    // gewählte Seite = deckende Akzentfläche (wie Tab und Listenauswahl)
                    color: on ? Theme.accentFill : ma.containsMouse ? Theme.raise : "transparent"
                    Behavior on color { ColorAnimation { duration: Theme.fade } }

                    Icon {
                        id: ic
                        anchors.left: parent.left
                        anchors.leftMargin: 14
                        anchors.verticalCenter: parent.verticalCenter
                        name: item.modelData.icon
                        size: 19
                        color: item.on ? Theme.accentText : Theme.textMuted
                    }
                    Column {
                        anchors.left: ic.right
                        anchors.leftMargin: 12
                        anchors.right: cnt.left
                        anchors.rightMargin: 6
                        anchors.verticalCenter: parent.verticalCenter
                        Txt {
                            width: parent.width
                            text: item.modelData.label
                            font.pixelSize: Theme.fontMd
                            color: item.on ? Theme.accentText : Theme.text
                        }
                        Txt {
                            width: parent.width
                            text: item.modelData.hint
                            font.pixelSize: Theme.fontXs
                            font.weight: Font.Normal
                            color: Theme.textFaint
                        }
                    }
                    Rectangle {
                        id: cnt
                        anchors.right: parent.right
                        anchors.rightMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        visible: item.n > 0
                        width: Math.max(24, cntT.implicitWidth + 14)
                        height: 22
                        radius: 11
                        color: Theme.accent
                        MonoTxt {
                            id: cntT
                            anchors.centerIn: parent
                            text: item.n
                            font.pixelSize: Theme.fontSm
                            font.weight: Font.DemiBold
                            color: Theme.bg
                        }
                    }
                    PkgSpinner {
                        anchors.right: parent.right
                        anchors.rightMargin: 14
                        anchors.verticalCenter: parent.verticalCenter
                        size: 16
                        visible: item.modelData.id === "updates" && panel.pk.updBusy && item.n === 0
                    }
                    MouseArea {
                        id: ma
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            panel.pk.setPage(item.modelData.id);
                            input.forceActiveFocus();
                        }
                    }
                }
                }
            }
        }

        Column {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: 20
            spacing: 12
            Button {
                small: true
                width: parent.width
                enabled: !panel.pk.updBusy && !panel.pk.busy
                icon: "refresh"
                text: "Check for updates"
                onClicked: panel.pk.refreshAll()
            }
            KeyHintRow {
                gap: Theme.space3
                hints: [["Tab", "switch"], ["Esc", "close"]]
            }
        }
    }

    VSep {
        anchors.left: side.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.topMargin: 20
        anchors.bottomMargin: 20
        implicitHeight: 1
        color: Theme.border
    }

    // ================================================================ Hauptbereich
    Item {
        id: main
        anchors.left: side.right
        anchors.leftMargin: 28
        anchors.right: parent.right
        anchors.rightMargin: 24
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.topMargin: 22
        anchors.bottomMargin: 20

        // Kopf
        Item {
            id: head
            anchors.left: parent.left
            anchors.right: parent.right
            height: 48

            Column {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2
                Txt {
                    text: panel.pk.view === "repos" ? (panel.pk.page === "system" ? "Repositories" : "Remotes") : panel.pk.pageInfo(panel.pk.page).label
                    font.pixelSize: Theme.fontXl
                    font.weight: Font.DemiBold
                }
                Txt {
                    text: panel.subtitle
                    color: Theme.textFaint
                    font.pixelSize: Theme.fontSm
                    font.weight: Font.Normal
                }
            }
            Row {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6
                visible: panel.pk.page === "system" || panel.pk.page === "flatpak"
                PkgChip {
                    visible: panel.pk.view === "list" && panel.pk.page === "system"
                    text: "Explicit"
                    on: panel.pk.filter === "explicit"
                    onClicked: panel.pk.filter = panel.pk.filter === "explicit" ? "all" : "explicit"
                }
                PkgChip {
                    visible: panel.pk.view === "list"
                    text: "Updates"
                    on: panel.pk.filter === "updates"
                    onClicked: panel.pk.filter = panel.pk.filter === "updates" ? "all" : "updates"
                }
                PkgChip {
                    icon: panel.pk.view === "repos" ? "arrow_back" : (panel.pk.page === "system" ? "dns" : "cloud")
                    text: panel.pk.view === "repos" ? "Packages" : (panel.pk.page === "system" ? "Repos" : "Remotes")
                    on: panel.pk.view === "repos"
                    onClicked: panel.pk.setView(panel.pk.view === "repos" ? "list" : "repos")
                }
            }
        }

        // Suchfeld
        Rectangle {
            id: sf
            anchors.top: head.bottom
            anchors.topMargin: 14
            anchors.left: parent.left
            anchors.right: parent.right
            height: 46
            radius: Theme.radiusMd
            color: Theme.raise
            border.width: 1
            border.color: input.activeFocus ? Qt.alpha(Theme.accent, 0.5) : Theme.border
            Behavior on border.color { ColorAnimation { duration: Theme.fade } }

            Icon {
                id: sIcon
                anchors.left: parent.left
                anchors.leftMargin: 14
                anchors.verticalCenter: parent.verticalCenter
                name: "search"
                size: 20
                color: Theme.textFaint
            }
            TextInput {
                id: input
                anchors.left: sIcon.right
                anchors.leftMargin: 10
                anchors.right: sBusy.left
                anchors.rightMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                clip: true
                text: panel.pk.query
                onTextChanged: panel.pk.query = text
                Connections {
                    target: panel.pk
                    function onQueryChanged() {
                        if (input.text !== panel.pk.query)
                            input.text = panel.pk.query;
                    }
                }
                color: Theme.text
                selectionColor: Theme.accentSoft
                font.family: Theme.fontUi
                font.pixelSize: Theme.fontLg
                focus: true

                Keys.onEscapePressed: {
                    if (panel.pk.confirm)
                        panel.pk.confirm = null;
                    else if (panel.pk.query !== "")
                        panel.pk.query = "";
                    else
                        panel.pk.close();
                }
                function enter(): void {
                    if (panel.pk.confirm)
                        panel.pk.confirmYes();
                    else if (panel.pk.page === "copr" && panel.pk.query.trim() && panel.pk.sel < 0)
                        panel.pk.searchCopr();
                    else if (panel.pk.sel >= 0)
                        list.activateSel();
                }
                Keys.onReturnPressed: enter()
                Keys.onEnterPressed: enter()
                Keys.onDownPressed: {
                    panel.pk.moveSel(1);
                    list.positionViewAtIndex(panel.pk.sel, ListView.Contain);
                }
                Keys.onUpPressed: {
                    panel.pk.moveSel(-1);
                    list.positionViewAtIndex(panel.pk.sel, ListView.Contain);
                }
                Keys.onTabPressed: panel.pk.cyclePage(1)
                Keys.onBacktabPressed: panel.pk.cyclePage(-1)

                Txt {
                    anchors.fill: parent
                    visible: input.text === ""
                    text: panel.placeholder
                    color: Theme.textFaint
                    font.pixelSize: Theme.fontLg
                    font.weight: Font.Normal
                }
            }
            PkgSpinner {
                id: sBusy
                anchors.right: parent.right
                anchors.rightMargin: 14
                anchors.verticalCenter: parent.verticalCenter
                size: 18
                visible: panel.pk.searchBusy
                width: visible ? 18 : 0
            }
        }

        // Quellen-Chips: Repo-Gruppe (System) bzw. Remote (Flatpak)
        Flow {
            id: srcRow
            visible: panel.pk.chips.length > 0
            anchors.top: sf.bottom
            anchors.topMargin: 10
            anchors.left: parent.left
            anchors.right: parent.right
            spacing: 6
            PkgChip {
                text: "All sources"
                on: panel.pk.groupFilter === ""
                onClicked: panel.pk.groupFilter = ""
            }
            Repeater {
                model: panel.pk.chips
                PkgChip {
                    required property var modelData
                    text: modelData.label + "  " + modelData.n
                    on: panel.pk.groupFilter === modelData.id
                    onClicked: panel.pk.groupFilter = panel.pk.groupFilter === modelData.id ? "" : modelData.id
                }
            }
        }

        // Log-Leiste (unten)
        PkgLog {
            id: logBar
            pk: panel.pk
            visible: panel.pk.logShown
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
        }

        // Liste
        Item {
            id: listArea
            anchors.top: srcRow.visible ? srcRow.bottom : sf.bottom
            anchors.topMargin: 10
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: logBar.visible ? logBar.top : parent.bottom
            anchors.bottomMargin: logBar.visible ? 10 : 0
            clip: true

            ListView {
                id: list
                anchors.fill: parent
                interactive: false   // Rad macht WheelScroll (weich)
                model: panel.pk.rows
                cacheBuffer: 400
                boundsBehavior: Flickable.StopAtBounds
                reuseItems: false

                function activateSel(): void {
                    const r = panel.pk.rows[panel.pk.sel];
                    if (!r)
                        return;
                    if (r.kind === "coprsearch")
                        panel.pk.searchCopr();
                    else
                        panel.pk.toggleExpand(r);
                    positionViewAtIndex(panel.pk.sel, ListView.Contain);
                }

                delegate: PkgRow {
                    pk: panel.pk
                }

                add: Transition {
                    NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 140 }
                }
            }

            WheelScroll {
                flick: list
                step: 160
            }

            // schmale Anzeige rechts
            Rectangle {
                visible: list.contentHeight > list.height
                anchors.right: parent.right
                width: 3
                radius: 1.5
                color: Qt.alpha(Theme.text, 0.22)
                y: list.visibleArea.yPosition * list.height
                height: Math.max(24, list.visibleArea.heightRatio * list.height)
            }

            // leer / lädt
            Column {
                anchors.centerIn: parent
                spacing: 10
                visible: panel.pk.rows.length === 0
                PkgSpinner {
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: panel.loading || (panel.pk.page === "updates" && panel.pk.updBusy) || panel.pk.searchBusy
                    size: 26
                }
                Icon {
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: !(panel.loading || (panel.pk.page === "updates" && panel.pk.updBusy) || panel.pk.searchBusy)
                    name: panel.loadSt.startsWith("error") ? "error" : panel.pk.page === "updates" ? "check_circle" : "inbox"
                    size: 34
                    color: panel.loadSt.startsWith("error") ? Theme.error : panel.pk.page === "updates" ? Theme.success : Theme.textFaint
                }
                Txt {
                    anchors.horizontalCenter: parent.horizontalCenter
                    horizontalAlignment: Text.AlignHCenter
                    color: Theme.textFaint
                    font.pixelSize: Theme.fontMd
                    font.weight: Font.Normal
                    text: panel.loadSt.startsWith("error") ? panel.loadSt.slice(6)
                        : panel.loading ? "Loading…"
                        : panel.pk.page === "updates" ? (panel.pk.updBusy ? "Checking sources…" : panel.pk.query ? "No updates match" : "Everything is up to date")
                        : panel.pk.searchBusy ? "Searching…"
                        : panel.pk.page === "appimage" ? "No AppImages found"
                        : "Nothing found"
                }
            }
        }
    }

    // .rpm-Datei aufs Fenster ziehen -> Installieren mit Vorschau
    DropArea {
        anchors.fill: parent
        onDropped: drop => {
            if (drop.hasUrls)
                panel.pk.dropFiles(drop.urls);
        }
    }

    // Bestätigung liegt über allem
    PkgConfirm {
        anchors.fill: parent
        pk: panel.pk
        z: 10
    }
}

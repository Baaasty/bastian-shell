import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.services
import qs.components

// Server-Popout unter dem Server-Chip (Klick öffnet, Klick daneben / Esc schließt, offen bis zum Weghovern).
// Server aus scripts/sshs (services/Servers.qml), zuletzt benutzter oben. Pro Server:
//   Upload   – Datei-Wähler der Shell (mehrere: Tab/Klick markiert) → in den Home-Ordner des Servers, Ergebnis als Benachrichtigung
//   Files    – sshs-Kitty-Fenster, das nach der Anmeldung auf Dateien (yazi per SFTP) umschaltet
//   Terminal – sshs-Kitty-Fenster mit der Shell auf dem Server
// Tastatur: ↑↓←→/Tab wählen, Enter löst aus, Esc zu (KeyNav.qml). Kürzel Super+Alt+U. Doku: docs/SSHS.md
PopupWindow {
    id: pop

    property var barWindow
    property Item chip
    readonly property int cardW: 540
    readonly property int maxCardH: 560
    readonly property int quick: Math.round(Theme.fade * 0.6)
    property real appear: 0
    property real _closedAt: 0

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
        Servers.refresh();
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
    // Aktion: erst zu (Wähler/Fenster brauchen die Tastatur), dann auslösen
    function run(fn: var): void {
        close();
        Qt.callLater(fn);
    }

    onVisibleChanged: {
        if (barWindow && barWindow.openMenus !== undefined)
            barWindow.openMenus += visible ? 1 : -1;
        if (visible) {
            Popouts.claim("servers");
            keys.forceActiveFocus();
        } else {
            Popouts.release("servers");
            _closedAt = Date.now();
            appearAnim.stop();
        }
    }
    Connections {
        target: Popouts
        function onCurrentChanged() {
            if (Popouts.current !== "servers" && pop.visible)
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
        Region { item: pop.appear > 0.4 ? card : null; radius: Theme.radiusLg }
    }

    // ---------- Bausteine ----------
    component Btn: Rectangle {
        id: bt
        property string text
        property string icon
        property string tone: "plain"                  // plain | primary
        signal clicked()
        width: btRow.implicitWidth + (text === "" ? 16 : 24)
        height: 30
        radius: height / 2
        opacity: enabled ? 1 : 0.45
        color: tone === "primary" ? (btArea.containsMouse ? Theme.accentSoft : Theme.accentFill)
            : btArea.containsMouse ? Theme.surface : Theme.surfaceSunken
        Behavior on color { ColorAnimation { duration: pop.quick } }
        Row {
            id: btRow
            anchors.centerIn: parent
            spacing: 5
            Icon {
                anchors.verticalCenter: parent.verticalCenter
                visible: bt.icon !== ""
                name: bt.icon
                size: 16
                color: bt.tone === "primary" ? Theme.accentText : Theme.textMuted
            }
            Txt {
                anchors.verticalCenter: parent.verticalCenter
                visible: bt.text !== ""
                text: bt.text
                font.pixelSize: 12
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

    // eine Server-Zeile: Symbol, Name, user@host · zuletzt, rechts Upload / Files / Terminal
    component ServerRow: Rectangle {
        id: row
        required property var modelData
        required property int index
        readonly property var s: modelData
        readonly property bool recent: index === 0 && s.last > 0
        readonly property bool busy: Servers.upHost === s.name
        width: list.width
        height: 56
        radius: Theme.radiusMd
        color: hov.hovered ? Theme.surfaceRaised : "transparent"
        Behavior on color { ColorAnimation { duration: pop.quick } }

        HoverHandler {
            id: hov
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
                name: row.busy ? "cloud_upload" : "dns"
                size: 19
                color: row.busy || row.recent ? Theme.accentText : Theme.woodLight
            }
        }
        Column {
            anchors.left: tile.right
            anchors.leftMargin: 12
            anchors.right: actions.left
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            spacing: 1
            Row {
                width: parent.width
                spacing: 8
                Txt {
                    id: nameTxt
                    width: Math.min(implicitWidth, parent.width - (agoTxt.visible ? agoTxt.implicitWidth + 8 : 0))
                    text: row.s.name
                    elide: Text.ElideRight
                }
                Txt {
                    id: agoTxt
                    anchors.baseline: nameTxt.baseline
                    visible: row.s.last > 0
                    text: Servers.ago(row.s.last)
                    color: Theme.textFaint
                    font.pixelSize: 11
                    font.weight: Font.Normal
                }
            }
            Txt {
                width: parent.width
                text: row.busy ? "Uploading " + Servers.upCount + (Servers.upCount === 1 ? " item…" : " items…")
                    : Servers.where(row.s)
                color: row.busy ? Theme.accentText : Theme.textFaint
                font.pixelSize: 12
                font.weight: Font.Normal
                elide: Text.ElideMiddle
            }
        }
        Row {
            id: actions
            anchors.right: parent.right
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6
            Btn {
                icon: "upload"
                text: "Upload"
                tone: row.recent ? "primary" : "plain"
                enabled: !Servers.uploading
                onClicked: pop.run(() => Servers.upload(row.s.name))
            }
            Btn {
                icon: "folder_open"
                text: "Files"
                onClicked: pop.run(() => Servers.files(row.s.name))
            }
            Btn {
                icon: "terminal"
                text: "Terminal"
                onClicked: pop.run(() => Servers.terminal(row.s.name))
            }
        }
    }

    // ---------- Karte ----------
    Glass {
        id: card
        // offen bis zum Weghovern (PopoutGuard.qml)
        PopoutGuard { id: guard; popout: pop; chip: pop.chip; name: "servers" }
        // Tastatur: Pfeile/Tab/Enter, Kürzel Super+Alt+U (KeyNav.qml)
        Keys.onPressed: e => nav.key(e)
        KeyNav { id: nav; root: card; scope: keys; popout: pop; guard: guard; name: "servers" }
        width: pop.cardW
        height: footer.y + footer.height + 16
        strong: true
        opacity: pop.appear
        transform: Translate { y: (1 - pop.appear) * -6 }

        FocusScope {
            id: keys
            anchors.fill: parent
            Keys.onEscapePressed: pop.close()
        }

        // Kopfzeile
        Item {
            id: head
            x: 20
            y: 18
            width: parent.width - 40
            height: 32
            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8
                Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    name: "dns"
                    size: 22
                    color: Theme.accentText
                }
                Txt {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Servers"
                    font.pixelSize: 18
                    font.weight: Font.DemiBold
                }
            }
            Txt {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: "Upload goes to ~ on the server"
                color: Theme.textFaint
                font.pixelSize: 12
                font.weight: Font.Normal
            }
        }

        // Liste
        Flickable {
            id: list
            x: 12
            y: head.y + head.height + 12
            width: card.width - 24
            height: Math.max(Servers.list.length ? 0 : 84, Math.min(rows.implicitHeight, pop.maxCardH - y - 64))
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
                    model: Servers.list
                    ServerRow {}
                }
            }

            Column {
                anchors.centerIn: parent
                visible: Servers.list.length === 0
                spacing: 4
                Txt {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: !Servers.ready ? "Reading…" : Servers.error !== "" ? Servers.error : "No servers yet"
                    color: Theme.textFaint
                    font.weight: Font.Normal
                }
                Txt {
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: Servers.ready && Servers.error === ""
                    text: "“New server” below, or sshs add in a terminal"
                    color: Theme.textFaint
                    font.pixelSize: 12
                    font.weight: Font.Normal
                }
            }
        }
        WheelScroll {
            flick: list
            step: 116
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

        // Fuß: Rückmeldung · neuer Server
        Item {
            id: footer
            x: 20
            y: list.y + list.height + 12
            width: card.width - 40
            height: 30
            Txt {
                anchors.left: parent.left
                anchors.right: addBtn.left
                anchors.rightMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                text: Servers.note !== "" ? Servers.note
                    : Servers.uploading ? "Uploading to " + Servers.upHost + "…"
                    : Servers.list.length + (Servers.list.length === 1 ? " server" : " servers") + " · Ctrl+Space in the window: terminal ↔ files"
                color: Servers.note !== "" || Servers.uploading ? Theme.accentText : Theme.textFaint
                font.pixelSize: 12
                font.weight: Font.Normal
                elide: Text.ElideRight
            }
            Btn {
                id: addBtn
                anchors.right: parent.right
                icon: "add"
                text: "New server"
                onClicked: {
                    pop.close();
                    Launch.cmd(["kitty", "--class", "sshs", "--title", "sshs · new server", "-e", Servers.sshs, "add"]);
                }
            }
        }
    }
}

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.SystemTray
import Quickshell.Wayland
import Quickshell.Widgets
import qs.config
import qs.services
import qs.components

// Tray: Links = aktivieren, Rechts = Menü (eigenes TrayMenu statt nativem Qt-Menü), Mitte = Zweitaktion.
// Ausgeblendete Symbole (Standard: Discord (alt Equibop/Vesktop), Spotify – die sind schon eingebettet) liegen hinter dem Pfeil.
Row {
    id: tray

    required property var barWindow
    property var hidden: ["discord", "equibop", "vesktop", "spotify"]

    spacing: 0

    // Popouts sitzen wie die Benachrichtigungen mit Lücke unter der Bar (nicht am Chip)
    function placeUnderBar(popup, item) {
        const p = item.mapToItem(null, 0, 0);
        popup.anchor.rect.x = p.x;
        popup.anchor.rect.y = Theme.barMargin + Theme.barHeight + Theme.windowGap - 1;
        popup.anchor.rect.width = item.width;
        popup.anchor.rect.height = 1;
    }

    function keyOf(item) {
        return ((item.id || item.title || "") + "").toLowerCase();
    }
    function isHidden(item) {
        const k = keyOf(item);
        return hidden.some(h => k.indexOf(h) >= 0);
    }
    function toggleHidden(item) {
        const k = keyOf(item);
        const match = hidden.find(h => k.indexOf(h) >= 0);
        hidden = match ? hidden.filter(h => h !== match) : hidden.concat([k]);
        prefs.setText(JSON.stringify({ hidden: hidden }));
    }

    FileView {
        id: prefs
        path: Quickshell.env("HOME") + "/.local/state/desktop/tray.json"
        printErrors: false
        onLoaded: {
            try {
                tray.hidden = JSON.parse(text()).hidden ?? tray.hidden;
            } catch (e) {}
        }
    }

    // mouse = null: per Tastatur (KeyNav) = Linksklick; menu() öffnet das Menü auch per Tastatur
    function click(item, mouse, anchorItem) {
        const button = mouse ? mouse.button : Qt.LeftButton;
        if (button === Qt.MiddleButton)
            item.secondaryActivate();
        else if (button === Qt.RightButton || item.onlyMenu) {
            menu(item, anchorItem, !mouse);
        } else
            item.activate();
    }
    function menu(item, anchorItem, kb) {
        if (!item.hasMenu || !item.menu)
            return;
        // aus der Liste hinter dem Pfeil: erst die Liste zu (grabFocus), dann das Menü am Pfeil auf
        if (pop.visible) {
            pop.close();
            Qt.callLater(() => trayMenu.openFor(item.menu, anchorItem, tray.placeUnderBar, kb));
        } else
            trayMenu.openFor(item.menu, anchorItem, tray.placeUnderBar, kb);
    }

    TrayMenu {
        id: trayMenu
        barWindow: tray.barWindow
    }

    Repeater {
        model: SystemTray.items

        Chip {
            id: btn

            required property SystemTrayItem modelData

            visible: !tray.isHidden(modelData)
            padding: 7
            implicitWidth: Theme.hitMin
            active: trayMenu.visible && trayMenu.handle === modelData.menu
            onClicked: mouse => tray.click(modelData, mouse, btn)

            IconImage {
                anchors.verticalCenter: parent.verticalCenter
                implicitSize: 18
                source: btn.modelData.icon
            }
        }
    }

    // Pfeil: alle Symbole, ein-/ausblenden
    Chip {
        id: more
        hintKey: BarKeys.keyFor("tray")   // Bar-Modus (Super+Leertaste): Liste aller Symbole, dort Pfeile/Enter
        padding: 4
        active: pop.visible
        onClicked: {
            if (pop.visible)
                return pop.close();
            tray.placeUnderBar(pop, more);
            pop.visible = true;
        }
        Icon {
            anchors.verticalCenter: parent.verticalCenter
            name: "expand_more"
            size: 16
            color: Theme.textFaint
        }
    }

    PopupWindow {
        id: pop

        anchor.window: tray.barWindow
        anchor.edges: Edges.Bottom
        anchor.gravity: Edges.Bottom | Edges.Left
        grabFocus: true
        // gewollt schließen (Esc, Pfeil-Chip, Weghovern, Menü geht auf); sonst holt PopoutGuard es zurück
        function close(): void {
            guard.intended = true;
            visible = false;
        }
        implicitWidth: 280
        implicitHeight: list.implicitHeight + 12
        color: "transparent"
        onVisibleChanged: {
            tray.barWindow.openMenus += visible ? 1 : -1;
            if (visible)
                Popouts.claim("tray");
            else
                Popouts.release("tray");
        }
        // nur ein Bar-Popout gleichzeitig
        Connections {
            target: Popouts
            function onCurrentChanged() {
                if (Popouts.current !== "tray" && pop.visible)
                    pop.visible = false;
            }
        }


        BackgroundEffect.blurRegion: Region {
            Region { x: 0; y: 0; width: 1; height: 1 }
            Region { item: card; radius: Theme.radiusMd }
        }

        Glass {
            id: card
            anchors.fill: parent
            strong: true
            radius: Theme.radiusMd

            // Tastatur: ↑↓ Zeilen, ←→ zwischen Symbol / Menü / Auge, Enter löst aus, Esc zu (KeyNav.qml)
            focus: true
            Keys.onPressed: e => nav.key(e)
            PopoutGuard { id: guard; popout: pop; chip: more; name: "tray" }
            KeyNav {
                id: nav
                root: card
                popout: pop
                guard: guard
                name: "tray"
                openFn: () => {
                    tray.placeUnderBar(pop, more);
                    pop.visible = true;
                }
            }

            Column {
                id: list
                x: 6
                y: 6
                width: parent.width - 12

                Repeater {
                    model: SystemTray.items

                    Rectangle {
                        id: row
                        required property SystemTrayItem modelData
                        readonly property bool hid: tray.isHidden(modelData)
                        width: list.width
                        height: 36
                        radius: Theme.radiusSm
                        color: rowHover.hovered ? Theme.raise : "transparent"
                        HoverHandler {
                            id: rowHover
                        }

                        Row {
                            x: 8
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 10
                            IconImage {
                                anchors.verticalCenter: parent.verticalCenter
                                implicitSize: 18
                                source: row.modelData.icon
                                opacity: row.hid ? 0.5 : 1
                            }
                            Txt {
                                anchors.verticalCenter: parent.verticalCenter
                                width: list.width - 80
                                text: row.modelData.tooltipTitle || row.modelData.title || row.modelData.id
                                color: row.hid ? Theme.textFaint : Theme.text
                                font.weight: Font.Normal
                            }
                        }
                        MouseArea {
                            anchors.fill: parent
                            anchors.rightMargin: row.modelData.hasMenu ? 74 : 40
                            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                            cursorShape: Qt.PointingHandCursor
                            onClicked: mouse => tray.click(row.modelData, mouse, more)
                        }
                        // Menü der App (wie Rechtsklick) – auch per Tastatur erreichbar
                        Icon {
                            visible: row.modelData.hasMenu
                            anchors.right: parent.right
                            anchors.rightMargin: 44
                            anchors.verticalCenter: parent.verticalCenter
                            name: "more_vert"
                            size: 17
                            color: Theme.textMuted
                            MouseArea {
                                anchors.fill: parent
                                anchors.margins: -8
                                cursorShape: Qt.PointingHandCursor
                                onClicked: tray.menu(row.modelData, more, true)
                            }
                        }
                        // Auge: in der Bar zeigen / ausblenden
                        Icon {
                            anchors.right: parent.right
                            anchors.rightMargin: 10
                            anchors.verticalCenter: parent.verticalCenter
                            name: row.hid ? "visibility_off" : "visibility"
                            size: 17
                            color: row.hid ? Theme.textFaint : Theme.textMuted
                            MouseArea {
                                anchors.fill: parent
                                anchors.margins: -8
                                cursorShape: Qt.PointingHandCursor
                                onClicked: tray.toggleHidden(row.modelData)
                            }
                        }
                    }
                }
            }
        }
    }
}

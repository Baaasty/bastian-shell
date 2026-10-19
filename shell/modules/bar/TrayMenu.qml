pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import qs.config
import qs.services
import qs.components

// Tray-Menü im eigenen Look (statt nativem Qt-Menü über QsMenuAnchor): Einträge aus QsMenuOpener,
// Häkchen/Radio, Icons, Trenner, deaktivierte Einträge gedämpft. Untermenüs klappen im selben Fenster auf
// (Zeile „‹ Elternname“ führt zurück; auch Esc/Rücktaste/Pfeil links). Look wie das Workspace-Menü (DesktopChips).
PopupWindow {
    id: root

    required property var barWindow
    property QsMenuHandle handle: null
    // Untermenü-Pfad: Einträge (QsMenuEntry ist selbst ein QsMenuHandle)
    property var stack: []
    readonly property QsMenuHandle current: stack.length ? stack[stack.length - 1] : handle
    property real closedAt: 0
    property QsMenuHandle lastHandle: null

    // Spalten nur, wenn ein Eintrag sie braucht (sonst bündig links wie die anderen Menüs)
    readonly property var entries: opener.children ? opener.children.values : []
    readonly property bool checkCol: entries.some(e => e && !e.isSeparator && e.buttonType !== QsMenuButtonType.None)
    readonly property bool iconCol: entries.some(e => e && !e.isSeparator && e.icon !== "")

    // kb = per Tastatur geöffnet: erste Zeile markieren, Bar behält die Tastatur bis zum Schließen
    function openFor(menuHandle, item, place, kb) {
        // Klick auf denselben Chip, der das Menü gerade geschlossen hat (Klick außerhalb) -> zu lassen
        if (Date.now() - closedAt < 300 && lastHandle === menuHandle)
            return;
        handle = menuHandle;
        stack = [];
        place(root, item);
        if (kb)
            BarKeys.kbOpen = "traymenu";
        visible = true;
        if (kb)
            kbStart.restart();
    }
    // Einträge kommen per DBusMenu etwas später
    Timer {
        id: kbStart
        interval: 150
        onTriggered: nav.start()
    }
    function close() {
        visible = false;
    }
    function enter(entry) {
        stack = stack.concat([entry]);
    }
    function back() {
        if (stack.length)
            stack = stack.slice(0, -1);
        else
            close();
    }

    anchor.window: barWindow
    anchor.edges: Edges.Bottom
    anchor.gravity: Edges.Bottom | Edges.Left
    grabFocus: true
    implicitWidth: Math.round(Math.max(220, Math.min(380, col.natural + 12)))
    implicitHeight: col.implicitHeight + 12
    color: "transparent"

    onVisibleChanged: {
        if (barWindow)
            barWindow.openMenus += visible ? 1 : -1;
        if (visible) {
            Popouts.claim("traymenu");
            emptyDelay.restart();
        } else {
            Popouts.release("traymenu");
            closedAt = Date.now();
            lastHandle = handle;
            stack = [];
        }
    }
    // App weg (Tray-Eintrag verschwunden) -> Menü zu
    onHandleChanged: if (!handle && visible) close()

    // nur ein Bar-Popout gleichzeitig
    Connections {
        target: Popouts
        function onCurrentChanged() {
            if (Popouts.current !== "traymenu" && root.visible)
                root.close();
        }
    }

    QsMenuOpener {
        id: opener
        menu: root.current
    }

    // DBusMenu lädt die Einträge nachträglich: „leer“ erst nach kurzer Zeit zeigen, nicht beim Aufklappen aufblitzen
    Timer {
        id: emptyDelay
        interval: 500
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

        focus: true
        Keys.onEscapePressed: root.close()
        Keys.onPressed: event => {
            if (event.key === Qt.Key_Backspace || event.key === Qt.Key_Left) {
                root.back();
                event.accepted = true;
                if (root.visible)
                    kbStart.restart();
                return;
            }
            // ↑↓/Tab wählen, Enter/Leertaste/→ löst aus (Untermenü auf) – KeyNav.qml
            if (event.key === Qt.Key_Right && nav.ringOn) {
                nav.activate();
                if (root.visible)
                    kbStart.restart();
                event.accepted = true;
                return;
            }
            const sub = (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) && root.visible;
            nav.key(event);
            if (sub && root.visible)
                kbStart.restart();
        }
        KeyNav {
            id: nav
            root: card
            popout: root
            name: "traymenu"
        }

        Column {
            id: col

            // breiteste Zeile -> Menübreite (220–380 px, lange Texte werden gekürzt)
            readonly property real natural: {
                let w = backRow.visible ? backRow.naturalWidth : 0;
                for (let i = 0; i < rep.count; i++) {
                    const it = rep.itemAt(i);
                    if (it)
                        w = Math.max(w, it.naturalWidth);
                }
                return w;
            }

            x: 6
            y: 6
            width: parent.width - 12

            // ---------- zurück aus dem Untermenü ----------
            Chip {
                id: backRow
                readonly property real naturalWidth: (padding + 4) * 2 + 17 + 10 + backTxt.implicitWidth
                visible: root.stack.length > 0
                width: col.width
                alignLeft: true
                height: 34
                onClicked: root.back()
                Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    name: "chevron_left"
                    size: 17
                }
                Txt {
                    id: backTxt
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.max(0, col.width - (backRow.padding + 4) * 2 - 27)
                    text: root.stack.length ? root.label(root.stack[root.stack.length - 1].text) : ""
                    color: Theme.textMuted
                }
            }
            Item {
                visible: backRow.visible
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

            // ---------- Einträge ----------
            Repeater {
                id: rep
                model: opener.children

                Item {
                    id: entry

                    required property QsMenuEntry modelData
                    readonly property bool sep: modelData.isSeparator
                    readonly property bool hasCheck: modelData.buttonType !== QsMenuButtonType.None
                    readonly property bool checked: modelData.checkState === Qt.Checked
                    // Spaltenbreiten: Häkchen 18, Icon 18, Pfeil 17 (+ je 10 Abstand)
                    readonly property real lead: (root.checkCol ? 28 : 0) + (root.iconCol ? 28 : 0)
                    readonly property real tail: modelData.hasChildren ? 27 : 0
                    readonly property real naturalWidth: sep ? 0 : (chip.padding + 4) * 2 + lead + label.implicitWidth + tail

                    width: col.width
                    height: sep ? 9 : 34

                    Rectangle {
                        visible: entry.sep
                        anchors.verticalCenter: parent.verticalCenter
                        x: 8
                        width: parent.width - 16
                        height: 1
                        color: Theme.border
                    }

                    Chip {
                        id: chip
                        visible: !entry.sep
                        anchors.fill: parent
                        alignLeft: true
                        enabled: entry.modelData.enabled
                        opacity: enabled ? 1 : 0.45
                        onClicked: mouse => {
                            if (mouse.button === Qt.MiddleButton)
                                return;
                            if (entry.modelData.hasChildren) {
                                root.enter(entry.modelData);
                            } else {
                                entry.modelData.triggered();
                                root.close();
                            }
                        }

                        // Häkchen / Radio
                        Icon {
                            visible: root.checkCol
                            anchors.verticalCenter: parent.verticalCenter
                            width: 18
                            size: 18
                            name: !entry.hasCheck ? ""
                                : entry.modelData.buttonType === QsMenuButtonType.RadioButton
                                    ? (entry.checked ? "radio_button_checked" : "radio_button_unchecked")
                                    : entry.modelData.checkState === Qt.PartiallyChecked ? "indeterminate_check_box"
                                    : entry.checked ? "check_box" : "check_box_outline_blank"
                            fill: entry.checked
                            color: entry.checked ? Theme.accentText : Theme.textFaint
                        }
                        // App-Icon des Eintrags
                        Item {
                            visible: root.iconCol
                            anchors.verticalCenter: parent.verticalCenter
                            width: 18
                            height: 18
                            IconImage {
                                anchors.fill: parent
                                visible: entry.modelData.icon !== ""
                                source: entry.modelData.icon
                                asynchronous: true
                                mipmap: true
                            }
                        }
                        Txt {
                            id: label
                            anchors.verticalCenter: parent.verticalCenter
                            width: Math.max(0, col.width - (chip.padding + 4) * 2 - entry.lead - entry.tail)
                            text: root.label(entry.modelData.text)
                            color: Theme.text
                            font.weight: Font.Normal
                        }
                        Icon {
                            visible: entry.modelData.hasChildren
                            anchors.verticalCenter: parent.verticalCenter
                            name: "chevron_right"
                            size: 17
                            color: Theme.textFaint
                        }
                    }
                }
            }

            // ---------- leer ----------
            Txt {
                visible: rep.count === 0 && !emptyDelay.running
                width: col.width
                height: 34
                leftPadding: 14
                text: "No entries"
                color: Theme.textFaint
                font.weight: Font.Normal
            }
        }
    }

    // Kürzel-Unterstrich aus DBusMenu-Texten („_Quit“ -> „Quit“, „__“ bleibt „_“)
    function label(text) {
        return (text || "").replace(/__/g, "\u0000").replace(/_/g, "").replace(/\u0000/g, "_");
    }
}

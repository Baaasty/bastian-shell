/*
 Fensterwechsler (Super+Tab), Ersatz für das KWin-TabBox-Layout bridge/kwin/desktop-switcher (Git-Tag kwin-final).
 Aussehen 1:1 von dort übernommen; dessen Aufbau stammt aus KWins Layouts "thumbnail_grid" und "big_icons":
   SPDX-FileCopyrightText: 2011 Martin Gräßlin <mgraesslin@kde.org>
   SPDX-FileCopyrightText: 2020 Chris Holland <zrenfire@gmail.com>
   SPDX-FileCopyrightText: 2023 Nate Graham <nate@kde.org>
   SPDX-License-Identifier: GPL-2.0-or-later

 Unter Hyprland: Fenster des aktuellen Desktops (alle Monitore), zuletzt benutzte zuerst, echte Vorschau per
 ScreencopyView (läuft nur, solange der Wechsler offen ist). Bedienung wie bei KWin:
   Super halten + Tab / Shift+Tab (Kürzel rufen switcher next/prev), Pfeile, Loslassen von Super = wechseln,
   Enter = wechseln, Esc = abbrechen, Klick = wechseln, Mittelklick = Fenster schließen.
 sameApp (Super+`): nur Fenster der aktiven App.
*/
import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import Quickshell.Hyprland
import qs.config
import qs.services
import qs.components

Scope {
    id: root

    property bool open: false
    property var list: []          // HyprlandToplevel in Reihenfolge
    property int current: 0
    property string screenName: Config.mainScreen

    // Liste beim Öffnen einmal festhalten (Reihenfolge ändert sich sonst beim Durchblättern)
    function collect(sameApp: bool): var {
        const app = sameApp && Hypr.activeToplevel ? Hypr.appId(Hypr.activeToplevel) : "";
        return Hypr.toplevels.values
            .filter(t => Hypr.usable(t) && Hypr.deskOf(t) === Hypr.currentDesk && (!app || Hypr.appId(t) === app))
            .sort((a, b) => (Hypr.ipc(a).focusHistoryID ?? 999) - (Hypr.ipc(b).focusHistoryID ?? 999));
    }

    function step(delta: int, sameApp: bool): void {
        if (!open) {
            list = collect(sameApp);
            if (!list.length)
                return;
            screenName = Hyprland.focusedMonitor?.name ?? Config.mainScreen;
            // wie KWin: Start beim zuletzt benutzten anderen Fenster
            current = list.length > 1 ? (delta > 0 ? 1 : list.length - 1) : 0;
            open = true;
            return;
        }
        if (list.length)
            current = (current + delta + list.length) % list.length;
    }
    function confirm(): void {
        if (!open)
            return;
        const t = list[current];
        open = false;
        list = [];
        if (t)
            Hypr.activate(t);
    }
    function cancel(): void {
        open = false;
        list = [];
    }

    IpcHandler {
        target: "switcher"
        // Super+Tab / Super+Shift+Tab
        function next(): void {
            root.step(1, false);
        }
        function prev(): void {
            root.step(-1, false);
        }
        // Super+` / Super+~ (Fenster derselben App)
        function nextApp(): void {
            root.step(1, true);
        }
        function prevApp(): void {
            root.step(-1, true);
        }
        // Loslassen von Super, falls die Taste nicht beim Wechsler ankommt (bindr in Hyprland)
        function confirm(): void {
            root.confirm();
        }
        function cancel(): void {
            root.cancel();
        }
    }

    PanelWindow {
        id: win

        screen: Quickshell.screens.find(s => s.name === root.screenName) ?? Quickshell.screens[0]
        visible: root.open
        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"
        WlrLayershell.namespace: "dock" // "dock": ohne Öffnen-Animation des Compositors
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: root.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        // nur die Karte nimmt Klicks; daneben klicken = abbrechen (FocusGrab)
        mask: Region { item: card }
        onVisibleChanged: if (visible) card.forceActiveFocus()

        HyprlandFocusGrab {
            active: root.open
            windows: [win]
            onCleared: root.cancel()
        }

        readonly property real sw: screen ? screen.width : 1920
        readonly property real sh: screen ? screen.height : 1080
        readonly property int padCard: 24
        readonly property int padItem: 12
        readonly property int gapItem: 8
        readonly property int gapRow: 12
        readonly property int iconSize: 22
        readonly property int radiusCard: Theme.radiusXl
        readonly property int radiusItem: Theme.radiusLg
        readonly property int radiusThumb: Theme.radiusMd
        readonly property int cardPad: padCard - gapItem / 2   // Zellen haben je gapItem/2 Luft rundum

        // weicher Schatten unter der Karte
        RectangularShadow {
            anchors.fill: card
            radius: card.radius
            offset.y: 8
            blur: 48
            spread: 4
            color: Theme.shadow
        }

        // deckender Grund
        Rectangle {
            id: card
            x: Math.round((win.width - width) / 2)
            y: Math.round((win.height - height) / 2)
            width: view.width + 2 * win.cardPad
            height: win.padCard + header.height + win.gapRow - win.gapItem / 2 + view.height + win.cardPad
            radius: win.radiusCard
            color: Theme.glass
            border.width: 1
            border.color: Theme.border

            // Lichtkante oben
            Rectangle {
                x: win.radiusCard
                y: 1
                width: parent.width - 2 * win.radiusCard
                height: 1
                color: Theme.innerHighlight
            }

            focus: true
            Keys.onPressed: event => {
                if (event.key === Qt.Key_Escape) {
                    root.cancel();
                } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                    root.confirm();
                } else if (event.key === Qt.Key_Backtab || (event.key === Qt.Key_Tab && (event.modifiers & Qt.ShiftModifier))) {
                    root.step(-1, false);
                } else if (event.key === Qt.Key_Tab) {
                    root.step(1, false);
                } else if (event.key === Qt.Key_Left) {
                    view.moveCurrentIndexLeft();
                } else if (event.key === Qt.Key_Right) {
                    view.moveCurrentIndexRight();
                } else if (event.key === Qt.Key_Up) {
                    view.moveCurrentIndexUp();
                } else if (event.key === Qt.Key_Down) {
                    view.moveCurrentIndexDown();
                } else {
                    return;
                }
                event.accepted = true;
            }
            // Super oder Alt (Alt+Tab) losgelassen = wechseln
            Keys.onReleased: event => {
                if (event.key === Qt.Key_Meta || event.key === Qt.Key_Super_L || event.key === Qt.Key_Super_R || event.key === Qt.Key_Alt) {
                    root.confirm();
                    event.accepted = true;
                }
            }

            // ---- Kopfzeile: Desktop links, Anzahl rechts ----
            Item {
                id: header
                x: win.padCard + win.padItem
                y: win.padCard
                width: view.width - win.gapItem - 2 * win.padItem
                height: deskLabel.implicitHeight

                Text {
                    id: deskLabel
                    anchors.left: parent.left
                    anchors.right: countLabel.left
                    anchors.rightMargin: win.padItem
                    text: (Desktops.names[Desktops.ids.indexOf(Desktops.current)] || "Windows").toUpperCase()
                    textFormat: Text.PlainText
                    elide: Text.ElideRight
                    color: Theme.textFaint
                    font.family: Theme.fontUi
                    font.pixelSize: 12
                    font.weight: Font.DemiBold
                    font.letterSpacing: 12 * 0.08
                }
                Text {
                    id: countLabel
                    anchors.right: parent.right
                    text: view.count === 1 ? "1 window" : view.count + " windows"
                    textFormat: Text.PlainText
                    color: Theme.textFaint
                    font.family: Theme.fontUi
                    font.pixelSize: 12
                    font.weight: Font.Medium
                }
            }

            // ---- Fenster-Raster ----
            GridView {
                id: view
                x: win.cardPad
                y: header.y + header.height + win.gapRow - win.gapItem / 2

                readonly property real screenFactor: win.sw / Math.max(1, win.sh)
                readonly property int thumbWidth: Math.round(Math.max(200, Math.min(280, win.sw * 0.11)))
                readonly property int thumbHeight: Math.round(thumbWidth / screenFactor)
                readonly property int itemWidth: thumbWidth + 2 * win.padItem
                readonly property int itemHeight: win.padItem + thumbHeight + win.gapRow + win.iconSize + win.padItem

                // Spalten so verteilen, dass die Reihen gleich voll sind; Rest scrollt
                readonly property int maxColumns: Math.max(1, Math.floor((win.sw * 0.9 - 2 * win.cardPad) / cellWidth))
                readonly property int maxRows: Math.max(1, Math.floor((win.sh * 0.8 - 3 * win.padCard) / cellHeight))
                readonly property int rowsNeeded: Math.max(1, Math.ceil(count / maxColumns))
                readonly property int columns: Math.max(1, Math.ceil(count / rowsNeeded))

                cellWidth: itemWidth + win.gapItem
                cellHeight: itemHeight + win.gapItem
                width: columns * cellWidth
                height: Math.min(rowsNeeded, maxRows) * cellHeight
                clip: rowsNeeded > maxRows
                interactive: false
                boundsBehavior: Flickable.StopAtBounds
                keyNavigationWraps: true

                model: root.list
                currentIndex: root.current
                onCurrentIndexChanged: {
                    if (root.current !== currentIndex)
                        root.current = currentIndex;
                    if (clip)
                        positionViewAtIndex(currentIndex, GridView.Contain);
                }

                // Auswahl selbst animieren (OutCubic), beim Öffnen ohne Gleiten
                highlightFollowsCurrentItem: false
                highlight: Item {
                    id: hl
                    readonly property Item target: view.currentItem
                    property bool ready: false
                    onTargetChanged: if (target && !ready) Qt.callLater(() => hl.ready = true)

                    x: target ? target.x + win.gapItem / 2 : 0
                    y: target ? target.y + win.gapItem / 2 : 0
                    width: view.itemWidth
                    height: view.itemHeight
                    visible: target !== null
                    Behavior on x { enabled: hl.ready; NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                    Behavior on y { enabled: hl.ready; NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }

                    // Glut-Rand + weicher Akzentgrund
                    Rectangle {
                        anchors.fill: parent
                        radius: win.radiusItem
                        color: Theme.accentSoft
                        border.width: 2
                        border.color: Theme.accent
                    }
                }

                delegate: MouseArea {
                    id: tile

                    required property var modelData
                    required property int index
                    readonly property bool current: GridView.isCurrentItem
                    readonly property bool minimized: Hypr.isMinimized(modelData)

                    width: view.cellWidth
                    height: view.cellHeight
                    hoverEnabled: true
                    acceptedButtons: Qt.LeftButton | Qt.MiddleButton

                    // Links: wechseln. Mitte: Fenster schließen
                    onClicked: mouse => {
                        if (mouse.button === Qt.MiddleButton) {
                            Hypr.close(modelData);
                            const l = root.list.slice();
                            l.splice(index, 1);
                            root.list = l;
                            if (!l.length)
                                root.cancel();
                            else
                                root.current = Math.min(root.current, l.length - 1);
                        } else {
                            root.current = index;
                            root.confirm();
                        }
                    }

                    Item {
                        x: win.gapItem / 2
                        y: win.gapItem / 2
                        width: view.itemWidth
                        height: view.itemHeight

                        Rectangle {   // Hover, leiser als die Auswahl
                            anchors.fill: parent
                            radius: win.radiusItem
                            color: Theme.raise
                            opacity: tile.containsMouse && !tile.current ? 1 : 0
                            Behavior on opacity { NumberAnimation { duration: Theme.fade; easing.type: Easing.OutCubic } }
                        }

                        // Vorschau in einer dunklen, runden Mulde
                        Rectangle {
                            id: well
                            x: win.padItem
                            y: win.padItem
                            width: view.thumbWidth
                            height: view.thumbHeight
                            radius: win.radiusThumb
                            color: Theme.bgBottom
                            border.width: 1
                            border.color: Theme.border

                            ScreencopyView {
                                id: shot
                                anchors.centerIn: parent
                                // Seitenverhältnis des Fensters behalten
                                readonly property real ar: sourceSize.width > 0 ? sourceSize.width / sourceSize.height : 16 / 9
                                readonly property real boxW: parent.width - win.radiusThumb
                                readonly property real boxH: parent.height - win.radiusThumb
                                width: ar > boxW / boxH ? boxW : boxH * ar
                                height: ar > boxW / boxH ? boxW / ar : boxH
                                captureSource: root.open ? (tile.modelData?.wayland ?? null) : null
                                live: root.open
                                opacity: tile.minimized ? 0.5 : 1
                            }
                            IconImage {   // noch keine Vorschau: großes Icon
                                anchors.centerIn: parent
                                implicitSize: 64
                                source: Hypr.iconPath(tile.modelData)
                                visible: !shot.hasContent
                            }
                        }

                        IconImage {
                            id: appIcon
                            x: win.padItem
                            y: well.y + well.height + win.gapRow
                            implicitSize: win.iconSize
                            source: Hypr.iconPath(tile.modelData)
                            opacity: tile.minimized ? 0.6 : 1
                        }
                        Text {
                            anchors.left: appIcon.right
                            anchors.leftMargin: win.gapItem
                            anchors.right: parent.right
                            anchors.rightMargin: win.padItem
                            anchors.verticalCenter: appIcon.verticalCenter
                            text: Hypr.title(tile.modelData)
                            textFormat: Text.PlainText
                            elide: Text.ElideRight
                            maximumLineCount: 1
                            font.family: Theme.fontUi
                            font.pixelSize: 14
                            font.weight: Font.Medium   // Gewicht bleibt gleich, sonst springt der Text
                            color: tile.current ? Theme.text : (tile.minimized ? Theme.textFaint : Theme.textMuted)
                            Behavior on color { ColorAnimation { duration: 120 } }
                        }
                    }
                }

                Text {
                    anchors.centerIn: parent
                    visible: view.count === 0
                    text: "No windows on this workspace"
                    textFormat: Text.PlainText
                    color: Theme.textMuted
                    font.family: Theme.fontUi
                    font.pixelSize: 14
                }
            }
        }
    }
}

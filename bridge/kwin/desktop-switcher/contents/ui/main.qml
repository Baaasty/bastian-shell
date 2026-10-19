/*
 Desktop-Fensterwechsler (KWin TabBox-Layout, Super+Tab).

 Aufbau und TabBox-API übernommen aus KWins Layouts "thumbnail_grid" und "big_icons"
 (/usr/share/kwin-wayland/tabbox/thumbnail_grid, /usr/share/kwin/tabbox/big_icons):
   SPDX-FileCopyrightText: 2011 Martin Gräßlin <mgraesslin@kde.org>
   SPDX-FileCopyrightText: 2020 Chris Holland <zrenfire@gmail.com>
   SPDX-FileCopyrightText: 2023 Nate Graham <nate@kde.org>
   SPDX-License-Identifier: GPL-2.0-or-later

 Farben und Maße kommen aus Theme.qml (erzeugt aus theme/palette.json per theme/gen/switcher.py).
 Welche Fenster drin sind (nur aktueller Desktop) und auf welchem Bildschirm, entscheidet KWin.
*/
import QtQuick
import org.kde.plasma.core as PlasmaCore
import org.kde.kirigami as Kirigami
import org.kde.kwin as KWin

KWin.TabBoxSwitcher {
    id: tabBox

    readonly property Theme theme: Theme {}

    Instantiator {
        active: tabBox.visible
        delegate: PlasmaCore.Dialog {
            location: PlasmaCore.Types.Floating
            backgroundHints: PlasmaCore.Dialog.NoBackground   // eigene Karte statt Plasma-Rahmen
            visible: true
            flags: Qt.Popup | Qt.X11BypassWindowManagerHint
            x: tabBox.screenGeometry.x + Math.round((tabBox.screenGeometry.width - root.width) / 2)
            y: tabBox.screenGeometry.y + Math.round((tabBox.screenGeometry.height - root.height) / 2)

            mainItem: FocusScope {
                id: root
                focus: true

                readonly property var t: tabBox.theme
                readonly property int shadowPad: 56          // Platz für den weichen Schatten um die Karte
                readonly property int cardPad: t.padCard - t.gapItem / 2   // Zellen haben je gapItem/2 Luft rundum

                width: card.width + 2 * shadowPad
                height: card.height + 2 * shadowPad

                // ---- Karte: weicher Schatten aus gestapelten Ringen (ohne Shader, läuft überall) ----
                Repeater {
                    model: 16
                    Rectangle {
                        required property int index
                        readonly property int spread: (index + 1) * 3
                        x: card.x - spread
                        y: card.y - spread + 8
                        width: card.width + 2 * spread
                        height: card.height + 2 * spread
                        radius: root.t.radiusCard + spread
                        color: "transparent"
                        border.width: 3
                        border.color: Qt.rgba(root.t.shadow.r, root.t.shadow.g, root.t.shadow.b,
                                              root.t.shadow.a * 0.28 * Math.pow(1 - index / 16, 2))
                    }
                }
                // fast deckender Grund (KWin blurt hinter dem Wechsler nicht)
                Rectangle {
                    anchors.fill: card
                    radius: root.t.radiusCard
                    color: root.t.card
                }

                Item {
                    id: card
                    x: root.shadowPad
                    y: root.shadowPad
                    width: view.width + 2 * root.cardPad
                    height: root.t.padCard + header.height + root.t.gapRow - root.t.gapItem / 2 + view.height + root.cardPad

                    // Hairline + Lichtkante oben
                    Rectangle {
                        anchors.fill: parent
                        radius: root.t.radiusCard
                        color: "transparent"
                        border.width: root.t.borderWidth
                        border.color: root.t.border
                    }
                    Rectangle {
                        x: root.t.radiusCard
                        y: root.t.borderWidth
                        width: parent.width - 2 * root.t.radiusCard
                        height: 1
                        color: root.t.innerHighlight
                    }

                    // ---- Kopfzeile: Desktop links, Anzahl rechts ----
                    Item {
                        id: header
                        x: root.t.padCard + root.t.padItem
                        y: root.t.padCard
                        width: view.width - root.t.gapItem - 2 * root.t.padItem
                        height: desktopLabel.implicitHeight

                        Text {
                            id: desktopLabel
                            anchors.left: parent.left
                            anchors.right: countLabel.left
                            anchors.rightMargin: root.t.padItem
                            text: ((view.currentItem && view.currentItem.desktopName) || "Windows").toUpperCase()
                            textFormat: Text.PlainText
                            elide: Text.ElideRight
                            color: root.t.textFaint
                            font.family: root.t.fontUi
                            font.pixelSize: root.t.fontLabel
                            font.weight: Font.DemiBold
                            font.letterSpacing: root.t.fontLabel * root.t.labelTracking
                        }
                        Text {
                            id: countLabel
                            anchors.right: parent.right
                            text: view.count === 1 ? "1 window" : view.count + " windows"
                            textFormat: Text.PlainText
                            color: root.t.textFaint
                            font.family: root.t.fontUi
                            font.pixelSize: root.t.fontLabel
                            font.weight: Font.Medium
                        }
                    }

                    // ---- Fenster-Raster ----
                    GridView {
                        id: view
                        x: root.cardPad
                        y: header.y + header.height + root.t.gapRow - root.t.gapItem / 2

                        readonly property rect sg: tabBox.screenGeometry
                        readonly property real screenFactor: sg.width / Math.max(1, sg.height)
                        readonly property int thumbWidth: Math.round(Math.max(200, Math.min(280, sg.width * 0.11)))
                        readonly property int thumbHeight: Math.round(thumbWidth / screenFactor)
                        readonly property int itemWidth: thumbWidth + 2 * root.t.padItem
                        readonly property int itemHeight: root.t.padItem + thumbHeight + root.t.gapRow + root.t.iconSize + root.t.padItem

                        // Spalten so verteilen, dass die Reihen gleich voll sind; Rest scrollt
                        readonly property int maxColumns: Math.max(1, Math.floor((sg.width * 0.9 - 2 * (root.shadowPad + root.cardPad)) / cellWidth))
                        readonly property int maxRows: Math.max(1, Math.floor((sg.height * 0.8 - 2 * root.shadowPad - 3 * root.t.padCard) / cellHeight))
                        readonly property int rowsNeeded: Math.max(1, Math.ceil(count / maxColumns))
                        readonly property int columns: Math.max(1, Math.ceil(count / rowsNeeded))

                        cellWidth: itemWidth + root.t.gapItem
                        cellHeight: itemHeight + root.t.gapItem
                        width: columns * cellWidth
                        height: Math.min(rowsNeeded, maxRows) * cellHeight
                        clip: rowsNeeded > maxRows
                        interactive: false
                        boundsBehavior: Flickable.StopAtBounds

                        model: tabBox.model
                        currentIndex: tabBox.currentIndex
                        focus: true
                        keyNavigationWraps: true

                        // Auswahl selbst animieren (OutCubic statt SmoothedAnimation), beim Öffnen ohne Gleiten
                        highlightFollowsCurrentItem: false
                        highlight: Item {
                            id: hl
                            readonly property Item target: view.currentItem
                            property bool ready: false
                            onTargetChanged: if (target && !ready) Qt.callLater(() => hl.ready = true)

                            x: target ? target.x + root.t.gapItem / 2 : 0
                            y: target ? target.y + root.t.gapItem / 2 : 0
                            width: view.itemWidth
                            height: view.itemHeight
                            visible: target !== null
                            Behavior on x { enabled: hl.ready; NumberAnimation { duration: root.t.moveDuration; easing.type: Easing.OutCubic } }
                            Behavior on y { enabled: hl.ready; NumberAnimation { duration: root.t.moveDuration; easing.type: Easing.OutCubic } }

                            // Glut-Schein außen, darin Glut-Rand + weicher Akzentgrund
                            Rectangle {
                                anchors.fill: parent
                                anchors.margins: -3
                                radius: root.t.radiusItem + 3
                                color: "transparent"
                                border.width: 3
                                border.color: root.t.glow
                            }
                            Rectangle {
                                anchors.fill: parent
                                radius: root.t.radiusItem
                                color: root.t.accentSoft
                                border.width: 2
                                border.color: root.t.accent
                            }
                        }

                        delegate: MouseArea {
                            id: tile
                            readonly property string desktopName: model.desktopName || ""
                            readonly property bool current: GridView.isCurrentItem

                            width: view.cellWidth
                            height: view.cellHeight
                            hoverEnabled: true
                            acceptedButtons: Qt.LeftButton | Qt.MiddleButton

                            Accessible.name: model.caption
                            Accessible.role: Accessible.ListItem

                            // Links: wechseln. Mitte: Fenster schließen
                            onClicked: mouse => {
                                if (mouse.button === Qt.MiddleButton) {
                                    if (model.closeable && typeof tabBox.model.close !== 'undefined')
                                        tabBox.model.close(index);
                                } else {
                                    tabBox.model.activate(index);
                                }
                            }

                            Item {
                                x: root.t.gapItem / 2
                                y: root.t.gapItem / 2
                                width: view.itemWidth
                                height: view.itemHeight

                                Rectangle {   // Hover, leiser als die Auswahl
                                    anchors.fill: parent
                                    radius: root.t.radiusItem
                                    color: root.t.innerHighlight
                                    opacity: tile.containsMouse && !tile.current ? 1 : 0
                                    Behavior on opacity { NumberAnimation { duration: root.t.fadeDuration; easing.type: Easing.OutCubic } }
                                }

                                // Vorschau in einer dunklen, runden Mulde
                                Rectangle {
                                    id: well
                                    x: root.t.padItem
                                    y: root.t.padItem
                                    width: view.thumbWidth
                                    height: view.thumbHeight
                                    radius: root.t.radiusThumb
                                    color: root.t.bgBottom
                                    border.width: root.t.borderWidth
                                    border.color: root.t.border

                                    KWin.WindowThumbnail {
                                        anchors.fill: parent
                                        anchors.margins: root.t.radiusThumb / 2
                                        wId: windowId
                                        visible: tabBox.compositing
                                        opacity: model.minimized ? 0.5 : 1
                                    }
                                    Kirigami.Icon {   // ohne Compositing gibt es keine Vorschau
                                        anchors.centerIn: parent
                                        width: Kirigami.Units.iconSizes.huge
                                        height: width
                                        source: model.icon
                                        visible: !tabBox.compositing
                                    }
                                }

                                Kirigami.Icon {
                                    id: appIcon
                                    x: root.t.padItem
                                    y: well.y + well.height + root.t.gapRow
                                    width: root.t.iconSize
                                    height: root.t.iconSize
                                    source: model.icon
                                    opacity: model.minimized ? 0.6 : 1
                                }
                                Text {
                                    anchors.left: appIcon.right
                                    anchors.leftMargin: root.t.gapItem
                                    anchors.right: parent.right
                                    anchors.rightMargin: root.t.padItem
                                    anchors.verticalCenter: appIcon.verticalCenter
                                    text: model.caption
                                    textFormat: Text.PlainText
                                    elide: Text.ElideRight
                                    maximumLineCount: 1
                                    font.family: root.t.fontUi
                                    font.pixelSize: root.t.fontTitle
                                    font.weight: Font.Medium   // Gewicht bleibt gleich, sonst springt der Text
                                    color: tile.current ? root.t.text : (model.minimized ? root.t.textFaint : root.t.textMuted)
                                    Behavior on color { ColorAnimation { duration: root.t.moveDuration } }
                                }
                            }
                        }

                        onCurrentIndexChanged: {
                            if (tabBox.currentIndex !== currentIndex)
                                tabBox.currentIndex = currentIndex;
                            if (clip)
                                positionViewAtIndex(currentIndex, GridView.Contain);
                        }

                        Connections {
                            target: tabBox
                            function onCurrentIndexChanged() {
                                view.currentIndex = tabBox.currentIndex;
                            }
                        }

                        Text {
                            anchors.centerIn: parent
                            visible: view.count === 0
                            text: "No windows on this desktop"
                            textFormat: Text.PlainText
                            color: root.t.textMuted
                            font.family: root.t.fontUi
                            font.pixelSize: root.t.fontTitle
                        }
                    }
                }

                // Pfeiltasten wie im Original auf dem äußeren Element (Fokus geht bei Mehrfachaufruf sonst verloren)
                Keys.onPressed: event => {
                    if (event.key === Qt.Key_Left) {
                        view.moveCurrentIndexLeft();
                    } else if (event.key === Qt.Key_Right) {
                        view.moveCurrentIndexRight();
                    } else if (event.key === Qt.Key_Up) {
                        view.moveCurrentIndexUp();
                    } else if (event.key === Qt.Key_Down) {
                        view.moveCurrentIndexDown();
                    }
                }
            }

            onSceneGraphError: () => {
                // Absichtlich leer, sonst kann QtQuick bei einem Grafik-Reset qFatal() auslösen (wie im Original).
            }
        }
    }
}

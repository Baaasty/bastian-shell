import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.services
import qs.components

// Teilen-Menü am Privatsphäre-Punkt „Bildschirm wird geteilt“ (PrivacyDot.qml), Bar-Modus „P“ / Super+Alt+P – für jede App.
// Eine Zeile je laufender Freigabe (Privacy.shareList, aus PipeWire): Symbol, App, was geteilt wird (letzte Antwort von
// share-pick), „Stop“ (scripts/share-stop: Screencast in PipeWire beenden; Discord mit Plugin sauberer über das Plugin).
// Darunter je App die gemerkte Auswahl (scripts/share-pick) mit „Forget“.
PopupWindow {
    id: pop

    property var barWindow
    property Item chip
    readonly property int cardW: 380
    property real appear: 0
    property real _closedAt: 0

    anchor.window: barWindow
    anchor.edges: Edges.Bottom
    anchor.gravity: Edges.Bottom
    grabFocus: true
    implicitWidth: cardW + 8
    implicitHeight: 420
    color: "transparent"
    visible: false
    mask: Region { item: card }

    readonly property var memApps: Object.keys(Screenshare.memory).sort()
    readonly property var rows: Privacy.shareList
    function isDiscord(row: var): bool {
        return row.app === "Discord";
    }
    function iconFor(row: var): string {
        const e = DesktopEntries.heuristicLookup(String(row.raw || row.app).toLowerCase());
        return Quickshell.iconPath(e && e.icon ? e.icon : String(row.raw).toLowerCase(), "application-x-executable");
    }
    function stopRow(row: var): void {
        // Discord: über das Plugin (Discord merkt es sauber); sonst und als Rückfall: Screencast in PipeWire beenden
        if (isDiscord(row) && Discord.viaPlugin && Discord.self.stream)
            Discord.setStream(false);
        else
            Screenshare.stop(row.node);
    }
    function stopAll(): void {
        for (const r of rows)
            stopRow(r);
    }

    // ---------- Öffnen / Schließen ----------
    function placeUnderBar(): void {
        if (!chip)
            return;
        anchor.rect.x = Math.round(chip.mapToItem(null, chip.width / 2, 0).x);
        anchor.rect.y = Theme.barMargin + Theme.barHeight + Theme.windowGap - 1;
        anchor.rect.width = 1;
        anchor.rect.height = 1;
    }
    function open(): void {
        openWith(true);
    }
    function openWith(grab: bool): void {
        if (visible)
            return;
        grabFocus = grab;
        placeUnderBar();
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

    onVisibleChanged: {
        if (barWindow && barWindow.openMenus !== undefined)
            barWindow.openMenus += visible ? 1 : -1;
        if (visible) {
            Popouts.claim("share");
            Screenshare.refresh();
            keys.forceActiveFocus();
        } else {
            Popouts.release("share");
            _closedAt = Date.now();
            appearAnim.stop();
        }
    }
    Connections {
        target: Popouts
        function onCurrentChanged() {
            if (Popouts.current !== "share" && pop.visible)
                pop.visible = false;
        }
    }
    // nichts mehr geteilt (Stopp, App zu): Menü schließt sich mit
    Connections {
        target: Privacy
        function onShareListChanged() {
            if (Privacy.shareList.length === 0 && pop.visible)
                pop.close();
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
    }

    // ---------- Karte ----------
    Glass {
        id: card
        PopoutGuard { id: guard; popout: pop; chip: pop.chip; name: "share" }
        Keys.onPressed: e => nav.key(e)
        KeyNav { id: nav; root: card; scope: keys; popout: pop; guard: guard; name: "share" }
        x: 4
        width: pop.cardW
        height: col.implicitHeight + 36
        strong: true
        opacity: pop.appear
        transform: Translate { y: (1 - pop.appear) * -6 }

        FocusScope {
            id: keys
            anchors.fill: parent
            Keys.onEscapePressed: pop.close()
        }

        Column {
            id: col
            x: 18
            y: 18
            width: card.width - 36
            spacing: 12

            Item {
                width: col.width
                height: 30
                Txt {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Screen sharing"
                    font.pixelSize: 16
                    font.weight: Font.DemiBold
                }
                Button {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    visible: pop.rows.length > 1
                    text: "Stop all"
                    icon: "stop_screen_share"
                    onClicked: {
                        pop.close();
                        pop.stopAll();
                    }
                }
            }

            // je laufende Freigabe eine Zeile
            Repeater {
                model: pop.rows
                Column {
                    id: shareRow
                    required property var modelData
                    readonly property string what: Screenshare.whatFor(modelData.raw)
                    width: col.width
                    spacing: 8

                    Item {
                        width: col.width
                        height: 36
                        Image {
                            id: appIcon
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            width: 24
                            height: 24
                            sourceSize: Qt.size(24, 24)
                            source: pop.iconFor(shareRow.modelData)
                        }
                        Column {
                            anchors.left: appIcon.right
                            anchors.leftMargin: 10
                            anchors.right: stopBtn.left
                            anchors.rightMargin: 8
                            anchors.verticalCenter: parent.verticalCenter
                            Txt {
                                width: parent.width
                                elide: Text.ElideRight
                                text: shareRow.modelData.app
                                font.weight: Font.Medium
                            }
                            Txt {
                                visible: shareRow.what !== ""
                                width: parent.width
                                elide: Text.ElideRight
                                text: "sees " + shareRow.what
                                color: Theme.textMuted
                                font.pixelSize: 12
                            }
                        }
                        Button {
                            id: stopBtn
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            visible: shareRow.modelData.stoppable || (pop.isDiscord(shareRow.modelData) && Discord.viaPlugin)
                            text: "Stop"
                            icon: "stop_screen_share"
                            onClicked: {
                                pop.close();
                                pop.stopRow(shareRow.modelData);
                            }
                        }
                    }
                }
            }

            // Quelle live wechseln geht unter Wayland nicht (docs/BACKLOG.md „Verworfen“)
            Txt {
                width: col.width
                wrapMode: Text.WordWrap
                text: "To share something else: stop and share again in the app."
                color: Theme.textFaint
                font.pixelSize: 12
            }

            Rectangle {
                width: col.width
                height: 1
                color: Theme.border
            }

            Txt {
                text: "Remembered choices"
                color: Theme.textMuted
                font.pixelSize: 13
            }
            Txt {
                visible: pop.memApps.length === 0
                text: "None – the picker asks every time."
                color: Theme.textFaint
                font.pixelSize: 13
            }
            Repeater {
                model: pop.memApps
                Item {
                    id: memRow
                    required property string modelData
                    width: col.width
                    height: 36
                    Txt {
                        anchors.left: parent.left
                        anchors.right: forgetBtn.left
                        anchors.rightMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        elide: Text.ElideRight
                        text: memRow.modelData + " → " + Screenshare.describe(Screenshare.memory[memRow.modelData])
                    }
                    Button {
                        id: forgetBtn
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Forget"
                        onClicked: Screenshare.forget(memRow.modelData)
                    }
                }
            }
        }
    }
}

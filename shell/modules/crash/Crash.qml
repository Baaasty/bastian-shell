import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.config
import qs.services
import qs.components

// Absturz-Meldungen (statt DrKonqi): Karten unten rechts auf dem Hauptmonitor, eine pro App (Crashes.items).
// Eigene Anzeigeliste wie Attention: Karten blenden erst aus und werden danach entfernt.
// Test: qs ipc --any-display -p ~/Workspace/bastian-shell/shell call crash test | testRenderer | hide
Scope {
    id: root

    readonly property int cardWidth: 400
    readonly property int maxShown: 3
    readonly property int gap: 10

    property var pendingFinish: []
    // Test: alle Karten aufgeklappt zeigen (IPC crash details)
    property bool forceExpand: false

    // { key, closing }
    ListModel {
        id: cards
    }

    Connections {
        target: Crashes
        function onItemsChanged() {
            root.sync();
        }
    }
    Component.onCompleted: sync()

    IpcHandler {
        target: "crash"
        // Fake-Absturz (Discord, Hauptprozess) – nichts am System
        function test(): void {
            Crashes.fake(false);
        }
        // Fake-Absturz eines Renderer-Prozesses (App läuft weiter)
        function testRenderer(): void {
            Crashes.fake(true);
        }
        function hide(): void {
            Crashes.hideAll();
            root.forceExpand = false;
        }
        // Details aller Karten auf-/zuklappen
        function details(): void {
            root.forceExpand = !root.forceExpand;
        }
        // Gruppen mit Zählern (ohne Stack-Traces)
        function list(): string {
            return JSON.stringify(Object.values(Crashes.groups).map(g => ({
                name: g.name, pid: g.pid, sig: g.sig, child: g.childType, running: g.running,
                today: Crashes.todayCount(g.key), shown: g.shown
            })));
        }
    }

    function sync(): void {
        const keys = Crashes.items.slice(0, root.maxShown);
        for (let i = 0; i < cards.count; i++) {
            const c = cards.get(i);
            if (!c.closing && !keys.includes(c.key))
                cards.setProperty(i, "closing", true);
        }
        // neueste oben: unbekannte vorn einfügen
        for (let j = keys.length - 1; j >= 0; j--) {
            let known = false;
            for (let i = 0; i < cards.count; i++)
                if (cards.get(i).key === keys[j] && !cards.get(i).closing)
                    known = true;
            if (!known)
                cards.insert(0, { key: keys[j], closing: false });
        }
    }

    function finishLater(key: string): void {
        pendingFinish.push(key);
        Qt.callLater(root.flushFinished);
    }
    function flushFinished(): void {
        const ks = pendingFinish;
        pendingFinish = [];
        for (const k of ks) {
            for (let i = 0; i < cards.count; i++) {
                if (cards.get(i).key === k && cards.get(i).closing) {
                    cards.remove(i);
                    break;
                }
            }
        }
    }

    Variants {
        model: Config.mainScreens

        PanelWindow {
            id: win

            required property var modelData

            screen: modelData
            visible: cards.count > 0
            anchors {
                bottom: true
                right: true
            }
            margins {
                bottom: Theme.barMargin
                right: Theme.barMargin
            }
            implicitWidth: root.cardWidth
            implicitHeight: Math.max(1, stack.implicitHeight)
            exclusionMode: ExclusionMode.Normal
            exclusiveZone: 0
            color: "transparent"
            WlrLayershell.namespace: "notification"
            WlrLayershell.layer: WlrLayer.Top

            mask: Region {
                item: stack
            }

            BackgroundEffect.blurRegion: Region {
                Region { x: 0; y: 0; width: 1; height: 1 }
                Region { item: rep.count > 0 && Theme.blurEnabled ? rep.itemAt(0) : null; radius: Theme.radiusLg }
                Region { item: rep.count > 1 && Theme.blurEnabled ? rep.itemAt(1) : null; radius: Theme.radiusLg }
                Region { item: rep.count > 2 && Theme.blurEnabled ? rep.itemAt(2) : null; radius: Theme.radiusLg }
            }

            Column {
                id: stack
                width: root.cardWidth
                spacing: root.gap

                move: Transition {
                    NumberAnimation { properties: "y"; duration: Theme.slide; easing.type: Easing.OutCubic }
                }

                Repeater {
                    id: rep
                    model: cards

                    CrashCard {
                        required property string key
                        required property bool closing

                        width: root.cardWidth
                        groupKey: key
                        isClosing: closing
                        expanded: root.forceExpand
                        onFinished: root.finishLater(key)
                    }
                }

                // ältere Abstürze warten (mehr als maxShown Apps)
                Glass {
                    readonly property int hidden: Math.max(0, Crashes.items.length - root.maxShown)

                    width: root.cardWidth
                    height: 30
                    radius: height / 2
                    visible: hidden > 0
                    Txt {
                        anchors.centerIn: parent
                        text: "+ " + parent.hidden + " more crashed  ·  dismiss all"
                        color: moreArea.containsMouse ? Theme.text : Theme.textMuted
                        font.pixelSize: 12
                    }
                    MouseArea {
                        id: moreArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Crashes.hideAll()
                    }
                }
            }
        }
    }
}

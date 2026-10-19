import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.services
import qs.components

// Claude braucht dich: Karten oben links unter der Bar (Hauptmonitor), auch über Vollbild (Overlay).
// Klickbar ist nur der Kartenstapel (Maske), die Tastatur gibt es erst nach einem Klick in eine Karte.
// Eigene Anzeigeliste statt direkt ClaudeGate.items: Karten blenden erst aus und werden danach entfernt.
Scope {
    id: root

    readonly property int cardWidth: 400
    readonly property int maxShown: 3
    readonly property int gap: 10

    property var pendingFinish: []

    // { gid, closing }
    ListModel {
        id: cards
    }

    Connections {
        target: ClaudeGate
        function onItemsChanged() {
            root.sync();
        }
    }
    Component.onCompleted: sync()

    function sync(): void {
        const ids = ClaudeGate.items.map(e => e.id);
        for (let i = 0; i < cards.count; i++) {
            const c = cards.get(i);
            if (!c.closing && !ids.includes(c.gid))
                cards.setProperty(i, "closing", true);
        }
        for (const id of ids) {
            let known = false;
            for (let i = 0; i < cards.count; i++)
                if (cards.get(i).gid === id)
                    known = true;
            if (!known)
                cards.append({ gid: id, closing: false });
        }
    }

    // nach dem Ausblenden entfernen – gesammelt, nie im Handler der Karte selbst
    function finishLater(gid: string): void {
        pendingFinish.push(gid);
        Qt.callLater(root.flushFinished);
    }
    function flushFinished(): void {
        const ids = pendingFinish;
        pendingFinish = [];
        for (const gid of ids) {
            for (let i = 0; i < cards.count; i++) {
                if (cards.get(i).gid === gid) {
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

            // Tastatur nur nach einem Klick in eine Karte (sonst kein Fokusklau beim Aufpoppen)
            property bool kbWanted: false
            // jemand tippt in ein Kartenfeld („Other…“, Notiz): Tastatur nicht wegnehmen
            property bool typing: false
            property real now: Date.now()
            property var blurItems: []
            readonly property int openCount: ClaudeGate.count

            screen: modelData
            visible: cards.count > 0
            anchors {
                top: true
                left: true
            }
            margins {
                top: Theme.barMargin + Theme.barHeight + Theme.windowGap
                left: 0
            }
            implicitWidth: root.cardWidth + Theme.barMargin * 2
            implicitHeight: Math.max(1, stack.height)
            exclusionMode: ExclusionMode.Ignore
            color: "transparent"
            WlrLayershell.namespace: "notification"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: kbWanted && openCount > 0 ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

            mask: Region {
                item: stack
            }

            BackgroundEffect.blurRegion: Region {
                Region { x: 0; y: 0; width: 1; height: 1 }
                Region { item: win.blurItems[0] ?? null; radius: Theme.radiusLg }
                Region { item: win.blurItems[1] ?? null; radius: Theme.radiusLg }
                Region { item: win.blurItems[2] ?? null; radius: Theme.radiusLg }
                Region { item: more.visible ? more : null; radius: more.radius }
            }

            onOpenCountChanged: if (openCount === 0) {
                kbWanted = false;
                typing = false;
            }

            function queueLayout(): void {
                Qt.callLater(win.relayout);
            }
            // wer ist im Blick (die neuesten maxShown), wer bekommt Blur
            function relayout(): void {
                let open = 0;
                const blur = [];
                for (let i = rep.count - 1; i >= 0; i--) {
                    const c = rep.itemAt(i);
                    if (!c)
                        continue;
                    if (!c.closing) {
                        c.inView = open < root.maxShown;
                        open++;
                    }
                }
                for (let i = 0; i < rep.count; i++) {
                    const c = rep.itemAt(i);
                    if (c && c.blurOn && blur.length < 3)
                        blur.push(c);
                }
                blurItems = blur;
            }

            // „vor 12 s“ mitzählen
            Timer {
                interval: 1000
                repeat: true
                running: win.visible
                triggeredOnStart: true
                onTriggered: win.now = Date.now()
            }

            // Maus lange weg: Tastatur zurück an das Fenster darunter
            HoverHandler {
                id: winHover
            }
            Timer {
                running: win.kbWanted && !winHover.hovered && !win.typing
                interval: 1500
                onTriggered: win.kbWanted = false
            }

            Item {
                id: keys
                focus: true
                Keys.onEscapePressed: win.kbWanted = false
                // Enter = Hauptknopf der neuesten Karte (Allow bzw. Send)
                Keys.onPressed: event => {
                    if (event.key !== Qt.Key_Return && event.key !== Qt.Key_Enter)
                        return;
                    event.accepted = true;
                    for (let i = rep.count - 1; i >= 0; i--) {
                        const c = rep.itemAt(i);
                        if (c && c.shown) {
                            c.primaryAction();
                            return;
                        }
                    }
                }
            }

            Column {
                id: stack
                x: Theme.barMargin
                width: root.cardWidth
                spacing: root.gap

                move: Transition {
                    NumberAnimation { properties: "y"; duration: Theme.slide; easing.type: Easing.OutCubic }
                }

                Repeater {
                    id: rep
                    model: cards
                    onItemAdded: win.queueLayout()
                    onItemRemoved: win.queueLayout()

                    AttentionCard {
                        required property string gid
                        required property bool closing
                        required property int index

                        width: root.cardWidth
                        entryId: gid
                        isClosing: closing
                        now: win.now
                        onFinished: root.finishLater(gid)
                        onTouched: win.kbWanted = true
                        onTypingChanged: win.typing = typing
                        onKeysBack: keys.forceActiveFocus()
                        onBlurOnChanged: win.queueLayout()
                        onShownChanged: win.queueLayout()
                        onIsClosingChanged: win.queueLayout()
                    }
                }

                // „+ n more“: ältere Rückfragen warten (in VS Code oder hier, sobald oben eine weg ist)
                Glass {
                    id: more

                    readonly property int hidden: Math.max(0, ClaudeGate.count - root.maxShown)

                    width: root.cardWidth
                    height: 30
                    radius: height / 2
                    visible: hidden > 0
                    Txt {
                        anchors.centerIn: parent
                        text: "+ " + more.hidden + " more waiting"
                        color: Theme.textMuted
                        font.pixelSize: 12
                    }
                }
            }
        }
    }
}

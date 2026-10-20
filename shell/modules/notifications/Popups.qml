import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Widgets
import Quickshell.Services.Notifications
import qs.config
import qs.services
import qs.components

// Popups oben rechts unter der Bar.
// Eigene Anzeigeliste statt direkt Notifs.popups: Karten animieren erst raus und werden danach entfernt.
// Jede Karte merkt sich ihren Inhalt (Snapshot), damit beim Ausblenden nichts auf eine schon
// zerstörte Notification zugreift. Höchstens 4 Karten, Rest als "+ n weitere".
// Gleiche Meldungen (App + Titel) werden, solange die Karte noch steht, zu "×n" zusammengefasst.
// Ruhezeit-Hinweis: QuietSummary.
Scope {
    id: root

    readonly property int maxShown: 4
    readonly property int gap: 10
    readonly property int shift: 16          // px, so weit gleiten Karten von rechts rein/raus
    readonly property int inMs: Theme.fade + 30
    readonly property int outMs: Theme.fade + 10
    readonly property int cardWidth: 440

    // Hover: solange die Maus auf IRGENDEINER Karte liegt, stehen alle Auto-Timeouts still, nichts wird zusammengefasst
    // oder aus dem Blick geschoben (Stapel bleibt stabil). Beim Loslassen läuft jede Karte mit ihrer Restzeit weiter,
    // mindestens minLeftMs, damit nichts sofort verschwindet.
    property int hoverN: 0
    property bool hoverForce: false          // Test: Hover vortäuschen (IPC popups fakeHover)
    readonly property bool anyHover: hoverN > 0 || hoverForce || kbOn

    // ---------- Tastatur (AP 22): Super+Alt+Z oder Bar-Modus Z ----------
    // ↑↓ Karte wählen, Enter öffnen, 1–3 Knöpfe der Meldung, X wegklicken (bleibt im Verlauf), Entf löschen
    // (auch aus dem Verlauf, wie das ✕ im Dashboard), Esc zu.
    // Solange der Modus läuft, stehen alle Auto-Timeouts (wie beim Hovern).
    property bool kbOn: false
    property int kbSel: -1       // markierte Karte (Index in rep, -1 = neueste)
    // offene Karten von oben nach unten (Repeater-Reihenfolge = Bildschirm-Reihenfolge, neueste unten)
    function openCards(rp) {
        const out = [];
        if (!rp)
            return out;
        for (let i = 0; i < rp.count; i++) {
            const c = rp.itemAt(i);
            if (c && c.shown)
                out.push(c);
        }
        return out;
    }
    function newest() {
        for (let i = entries.count - 1; i >= 0; i--) {
            const e = entries.get(i);
            if (!e.closing && live[e.key])
                return live[e.key];
        }
        return null;
    }
    // Kürzel Super+Alt+X: neueste Meldung wegklicken (bleibt im Verlauf)
    function dismissNewest(): bool {
        const n = newest();
        if (!n)
            return false;
        Notifs.close(n);
        return true;
    }
    Connections {
        target: BarKeys
        function onNotifsRequested() {
            if (root.kbOn) {
                root.kbOn = false;
            } else if (root.newest()) {
                root.kbSel = -1;
                root.kbOn = true;
            } else {
                BarKeys.flash("No notifications · history is in the dashboard");
            }
        }
    }
    readonly property int minLeftMs: 1500
    readonly property int tickMs: 100

    // key → Notification (lebendes Objekt; ist es zerstört, liest es sich als null)
    property var live: ({})
    property int nextKey: 0
    property var pendingFinish: []

    // Anzeigeliste: { key, closing, count, rev }
    ListModel {
        id: entries
    }

    Connections {
        target: Notifs
        function onPopupsChanged() {
            root.sync();
        }
    }
    Component.onCompleted: sync()

    QuietSummary {}

    // Test ohne Maus: Hover vortäuschen und Restzeiten ansehen (keine Inhalte)
    IpcHandler {
        target: "popups"
        function fakeHover(on: bool): void {
            root.hoverForce = on;
        }
        // Tastatur-Modus an/aus (wie Super+Alt+Z)
        function keys(): void {
            BarKeys.notifsRequested();
        }
        function dismissNewest(): string {
            return root.dismissNewest() ? "ok" : "none";
        }
        function state(): string {
            const out = [];
            for (let i = 0; i < entries.count; i++) {
                const e = entries.get(i);
                out.push({ key: e.key, closing: e.closing, count: e.count });
            }
            return JSON.stringify({ anyHover: root.anyHover, hoverN: root.hoverN, kbOn: root.kbOn, cards: out });
        }
    }

    // Notifs.popups → Anzeigeliste abgleichen (ohne Rekursion, falls dismissPopup erneut auslöst)
    property bool syncing: false
    property bool syncAgain: false
    function sync() {
        if (syncing) {
            syncAgain = true;
            return;
        }
        syncing = true;
        do {
            syncAgain = false;
            syncOnce();
        } while (syncAgain)
        syncing = false;
    }

    function syncOnce() {
        const cur = Notifs.popups;
        const drop = [];

        // weg aus popups → Karte animiert raus
        for (let i = 0; i < entries.count; i++) {
            const e = entries.get(i);
            if (!e.closing && !cur.includes(live[e.key]))
                entries.setProperty(i, "closing", true);
        }

        // neu dazu
        for (const n of cur) {
            if (!n || hasLive(n))
                continue;
            const dup = findDuplicate(n);
            if (dup >= 0) {
                const e = entries.get(dup);
                const old = live[e.key];
                live[e.key] = n;
                entries.setProperty(dup, "count", e.count + 1);
                entries.setProperty(dup, "rev", e.rev + 1);
                if (old)
                    drop.push(old);
            } else {
                const k = nextKey++;
                live[k] = n;
                entries.append({ key: k, closing: false, count: 1, rev: 0 });
            }
        }

        // zusammengefasste Vorgänger still aus popups nehmen (bleiben im Verlauf)
        for (const o of drop)
            Notifs.dismissPopup(o);
    }

    function hasLive(n) {
        for (let i = 0; i < entries.count; i++) {
            const e = entries.get(i);
            if (!e.closing && live[e.key] === n)
                return true;
        }
        return false;
    }

    // gleiche App + gleicher Titel → eine Karte mit dem neuesten Text; Dringendes bleibt einzeln
    function findDuplicate(n) {
        // beim Hovern nichts umbauen: neue Meldung bekommt eine eigene Karte
        if (anyHover || Notifs.isUrgent(n))
            return -1;
        for (let i = entries.count - 1; i >= 0; i--) {
            const e = entries.get(i);
            const o = live[e.key];
            if (e.closing || !o || Notifs.isUrgent(o))
                continue;
            if (o.appName === n.appName && o.summary === n.summary)
                return i;
        }
        return -1;
    }

    // nach der Ausblend-Animation wirklich entfernen – gesammelt und verzögert,
    // damit nie mitten in einem Abgleich oder im Handler der Karte selbst gelöscht wird
    function finishLater(key) {
        pendingFinish.push(key);
        Qt.callLater(root.flushFinished);
    }
    function flushFinished() {
        const keys = pendingFinish;
        pendingFinish = [];
        for (const key of keys) {
            for (let i = 0; i < entries.count; i++) {
                if (entries.get(i).key === key) {
                    entries.remove(i);
                    break;
                }
            }
            delete live[key];
        }
    }

    function dismissAll() {
        const all = [];
        for (let i = 0; i < entries.count; i++) {
            const e = entries.get(i);
            if (!e.closing && live[e.key])
                all.push(live[e.key]);
        }
        for (const n of all)
            Notifs.close(n);
    }

    Variants {
        model: Config.mainScreens

        PanelWindow {
            id: win

            required property var modelData

            property int hiddenCount: 0
            property var blurItems: []
            property real targetH: 0
            property real winH: 1

            screen: modelData
            visible: entries.count > 0
            anchors {
                top: true
                right: true
            }
            // rechts kein Fensterrand: Karten gleiten vom Bildschirmrand rein, den Abstand hält stack
            margins {
                top: Theme.barMargin + Theme.barHeight + Theme.windowGap
                right: 0
            }
            implicitWidth: root.cardWidth + Theme.barMargin
            implicitHeight: Math.max(1, winH)
            exclusionMode: ExclusionMode.Ignore
            color: "transparent"
            WlrLayershell.namespace: "notification"
            WlrLayershell.layer: root.kbOn ? WlrLayer.Overlay : WlrLayer.Top
            WlrLayershell.keyboardFocus: root.kbOn ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

            // ---------- Tastatur ----------
            readonly property var cards: { root.kbOn; root.kbSel; entries.count; return root.openCards(rep); }
            function selCard() {
                const list = root.openCards(rep);
                if (!list.length)
                    return null;
                const i = root.kbSel < 0 || root.kbSel >= list.length ? list.length - 1 : root.kbSel;
                return list[i];
            }
            function kbKey(e) {
                const list = root.openCards(rep);
                if (!list.length) {
                    root.kbOn = false;
                    return;
                }
                let i = root.kbSel < 0 || root.kbSel >= list.length ? list.length - 1 : root.kbSel;
                const c = list[i];
                const k = e.key;
                if (k === Qt.Key_Escape) {
                    root.kbOn = false;
                } else if (k === Qt.Key_Up || k === Qt.Key_K || (k === Qt.Key_Tab && (e.modifiers & Qt.ShiftModifier)) || k === Qt.Key_Backtab) {
                    root.kbSel = Math.max(0, i - 1);
                } else if (k === Qt.Key_Down || k === Qt.Key_J || k === Qt.Key_Tab) {
                    root.kbSel = Math.min(list.length - 1, i + 1);
                } else if (e.isAutoRepeat) {
                    return;
                } else if (k === Qt.Key_Return || k === Qt.Key_Enter || k === Qt.Key_Space) {
                    c.openIt();
                    root.kbOn = false;
                } else if (k === Qt.Key_Delete || k === Qt.Key_X || k === Qt.Key_Backspace) {
                    if (k === Qt.Key_X)
                        Notifs.close(c.n);
                    else
                        Notifs.deletePopup(c.n);
                    root.kbSel = Math.min(i, list.length - 2);
                    if (list.length <= 1)
                        root.kbOn = false;
                } else if (k >= Qt.Key_1 && k <= Qt.Key_9) {
                    const d = k - Qt.Key_1;
                    if (c.sActions[d]) {
                        const n = c.n;
                        c.act(c.sActions[d].id);
                        Notifs.close(n);
                    }
                } else if (k === Qt.Key_A && (e.modifiers & Qt.ShiftModifier)) {
                    root.dismissAll();
                    root.kbOn = false;
                }
            }
            Item {
                id: kbItem
                focus: root.kbOn
                Keys.onPressed: e => {
                    win.kbKey(e);
                    e.accepted = true;
                }
            }
            property bool kbGrabReady: false
            Timer {
                id: kbGrabDelay
                interval: 250
                onTriggered: win.kbGrabReady = root.kbOn
            }
            Connections {
                target: root
                function onKbOnChanged() {
                    win.kbGrabReady = false;
                    if (root.kbOn) {
                        kbGrabDelay.restart();
                        kbItem.forceActiveFocus();
                    }
                }
            }
            HyprlandFocusGrab {
                active: root.kbOn && win.kbGrabReady
                windows: [win]
                onCleared: root.kbOn = false
            }

            // Blur pro Karte (feste Plätze, Region.regions ist nicht dynamisch zuweisbar).
            // Lücken bleiben frei; beim Ein-/Ausblenden gibt es Blur erst ab 40 % Deckkraft.
            BackgroundEffect.blurRegion: Region {
                Region { x: 0; y: 0; width: 1; height: 1 }
                Region { item: win.blurItems[0] ?? null; radius: Theme.radiusLg }
                Region { item: win.blurItems[1] ?? null; radius: Theme.radiusLg }
                Region { item: win.blurItems[2] ?? null; radius: Theme.radiusLg }
                Region { item: win.blurItems[3] ?? null; radius: Theme.radiusLg }
                Region { item: win.blurItems[4] ?? null; radius: Theme.radiusLg }
                Region { item: win.blurItems[5] ?? null; radius: Theme.radiusLg }
                Region { item: win.blurItems[6] ?? null; radius: Theme.radiusLg }
                Region { item: win.blurItems[7] ?? null; radius: Theme.radiusLg }
                Region { item: more.blurOn ? more : null; radius: more.radius }
            }

            function queueLayout() {
                Qt.callLater(win.relayout);
            }

            // wer ist im Blick, wohin rückt wer, wie hoch ist das Fenster, wer bekommt Blur
            function relayout() {
                const cards = [];
                for (let i = 0; i < rep.count; i++) {
                    const c = rep.itemAt(i);
                    if (c)
                        cards.push(c);
                }

                // die neuesten maxShown offenen Karten sind im Blick; beim Hovern gilt die Grenze nicht:
                // wer schon im Blick ist, bleibt, wer neu dazukommt, reiht sich ein, versteckte bleiben versteckt
                let open = 0;
                let hidden = 0;
                for (let i = cards.length - 1; i >= 0; i--) {
                    const c = cards[i];
                    if (c.closing)
                        continue;
                    c.inView = root.anyHover ? (c.inView || !c.evaluated) : open < root.maxShown;
                    c.evaluated = true;
                    if (!c.inView)
                        hidden++;
                    open++;
                }
                hiddenCount = hidden;

                let y = 0;
                const blur = [];
                for (const c of cards) {
                    if (!c.occupies)
                        continue;
                    // noch nicht platziert: springt hin (Behavior aus), danach gleitet es
                    c.slotY = y;
                    c.placed = true;
                    y += c.height + root.gap;
                    if (c.blurOn && blur.length < 8)
                        blur.push(c);
                }
                more.slotY = y;
                if (hiddenCount > 0) {
                    more.placed = true;
                    y += more.height + root.gap;
                }
                blurItems = blur;

                // wachsen sofort, schrumpfen erst wenn alles nachgerückt ist (sonst abgeschnitten)
                targetH = Math.max(0, y - root.gap);
                if (targetH >= winH) {
                    shrink.stop();
                    winH = targetH;
                } else {
                    shrink.restart();
                }
            }

            Connections {
                target: root
                function onAnyHoverChanged() {
                    win.queueLayout();
                }
            }

            Timer {
                id: shrink
                interval: Theme.slide + 40
                onTriggered: win.winH = win.targetH
            }

            Item {
                id: stack
                width: root.cardWidth
                height: win.height

                Repeater {
                    id: rep
                    model: entries
                    onItemAdded: win.queueLayout()
                    onItemRemoved: win.queueLayout()

                    Glass {
                        id: card

                        required property int key
                        required property bool closing
                        required property int count
                        required property int rev

                        // lebendes Objekt; rev ändert sich, wenn eine gleiche Meldung es ablöst
                        readonly property var n: {
                            rev;
                            return root.live[key] ?? null;
                        }

                        // Snapshot – angezeigt wird nur daraus
                        property string sApp: ""
                        property string sSummary: ""
                        property string sBody: ""
                        property string sImage: ""
                        property string sIcon: ""
                        property string sDesktop: ""
                        property string sKind: ""
                        property string sFile: ""
                        property bool sUrgent: false
                        property var sActions: []

                        function snap() {
                            const o = card.n;
                            if (!o || card.closing)
                                return;
                            sApp = o.appName;
                            sSummary = o.summary;
                            sBody = o.body;
                            sImage = o.image || "";
                            sIcon = o.appIcon || "";
                            sDesktop = o.desktopEntry || "";
                            sFile = Notifs.fileOf(o);
                            sUrgent = Notifs.isUrgent(o);
                            sKind = Notifs.kindOf(o);
                            sActions = o.actions.filter(a => a.identifier !== "default").map(a => ({ id: a.identifier, text: a.text }));
                        }
                        function act(id) {
                            const o = card.n;
                            if (!o || card.closing)
                                return;
                            const a = o.actions.find(x => x.identifier === id);
                            if (a)
                                a.invoke();
                        }

                        readonly property bool urgent: sUrgent

                        // Layout-Zustand (setzt win.relayout)
                        property bool inView: false
                        property bool evaluated: false     // schon einmal von relayout einsortiert
                        property int leftMs: Notifs.popupMs   // Restzeit bis zum Auto-Ausblenden
                        property real slotY: 0
                        property bool placed: false
                        readonly property bool shown: inView && !closing
                        readonly property bool occupies: shown || exitAnim.running
                        readonly property bool blurOn: occupies && opacity >= 0.4

                        // Tastatur-Modus: diese Karte ist markiert (Rahmen + Tastenzeile unten)
                        readonly property bool kbMark: root.kbOn && win.cards && win.selCard() === card
                        readonly property int kbH: kbMark ? 30 : 0
                        function openIt() {
                            const o = card.n;
                            // Screenshot/Aufnahme: Klick öffnet die Datei selbst
                            if (card.sFile) {
                                Notifs.openFile(card.sFile);
                                Notifs.close(o);
                                return;
                            }
                            card.act("default");
                            // Wayland lässt die App sich nicht selbst nach vorn holen, also macht es die Shell
                            Parked.focus(card.sDesktop || card.sApp);
                            Notifs.close(o);
                        }

                        width: stack.width
                        height: content.implicitHeight + 28 + kbH
                        x: root.shift
                        y: slotY
                        opacity: 0
                        visible: occupies
                        strong: urgent
                        border.color: urgent ? Qt.alpha(Theme.accent, 0.65) : Theme.border

                        Behavior on y {
                            enabled: card.placed
                            NumberAnimation { duration: Theme.slide; easing.type: Easing.OutCubic }
                        }

                        Component.onCompleted: snap()
                        onNChanged: snap()
                        onRevChanged: leftMs = Notifs.popupMs
                        onOccupiesChanged: win.queueLayout()
                        onBlurOnChanged: win.queueLayout()
                        onHeightChanged: win.queueLayout()
                        onClosingChanged: {
                            win.queueLayout();
                            // nie sichtbar gewesen (hinter "+ n weitere"): direkt weg
                            if (closing && !inView && !exitAnim.running)
                                root.finishLater(key);
                        }
                        onShownChanged: {
                            if (shown) {
                                exitAnim.stop();
                                enterAnim.start();
                            } else {
                                enterAnim.stop();
                                if (opacity > 0)
                                    exitAnim.start();
                                else
                                    exitDone();
                            }
                        }
                        function exitDone() {
                            placed = false;
                            x = root.shift;
                            if (closing)
                                root.finishLater(key);
                        }

                        Connections {
                            target: card.closing ? null : card.n
                            ignoreUnknownSignals: true
                            function onAppNameChanged() { card.snap(); }
                            function onSummaryChanged() { card.snap(); }
                            function onBodyChanged() { card.snap(); }
                            function onImageChanged() { card.snap(); }
                            function onAppIconChanged() { card.snap(); }
                            function onDesktopEntryChanged() { card.snap(); }
                            function onUrgencyChanged() { card.snap(); }
                            function onActionsChanged() { card.snap(); }
                        }

                        ParallelAnimation {
                            id: enterAnim
                            NumberAnimation { target: card; property: "opacity"; to: 1; duration: root.inMs; easing.type: Easing.OutCubic }
                            NumberAnimation { target: card; property: "x"; to: 0; duration: root.inMs; easing.type: Easing.OutCubic }
                        }
                        ParallelAnimation {
                            id: exitAnim
                            NumberAnimation { target: card; property: "opacity"; to: 0; duration: root.outMs; easing.type: Easing.InCubic }
                            NumberAnimation { target: card; property: "x"; to: root.shift; duration: root.outMs; easing.type: Easing.InCubic }
                            onFinished: card.exitDone()
                        }

                        // normal: nach 6 s weg (bleibt im Verlauf). Läuft in 100-ms-Schritten, damit die Restzeit stehen
                        // bleibt, solange irgendeine Karte gehovert wird (root.anyHover); dringende bleiben bis Klick
                        Timer {
                            id: life
                            running: !card.closing && !card.urgent && !root.anyHover
                            interval: root.tickMs
                            repeat: true
                            onTriggered: {
                                card.leftMs -= root.tickMs;
                                if (card.leftMs > 0)
                                    return;
                                if (card.n)
                                    Notifs.dismissPopup(card.n);
                                else
                                    root.finishLater(card.key);
                            }
                        }
                        // Maus weg: mindestens minLeftMs Restzeit, damit nichts abrupt verschwindet
                        Connections {
                            target: root
                            function onAnyHoverChanged() {
                                if (!root.anyHover)
                                    card.leftMs = Math.max(card.leftMs, root.minLeftMs);
                            }
                        }
                        property bool hv: hover.hovered
                        onHvChanged: root.hoverN += hv ? 1 : -1
                        Component.onDestruction: if (hv) root.hoverN--
                        HoverHandler {
                            id: hover
                        }
                        MouseArea {
                            anchors.fill: parent
                            enabled: !card.closing
                            cursorShape: Qt.PointingHandCursor
                            onClicked: card.openIt()
                        }

                        Row {
                            id: content
                            x: 16
                            y: 14
                            width: parent.width - 32
                            spacing: 12

                            NotifIcon {
                                size: 36
                                kind: card.sKind
                                // Datei-Vorschau (Snip) zählt nicht als Bild: dort gilt das Symbol
                                image: card.sFile ? "" : card.sImage
                                appIcon: card.sIcon
                                desktop: card.sDesktop
                            }

                            Column {
                                width: parent.width - 48
                                spacing: 2

                                Row {
                                    width: parent.width
                                    Txt {
                                        width: parent.width - when.width
                                        text: card.sApp + (card.urgent ? " · stays until clicked" : "")
                                        color: Theme.textFaint
                                        font.pixelSize: 12
                                        font.weight: Font.Normal
                                    }
                                    MonoTxt {
                                        id: when
                                        text: card.count > 1 ? "×" + card.count + " · now" : "now"
                                        opacity: hover.hovered ? 0 : 1
                                        color: card.count > 1 ? Theme.accentText : Theme.textFaint
                                        font.pixelSize: 11
                                    }
                                }
                                Txt {
                                    width: parent.width
                                    text: card.sSummary
                                    font.pixelSize: 14
                                    font.weight: Font.DemiBold
                                }
                                Text {
                                    width: parent.width
                                    visible: text !== ""
                                    text: card.sBody
                                    textFormat: Text.PlainText
                                    wrapMode: Text.WordWrap
                                    maximumLineCount: 4
                                    elide: Text.ElideRight
                                    color: Theme.textMuted
                                    font.family: Theme.fontUi
                                    font.pixelSize: 14
                                    lineHeight: 1.2
                                }
                                Row {
                                    topPadding: 8
                                    spacing: 8
                                    visible: card.sActions.length > 0
                                    Repeater {
                                        model: card.sActions
                                        Button {
                                            required property var modelData
                                            required property int index
                                            primary: index === 0
                                            text: modelData.text
                                            onClicked: {
                                                const o = card.n;
                                                card.act(modelData.id);
                                                Notifs.close(o);
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // Tastatur-Modus: Rahmen + Tastenzeile
                        Rectangle {
                            anchors.fill: parent
                            visible: card.kbMark
                            color: "transparent"
                            radius: card.radius
                            border.width: 2
                            border.color: Theme.accent
                        }
                        Row {
                            visible: card.kbMark
                            x: 16 + 48
                            y: parent.height - 30
                            height: 22
                            spacing: 12
                            Repeater {
                                model: [["Enter", "open"]].concat(card.sActions.length ? [["1–" + card.sActions.length, "buttons"]] : [])
                                    .concat([["X", "dismiss"], ["Del", "delete"], ["↑↓", "select"], ["Esc", "close"]])
                                Row {
                                    required property var modelData
                                    spacing: 4
                                    MonoTxt {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: modelData[0]
                                        font.pixelSize: 11
                                        font.weight: Font.Bold
                                        color: Theme.accentText
                                    }
                                    Txt {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: modelData[1]
                                        color: Theme.textFaint
                                        font.pixelSize: 11
                                        font.weight: Font.Normal
                                    }
                                }
                            }
                        }

                        // schließen (nur beim Überfahren)
                        Icon {
                            anchors.top: parent.top
                            anchors.right: parent.right
                            anchors.margins: 10
                            visible: hover.hovered && !card.closing
                            name: "close"
                            size: 16
                            color: closeArea.containsMouse ? Theme.text : Theme.textFaint
                            MouseArea {
                                id: closeArea
                                anchors.fill: parent
                                anchors.margins: -6
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: Notifs.close(card.n)
                            }
                        }
                    }
                }

                // "+ n weitere" unter den Karten – Klick schließt alle
                Glass {
                    id: more

                    property real slotY: 0
                    property bool placed: false
                    property int shownCount: 0
                    readonly property bool active: win.hiddenCount > 0
                    readonly property bool blurOn: visible && opacity >= 0.4

                    width: stack.width
                    height: 34
                    radius: height / 2
                    y: slotY
                    opacity: active ? 1 : 0
                    visible: opacity > 0
                    onActiveChanged: {
                        if (!active)
                            placed = false;
                    }

                    Behavior on y {
                        enabled: more.placed
                        NumberAnimation { duration: Theme.slide; easing.type: Easing.OutCubic }
                    }
                    Behavior on opacity {
                        NumberAnimation { duration: more.active ? root.inMs : root.outMs; easing.type: more.active ? Easing.OutCubic : Easing.InCubic }
                    }

                    // Zahl beim Ausblenden nicht auf 0 springen lassen
                    Connections {
                        target: win
                        function onHiddenCountChanged() {
                            if (win.hiddenCount > 0)
                                more.shownCount = win.hiddenCount;
                        }
                    }

                    Txt {
                        anchors.centerIn: parent
                        text: "+ " + more.shownCount + " more  ·  close all"
                        color: moreArea.containsMouse ? Theme.text : Theme.textMuted
                        font.pixelSize: 12
                        Behavior on color { ColorAnimation { duration: Theme.fade } }
                    }
                    MouseArea {
                        id: moreArea
                        anchors.fill: parent
                        enabled: more.active
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.dismissAll()
                    }
                }
            }
        }
    }
}

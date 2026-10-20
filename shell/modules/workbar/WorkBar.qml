import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Widgets
import qs.config
import qs.services
import qs.components
import qs.modules.bar

// Arbeitsplatz-Leiste unten links: Desktops (App-Icons oder Mini-Vorschau), + / Vorlagen, offene Apps.
// Weicht wie die Top-Bar Fenstern aus, die unten hineinragen; Hover am unteren Rand holt sie zurück.
Scope {
    id: root


    readonly property var screens: Quickshell.screens
    readonly property real vx: Math.min(...screens.map(s => s.x))
    readonly property real vy: Math.min(...screens.map(s => s.y))
    readonly property real vw: Math.max(...screens.map(s => s.x + s.width)) - vx
    readonly property real vh: Math.max(...screens.map(s => s.y + s.height)) - vy

    // alle Fenster aller Desktops kommen aus Hyprland (Hypr.toplevels); version zählt bei Änderungen hoch
    readonly property int version: Hypr.version

    function windowsOn(desktopId, v) {
        return Hypr.windowsOnDesk(Number(desktopId));
    }

    // Hintergrund-Apps: sichtbar = auf dem aktuellen Desktop und nicht minimiert/weggeräumt
    function findApp(part) {
        return Hypr.toplevels.values.find(t => Hypr.appId(t).toLowerCase().indexOf(part) >= 0) ?? null;
    }
    function isOut(part, v) {
        const t = findApp(part);
        return !!t && !Hypr.isMinimized(t) && !Hypr.isStashed(t) && Hypr.deskOf(t) === Hypr.currentDesk;
    }
    onVersionChanged: {
        const o = {};
        for (const p of Parked.apps)
            o[p] = isOut(p, version);
        Parked.out = o;
    }

    // Hintergrund-App auf diesen Desktop holen (Hyprland: ein Fenster liegt auf genau einem Workspace,
    // es wandert also her – auf seinen Monitor) und nach vorn
    function bringHere(t) {
        if (Hypr.deskOf(t) !== Hypr.currentDesk || Hypr.isMinimized(t) || Hypr.isStashed(t))
            Hypr.batch(["dispatch movetoworkspacesilent " + Hypr.wsFor(Hypr.slotOf(t), Hypr.currentDesk) + "," + Hypr.sel(t),
                "dispatch focuswindow " + Hypr.sel(t)], null);
        else
            Hypr.activate(t);
    }

    Component.onCompleted: Parked.impl = {
        toggle: part => {
            const t = root.findApp(part);
            if (!t)
                return Launch.run(part);   // spotify | discord: RPM, sonst Flatpak
            if (root.isOut(part, root.version))
                Hypr.stash(t);   // wegräumen: unsichtbar, kein Desktop
            else
                root.bringHere(t);
        },
        focus: name => {
            const t = root.findApp(name);
            if (!t)
                return;
            if (Parked.isParked(Hypr.appId(t)))
                root.bringHere(t);
            else
                Hypr.activate(t);   // holt auch minimierte Fenster zurück
        }
    }

    property int revealTick: 0   // per IPC (z. B. Kürzel) → Leiste holen
    signal quickLinksRequested(string deskId)   // per IPC: Quicklinks-Popup eines Workspaces öffnen
    signal modeLinksRequested()                 // per IPC: wie Q im Workspace-Modus

    // ---------- Workspace-Modus (Alt antippen / Alt+Esc): Leiste per Tastatur bedienen ----------
    property bool modeOn: false
    property int modeSel: 0          // markierte Kachel (Platz in der Leiste, 0-basiert)
    property string delId: ""        // Workspace, dessen Kachel „Close N windows? · Enter“ zeigt (3 s, dann verfällt es)
    property int delCount: 0
    property string closingId: ""    // Workspace, dessen Fenster gerade schließen (danach wird er entfernt)
    property int closingTries: 0
    // Tastatur nötig: Modus oder offene Rückfrage
    readonly property bool keyOn: modeOn || delId !== ""
    property string modeNote: ""     // kurze Rückmeldung („No workspace 7“)
    property var modeWin: null       // Fenster, das beim Öffnen aktiv war (Shift+Ziffer schiebt es)
    function modeOpen() {
        modeSel = Math.max(0, Desktops.ids.indexOf(Desktops.current));
        delId = "";
        modeNote = "";
        modeWin = Hypr.activeToplevel;
        modeOn = true;
    }
    function modeClose() {
        modeOn = false;
        delId = "";
        modeNote = "";
    }
    function note(text) {
        modeNote = text;
        noteTimer.restart();
    }
    Timer {
        id: noteTimer
        interval: 2500
        onTriggered: root.modeNote = ""
    }
    // Diese Fenster bleiben beim Entfernen eines Workspaces offen: Chat-Client und Spotify, mitkommende Apps
    // (config/follow.json, folgen allen Workspaces), geparkte/weggeräumte Fenster
    function keeps(t) {
        const id = Hypr.appId(t);
        return Parked.isParked(id) || Chat.matches(id) || /spotify/i.test(id) || Hypr.followsApp(id) || Hypr.isStashed(t);
    }
    // Fenster eines Workspaces, die beim Entfernen schließen (auch minimierte)
    function closableOn(id) {
        version;
        return Hypr.windowsOnDesk(Number(id)).filter(t => !keeps(t));
    }
    // Workspace entfernen (Modus X/Entf, Mittelklick): leer = sofort; sonst zeigt die Kachel „Close N windows? · Enter“
    // (zweites X/Entf oder Enter bestätigt, anderes bricht ab, nach 3 s verfällt es). Es bleibt immer mindestens einer:
    // der letzte wird nicht entfernt, sondern nach dem Schließen seiner Fenster auf einen leeren Standard-Workspace zurückgesetzt (Standardname).
    function finishRemove(id) {
        if (Desktops.count <= 1) {
            Desktops.rename(id, "");
            note("Workspace reset");
            revealTick++;
        } else {
            Desktops.remove(id);
        }
        modeSel = Math.min(modeSel, Desktops.count - 1);
    }
    function requestRemove(id) {
        const i = Desktops.ids.indexOf(id);
        if (i < 0)
            return;
        const n = closableOn(id).length;
        if (n === 0) {
            finishRemove(id);
            return;
        }
        delCount = n;
        delId = id;
        delTimer.restart();
    }
    function cancelRemove() {
        delId = "";
        delTimer.stop();
    }
    Timer {
        id: delTimer
        interval: 3000
        onTriggered: root.delId = ""
    }
    // Fenster sanft schließen (Apps dürfen nachfragen), dann Workspace entfernen; bleibt etwas offen, bleibt der Workspace
    function confirmRemove(target) {
        const id = target ?? delId;
        cancelRemove();
        if (!id || Desktops.ids.indexOf(id) < 0)
            return;
        for (const t of closableOn(id))
            Hypr.close(t);
        closingId = id;
        closingTries = 0;
        closeTimer.restart();
    }
    Timer {
        id: closeTimer
        interval: 400
        repeat: true
        onTriggered: {
            root.closingTries++;
            const left = root.closableOn(root.closingId);
            if (left.length === 0) {
                const id = root.closingId;
                root.closingId = "";
                root.finishRemove(id);
                stop();
            } else if (root.closingTries >= 8) {
                root.closingId = "";
                stop();
                root.note(left.length + (left.length === 1 ? " window" : " windows") + " still open");
                root.revealTick++;
            }
        }
    }

    IpcHandler {
        target: "workbar"
        function reveal(): void {
            root.revealTick++;
        }
        // Quicklinks des n-ten Workspaces (Platz in der Leiste, 0 = aktueller) öffnen – nur Projekt-Workspaces
        function quickLinks(n: int): void {
            const id = n > 0 ? Desktops.ids[n - 1] : Desktops.current;
            if (id && GitInfo.projectForId(id))
                root.quickLinksRequested(id);
        }
        // Alt antippen / Alt+Esc: Workspace-Modus an/aus (Leiste unten bekommt die Tastatur); modeOpen / modeClose einzeln
        function mode(): void {
            if (root.modeOn)
                root.modeClose();
            else
                root.modeOpen();
        }
        function modeOpen(): void {
            root.modeOpen();
        }
        function modeClose(): void {
            root.modeClose();
        }
        function modeState(): string {
            return JSON.stringify({ on: root.modeOn, sel: root.modeSel, del: root.delId, closing: root.closingId });
        }
        // wie Q im Modus: Quicklinks der markierten Kachel per Tastatur (Test ohne Tastatur)
        function modeLinks(): void {
            if (root.modeOn)
                root.modeLinksRequested();
        }
        // Alt+→ / Alt+←: reihum durch die Desktops, Leiste zeigt kurz wo; im Workspace-Modus nur die Markierung
        function nextDesk(): void {
            if (root.modeOn)
                root.modeSel = (root.modeSel + 1) % Math.max(1, Desktops.count);
            else
                root.stepDesk(1);
        }
        function prevDesk(): void {
            if (root.modeOn)
                root.modeSel = (root.modeSel - 1 + Math.max(1, Desktops.count)) % Math.max(1, Desktops.count);
            else
                root.stepDesk(-1);
        }
        // Kürzel Alt+1…9: zum n-ten Workspace in der Leiste (Platz, nicht Hyprland-Nummer), alle Monitore, Leiste zeigt kurz wo
        function goDesk(n: int): void {
            if (n < 1 || n > Desktops.list.length)
                return;
            Desktops.goIndex(n);
            root.revealTick++;
        }
        // Kürzel Alt+Shift+1…9: aktives Fenster auf den n-ten Workspace der Leiste (Monitor-Slot des Fensters), ohne mitzugehen
        function moveToDesk(n: int): void {
            const d = Desktops.list[n - 1];
            if (!d || !Hypr.activeToplevel)
                return;
            Hypr.moveToDesk(Hypr.activeToplevel, d.id);
            root.revealTick++;
        }
        // Fenster aller Desktops (AppId, Desktop, Geometrie) – zum Prüfen
        function apps(): string {
            return JSON.stringify(Hypr.toplevels.values.map(t => {
                const g = Hypr.geo(t);
                return { app: Hypr.appId(t), stacking: Hypr.stacking(t), active: Hypr.isActive(t), desktop: Hypr.deskOf(t), ws: Hypr.wsName(t), x: g.x, y: g.y, w: g.width, h: g.height };
            }));
        }
    }

    Variants {
        model: Config.mainScreens

        Scope {
            id: scr

            required property var modelData

            PanelWindow {
                id: win

                property bool revealed: false
                Connections {
                    target: root
                    function onRevealTickChanged() { win.revealed = true; }
                }
                property int openMenus: 0
                // Git-/CI-Daten nur holen, solange die Leiste zu sehen ist
                Binding {
                    target: GitInfo
                    property: "active"
                    value: win.shown && win.visible
                }
                Connections {
                    target: root
                    function onQuickLinksRequested(id) {
                        const it = deskRep.itemAt(Desktops.ids.indexOf(id));
                        if (!it)
                            return;
                        win.revealed = true;
                        win.placeAboveBar(quickLinks, it);
                        quickLinks.openFor(id);
                    }
                }

                // ---------- Maße: Workspace-Kacheln schrumpfen bei vielen Workspaces, die Leiste bleibt auf dem Bildschirm ----------
                readonly property int tilePad: 10
                // Vorschau-Breite: höchstens 320, bei vielen Workspaces bis herunter auf 96 (etwa 62 % der Bildschirmbreite für die Kacheln)
                readonly property real deskPw: Math.round(Math.max(96, Math.min(320, (scr.modelData.width * 0.62 - 8 * (Desktops.count - 1)) / Math.max(1, Desktops.count) - 2 * tilePad)))
                readonly property real deskPh: Math.round(deskPw * root.vh / root.vw)
                // Kachelhöhe: Kopf 24 + Abstand 5 + Vorschau + Rand
                readonly property real tileH: 24 + 5 + deskPh + 2 * 9

                // Farbe je App-Klasse für die Fenster-Kacheln der Vorschau (nur Theme-Töne, stabil nach Klassenname)
                readonly property var appTones: [Theme.accent, Theme.success, Theme.warning, Theme.woodLight, Theme.accentText, Theme.textMuted, Theme.error]
                function appColor(id) {
                    let h = 0;
                    const s = String(id).toLowerCase();
                    for (let i = 0; i < s.length; i++)
                        h = (h * 31 + s.charCodeAt(i)) % 1009;
                    return appTones[h % appTones.length];
                }

                // Fenster per Ziehen auf einen anderen Workspace schieben: Zustand des Zieh-Vorgangs (Pos. in Leisten-Koordinaten)
                property bool wdActive: false
                property var wdWin: null
                property string wdFrom: ""
                property real wdX: 0
                property real wdY: 0
                property int wdTo: -1
                // Ziel-Monitor in der Ziel-Kachel ("" = Kopf/Rand: alter Weg, gleicher Monitor-Platz) und dessen Workspace
                property string wdMon: ""
                property int wdWs: 0
                // Monitor (Name) unter Leisten-Koordinate (px, py) in der Mini-Vorschau von Kachel i, sonst ""
                function monAt(i, px, py) {
                    const it = deskRep.itemAt(i);
                    if (!it || !it.miniItem)
                        return "";
                    const m = it.miniItem, p = m.mapToItem(bar, 0, 0);
                    const lx = root.vx + (px - p.x) / m.width * root.vw, ly = root.vy + (py - p.y) / m.height * root.vh;
                    const s = root.screens.find(s => lx >= s.x && lx < s.x + s.width && ly >= s.y && ly < s.y + s.height);
                    return s ? s.name : "";
                }
                // Workspace-Kachel unter Leisten-Koordinate (px, py), sonst -1
                function deskAt(px, py) {
                    for (let i = 0; i < deskRep.count; i++) {
                        const it = deskRep.itemAt(i);
                        if (!it)
                            continue;
                        const p = it.mapToItem(bar, 0, 0);
                        if (px >= p.x && px <= p.x + it.width && py >= p.y - 6 && py <= p.y + it.height + 6)
                            return i;
                    }
                    return -1;
                }
                // ragt ein Fenster (aktueller Desktop, Hauptmonitor) unten in die Leiste?
                readonly property bool blocked: {
                    root.version;
                    const s = scr.modelData;
                    const top = s.y + s.height - (Theme.barMargin + bar.height + 4);
                    const right = s.x + Theme.barMargin + bar.width;
                    for (const t of root.windowsOn(Desktops.current, root.version)) {
                        if (Hypr.isMinimized(t))
                            continue;
                        const g = Hypr.geo(t);
                        if (g.x < right && g.x + g.width > s.x && g.y + g.height > top && g.y < s.y + s.height)
                            return true;
                    }
                    return false;
                }
                // Menüs sitzen wie die Bar-Popouts mit Lücke über der ganzen Leiste, links bündig zum Auslöser
                function placeAboveBar(popup, item) {
                    const p = item.mapToItem(null, 0, 0);
                    popup.anchor.rect.x = p.x;
                    popup.anchor.rect.y = win.height - Theme.barMargin - bar.height - Theme.windowGap + 1;
                    popup.anchor.rect.width = item.width;
                    popup.anchor.rect.height = 1;
                }

                // nach Klick/Menü offen bleiben, bis die Maus die Leiste wirklich verlässt
                // (Desktopwechsel oder geschlossenes Menü melden kein neues Hovern, bis sich die Maus bewegt)
                property bool sticky: false
                function stick() {
                    sticky = true;
                    stickFallback.restart();
                }
                onBlockedChanged: if (blocked && (hover.hovered || openMenus > 0)) stick()
                readonly property bool shown: !blocked || revealed || sticky || openMenus > 0 || hover.hovered || root.keyOn

                screen: scr.modelData
                // Vollbild/Spiel: ganz weg, wie die Top-Bar (Windows.bare) – nur für den Workspace-Modus darf sie erscheinen
                visible: !Windows.bare || root.keyOn
                anchors {
                    bottom: true
                    left: true
                }
                // + Platz rechts für Tooltips der App-Icons (Klicks nimmt nur die Leiste an, siehe mask)
                implicitWidth: Math.min(scr.modelData.width, bar.width + Theme.barMargin + 12 + 360)
                // Platz über der Leiste für Tooltips (Eingaben gehen per Maske nur an die Leiste)
                implicitHeight: bar.height + Theme.barMargin + 96
                exclusionMode: ExclusionMode.Ignore
                color: "transparent"
                WlrLayershell.namespace: "dock"
                // Overlay wie die Bar: sonst bleibt sie bei Vollbild unter dem Fenster
                WlrLayershell.layer: WlrLayer.Overlay
                // Tastatur nur im Workspace-Modus
                WlrLayershell.keyboardFocus: root.keyOn ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

                mask: Region {
                    item: win.shown ? bar : null
                }
                BackgroundEffect.blurRegion: Region {
                    Region { x: 0; y: 0; width: 1; height: 1 }
                    Region {
                        item: win.shown && Theme.blurEnabled ? bar : null
                        radius: Theme.barRadius
                    }
                }

                Timer {
                    running: win.revealed && !hover.hovered && win.openMenus === 0
                    interval: 600
                    onTriggered: win.revealed = false
                }
                // Klick außerhalb beendet den Modus
                // (erst kurz nach dem Öffnen scharf: sofort aktiviert meldet Hyprland „cleared“, bevor die Fläche den Fokus hat)
                HyprlandFocusGrab {
                    active: root.keyOn && win.grabReady
                    // Quicklinks per Taste (ohne eigenen Grab) zählen mit, sonst beendet ein Klick hinein den Modus
                    windows: quickLinks.visible ? [win, quickLinks] : [win]
                    onCleared: { root.cancelRemove(); root.modeClose(); }
                }
                property bool grabReady: false
                Timer {
                    id: grabDelay
                    interval: 250
                    onTriggered: win.grabReady = root.keyOn
                }
                Connections {
                    target: root
                    function onKeyOnChanged() {
                        win.grabReady = false;
                        if (root.keyOn) {
                            grabDelay.restart();
                            keys.forceActiveFocus();
                            win.stick();
                        } else {
                            // Leiste kurz stehen lassen (zeigt, wo man gelandet ist), dann wie sonst wieder weg
                            win.revealed = true;
                            if (quickLinks.kb && quickLinks.visible)
                                quickLinks.visible = false;
                        }
                    }
                }
                // Quicklinks per Taste zu: Esc = zurück in den Modus, sonst (Link geöffnet, Add link) ist der Modus fertig
                Connections {
                    target: quickLinks
                    function onVisibleChanged() {
                        if (quickLinks.visible || !quickLinks.kb)
                            return;
                        const back = quickLinks.kbBack;
                        quickLinks.kb = false;
                        if (back && root.modeOn)
                            keys.forceActiveFocus();
                        else
                            root.modeClose();
                    }
                }

                // Tastatur im Workspace-Modus
                Item {
                    id: keys
                    focus: root.keyOn
                    Keys.onPressed: event => {
                        win.modeKey(event);
                        event.accepted = true;
                    }
                }

                function modeKey(e) {
                    const ids = Desktops.ids, n = ids.length;
                    const k = e.key;
                    const shift = !!(e.modifiers & Qt.ShiftModifier);
                    const enter = k === Qt.Key_Return || k === Qt.Key_Enter;
                    // Quicklinks der Kachel offen (Q): Tasten gehören dem Popup
                    if (quickLinks.visible && quickLinks.kb) {
                        quickLinks.key(e);
                        return;
                    }
                    // Rückfrage „Move windows …?“
                    if (root.delId !== "") {
                        if (e.isAutoRepeat)
                            return;
                        if (enter || k === Qt.Key_X || k === Qt.Key_Delete)
                            root.confirmRemove();
                        else
                            root.cancelRemove();
                        return;
                    }
                    // Ziffer 1…9: Taste selbst oder (mit Shift, da dann ein Sonderzeichen kommt) der Tastencode der Zifferreihe (10…18)
                    let digit = 0;
                    if (k >= Qt.Key_1 && k <= Qt.Key_9)
                        digit = k - Qt.Key_0;
                    else if (shift && e.nativeScanCode >= 10 && e.nativeScanCode <= 18)
                        digit = e.nativeScanCode - 9;
                    if (digit > 0) {
                        if (e.isAutoRepeat)
                            return;
                        if (digit > n) {
                            root.note("No workspace " + digit);
                            return;
                        }
                        if (shift) {
                            if (root.modeWin)
                                Hypr.moveToDesk(root.modeWin, Number(ids[digit - 1]));
                            else
                                root.note("No window to move");
                        } else {
                            Desktops.goIndex(digit);
                        }
                        root.modeClose();
                        root.revealTick++;
                        return;
                    }
                    if (k === Qt.Key_Escape) {
                        root.modeClose();
                    } else if (k === Qt.Key_Left || k === Qt.Key_H || k === Qt.Key_Right || k === Qt.Key_L) {
                        const d = (k === Qt.Key_Left || k === Qt.Key_H) ? -1 : 1;
                        if (shift && (k === Qt.Key_Left || k === Qt.Key_Right)) {
                            const to = root.modeSel + d;
                            if (to >= 0 && to < n) {
                                root.moveDesk(root.modeSel, to);
                                root.modeSel = to;
                            }
                        } else {
                            root.modeSel = (root.modeSel + d + n) % n;
                        }
                    } else if (e.isAutoRepeat) {
                        return;
                    } else if (enter) {
                        Desktops.goIndex(root.modeSel + 1);
                        root.modeClose();
                        root.revealTick++;
                    } else if (k === Qt.Key_Delete || k === Qt.Key_X) {
                        root.requestRemove(ids[root.modeSel]);
                    } else if (k === Qt.Key_N) {
                        root.modeClose();
                        Desktops.add("", null);
                        root.revealTick++;
                    } else if (k === Qt.Key_T) {
                        root.modeClose();
                        placeAboveBar(tplMenu, tplBtn);
                        tplMenu.visible = true;
                    } else if (k === Qt.Key_R || k === Qt.Key_F2) {
                        const id = ids[root.modeSel];
                        root.modeClose();
                        Qt.callLater(() => root.rename(id));
                    } else if (k === Qt.Key_Q) {
                        modeLinks();
                    }
                }
                // Q: Quicklinks + Git der markierten Kachel (nur Projekt-Workspaces), Tastatur bleibt bei der Leiste
                function modeLinks() {
                    const id = Desktops.ids[root.modeSel];
                    const it = deskRep.itemAt(root.modeSel);
                    if (!it || !GitInfo.projectForId(id)) {
                        root.note("No project on this workspace");
                        return;
                    }
                    placeAboveBar(quickLinks, it);
                    quickLinks.openKb(id);
                }
                Connections {
                    target: root
                    function onModeLinksRequested() {
                        win.modeLinks();
                    }
                }
                // Projekt der markierten Kachel (Workspace-Modus): Git-Zeile + „Q links“ in der Hinweiszeile
                readonly property var modeProj: root.modeOn ? GitInfo.projectForId(Desktops.ids[root.modeSel] ?? "") : null

                // Hinweiszeile über der Leiste: Tasten des Modus (eine Zeile) oder kurze Meldung
                Rectangle {
                    id: modeHint
                    // offene Quicklinks (per Taste) liegen an derselben Stelle und haben eine eigene Tastenzeile
                    visible: (root.modeOn || root.modeNote !== "") && win.shown && !(quickLinks.visible && quickLinks.kb)
                    x: bar.x
                    y: bar.y - height - 10
                    width: (root.modeNote !== "" ? noteTxt.implicitWidth : Math.max(hintRow.implicitWidth, modeGit.visible ? modeGit.implicitWidth : 0)) + 28
                    height: modeGit.visible ? 74 : 44
                    radius: Theme.radiusMd
                    color: Theme.surfaceRaised
                    border.width: 1
                    border.color: Theme.borderStrong

                    Txt {
                        id: noteTxt
                        anchors.centerIn: parent
                        visible: root.modeNote !== ""
                        text: root.modeNote
                        font.pixelSize: 16
                        font.weight: Font.DemiBold
                    }
                    // Git/CI der markierten Kachel (nur Projekt-Workspaces)
                    QuickLinksTip {
                        id: modeGit
                        visible: root.modeNote === "" && !!win.modeProj && !!g && g.branch !== ""
                        x: 14
                        y: 12
                        proj: win.modeProj
                    }
                    Row {
                        id: hintRow
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: modeGit.visible ? 40 : (parent.height - height) / 2
                        visible: root.modeNote === ""
                        spacing: 16
                        Repeater {
                            model: [["1–9", "go"], ["←→", "select"], ["Enter", "go"]].concat(win.modeProj ? [["Q", "links"]] : [])
                                .concat([["Del", Desktops.count <= 1 ? "reset" : "delete"], ["N", "new"], ["R", "rename"], ["Esc", "close"]])
                            Row {
                                required property var modelData
                                spacing: 6
                                Rectangle {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: Math.max(24, keyTxt.implicitWidth + 12)
                                    height: 24
                                    radius: 7
                                    color: Theme.surfaceSunken
                                    border.width: 1
                                    border.color: Theme.border
                                    MonoTxt {
                                        id: keyTxt
                                        anchors.centerIn: parent
                                        text: modelData[0]
                                        font.pixelSize: 14
                                        font.weight: Font.Bold
                                        color: Theme.accentText
                                    }
                                }
                                Txt {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: modelData[1]
                                    color: Theme.textMuted
                                    font.pixelSize: 15
                                }
                            }
                        }
                    }
                }

                // Notbremse: kommt die Maus gar nicht mehr zurück, nach 3 s zu
                Timer {
                    id: stickFallback
                    interval: 3000
                    onTriggered: if (!hover.hovered && win.openMenus === 0) win.sticky = false
                }

                // dunkler Hof um die Leiste, wenn ein Fenster dahinter liegt
                RectangularShadow {
                    anchors.fill: bar
                    radius: bar.radius
                    offset.y: -3
                    blur: 26
                    spread: 2
                    color: Qt.alpha(Theme.shadow, 0.7)
                    opacity: win.blocked ? bar.opacity : 0
                    Behavior on opacity { NumberAnimation { duration: Theme.fade } }
                }

                Glass {
                    id: bar

                    // surface (dunkler als die Kacheln darauf), deckend
                    strong: false
                    x: Theme.barMargin
                    y: win.shown ? win.height - height - Theme.barMargin : win.height + 8
                    width: row.implicitWidth + 22
                    height: win.tileH + 16
                    radius: Theme.barRadius
                    opacity: win.shown ? 1 : 0

                    Behavior on y { NumberAnimation { duration: Theme.slide; easing.type: Easing.OutCubic } }
                    Behavior on opacity { NumberAnimation { duration: Theme.fade; easing.type: Easing.OutCubic } }
                    Behavior on height { NumberAnimation { duration: Theme.slide; easing.type: Easing.OutCubic } }

                    HoverHandler {
                        id: hover
                        onHoveredChanged: {
                            if (hovered)
                                stickFallback.stop();
                            else if (win.openMenus === 0)
                                win.sticky = false;
                        }
                    }

                    Row {
                        id: row
                        x: 11
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 10

                        // ---------- Workspaces ----------
                        Row {
                        id: deskRow
                        spacing: 8
                        anchors.verticalCenter: parent.verticalCenter
                        Repeater {
                            id: deskRep
                            model: Desktops.ids

                            Rectangle {
                                id: desk

                                required property var modelData
                                required property int index
                                readonly property bool isCurrent: modelData === Desktops.current
                                readonly property string name: Desktops.names[index] ?? ""
                                readonly property bool hovered: tileHover.hovered
                                // Projekt dieses Workspaces (Name = Projekt in projects.json), sonst null: Quicklinks, Git/CI
                                readonly property var proj: GitInfo.projectFor(Desktops.list[index] ? Desktops.list[index].name : "")
                                // Projektzeit heute (ProjectTime zählt, solange dieser Workspace aktiv ist); erst ab 1 min,
                                // auf schmalen Kacheln (viele Workspaces) nicht, damit der Name lesbar bleibt
                                readonly property int projSec: proj ? (ProjectTime.total[proj.id] || 0) : 0
                                readonly property bool showTime: projSec >= 60 && win.deskPw >= 150
                                // Fenster dieses Workspaces (ohne minimierte), für „leer“-Hinweis und Tooltip
                                readonly property int winCount: {
                                    root.version;
                                    return Hypr.windowsOnDesk(Number(modelData)).filter(t => Hypr.usable(t) && !Hypr.isMinimized(t)).length;
                                }

                                anchors.verticalCenter: parent.verticalCenter
                                width: win.deskPw + 2 * win.tilePad
                                height: win.tileH
                                radius: Theme.radiusMd
                                // aktiv: deckende Akzentfläche; inaktiv: ruhig surfaceRaised; Hover heller, Pressed dunkler
                                color: isCurrent ? (deskArea.pressed && !dragging ? Theme.accentPressed : hovered ? Theme.accentHover : Theme.accent)
                                    : (deskArea.pressed && !dragging ? Theme.surfaceSunken : hovered ? Qt.lighter(Theme.surfaceRaised, 1.18) : Theme.surfaceRaised)
                                Behavior on color { ColorAnimation { duration: Theme.fade } }
                                // beim Ziehen (Tile oder Fenster): Ziel bekommt einen hellen Rahmen, der gezogene Workspace folgt der Maus
                                // Fenster über einem Mini-Monitor: dann markiert nur der Monitor (siehe unten), nicht die Kachel
                                readonly property bool dropHere: (root.dragFrom >= 0 && root.dragTo === index && index !== root.dragFrom)
                                    || (win.wdActive && win.wdTo === index && win.wdMon === "" && Desktops.ids[index] !== win.wdFrom)
                                border.width: dropHere ? 3 : isCurrent ? 0 : 1
                                border.color: dropHere ? Theme.text : (hovered ? Theme.borderStrong : Theme.border)
                                property bool dragging: false
                                property real pressRowX: 0
                                property real dragDx: 0
                                z: dragging ? 10 : 0
                                opacity: dragging ? 0.9 : 1
                                transform: Translate { x: desk.dragging ? desk.dragDx : 0 }
                                property bool tipShown: false
                                readonly property Item miniItem: mini

                                function endDrag(apply) {
                                    if (!dragging)
                                        return;
                                    const from = root.dragFrom, to = root.dragTo;
                                    dragging = false;
                                    dragDx = 0;
                                    root.dragFrom = -1;
                                    root.dragTo = -1;
                                    if (apply)
                                        root.moveDesk(from, to);
                                }

                                // Rückfrage nach X/Entf: die Kachel zeigt nur kurz „Close N windows? · Enter“ in der Warnfarbe
                                Rectangle {
                                    visible: root.delId === desk.modelData
                                    anchors.fill: parent
                                    z: 25
                                    radius: desk.radius
                                    color: Theme.warning
                                    Txt {
                                        anchors.fill: parent
                                        anchors.margins: 8
                                        horizontalAlignment: Text.AlignHCenter
                                        wrapMode: Text.WordWrap
                                        elide: Text.ElideNone
                                        text: "Close " + root.delCount + (root.delCount === 1 ? " window" : " windows") + "? · Enter"
                                        color: Theme.onAccent
                                        font.pixelSize: 17
                                        font.weight: Font.Bold
                                    }
                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.confirmRemove()
                                    }
                                }

                                // Auswahl im Workspace-Modus: heller Akzentrahmen um die Kachel
                                Rectangle {
                                    visible: root.modeOn && root.modeSel === desk.index
                                    anchors.fill: parent
                                    anchors.margins: -4
                                    z: 30
                                    radius: Theme.radiusMd + 4
                                    color: "transparent"
                                    border.width: 3
                                    border.color: Theme.accentText
                                }

                                HoverHandler {
                                    id: tileHover
                                    onHoveredChanged: {
                                        if (!hovered)
                                            desk.tipShown = false;
                                    }
                                }
                                Timer {
                                    running: desk.hovered && !desk.dragging && root.dragFrom < 0 && !win.wdActive && win.openMenus === 0 && !root.modeOn
                                    interval: 500
                                    onTriggered: desk.tipShown = true
                                }
                                // Wochenzeit für den Tooltip frisch rechnen lassen (scripts/projecttime)
                                onTipShownChanged: if (tipShown && proj) ProjectTime.refreshWeek()

                                Column {
                                    id: tileCol
                                    x: win.tilePad
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 5

                                    // Kopf: Nummer (= Alt+n) und Name
                                    Row {
                                        height: 24
                                        spacing: 8
                                        Rectangle {
                                            anchors.verticalCenter: parent.verticalCenter
                                            width: Math.max(24, badgeTxt.implicitWidth + 12)
                                            height: 24
                                            radius: 8
                                            // im Modus als Tastenhinweis hervorgehoben (die Zahl ist die Taste)
                                            color: desk.isCurrent ? Theme.onAccent : root.modeOn ? Theme.accentFill : Theme.surfaceSunken
                                            MonoTxt {
                                                id: badgeTxt
                                                anchors.centerIn: parent
                                                text: desk.index + 1
                                                font.pixelSize: 15
                                                font.weight: Font.Bold
                                                color: desk.isCurrent ? Theme.accentText : root.modeOn ? Theme.accentText : Theme.textMuted
                                            }
                                        }
                                        Txt {
                                            id: nameO
                                            anchors.verticalCenter: parent.verticalCenter
                                            width: Math.min(implicitWidth, win.deskPw - 24 - 8 - (desk.proj ? 32 : 0) - (deskDots.visible ? 30 : 0) - (deskTime.visible ? deskTime.implicitWidth + 8 : 0))
                                            text: desk.name
                                            color: desk.isCurrent ? Theme.onAccent : Theme.text
                                            font.pixelSize: 16
                                            font.weight: desk.isCurrent ? Font.Bold : Font.Medium
                                        }
                                    }

                                    // Mini-Vorschau: Monitore als Flächen, Fenster als farbige Kacheln je App-Klasse (alle Monitore)
                                    Item {
                                        id: mini
                                        width: win.deskPw
                                        height: win.deskPh

                                        Repeater {
                                            model: root.screens
                                            Rectangle {
                                                required property var modelData
                                                // Fenster wird hierher gezogen (anderer Workspace oder anderer Monitor als jetzt)
                                                readonly property bool dropMon: win.wdActive && win.wdTo === desk.index && win.wdMon === modelData.name
                                                    && win.wdWs > 0 && win.wdWs !== Hypr.wsId(win.wdWin)
                                                x: (modelData.x - root.vx) / root.vw * mini.width
                                                y: (modelData.y - root.vy) / root.vh * mini.height
                                                width: modelData.width / root.vw * mini.width
                                                height: modelData.height / root.vh * mini.height
                                                radius: 4
                                                color: dropMon ? Theme.accentFill : Theme.surfaceSunken
                                                border.width: dropMon ? 3 : 1
                                                border.color: dropMon ? Theme.accentText : desk.isCurrent ? Qt.alpha(Theme.onAccent, 0.5) : Theme.border
                                            }
                                        }

                                        Txt {
                                            anchors.centerIn: parent
                                            visible: desk.winCount === 0
                                            text: "Empty"
                                            color: Theme.textFaint
                                            font.pixelSize: 14
                                        }

                                        // ein Delegat je Fenster (bleibt stehen, solange es das Fenster gibt)
                                        Repeater {
                                            model: Hypr.toplevels
                                            Rectangle {
                                                id: thumb
                                                required property var modelData
                                                readonly property rect g: { root.version; return Hypr.geo(modelData); }
                                                readonly property bool here: {
                                                    root.version;
                                                    return Hypr.usable(modelData) && !Hypr.isMinimized(modelData)
                                                        && Hypr.deskOf(modelData) === Number(desk.modelData);
                                                }
                                                readonly property color tone: win.appColor(Hypr.appId(modelData))
                                                readonly property bool active: { root.version; return Hypr.isActive(modelData); }
                                                readonly property bool lifted: win.wdActive && win.wdWin === modelData
                                                visible: here && g.width > 0
                                                // vorne, was in Hyprland vorne liegt (aktives Fenster ganz oben)
                                                z: { root.version; return active ? 100000 : Hypr.stacking(modelData); }
                                                x: (g.x - root.vx) / root.vw * mini.width
                                                y: (g.y - root.vy) / root.vh * mini.height
                                                width: Math.max(4, g.width / root.vw * mini.width)
                                                height: Math.max(4, g.height / root.vh * mini.height)
                                                radius: 3
                                                // deckend: App-Farbe auf den Monitorgrund gerechnet
                                                color: Qt.tint(Theme.surfaceSunken, Qt.alpha(tone, thumbArea.containsMouse ? 0.75 : 0.5))
                                                border.width: active ? 2 : 1
                                                border.color: active ? Theme.text : tone
                                                opacity: lifted ? 0.35 : 1
                                                clip: true

                                                IconImage {
                                                    readonly property real side: Math.min(24, parent.width - 6, parent.height - 6)
                                                    anchors.centerIn: parent
                                                    implicitSize: side
                                                    visible: side >= 10
                                                    source: thumb.here ? Hypr.iconPath(thumb.modelData) : ""
                                                }

                                                // Klick = Fenster nach vorn (wechselt den Workspace), Ziehen auf einen anderen Workspace = Fenster dorthin;
                                                // auf einen Mini-Monitor (auch in derselben Kachel) = genau dieser Workspace auf genau diesem Monitor
                                                MouseArea {
                                                    id: thumbArea
                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    acceptedButtons: Qt.LeftButton
                                                    cursorShape: Qt.PointingHandCursor
                                                    property bool moved: false
                                                    property point startP
                                                    onPressed: mouse => {
                                                        moved = false;
                                                        startP = mapToItem(bar, mouse.x, mouse.y);
                                                    }
                                                    onPositionChanged: mouse => {
                                                        if (!pressed)
                                                            return;
                                                        const p = mapToItem(bar, mouse.x, mouse.y);
                                                        if (!moved && Math.hypot(p.x - startP.x, p.y - startP.y) > 8) {
                                                            moved = true;
                                                            win.wdWin = thumb.modelData;
                                                            win.wdFrom = String(desk.modelData);
                                                            win.wdActive = true;
                                                            win.stick();
                                                        }
                                                        if (moved) {
                                                            win.wdX = p.x;
                                                            win.wdY = p.y;
                                                            win.wdTo = win.deskAt(p.x, p.y);
                                                            win.wdMon = win.wdTo >= 0 ? win.monAt(win.wdTo, p.x, p.y) : "";
                                                            win.wdWs = win.wdMon !== "" ? Hypr.wsFor(Hypr.slotOfMonitor(win.wdMon), Number(Desktops.ids[win.wdTo])) : 0;
                                                        }
                                                    }
                                                    onReleased: mouse => {
                                                        const was = moved;
                                                        const to = win.wdTo, mon = win.wdMon;
                                                        moved = false;
                                                        win.wdActive = false;
                                                        win.wdTo = -1;
                                                        win.wdMon = "";
                                                        win.wdWs = 0;
                                                        win.stick();
                                                        if (was) {
                                                            if (to >= 0 && mon !== "")
                                                                Hypr.moveToSlot(thumb.modelData, Hypr.slotOfMonitor(mon), Number(Desktops.ids[to]));
                                                            else if (to >= 0 && Desktops.ids[to] !== String(desk.modelData))
                                                                Hypr.moveToDesk(thumb.modelData, Number(Desktops.ids[to]));
                                                        } else if (containsMouse) {
                                                            Hypr.activate(thumb.modelData);
                                                        }
                                                    }
                                                    onCanceled: {
                                                        moved = false;
                                                        win.wdActive = false;
                                                        win.wdTo = -1;
                                                        win.wdMon = "";
                                                        win.wdWs = 0;
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }

                                // Git/CI-Punkte (nur Projekt-Workspaces) rechts im Kopf, links neben dem Link-Knopf
                                QuickLinksDots {
                                    id: deskDots
                                    visible: !!desk.proj && (dirty || hasCi)
                                    proj: desk.proj
                                    z: 14
                                    x: desk.width - width - win.tilePad - 28 - 4
                                    y: tileCol.y
                                }

                                // Projektzeit heute, leise rechts im Kopf vor den Git/CI-Punkten (Woche steht im Tooltip)
                                Txt {
                                    id: deskTime
                                    visible: desk.showTime && !desk.dragging
                                    z: 14
                                    x: desk.width - implicitWidth - win.tilePad - 28 - 4 - (deskDots.visible ? deskDots.width + 4 : 0)
                                    y: tileCol.y
                                    height: 24
                                    verticalAlignment: Text.AlignVCenter
                                    text: ProjectTime.short(desk.projSec)
                                    color: desk.isCurrent ? Qt.alpha(Theme.onAccent, 0.75) : Theme.textFaint
                                    font.pixelSize: 14
                                }

                                // Quicklinks (nur Projekt-Workspaces): kleiner Knopf rechts im Kopf, immer sichtbar
                                Rectangle {
                                    visible: !!desk.proj && !desk.dragging && !win.wdActive
                                    z: 15
                                    x: desk.width - width - win.tilePad
                                    y: tileCol.y
                                    width: 28
                                    height: 24
                                    radius: 8
                                    color: linkArea.pressed ? Theme.surfaceSunken : linkArea.containsMouse ? Theme.surfaceRaised : Theme.surface
                                    border.width: 1
                                    border.color: linkArea.containsMouse ? Theme.borderStrong : Theme.border
                                    Icon {
                                        anchors.centerIn: parent
                                        name: "link"
                                        size: 17
                                        color: Theme.text
                                    }
                                    MouseArea {
                                        id: linkArea
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            desk.tipShown = false;
                                            win.placeAboveBar(quickLinks, desk);
                                            quickLinks.openFor(desk.modelData);
                                        }
                                    }
                                }

                                // Tooltip über der Kachel (Fensterfläche reicht dafür nach oben, Eingaben nimmt nur die Leiste)
                                Rectangle {
                                    visible: desk.tipShown
                                    x: 0
                                    y: -height - 12
                                    z: 20
                                    width: Math.max(tipTitle.implicitWidth, tipHint.implicitWidth, tipGit.visible ? tipGit.implicitWidth : 0, tipTime.visible ? tipTime.implicitWidth : 0) + 28
                                    height: tipCol.implicitHeight + 18
                                    radius: Theme.radiusSm
                                    color: Theme.surfaceRaised
                                    border.width: 1
                                    border.color: Theme.borderStrong
                                    Column {
                                        id: tipCol
                                        anchors.centerIn: parent
                                        spacing: 2
                                        Txt {
                                            id: tipTitle
                                            text: desk.name + "  ·  " + desk.winCount + (desk.winCount === 1 ? " window" : " windows")
                                                + (desk.index < 9 ? "  ·  Alt+" + (desk.index + 1) : "")
                                            font.pixelSize: 16
                                            font.weight: Font.DemiBold
                                        }
                                        QuickLinksTip {
                                            id: tipGit
                                            proj: desk.proj
                                        }
                                        Txt {
                                            id: tipTime
                                            readonly property int weekSec: desk.proj ? ProjectTime.weekSecOf(desk.proj.id) : 0
                                            visible: !!desk.proj && (desk.projSec >= 60 || weekSec >= 60)
                                            text: "Project time: " + ProjectTime.fmt(desk.projSec) + " today  ·  " + ProjectTime.fmt(weekSec) + " this week"
                                            color: Theme.textMuted
                                            font.pixelSize: 14
                                        }
                                        Txt {
                                            id: tipHint
                                            text: "Click: go · double-click: rename · drag: reorder\nMiddle-click: close its windows and " + (Desktops.count <= 1 ? "reset" : "remove")
                                            color: Theme.textMuted
                                            font.pixelSize: 14
                                        }
                                    }
                                }

                                MouseArea {
                                    id: deskArea
                                    anchors.fill: parent
                                    z: -1   // unter den Fenster-Kacheln der Vorschau
                                    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                                    cursorShape: Qt.PointingHandCursor
                                    // Ziehen (ab 8 px) = Reihenfolge ändern; Koordinaten in row, damit die Verschiebung nicht mitzählt
                                    onPressed: mouse => {
                                        if (mouse.button === Qt.LeftButton)
                                            desk.pressRowX = mapToItem(row, mouse.x, 0).x;
                                    }
                                    onPositionChanged: mouse => {
                                        if (!(mouse.buttons & Qt.LeftButton))
                                            return;
                                        const dx = mapToItem(row, mouse.x, 0).x - desk.pressRowX;
                                        if (!desk.dragging && Math.abs(dx) > 8) {
                                            desk.dragging = true;
                                            desk.tipShown = false;
                                            root.dragFrom = desk.index;
                                            root.dragTo = desk.index;
                                            win.stick();
                                        }
                                        if (desk.dragging) {
                                            desk.dragDx = dx;
                                            root.dragTo = root.dropIndex(deskRep, desk.x + desk.width / 2 + dx);
                                        }
                                    }
                                    // Entscheidung beim Loslassen statt über clicked: nach einem Ziehen (Delegat wird beim
                                    // Umsortieren neu gebaut) kam clicked teils nicht, der nächste Klick wurde dann verschluckt
                                    onReleased: mouse => {
                                        const dragged = desk.dragging;
                                        desk.endDrag(true);
                                        if (dragged || !containsMouse)
                                            return;
                                        if (mouse.button === Qt.LeftButton) {
                                            win.stick();
                                            Desktops.switchTo(desk.modelData);
                                            if (root.modeOn)
                                                root.modeClose();
                                        } else if (mouse.button === Qt.RightButton) {
                                            deskMenu.target = desk.modelData;
                                            win.placeAboveBar(deskMenu, desk);
                                            deskMenu.visible = true;
                                        } else if (mouse.button === Qt.MiddleButton) {
                                            // Mittelklick (Mausrad drücken) = Workspace entfernen, wie "Remove" im Menü
                                            root.requestRemove(desk.modelData);
                                        }
                                    }
                                    onCanceled: desk.endDrag(false)
                                    onDoubleClicked: mouse => {
                                        if (mouse.button === Qt.LeftButton)
                                            root.rename(desk.modelData);
                                    }
                                }
                            }
                        }
                        }

                        // ---------- neu: Plus = Menü (Leer + Vorlagen), Doppelklick = sofort leerer Workspace ----------
                        Chip {
                            id: tplBtn
                            anchors.verticalCenter: parent.verticalCenter
                            padding: 0
                            implicitWidth: 60
                            height: win.tileH
                            radius: Theme.radiusMd
                            active: tplMenu.visible
                            color: pressed ? Theme.surfaceSunken : (active || hovered) ? Qt.lighter(Theme.surfaceRaised, 1.18) : Theme.surfaceRaised
                            border.width: 1
                            border.color: hovered ? Theme.borderStrong : Theme.border
                            // Menü sofort auf; zweiter Klick (Menü offen) = leerer Workspace, siehe tplMenu.onVisibleChanged
                            onClicked: {
                                if (Date.now() - tplMenu.closedAt < 400)
                                    return; // gerade beim Schließen des Menüs schon erledigt
                                if (tplMenu.visible) {
                                    tplMenu.visible = false;
                                } else {
                                    win.placeAboveBar(tplMenu, tplBtn);
                                    tplMenu.visible = true;
                                }
                            }
                            // kommt der zweite Klick als Doppelklick an (statt vom Menü abgefangen)
                            onDoubleClicked: {
                                if (Date.now() - tplMenu.closedAt < 400)
                                    return;
                                if (tplMenu.visible)
                                    tplMenu.visible = false;
                                else
                                    Desktops.add("", null);
                            }
                            Column {
                                spacing: 0
                                Icon {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    name: "add"
                                    size: 32
                                    color: Theme.text
                                }
                                Txt {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: "New"
                                    color: Theme.textMuted
                                    font.pixelSize: 14
                                }
                            }
                        }

                        VSep {
                            id: sep
                            anchors.verticalCenter: parent.verticalCenter
                            implicitHeight: 40
                        }

                        // ---------- offene Apps (aktueller Workspace) ----------
                        AppStrip {
                            anchors.verticalCenter: parent.verticalCenter
                            tipAbove: true
                            // viele Apps: Kacheln schrumpfen, die Leiste bleibt auf dem Bildschirm
                            maxWidth: scr.modelData.width * 0.92 - Theme.barMargin - 22 - deskRow.width - tplBtn.width - sep.width - 3 * row.spacing
                        }
                    }

                    // Fenster-Ziehen: kleines Icon folgt der Maus (liegt über der Vorschau, die selbst klippt)
                    Rectangle {
                        visible: win.wdActive
                        z: 60
                        x: win.wdX - width / 2
                        y: win.wdY - height / 2
                        width: 44
                        height: 44
                        radius: Theme.radiusSm
                        color: Theme.surfaceRaised
                        border.width: 2
                        border.color: Theme.accent
                        IconImage {
                            anchors.centerIn: parent
                            implicitSize: 30
                            source: win.wdActive && win.wdWin ? Hypr.iconPath(win.wdWin) : ""
                        }
                    }
                }

                // ---------- Vorlagen-Menü ----------
                PopupWindow {
                    id: tplMenu

                    anchor.window: win
                    anchor.edges: Edges.Top
                    anchor.gravity: Edges.Top
                    grabFocus: true
                    implicitWidth: 240
                    implicitHeight: tplCol.implicitHeight + 12
                    color: "transparent"
                    property double closedAt: 0
                    onVisibleChanged: {
                        win.openMenus += visible ? 1 : -1;
                        if (!visible) {
                            win.stick();
                            closedAt = Date.now();
                            // Menü offen + nochmal aufs Plus = leerer Desktop (das Menü fängt den Klick selbst ab)
                            if (tplBtn.hovered)
                                Desktops.add("", null);
                        }
                    }

                    BackgroundEffect.blurRegion: Region {
                        Region { x: 0; y: 0; width: 1; height: 1 }
                        Region { item: tplCard; radius: Theme.radiusMd }
                    }

                    Glass {
                        id: tplCard
                        anchors.fill: parent
                        strong: true
                        radius: Theme.radiusMd

                        Column {
                            id: tplCol
                            x: 6
                            y: 6
                            width: parent.width - 12

                            Label {
                                leftPadding: 10
                                topPadding: 6
                                bottomPadding: 6
                                text: "New Workspace"
                            }
                            Chip {
                                width: tplCol.width
                                alignLeft: true
                                height: 36
                                onClicked: {
                                    tplMenu.visible = false;
                                    Desktops.add("", null);
                                }
                                Icon {
                                    anchors.verticalCenter: parent.verticalCenter
                                    name: "add"
                                    size: 17
                                }
                                Txt {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "Empty"
                                }
                            }
                            Rectangle {
                                x: 10
                                width: tplCol.width - 20
                                height: 1
                                color: Theme.border
                            }
                            Repeater {
                                model: Templates.list
                                Chip {
                                    required property var modelData
                                    width: tplCol.width
                                    alignLeft: true
                                    height: 36
                                    onClicked: {
                                        tplMenu.visible = false;
                                        Templates.open(modelData.id);
                                    }
                                    ProfileGlyph {
                                        anchors.verticalCenter: parent.verticalCenter
                                        name: modelData.glyph
                                    }
                                    Txt {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: modelData.name
                                    }
                                }
                            }
                        }
                    }
                }

                // ---------- Desktop-Menü (Rechtsklick) ----------
                PopupWindow {
                    id: deskMenu

                    property string target: ""

                    anchor.window: win
                    anchor.edges: Edges.Top
                    anchor.gravity: Edges.Top
                    grabFocus: true
                    implicitWidth: 270
                    implicitHeight: deskCol.implicitHeight + 12
                    color: "transparent"
                    onVisibleChanged: {
                        win.openMenus += visible ? 1 : -1;
                        if (!visible)
                            win.stick();
                    }

                    BackgroundEffect.blurRegion: Region {
                        Region { x: 0; y: 0; width: 1; height: 1 }
                        Region { item: deskCard; radius: Theme.radiusMd }
                    }

                    Glass {
                        id: deskCard
                        anchors.fill: parent
                        strong: true
                        radius: Theme.radiusMd

                        Column {
                            id: deskCol
                            x: 6
                            y: 6
                            width: parent.width - 12
                            Chip {
                                width: deskCol.width
                                alignLeft: true
                                height: 34
                                visible: !!GitInfo.projectForId(deskMenu.target)
                                onClicked: {
                                    deskMenu.visible = false;
                                    const id = deskMenu.target;
                                    // erst nach dem Schließen dieses Menüs (grabFocus) das nächste öffnen
                                    Qt.callLater(() => {
                                        const it = deskRep.itemAt(Desktops.ids.indexOf(id));
                                        if (it) {
                                            win.placeAboveBar(quickLinks, it);
                                            quickLinks.openFor(id);
                                        }
                                    });
                                }
                                Icon {
                                    anchors.verticalCenter: parent.verticalCenter
                                    name: "link"
                                    size: 17
                                }
                                Txt {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "Quick links"
                                }
                            }
                            Chip {
                                width: deskCol.width
                                alignLeft: true
                                height: 34
                                onClicked: {
                                    deskMenu.visible = false;
                                    root.rename(deskMenu.target);
                                }
                                Icon {
                                    anchors.verticalCenter: parent.verticalCenter
                                    name: "edit"
                                    size: 17
                                }
                                Txt {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "Rename"
                                }
                            }
                            Chip {
                                width: deskCol.width
                                alignLeft: true
                                height: 34
                                visible: Desktops.ids.indexOf(deskMenu.target) > 0
                                onClicked: {
                                    deskMenu.visible = false;
                                    const i = Desktops.ids.indexOf(deskMenu.target);
                                    root.moveDesk(i, i + (-1));
                                }
                                Icon {
                                    anchors.verticalCenter: parent.verticalCenter
                                    name: "arrow_back"
                                    size: 17
                                }
                                Txt {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "Move Left"
                                }
                            }
                            Chip {
                                width: deskCol.width
                                alignLeft: true
                                height: 34
                                visible: Desktops.ids.indexOf(deskMenu.target) < Desktops.ids.length - 1
                                onClicked: {
                                    deskMenu.visible = false;
                                    const i = Desktops.ids.indexOf(deskMenu.target);
                                    root.moveDesk(i, i + (1));
                                }
                                Icon {
                                    anchors.verticalCenter: parent.verticalCenter
                                    name: "arrow_forward"
                                    size: 17
                                }
                                Txt {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "Move Right"
                                }
                            }
                            Chip {
                                width: deskCol.width
                                alignLeft: true
                                height: 34
                                onClicked: {
                                    deskMenu.visible = false;
                                    root.confirmRemove(deskMenu.target);
                                }
                                Icon {
                                    anchors.verticalCenter: parent.verticalCenter
                                    name: "delete"
                                    size: 17
                                    color: Theme.error
                                }
                                Txt {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: root.closableOn(deskMenu.target).length > 0 ? "Close " + root.closableOn(deskMenu.target).length + (root.closableOn(deskMenu.target).length === 1 ? " window" : " windows") + (Desktops.count <= 1 ? " & reset" : " & remove") : (Desktops.count <= 1 ? "Reset" : "Remove")
                                    color: Theme.error
                                }
                            }
                        }
                    }
                }

                // ---------- Quicklinks (Projekt-Workspaces): Ports + Links, Klick öffnet in Helium ----------
                QuickLinksPopup {
                    id: quickLinks
                    host: win
                }
            }

            // Hover-Streifen unten (volle Breite): Hyprland meldet keine Bildschirmkanten, also 2 px Layer,
            // nur solange die Leiste ausgewichen ist. Normal sofort, bei Vollbild erst nach kurzem Verweilen.
            PanelWindow {
                screen: scr.modelData
                visible: win.blocked && !win.shown && !Windows.bare
                anchors {
                    bottom: true
                    left: true
                    right: true
                }
                implicitHeight: 2
                exclusionMode: ExclusionMode.Ignore
                color: "transparent"
                WlrLayershell.namespace: "dock"
                WlrLayershell.layer: WlrLayer.Overlay
                WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    onEntered: {
                        if (Windows.fullscreen)
                            dwell.restart();
                        else
                            win.revealed = true;
                    }
                    onExited: dwell.stop()
                }
                Timer {
                    id: dwell
                    interval: 250
                    onTriggered: win.revealed = true
                }
            }
        }
    }

    // Reihenfolge ändern: nur die Liste in Desktops (Fenster bleiben, wo sie sind; Namen wandern mit)
    property int dragFrom: -1
    property int dragTo: -1
    function moveDesk(from, to) {
        Desktops.move(from, to);
    }
    function stepDesk(delta) {
        const ids = Desktops.ids;
        if (ids.length < 2)
            return;
        const i = ids.indexOf(Desktops.current);
        Desktops.switchTo(ids[(i + delta + ids.length) % ids.length]);
        revealTick++;
    }
    // rep = Repeater der Desktop-Karten: liegt im Fenster-Delegaten (Variants) und ist von hier aus nicht per id
    // erreichbar – vorher „deskRep is not defined“, Umsortieren fand nie ein Ziel
    function dropIndex(rep, centerX) {
        for (let i = 0; i < rep.count; i++) {
            const it = rep.itemAt(i);
            if (it && centerX < it.x + it.width + 2)
                return i;
        }
        return rep.count - 1;
    }

    function rename(id) {
        Prompt.askAt("bottom", "edit", "Name for this workspace", Desktops.names[Desktops.ids.indexOf(id)] ?? "", text => {
            if (text.trim() !== "")
                Desktops.rename(id, text.trim());
        });
    }
}

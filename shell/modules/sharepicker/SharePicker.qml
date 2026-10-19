import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import Quickshell.Hyprland
import qs.config
import qs.services
import qs.components

// Bildschirm-teilen-Auswahl im Desktop-Look (Ersatz für hyprland-share-picker, Doku: docs/knowledge/shell-features.md).
// xdg-desktop-portal-hyprland startet pro Teilen-Anfrage scripts/share-pick (custom_picker_binary in xdph.conf),
// das ruft hier „open“ mit der Fensterliste von xdph auf und wartet auf die Ergebnisdatei
// $XDG_RUNTIME_DIR/desktop-share-pick/<token>.result („ok <flags>/<auswahl>“ oder „cancel“).
// Reiter Screens · Windows · Region, echte Vorschauen per ScreencopyView (Monitore: wlr-screencopy,
// Fenster: hyprland-toplevel-export über HyprlandToplevel.wayland). Region: slurp in Palette-Farben.
// Bedienung: Pfeile wählen, Tab wechselt den Reiter, Tippen sucht Fenster, Enter teilt, Esc / Klick daneben bricht ab,
// Doppelklick teilt sofort. Beim Laden der Shell ist nichts sichtbar (LazyLoader nur, solange eine Anfrage offen ist).
// IPC: qs ipc … call sharepicker open '<json>' | close <token> | alive <token> | status
Scope {
    id: root

    property bool open: false
    property string token: ""
    property bool demo: false             // scripts/share-pick --demo: nur anzeigen, xdph bekommt nichts
    property bool allowToken: false       // Haken „Remember this choice“ = Flag r (Restore-Token)
    property string tab: "screens"        // screens | windows | region
    property int screenIndex: 0
    property int windowIndex: 0
    property string query: ""
    readonly property string instanceId: Date.now().toString(36) + Math.floor(Math.random() * 1e9).toString(36)
    property bool selecting: false        // slurp läuft, Karte ist so lange weg
    property var windows: []              // [{id, cls, title, top}] top = HyprlandToplevel oder null
    property var screensList: []          // [{name, label, detail, screen}]
    property string screenName: Config.mainScreen

    readonly property string dir: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/desktop-share-pick"
    readonly property var tabs: ["screens", "windows", "region"]
    readonly property var shownWindows: {
        const q = query.trim().toLowerCase();
        return q === "" ? windows : windows.filter(w => (title(w) + " " + w.cls).toLowerCase().includes(q));
    }

    // Abstände/Radien aus palette.json (space, radius) – Theme.qml reicht nicht alle durch
    function sp(n: string, fallback: int): int {
        const s = Theme.data.space || ({});
        return s[n] || fallback;
    }
    readonly property int radiusXs: Theme.radii.xs || 6

    // ---------- Daten ----------
    function norm(a): string {
        return String(a || "").toLowerCase().replace(/^0x/, "").replace(/^0+/, "");
    }
    function title(w): string {
        return (w.top ? Hypr.title(w.top) : "") || w.title || w.cls || "Window";
    }
    function appName(w): string {
        const id = (w.top ? Hypr.appId(w.top) : "") || w.cls;
        const e = id ? (DesktopEntries.byId(id.replace(/\.desktop$/, "")) ?? DesktopEntries.heuristicLookup(id)) : null;
        return e && e.name ? e.name : id;
    }
    function iconFor(w): string {
        if (w.top)
            return Hypr.iconPath(w.top);
        const e = w.cls ? (DesktopEntries.byId(w.cls) ?? DesktopEntries.heuristicLookup(w.cls)) : null;
        return Quickshell.iconPath(e && e.icon ? e.icon : w.cls, "application-x-executable");
    }

    // Monitore von links nach rechts, freundlich benannt (bei Bastian: HDMI-A-2 links, DP-2 Mitte, DP-1 rechts)
    function buildScreens(): var {
        const s = [];
        for (let i = 0; i < Quickshell.screens.length; i++)
            s.push(Quickshell.screens[i]);
        s.sort((a, b) => a.x - b.x);
        const pos = s.length === 3 ? ["Left", "Center", "Right"] : s.length === 2 ? ["Left", "Right"] : [];
        return s.map((sc, i) => ({
            name: sc.name,
            label: pos[i] ? pos[i] + " screen" : (s.length === 1 ? "Screen" : "Screen " + (i + 1)),
            detail: sc.name + " · " + sc.width + " × " + sc.height + (sc.name === Config.mainScreen ? " · main" : ""),
            screen: sc
        }));
    }

    // Fensterliste von xdph → Hyprland-Fenster (für Vorschau, Icon, aktuellen Titel), zuletzt benutzte zuerst
    function buildWindows(list): var {
        const tops = Hypr.toplevels.values;
        const out = [];
        for (const w of (list || [])) {
            if (typeof w.id !== "number")
                continue;
            const cls = String(w.cls || "");
            const ttl = String(w.title || "");
            let top = w.addr ? (tops.find(t => root.norm(t.address) === root.norm(w.addr)) ?? null) : null;
            if (!top)
                top = tops.find(t => Hypr.appId(t) === cls && Hypr.title(t) === ttl) ?? null;
            if (top && Hypr.helperClasses.includes(Hypr.appId(top)))
                continue;
            out.push({ id: w.id, cls: cls, title: ttl, top: top });
        }
        const rank = w => {
            const h = w.top ? Hypr.ipc(w.top).focusHistoryID : undefined;
            return typeof h === "number" ? h : 9999;
        };
        return out.sort((a, b) => rank(a) - rank(b));
    }

    // Anfrage übernehmen, ohne etwas zu zeigen (auch für Tests)
    function prepare(req): void {
        windows = buildWindows(req.windows);
        screensList = buildScreens();
        allowToken = req.allowToken === true;
        demo = req.demo === true;
        query = "";
        tab = "screens";
        windowIndex = 0;
        const main = screensList.findIndex(s => s.name === Config.mainScreen);
        screenIndex = Math.max(0, main);
        selecting = false;
    }

    function openRequest(request: string): string {
        let req;
        try {
            req = JSON.parse(request);
        } catch (e) {
            return "bad request";
        }
        if (!/^[0-9a-f]{16}$/.test(String(req.token || "")))
            return "bad token";
        if (open && token !== "")
            writeResult(token, "cancel");   // ältere Anfrage verwerfen
        prepare(req);
        token = req.token;
        screenName = Hyprland.focusedMonitor?.name ?? Config.mainScreen;
        open = true;
        return "ok";
    }

    function writeResult(tok: string, answer: string): void {
        if (!/^[0-9a-f]{16}$/.test(tok))
            return;
        Quickshell.execDetached(["sh", "-c", "mkdir -p \"$1\" && printf '%s\\n' \"$3\" > \"$1/$2.result.tmp\" && mv -f \"$1/$2.result.tmp\" \"$1/$2.result\"",
            "sh", dir, tok, answer]);
    }
    function close(): void {
        open = false;
        selecting = false;
        token = "";
        windows = [];
        query = "";
        if (slurp.running)
            slurp.signal(15);
    }
    function finish(answer: string): void {
        const tok = token;
        close();
        writeResult(tok, answer);
    }
    function cancel(): void {
        if (open)
            finish("cancel");
    }

    function currentSelection(): string {
        if (tab === "screens") {
            const s = screensList[screenIndex];
            return s ? "screen:" + s.name : "";
        }
        if (tab === "windows") {
            const w = shownWindows[windowIndex];
            return w ? "window:" + w.id : "";
        }
        return "";
    }
    readonly property bool canShare: {
        tab; screenIndex; windowIndex; shownWindows; screensList;
        return tab === "region" || currentSelection() !== "";
    }
    function share(): void {
        if (!open || selecting)
            return;
        if (tab === "region") {
            startRegion();
            return;
        }
        const sel = currentSelection();
        if (sel !== "")
            finish("ok " + (allowToken ? "r" : "") + "/" + sel);
    }

    function setTab(t: string): void {
        if (tab === t)
            return;
        tab = t;
    }
    function stepTab(d: int): void {
        const i = tabs.indexOf(tab);
        setTab(tabs[(i + d + tabs.length) % tabs.length]);
    }
    function move(d: int): void {
        if (tab === "screens" && screensList.length)
            screenIndex = Math.max(0, Math.min(screensList.length - 1, screenIndex + d));
        else if (tab === "windows" && shownWindows.length)
            windowIndex = Math.max(0, Math.min(shownWindows.length - 1, windowIndex + d));
    }
    onQueryChanged: {
        windowIndex = 0;
        if (query !== "" && tab !== "windows")
            tab = "windows";
    }

    // ---------- Region (slurp, Farben aus der Palette) ----------
    function hex8(c): string {
        const h = v => ("0" + Math.round(Math.max(0, Math.min(1, v)) * 255).toString(16)).slice(-2);
        return "#" + h(c.r) + h(c.g) + h(c.b) + h(c.a);
    }
    function startRegion(): void {
        if (slurp.running)
            return;
        selecting = true;   // vor dem Verstecken setzen: das Freigeben des Fokus-Grabs bricht sonst ab
        slurpDelay.restart();
    }
    // Karte erst verschwinden lassen, dann slurp (sonst landet das Overlay mit im Bild der Auswahl)
    Timer {
        id: slurpDelay
        interval: 80
        onTriggered: if (root.selecting) slurp.running = true
    }
    Process {
        id: slurp
        command: ["slurp", "-d",
            "-b", root.hex8(Theme.dim),
            "-c", root.hex8(Theme.accent),
            "-s", "#00000000",
            "-B", root.hex8(Qt.alpha(Theme.accent, 0.18)),
            "-F", Theme.fontUi,
            "-w", "2",
            "-f", "%o@%X,%Y,%W,%H"]
        stdout: StdioCollector {
            onStreamFinished: {
                if (!root.selecting)
                    return;
                const r = text.trim();
                const m = /^[A-Za-z0-9._-]+@-?\d+,-?\d+,(\d+),(\d+)$/.exec(r);
                if (m && Number(m[1]) > 0 && Number(m[2]) > 0)
                    root.finish("ok " + (root.allowToken ? "r" : "") + "/region:" + r);
                else
                    root.selecting = false;   // abgebrochen oder leer: zurück zur Auswahl
            }
        }
        onExited: code => {
            if (code !== 0 && root.selecting)
                root.selecting = false;
        }
    }

    IpcHandler {
        target: "sharepicker"

        // von scripts/share-pick: {"token", "allowToken", "windows": [{id, cls, title, addr}], "demo"} → "ok"
        function open(request: string): string {
            return root.openRequest(request);
        }
        // Zeit abgelaufen (scripts/share-pick): ohne Ergebnis schließen
        function close(token: string): void {
            if (root.open && token === root.token)
                root.close();
        }
        // Kennung dieser Shell-Instanz: scripts/share-pick erkennt daran ein Neuladen (ein „cancel“ der alten Instanz zählt dann nicht)
        function instance(): string {
            return root.instanceId;
        }
        function alive(token: string): string {
            return root.open && token === root.token ? "yes" : "no";
        }
        function status(): string {
            return JSON.stringify({ open: root.open, selecting: root.selecting, tab: root.tab, demo: root.demo,
                windows: root.windows.length, screens: root.buildScreens().map(s => s.name + " = " + s.label) });
        }
    }

    // ---------- Bausteine (Kacheln, Reiter, Knöpfe) ----------
    // Kachel-Grund: Auswahl = Akzentfläche + Akzentrand, Hover = etwas heller
    component TileBg: Rectangle {
        property bool current: false
        property bool hovered: false
        radius: Theme.radiusLg
        color: current ? Theme.accentFill : hovered ? Theme.surfaceRaised : "transparent"
        border.width: 2
        border.color: current ? Theme.accent : "transparent"
        Behavior on color { ColorAnimation { duration: Theme.fade; easing.type: Easing.OutCubic } }
    }

    // Vorschau in einer dunklen, runden Mulde; Seitenverhältnis bleibt
    component Well: Rectangle {
        id: wl
        property var source: null
        property bool liveView: false
        property string fallbackIcon: ""
        property real fallbackAr: 16 / 9
        radius: Theme.radiusMd
        color: Theme.bgBottom
        border.width: 1
        border.color: Theme.border
        ScreencopyView {
            id: shot
            anchors.centerIn: parent
            readonly property real ar: sourceSize.width > 0 ? sourceSize.width / sourceSize.height : wl.fallbackAr
            readonly property real boxW: parent.width - Theme.radiusMd
            readonly property real boxH: parent.height - Theme.radiusMd
            width: ar > boxW / boxH ? boxW : boxH * ar
            height: ar > boxW / boxH ? boxW / ar : boxH
            captureSource: root.open ? wl.source : null
            live: root.open && wl.liveView
        }
        IconImage {
            anchors.centerIn: parent
            implicitSize: 48
            source: wl.fallbackIcon
            visible: !shot.hasContent && wl.fallbackIcon !== ""
        }
        Icon {
            anchors.centerIn: parent
            visible: !shot.hasContent && wl.fallbackIcon === ""
            name: "desktop_windows"
            size: 40
            color: Theme.textFaint
        }
    }

    component OutlineBtn: Rectangle {
        id: ob
        property string text
        signal clicked()
        width: obTxt.implicitWidth + 40
        height: 40
        radius: Theme.radiusMd
        color: obArea.containsMouse ? Theme.surfaceRaised : "transparent"
        border.width: 1
        border.color: Theme.borderStrong
        Txt {
            id: obTxt
            anchors.centerIn: parent
            text: ob.text
        }
        MouseArea {
            id: obArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: ob.clicked()
        }
    }

    // ---------- Oberfläche (nur solange eine Anfrage offen ist) ----------
    LazyLoader {
        active: root.open

        PanelWindow {
            id: win

            screen: Quickshell.screens.find(s => s.name === root.screenName) ?? Quickshell.screens[0]
            visible: root.open && !root.selecting
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
            WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
            onVisibleChanged: if (visible) search.forceActiveFocus()

            // Klick auf einen anderen Monitor = abbrechen (wie Esc)
            HyprlandFocusGrab {
                active: win.visible
                windows: [win]
                // kurz verzögert: beim Neuladen der Shell fällt der Grab auch weg – dann stirbt der Timer mit,
                // und scripts/share-pick zeigt dieselbe Anfrage in der neuen Shell wieder (kein Abbruch)
                onCleared: grabLost.restart()
            }
            Timer {
                id: grabLost
                interval: 250
                onTriggered: if (root.open && !root.selecting) root.cancel()
            }

            readonly property int pad: root.sp("6", 24) + 4
            readonly property int gap: root.sp("4", 16)
            readonly property int inner: card.width - 2 * pad
            readonly property int bodyHeight: 2 * windowGrid.cellHeight + win.gap   // zwei Fensterreihen, mehr scrollt

            // ruhiger Grund, Klick daneben = abbrechen
            Rectangle {
                anchors.fill: parent
                color: Theme.dim
                MouseArea {
                    anchors.fill: parent
                    onClicked: root.cancel()
                }
            }

            // ---------- Karte ----------
            Glass {
                id: card
                strong: true
                radius: Theme.radiusXl
                border.color: Theme.borderStrong
                width: Math.min(win.width - 2 * root.sp("20", 80), 1000)
                height: col.implicitHeight + 2 * win.pad
                anchors.centerIn: parent

                // Klicks auf der Karte nicht durchreichen (sonst bräche der Grund ab)
                MouseArea {
                    anchors.fill: parent
                    onPressed: search.forceActiveFocus()
                }

                Column {
                    id: col
                    x: win.pad
                    y: win.pad
                    width: win.inner
                    spacing: root.sp("5", 20) - 2

                    // Kopf
                    Row {
                        spacing: root.sp("3", 12) + 2
                        Rectangle {
                            width: 44
                            height: 44
                            radius: Theme.radiusMd
                            color: Theme.accentFill
                            Icon {
                                anchors.centerIn: parent
                                name: "screen_share"
                                size: 24
                                color: Theme.accentText
                            }
                        }
                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 2
                            Txt {
                                text: "Share your screen"
                                font.pixelSize: 18
                                font.weight: Font.DemiBold
                            }
                            Txt {
                                text: root.demo ? "Preview · nothing will be shared" : "Choose what the app is allowed to see"
                                color: Theme.textFaint
                                font.pixelSize: 12
                                font.weight: Font.Normal
                            }
                        }
                    }

                    // Reiter + Suche
                    Item {
                        width: parent.width
                        height: 36
                        Row {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 2
                            Tab { text: "Screens"; icon: "desktop_windows"; current: root.tab === "screens"; onPicked: root.setTab("screens") }
                            Tab { text: "Windows"; icon: "web_asset"; count: root.windows.length; current: root.tab === "windows"; onPicked: root.setTab("windows") }
                            Tab { text: "Region"; icon: "crop_free"; current: root.tab === "region"; onPicked: root.setTab("region") }
                        }
                        Rectangle {
                            id: searchBox
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            width: 240
                            height: 36
                            radius: Theme.radiusMd
                            color: Theme.surfaceSunken
                            border.width: 1
                            border.color: search.activeFocus && search.text !== "" ? Qt.alpha(Theme.accent, 0.5) : "transparent"
                            Behavior on border.color { ColorAnimation { duration: Theme.fade } }
                            Icon {
                                id: searchIcon
                                x: 12
                                anchors.verticalCenter: parent.verticalCenter
                                name: "search"
                                size: 17
                                color: Theme.textFaint
                            }
                            TextInput {
                                id: search
                                anchors.left: searchIcon.right
                                anchors.leftMargin: 8
                                anchors.right: clearBtn.left
                                anchors.rightMargin: 6
                                anchors.verticalCenter: parent.verticalCenter
                                color: Theme.text
                                selectionColor: Theme.accentSoft
                                selectedTextColor: Theme.text
                                font.family: Theme.fontUi
                                font.pixelSize: 14
                                clip: true
                                focus: true
                                onTextChanged: root.query = text
                                Component.onCompleted: forceActiveFocus()
                                // Fokus bleibt immer hier: alle Tasten laufen über dieses Feld
                                onActiveFocusChanged: if (!activeFocus && win.visible) Qt.callLater(() => search.forceActiveFocus())

                                Keys.onPressed: event => {
                                    const cols = windowGrid.columns;
                                    if (event.key === Qt.Key_Escape) {
                                        if (text !== "")
                                            text = "";
                                        else
                                            root.cancel();
                                    } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                        root.share();
                                    } else if (event.key === Qt.Key_Backtab || (event.key === Qt.Key_Tab && (event.modifiers & Qt.ShiftModifier))) {
                                        root.stepTab(-1);
                                    } else if (event.key === Qt.Key_Tab) {
                                        root.stepTab(1);
                                    } else if (event.key === Qt.Key_Left) {
                                        root.move(-1);
                                    } else if (event.key === Qt.Key_Right) {
                                        root.move(1);
                                    } else if (event.key === Qt.Key_Up) {
                                        if (root.tab === "windows")
                                            root.move(-cols);
                                    } else if (event.key === Qt.Key_Down) {
                                        if (root.tab === "windows")
                                            root.move(cols);
                                    } else {
                                        return;
                                    }
                                    event.accepted = true;
                                }

                                Txt {
                                    anchors.fill: parent
                                    visible: search.text === ""
                                    text: "Search…"
                                    color: Theme.textFaint
                                    font.pixelSize: 14
                                    font.weight: Font.Normal
                                }
                            }
                            Icon {
                                id: clearBtn
                                anchors.right: parent.right
                                anchors.rightMargin: 12
                                anchors.verticalCenter: parent.verticalCenter
                                visible: search.text !== ""
                                name: "close"
                                size: 16
                                color: Theme.textFaint
                                MouseArea {
                                    anchors.fill: parent
                                    anchors.margins: -6
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: search.text = ""
                                }
                            }
                            MouseArea {
                                anchors.fill: parent
                                z: -1
                                acceptedButtons: Qt.NoButton
                                cursorShape: Qt.IBeamCursor
                            }
                        }
                    }

                    // Inhalt (feste Höhe: Karte springt beim Reiterwechsel nicht)
                    Rectangle {
                        width: parent.width
                        height: win.bodyHeight
                        radius: Theme.radiusLg
                        color: Theme.surfaceSunken

                        // --- Screens ---
                        Row {
                            id: screenRow
                            visible: root.tab === "screens"
                            anchors.centerIn: parent
                            spacing: win.gap
                            readonly property int n: Math.max(1, root.screensList.length)
                            readonly property int tileW: Math.min(320, Math.floor((win.inner - 2 * win.gap - (n - 1) * win.gap) / n))

                            Repeater {
                                model: root.screensList
                                MouseArea {
                                    id: st
                                    required property var modelData
                                    required property int index
                                    readonly property bool current: root.screenIndex === index
                                    width: screenRow.tileW
                                    height: stCol.implicitHeight + 2 * 12
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.screenIndex = index
                                    onDoubleClicked: {
                                        root.screenIndex = index;
                                        root.share();
                                    }
                                    TileBg {
                                        anchors.fill: parent
                                        current: st.current
                                        hovered: st.containsMouse
                                    }
                                    Column {
                                        id: stCol
                                        x: 12
                                        y: 12
                                        width: parent.width - 24
                                        spacing: root.sp("3", 12) - 2
                                        Well {
                                            width: parent.width
                                            height: Math.round(width * 9 / 16)
                                            source: st.modelData.screen
                                            liveView: true
                                            fallbackAr: st.modelData.screen.width / Math.max(1, st.modelData.screen.height)
                                        }
                                        Column {
                                            width: parent.width
                                            spacing: 2
                                            Txt {
                                                width: parent.width
                                                text: st.modelData.label
                                                color: st.current ? Theme.text : Theme.textMuted
                                                font.weight: Font.DemiBold
                                            }
                                            Txt {
                                                width: parent.width
                                                text: st.modelData.detail
                                                color: Theme.textFaint
                                                font.pixelSize: 12
                                                font.weight: Font.Normal
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // --- Windows ---
                        GridView {
                            id: windowGrid
                            visible: root.tab === "windows"
                            x: win.gap / 2
                            y: win.gap / 2
                            width: parent.width - win.gap
                            height: parent.height - win.gap
                            readonly property int columns: 4
                            cellWidth: Math.floor(width / columns)
                            cellHeight: Math.round((cellWidth - 2 * 12 - win.gap / 2) * 9 / 16) + 2 * 12 + 46 + win.gap / 2
                            clip: true
                            boundsBehavior: Flickable.StopAtBounds
                            model: root.shownWindows
                            currentIndex: root.windowIndex
                            onCurrentIndexChanged: if (currentIndex >= 0) positionViewAtIndex(currentIndex, GridView.Contain)
                            highlightFollowsCurrentItem: false

                            delegate: MouseArea {
                                id: wt
                                required property var modelData
                                required property int index
                                readonly property bool current: root.windowIndex === index
                                width: windowGrid.cellWidth
                                height: windowGrid.cellHeight
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.windowIndex = index
                                onDoubleClicked: {
                                    root.windowIndex = index;
                                    root.share();
                                }
                                TileBg {
                                    x: win.gap / 4
                                    y: win.gap / 4
                                    width: parent.width - win.gap / 2
                                    height: parent.height - win.gap / 2
                                    current: wt.current
                                    hovered: wt.containsMouse
                                }
                                Well {
                                    id: wWell
                                    x: win.gap / 4 + 12
                                    y: win.gap / 4 + 12
                                    width: parent.width - win.gap / 2 - 24
                                    height: Math.round(width * 9 / 16)
                                    source: wt.modelData.top?.wayland ?? null
                                    liveView: wt.current   // nur die gewählte Vorschau läuft mit, die anderen zeigen ein Standbild
                                    fallbackIcon: root.iconFor(wt.modelData)
                                }
                                IconImage {
                                    id: wIcon
                                    x: wWell.x
                                    y: wWell.y + wWell.height + 10
                                    implicitSize: 20
                                    source: root.iconFor(wt.modelData)
                                }
                                Column {
                                    anchors.left: wIcon.right
                                    anchors.leftMargin: root.sp("2", 8)
                                    anchors.right: wWell.right
                                    y: wIcon.y - 1
                                    spacing: 1
                                    Txt {
                                        width: parent.width
                                        text: root.title(wt.modelData)
                                        color: wt.current ? Theme.text : Theme.textMuted
                                        font.pixelSize: 13
                                        maximumLineCount: 1
                                    }
                                    Txt {
                                        width: parent.width
                                        text: root.appName(wt.modelData)
                                        color: Theme.textFaint
                                        font.pixelSize: 11
                                        font.weight: Font.Normal
                                    }
                                }
                            }

                            Txt {
                                anchors.centerIn: parent
                                visible: windowGrid.count === 0
                                text: root.query !== "" ? "No matching windows" : "No windows to share"
                                color: Theme.textMuted
                                font.weight: Font.Normal
                            }
                        }

                        // --- Region ---
                        Column {
                            visible: root.tab === "region"
                            anchors.centerIn: parent
                            spacing: root.sp("3", 12)
                            Rectangle {
                                anchors.horizontalCenter: parent.horizontalCenter
                                width: 72
                                height: 72
                                radius: Theme.radiusLg
                                color: Theme.surface
                                border.width: 1
                                border.color: Theme.border
                                Icon {
                                    anchors.centerIn: parent
                                    name: "crop_free"
                                    size: 36
                                    color: Theme.accentText
                                }
                            }
                            Txt {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: "Share a part of a screen"
                                font.pixelSize: 16
                                font.weight: Font.DemiBold
                            }
                            Txt {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: "Press Select region, then drag a rectangle. Esc goes back."
                                color: Theme.textFaint
                                font.pixelSize: 13
                                font.weight: Font.Normal
                            }
                        }
                    }

                    // Fuß: Merken links, Knöpfe rechts
                    Item {
                        width: parent.width
                        height: 40

                        MouseArea {
                            id: remember
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            width: remRow.implicitWidth
                            height: 36
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.allowToken = !root.allowToken;
                                search.forceActiveFocus();
                            }
                            Row {
                                id: remRow
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: root.sp("3", 12) - 2
                                Rectangle {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 20
                                    height: 20
                                    radius: root.radiusXs
                                    color: root.allowToken ? Theme.accent : remember.containsMouse ? Theme.surfaceRaised : Theme.surfaceSunken
                                    border.width: root.allowToken ? 0 : 1
                                    border.color: Theme.borderStrong
                                    Behavior on color { ColorAnimation { duration: Theme.fade } }
                                    Icon {
                                        anchors.centerIn: parent
                                        visible: root.allowToken
                                        name: "check"
                                        size: 16
                                        color: Theme.onAccent
                                    }
                                }
                                Column {
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 1
                                    Txt {
                                        text: "Remember this choice"
                                        font.pixelSize: 13
                                    }
                                    Txt {
                                        text: "The app may share the same source again without asking"
                                        color: Theme.textFaint
                                        font.pixelSize: 11
                                        font.weight: Font.Normal
                                    }
                                }
                            }
                        }

                        Row {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: root.sp("3", 12) - 2
                            OutlineBtn {
                                text: "Cancel"
                                onClicked: root.cancel()
                            }
                            Rectangle {
                                width: shareRow.implicitWidth + 40
                                height: 40
                                radius: Theme.radiusMd
                                opacity: root.canShare ? 1 : 0.5
                                color: shareArea.pressed ? Theme.accentPressed : shareArea.containsMouse && root.canShare ? Theme.accentHover : Theme.accent
                                Row {
                                    id: shareRow
                                    anchors.centerIn: parent
                                    spacing: 6
                                    Icon {
                                        anchors.verticalCenter: parent.verticalCenter
                                        name: root.tab === "region" ? "crop_free" : "screen_share"
                                        size: 18
                                        color: Theme.onAccent
                                    }
                                    Txt {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: root.tab === "region" ? "Select region" : "Share"
                                        color: Theme.onAccent
                                    }
                                }
                                MouseArea {
                                    id: shareArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    enabled: root.canShare
                                    onClicked: root.share()
                                }
                            }
                        }
                    }

                    Txt {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "Arrows to choose · Tab to switch · Enter to share · Esc to cancel"
                        color: Theme.textFaint
                        font.pixelSize: 12
                        font.weight: Font.Normal
                    }
                }
            }
        }
    }
}

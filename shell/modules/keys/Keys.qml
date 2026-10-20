import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.config
import qs.services
import qs.components

// Keybind-Viewer (Super+K): durchsuchbares Cheat-Sheet für alles.
//  - oben die App, die beim Öffnen fokussiert war (hervorgehoben; Kitty mit yazi/lazygit: beide)
//  - dann die Topbar (Abschnitt „Topbar“ in hypr/binds.conf + Anleitungen mit "area": "topbar" aus shell.json)
//  - dann die übrige Shell: live gebundene Kürzel aus hyprctl binds -j + Kommentare in hypr/binds.conf, dazu die Anleitungen
//    aus config/appkeys/shell.json (Workspace-Modus, Launcher, Launcher-Präfixe automatisch)
//  - darunter alle anderen Programme aus config/appkeys/*.json, nach App gruppiert
// Tippen sucht überall (App-Name, Tasten, Titel, Beschreibung). Daten und Gruppierung: services/Keybinds.qml
Scope {
    id: root

    property bool open: false
    property string query: ""
    property bool mediaOpen: false
    property string screenName: Config.mainScreen
    // Abschnittsname in hypr/binds.conf ("# ---------- Topbar ----------"), der in die eigene Gruppe „Topbar“ kommt
    readonly property string topbarSection: "Topbar"
    // Fenster, das beim Öffnen fokussiert war (der Viewer selbst ist eine Layer-Fläche, ändert das also nicht)
    property string activeClass: ""
    property string activeTitle: ""

    function show(): void {
        // Suchfeld immer leer, auch wenn schon offen (z. B. zweiter open-Aufruf)
        query = "";
        Keybinds.refresh();
        if (open)
            return;
        const t = Hyprland.activeToplevel;
        activeClass = t ? Hypr.appId(t) : "";
        activeTitle = t ? Hypr.title(t) : "";
        screenName = Hyprland.focusedMonitor?.name ?? Config.mainScreen;
        query = "";
        mediaOpen = false;
        Hypr.panelOpened("keys");
        open = true;
    }

    // Anderes Panel geht auf → dieses zu (Hypr.panelOpened)
    Connections {
        target: Hypr
        function onPanelOpened(name: string): void {
            if (name !== "keys" && root.open)
                root.open = false;
        }
    }
    function toggle(): void {
        if (open)
            open = false;
        else
            show();
    }

    // qs ipc --any-display -p ~/Workspace/bastian-shell/shell call keys toggle|open|close
    IpcHandler {
        target: "keys"

        function toggle(): void {
            root.toggle();
        }
        function open(): void {
            root.show();
        }
        function close(): void {
            root.open = false;
        }
        // zum Testen: öffnet mit Suchbegriff
        function search(text: string): void {
            root.show();
            root.query = text;
        }
        // zum Testen: so öffnen, als wäre dieses Fenster fokussiert (Klasse, Titel)
        function app(cls: string, title: string): void {
            root.show();
            root.activeClass = cls;
            root.activeTitle = title;
        }
    }

    // ---------- Filter ----------
    // jedes Wort (Trenner Leerzeichen oder +) muss in Taste, Titel, Beschreibung oder Kategorie vorkommen;
    // ab 3 Zeichen zählt auch ein Fuzzy-Treffer im Titel
    function matches(row: var, tokens: var): bool {
        return tokens.every(t => row.search.includes(t) || (t.length >= 3 && Fuzzy.score(t, row.title) > 0));
    }
    // "+" allein ist auch eine Taste (Ctrl++), sonst Trenner
    readonly property var tokens: query.toLowerCase().replace(/([^\s+])\+(?=\S)/g, "$1 ").split(/\s+/).filter(t => t)
    function filterCats(cats: var, tk: var): var {
        const out = [];
        for (const c of cats) {
            const rows = tk.length ? c.rows.filter(r => matches(r, tk)) : c.rows;
            if (rows.length)
                out.push({ name: c.name, media: c.media, note: c.note || "", rows: rows });
        }
        return out;
    }
    readonly property var activeApps: Keybinds.appsFor(activeClass, activeTitle)
    // Gruppen: [{ key, title, about, active, cats }] – fokussierte App(s), Shell, restliche Apps
    readonly property var groups: {
        const tk = tokens;
        const out = [];
        const act = activeApps;
        const actIds = act.map(a => a.id);
        for (const a of act)
            out.push({ key: "a:" + a.id, title: a.name, about: a.about, active: true, cats: filterCats(a.cats, tk) });
        // Topbar zuerst: binds.conf-Abschnitt „Topbar“ (Super+Leertaste, Super+<Buchstabe>, Super+Alt+<Buchstabe>) + Anleitungen mit area "topbar".
        // Dann die übrige Shell: Hyprland-Kürzel, Anleitungen aus shell.json vor den (eingeklappten) Media keys
        const guides = [];
        const barGuides = [];
        let about = "";
        for (const a of Keybinds.apps)
            if (a.group === "shell") {
                for (const c of a.cats)
                    (c.area === "topbar" ? barGuides : guides).push(c);
                about = about || a.about;
            }
        const hypr = Keybinds.cats;
        const isBar = c => c.name === root.topbarSection;
        const barCats = hypr.filter(isBar).concat(barGuides);
        out.push({ key: "topbar", title: "Topbar", about: "Super+Space, then a letter – or the key directly", active: false, cats: filterCats(barCats, tk) });
        const shellCats = hypr.filter(c => !c.media && !isBar(c)).concat(guides, hypr.filter(c => c.media));
        out.push({ key: "shell", title: "Desktop shell", about: about, active: false, cats: filterCats(shellCats, tk) });
        for (const a of Keybinds.apps)
            if (a.group === "app" && !actIds.includes(a.id))
                out.push({ key: "a:" + a.id, title: a.name, about: a.about, active: false, cats: filterCats(a.cats, tk) });
        return out.filter(g => g.cats.length);
    }
    readonly property int shownCount: groups.reduce((n, g) => n + g.cats.reduce((m, c) => m + c.rows.length, 0), 0)

    // ---------- Spalten verteilen ----------
    // Gewicht ~ Höhe: Zeile 1 (+0,5 mit Beschreibung, je weiterer Akkord +1), Kopf 1,8
    function weight(r: var): real {
        return Math.max(1, r.chords.length) + (r.sub ? 0.55 : 0);
    }
    function distribute(cats: var, n: int, mediaOpen: bool): var {
        const pieces = [];
        let total = 0;
        const rowsW = rows => rows.reduce((s, r) => s + weight(r), 0);
        for (const c of cats) {
            const collapsed = c.media && !mediaOpen && tokens.length === 0;
            if (collapsed) {
                pieces.push({ name: c.name, note: "", media: true, collapsed: true, count: c.rows.length, rows: [], cont: false, w: 2.2 });
                total += 2.2;
                continue;
            }
            total += rowsW(c.rows) + 1.8;
            pieces.push({ name: c.name, note: c.note || "", media: c.media, collapsed: false, count: c.rows.length, rows: c.rows, cont: false, w: rowsW(c.rows) + 1.8 });
        }
        const target = total / n;
        // zu große Karten in Stücke teilen
        const split = [];
        for (const p of pieces) {
            if (p.collapsed || n < 2 || p.rows.length < 6 || p.w <= target * 1.3) {
                split.push(p);
                continue;
            }
            const parts = Math.min(Math.ceil(p.w / target), n);
            const per = rowsW(p.rows) / parts;
            let cur = [], acc = 0;
            const chunks = [];
            for (const r of p.rows) {
                const rw = weight(r);
                if (cur.length && acc + rw / 2 > per && chunks.length < parts - 1) {
                    chunks.push(cur);
                    cur = [];
                    acc = 0;
                }
                cur.push(r);
                acc += rw;
            }
            chunks.push(cur);
            chunks.forEach((rows, i) => split.push({ name: p.name, note: i > 0 ? "" : p.note, media: p.media, collapsed: false, count: p.count, rows: rows, cont: i > 0, w: rowsW(rows) + 1.8 }));
        }
        // der Reihe nach in Spalten füllen
        const cols = Array.from({ length: n }, () => []);
        const colW = new Array(n).fill(0);
        let idx = 0;
        for (const p of split) {
            if (colW[idx] > 0 && idx < n - 1 && colW[idx] + p.w / 2 > target)
                idx++;
            cols[idx].push(p);
            colW[idx] += p.w;
        }
        return cols.filter(c => c.length);
    }

    Variants {
        model: Quickshell.screens.filter(s => s.name === root.screenName)

        PanelWindow {
            id: win

            required property var modelData

            // weich auf, aber sofort tippbar
            property real progress: root.open ? 1 : 0
            Behavior on progress { NumberAnimation { duration: root.open ? 150 : 110; easing.type: Easing.OutCubic } }

            readonly property int panelW: Math.min(width - 160, 1560)
            readonly property int pad: 28
            readonly property int gap: 16
            readonly property int ncols: Math.max(1, Math.min(4, Math.floor((panelW - 2 * pad + gap) / (410 + gap))))
            // feste Spaltenbreite für alle Gruppen (kleine Apps strecken sich nicht über die ganze Breite)
            readonly property int colW: Math.floor((panelW - 2 * pad - (ncols - 1) * gap) / ncols)
            readonly property int maxContentH: height - 200 - 52 - 3 * 18 - 2 * pad - 20

            screen: modelData
            visible: root.open || progress > 0
            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }
            exclusionMode: ExclusionMode.Ignore
            color: "transparent"
            WlrLayershell.namespace: "dock" // "dock": ohne Öffnen-Animation (Hyprland: layerrule noanim)
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: root.open ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

            // Klick irgendwo daneben (auch auf den anderen Monitoren) schließt
            HyprlandFocusGrab {
                active: root.open
                windows: [win]
                onCleared: root.open = false
            }

            readonly property bool blurOn: root.open && progress > 0.4
            BackgroundEffect.blurRegion: Region {
                Region { x: 0; y: 0; width: 1; height: 1 }
                Region { item: win.blurOn ? backdrop : null }
                Region { item: panel; radius: Theme.radiusXl }
            }

            onVisibleChanged: {
                if (visible) {
                    search.text = root.query;
                    search.forceActiveFocus();
                    flick.contentY = 0;
                }
            }
            Connections {
                target: root
                function onOpenChanged() {
                    if (root.open) {
                        search.text = root.query;
                        search.forceActiveFocus();
                        flick.contentY = 0;
                    }
                }
                function onQueryChanged() {
                    flick.contentY = 0;
                }
            }

            Rectangle {
                id: backdrop
                anchors.fill: parent
                opacity: win.progress
                color: Theme.dim
                MouseArea {
                    anchors.fill: parent
                    onClicked: root.open = false
                }
            }

            Glass {
                id: panel

                width: win.panelW
                height: win.pad * 2 + 52 + 18 + flick.height + 18 + hint.height
                x: (parent.width - width) / 2
                y: Math.max(60, parent.height * 0.1) - (1 - win.progress) * 14
                opacity: win.progress
                scale: 0.98 + 0.02 * win.progress
                radius: Theme.radiusXl
                strong: true
                Behavior on height { NumberAnimation { duration: Theme.fade; easing.type: Easing.OutCubic } }

                // schluckt Klicks im Panel (sonst schließt der Hintergrund)
                MouseArea {
                    anchors.fill: parent
                }

                Column {
                    x: win.pad
                    y: win.pad
                    width: parent.width - 2 * win.pad
                    spacing: 18

                    // Suchfeld
                    Rectangle {
                        width: parent.width
                        height: 52
                        radius: Theme.radiusMd
                        color: Theme.raise
                        border.width: 1
                        border.color: Qt.alpha(Theme.accent, 0.5)

                        Icon {
                            id: searchIcon
                            anchors.left: parent.left
                            anchors.leftMargin: 16
                            anchors.verticalCenter: parent.verticalCenter
                            name: "keyboard"
                            size: 22
                            color: Theme.textFaint
                        }
                        TextInput {
                            id: search
                            anchors.left: searchIcon.right
                            anchors.leftMargin: 12
                            anchors.right: countTxt.left
                            anchors.rightMargin: 12
                            anchors.verticalCenter: parent.verticalCenter
                            clip: true
                            text: root.query
                            onTextChanged: root.query = text
                            Connections {
                                target: root
                                function onQueryChanged() {
                                    if (search.text !== root.query)
                                        search.text = root.query;
                                }
                            }
                            color: Theme.text
                            selectionColor: Theme.accentSoft
                            font.family: Theme.fontUi
                            font.pixelSize: 19
                            focus: true
                            Keys.onEscapePressed: root.open = false
                            Keys.onDownPressed: flick.scrollBy(1)
                            Keys.onUpPressed: flick.scrollBy(-1)
                            Keys.onTabPressed: flick.jumpGroup(1)
                            Keys.onBacktabPressed: flick.jumpGroup(-1)
                            Keys.onPressed: event => {
                                if (event.key === Qt.Key_PageDown) {
                                    flick.scrollBy(4);
                                    event.accepted = true;
                                } else if (event.key === Qt.Key_PageUp) {
                                    flick.scrollBy(-4);
                                    event.accepted = true;
                                }
                            }
                            Txt {
                                anchors.fill: parent
                                visible: search.text === ""
                                text: "Search all shortcuts…   e.g. upload · discord mute · workspace · vimium"
                                color: Theme.textFaint
                                font.pixelSize: 19
                                font.weight: Font.Normal
                            }
                        }
                        Txt {
                            id: countTxt
                            anchors.right: parent.right
                            anchors.rightMargin: 18
                            anchors.verticalCenter: parent.verticalCenter
                            text: root.shownCount + (root.shownCount === 1 ? " shortcut" : " shortcuts")
                            color: Theme.textFaint
                            font.pixelSize: 12
                            font.weight: Font.Normal
                        }
                    }

                    // Karten in Spalten
                    Flickable {
                        id: flick

                        function scrollBy(steps: real): void {
                            const max = Math.max(0, contentHeight - height);
                            contentY = Math.max(0, Math.min(max, contentY + steps * 120));
                        }
                        // Tab / Shift+Tab: zur nächsten / vorigen Gruppe (App) springen
                        function jumpGroup(dir: int): void {
                            const ys = [];
                            for (let i = 0; i < groupRep.count; i++) {
                                const it = groupRep.itemAt(i);
                                if (it)
                                    ys.push(it.y);
                            }
                            if (!ys.length)
                                return;
                            const max = Math.max(0, contentHeight - height);
                            const cur = Math.min(contentY, max);
                            let to = dir > 0 ? ys.find(y => y > cur + 4) : ys.slice().reverse().find(y => y < cur - 4);
                            if (to === undefined)
                                to = dir > 0 ? ys[0] : ys[ys.length - 1];
                            contentY = Math.max(0, Math.min(max, to));
                        }

                        width: parent.width
                        height: Math.max(80, Math.min(content.height, win.maxContentH))
                        contentWidth: width
                        contentHeight: content.height
                        interactive: false
                        clip: contentHeight > height
                        boundsBehavior: Flickable.StopAtBounds
                        Behavior on height { NumberAnimation { duration: Theme.fade; easing.type: Easing.OutCubic } }

                        Column {
                            id: content
                            width: flick.width
                            spacing: 26

                            Repeater {
                                id: groupRep
                                model: root.groups

                                // eine Gruppe = Kopf (App-Name) + Karten in Spalten
                                Column {
                                    id: groupItem
                                    required property var modelData
                                    readonly property var columns: root.distribute(modelData.cats, win.ncols, root.mediaOpen)
                                    width: content.width
                                    spacing: 12

                                    Row {
                                        spacing: 10
                                        height: 28

                                        Txt {
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: groupItem.modelData.title
                                            color: groupItem.modelData.active ? Theme.accentText : Theme.text
                                            font.pixelSize: 17
                                            font.weight: Font.DemiBold
                                        }
                                        Rectangle {
                                            visible: groupItem.modelData.active
                                            anchors.verticalCenter: parent.verticalCenter
                                            width: focusTxt.implicitWidth + 16
                                            height: 22
                                            radius: 11
                                            color: Theme.accentFill
                                            Txt {
                                                id: focusTxt
                                                anchors.centerIn: parent
                                                text: "focused app"
                                                color: Theme.accentText
                                                font.pixelSize: 11
                                                font.weight: Font.Medium
                                            }
                                        }
                                        Txt {
                                            visible: text !== ""
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: groupItem.modelData.about
                                            color: Theme.textFaint
                                            font.pixelSize: 12
                                            font.weight: Font.Normal
                                            elide: Text.ElideRight
                                            width: Math.min(implicitWidth, content.width - 320)
                                        }
                                    }

                                    Row {
                                        spacing: win.gap

                                        Repeater {
                                            model: groupItem.columns

                                            Column {
                                                id: colItem
                                                required property var modelData
                                                width: win.colW
                                                spacing: win.gap

                                                Repeater {
                                                    model: colItem.modelData
                                                    KeyCard {
                                                        width: win.colW
                                                        hot: groupItem.modelData.active
                                                        onToggled: root.mediaOpen = !root.mediaOpen
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // Leer-/Ladezustand
                        Txt {
                            anchors.horizontalCenter: parent.horizontalCenter
                            y: 24
                            visible: root.groups.length === 0
                            text: !Keybinds.loaded ? "Reading key bindings…" : Keybinds.failed ? "Could not read key bindings" : "Nothing matches “" + root.query + "”"
                            color: Theme.textFaint
                            font.pixelSize: 14
                            font.weight: Font.Normal
                        }

                        WheelScroll {
                            flick: flick
                        }
                    }

                    Txt {
                        id: hint
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        text: "Type to search everything · ↑↓ PgUp PgDn scroll · Tab next app · Esc closes · apps: config/appkeys/"
                        color: Theme.textFaint
                        font.pixelSize: 12
                        font.weight: Font.Normal
                    }
                }
            }
        }
    }
}

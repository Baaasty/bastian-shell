import QtQuick
import Quickshell
import Quickshell.Wayland
import org.kde.kirigami as Kirigami
import "resources-sort.js" as RS
import qs.config
import qs.services
import qs.components

// Ressourcen-Popout unter den Technik-Chips (Klick öffnet, Klick daneben / Esc schließt), angelehnt an die „Processes“-Ansicht:
// Titelzeile mit Reitern All / User / System und Suche, Systemkarte (Rechner, OS, Uptime, Ringe CPU und Memory),
// darunter die Tabelle Name · CPU · Memory · PID (Spaltenkopf = sortieren, aktive Spalte als Pille mit Pfeil).
// Eine Zeile = eine Anwendung (viele Prozesse → Gruppe mit Summe); Klick klappt sie auf (Befehl mit Kopieren, Details, Einzelprozesse).
// End (SIGTERM) und Force (SIGKILL) nur für eigene Prozesse, immer mit schlanker Rückfrage in der aufgeklappten Zeile.
// Sortier-/Abgleichlogik: resources-sort.js (mit Test: scripts/tests/resources-sort-test.js). Daten: Procs.qml / scripts/procs (alle 2 s, nur solange offen).
PopupWindow {
    id: pop

    property var barWindow
    property Item chip
    readonly property int cardW: 680
    readonly property int cardH: 720
    readonly property int quick: Math.round(Theme.fade * 0.6)
    readonly property int rowH: 44
    // Spalten von rechts: PID, Memory, CPU (Name nimmt den Rest); chevW = rechter Innenrand. Aufklapp-Pfeil und Symbol stehen vorn.
    readonly property int chevW: 16
    readonly property int nameX: 72
    readonly property int pidW: 66
    readonly property int memW: 92
    readonly property int cpuW: 76
    property real appear: 0
    property real _closedAt: 0

    property string tab: "all"                         // all | user | system
    property string sortKey: "cpu"                     // name | cpu | rss | pid
    property bool sortAsc: false
    property string expandedKey: ""
    property var confirm: null                         // { rowKey, sig, title, hint, warn, targets, label }
    property string note: ""
    property var curKeys: []                           // Spiegel der Schlüssel in `rows` (für resources-sort.js)

    readonly property var protectedNames: ["Hyprland", "start-hyprland", "qs", "quickshell", "systemd", "dbus-broker", "pipewire", "wireplumber", "plasmalogin"]

    anchor.window: barWindow
    anchor.edges: Edges.Bottom | Edges.Right
    anchor.gravity: Edges.Bottom | Edges.Left
    grabFocus: true
    implicitWidth: cardW
    implicitHeight: cardH + 8
    color: "transparent"
    visible: false
    mask: Region { item: card }

    // ---------- Öffnen / Schließen ----------
    function placeUnderBar(): void {
        if (!chip)
            return;
        anchor.rect.x = Math.round(chip.mapToItem(null, chip.width, 0).x) - 1;
        anchor.rect.y = Theme.barMargin + Theme.barHeight + Theme.windowGap - 1;
        anchor.rect.width = 1;
        anchor.rect.height = 1;
    }
    function open(): void {
        if (visible)
            return;
        placeUnderBar();
        search.input.text = "";
        tab = "all";                // jedes Öffnen beginnt beim ersten Tab
        expandedKey = "";
        confirm = null;
        note = "";
        rows.clear();
        curKeys = [];
        appear = 0;
        visible = true;
        appearAnim.restart();
    }
    function close(): void {
        guard.intended = true;
        visible = false;
    }
    // Klick auf den Chip bei offenem Popout: der Compositor schließt es schon beim Drücken, der Klick soll es nicht gleich wieder öffnen
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
            Popouts.claim("resources");
            search.input.forceActiveFocus();
        } else {
            Popouts.release("resources");
            _closedAt = Date.now();
            appearAnim.stop();
        }
    }
    // nur ein Bar-Popout gleichzeitig
    Connections {
        target: Popouts
        function onCurrentChanged() {
            if (Popouts.current !== "resources" && pop.visible)
                pop.visible = false;
        }
    }
    // Daten nur, solange offen
    Binding {
        target: Procs
        property: "active"
        value: pop.visible
    }
    Connections {
        target: Procs
        function onSampled() { pop.rebuild(false); }
        function onKilled(text, ok) {
            pop.note = text;
            noteTimer.restart();
        }
    }
    Timer {
        id: noteTimer
        interval: 5000
        onTriggered: pop.note = ""
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
        Region { item: pop.appear > 0.4 ? card : null; radius: Theme.radiusLg }
    }

    // ---------- Liste: filtern, sortieren (RS), im ListModel abgleichen (kein Neuaufbau -> Scrollstand bleibt) ----------
    function matches(r: var, q: string): bool {
        if (r.name.toLowerCase().includes(q) || r.user.toLowerCase().includes(q) || String(r.pid).includes(q) || (r.cmd && r.cmd.toLowerCase().includes(q)))
            return true;
        if (r.kids)
            for (let i = 0; i < r.kids.length; i++) {
                const k = r.kids[i];
                if (String(k.pid).includes(q) || k.name.toLowerCase().includes(q) || (k.cmd && k.cmd.toLowerCase().includes(q)))
                    return true;
            }
        return false;
    }
    function roleOf(r: var): var {
        return {
            key: r.key, name: r.name, user: r.user, own: r.own, pid: r.pid, ppid: r.ppid, n: r.n, cpu: r.cpu, rss: r.rss,
            threads: r.threads, pstate: r.state, start: r.start, st: r.st, cmd: r.cmd || "",
            // Einzelprozesse der Gruppe nur für die aufgeklappte Zeile, gleich sortiert wie die Liste
            kidsJson: r.kids && r.key === expandedKey ? JSON.stringify(pop.kidsOf(r)) : ""
        };
    }
    // Solange eine Zeile aufgeklappt ist, bleibt die Reihenfolge stehen (Liste und Einzelprozesse der Gruppe): nur die
    // Werte laufen weiter, sonst springt die Zeile beim Beenden weg. Neue Prozesse kommen ans Ende. Zuklappen,
    // Tab, Sortierung oder Suche ändern = wieder normal sortiert.
    readonly property bool frozen: expandedKey !== ""
    property var kidOrder: []                           // PIDs der aufgeklappten Gruppe in eingefrorener Reihenfolge
    function kidsOf(r: var): var {
        const list = frozen && kidOrder.length ? RS.stable(r.kids, kidOrder, sortKey, sortAsc, k => k.pid) : RS.sorted(r.kids, sortKey, sortAsc);
        kidOrder = list.map(k => k.pid);
        return list;
    }
    function rebuild(resort: bool): void {
        const q = search.input.text.trim().toLowerCase();
        const arr = Procs.rows.filter(r => (tab === "all" || (tab === "user") === r.own) && (q === "" || matches(r, q)));
        if (resort)
            kidOrder = [];
        RS.sync(rows, curKeys, frozen && !resort ? RS.stable(arr, curKeys, sortKey, sortAsc, r => r.key) : RS.sorted(arr, sortKey, sortAsc), roleOf);
    }
    ListModel {
        id: rows
    }
    onTabChanged: rebuild(true)
    onSortKeyChanged: rebuild(true)
    onSortAscChanged: rebuild(true)
    // Aufklappen friert den jetzigen Stand ein (kein Sprung beim Klick), Zuklappen sortiert wieder
    onExpandedKeyChanged: {
        kidOrder = [];
        rebuild(expandedKey === "");
    }

    function setSearch(t: string): void {
        search.input.text = t;
    }
    // erster Klick: CPU/Memory größte zuerst, Name/PID aufsteigend; zweiter Klick dreht um
    function sortBy(key: string): void {
        if (sortKey === key) {
            sortAsc = !sortAsc;
        } else {
            sortAsc = key === "name" || key === "pid";
            sortKey = key;
        }
    }

    // ---------- Beenden mit Rückfrage (in der aufgeklappten Zeile) ----------
    function ask(sig: string, name: string, targets: var, rowKey: string): void {
        if (targets.length === 0)
            return;
        const many = targets.length > 1 ? " (" + targets.length + " processes)" : "";
        confirm = {
            rowKey: rowKey,
            sig: sig,
            title: (sig === "KILL" ? "Force quit " : "End ") + "\"" + name + "\"" + many + "?",
            hint: sig === "KILL" ? "Stops it right away, without asking. Unsaved work is lost." : "Asks it to quit. Unsaved work may be lost.",
            warn: protectedNames.includes(name) ? "This belongs to your desktop session." : "",
            targets: targets,
            label: name + many
        };
    }
    function askRow(sig: string, name: string, pid: int, st: real, kidsJson: string, n: int, rowKey: string): void {
        if (n > 1 && kidsJson !== "")
            ask(sig, name, JSON.parse(kidsJson).map(k => ({ pid: k.pid, st: k.st })), rowKey);
        else
            ask(sig, name, [{ pid: pid, st: st }], rowKey);
    }
    function doConfirm(): void {
        if (!confirm)
            return;
        Procs.kill(confirm.sig, confirm.targets, confirm.label);
        confirm = null;
    }

    // ---------- Formate ----------
    function fmtMem(b: real): string {
        if (b >= 1073741824)
            return (b / 1073741824).toFixed(1) + " GB";
        if (b >= 1048576)
            return Math.round(b / 1048576) + " MB";
        return Math.round(b / 1024) + " KB";
    }
    function fmtCpu(c: real): string {
        if (c < 0.05)
            return "0%";
        return (c < 10 ? c.toFixed(1) : Math.round(c)) + "%";
    }
    function fmtUp(s: int): string {
        const m = Math.floor(s / 60), h = Math.floor(m / 60), d = Math.floor(h / 24);
        if (d > 0)
            return d + " d " + (h % 24) + " h";
        if (h > 0)
            return h + " h " + (m % 60) + " min";
        return m + " min";
    }
    function fmtStart(ts: real): string {
        const d = new Date(ts * 1000);
        return ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"][d.getMonth()] + " " + d.getDate()
            + ", " + String(d.getHours()).padStart(2, "0") + ":" + String(d.getMinutes()).padStart(2, "0");
    }
    // Stufen für die Wert-Pillen: 0 ruhig, 1 amber, 2 rot
    function cpuLevel(c: real): int {
        return c >= 150 ? 2 : c >= 50 ? 1 : 0;
    }
    function memLevel(b: real): int {
        return b >= 4294967296 ? 2 : b >= 1610612736 ? 1 : 0;
    }
    // ---------- App-Symbole ----------
    // Jede Zeile bekommt eins: 1) Desktop-Eintrag (Index über Datei-ID, Fensterklasse, Programm im Exec, Name), 2) Symbol gleichen Namens im
    // Icon-Theme, 3) sonst ein Symbol nach Art (Terminal, Browser, Skript, Kernel, Dienst, Zahnrad für fremde Prozesse).
    // Ergebnis "icon:<theme-name>" (Kirigami) oder "glyph:<Material-Symbol>"; pro Programmname einmal gemerkt (kein Flackern beim 2-s-Update).
    // DesktopEntries lädt erst nach dem ersten Zugriff -> der Index wird gebaut, sobald die Liste da ist (iconRev meldet es den Zeilen).
    property var iconIndex: ({})
    property var iconCache: ({})
    property int iconRev: 0
    readonly property var wrappers: ["env", "flatpak", "sh", "bash", "kstart", "kstart5", "systemd-run", "gtk-launch", "run", "setsid", "nohup", "uwsp"]

    function baseName(path: string): string {
        const t = String(path).split(" ")[0];
        return t.substring(t.lastIndexOf("/") + 1).toLowerCase();
    }
    function buildIndex(): void {
        const apps = DesktopEntries.applications.values;
        if (!apps || apps.length === 0)
            return;
        const idx = {};
        const add = (k, icon) => {
            if (k && idx[k] === undefined)
                idx[k] = icon;
        };
        for (const e of apps) {
            if (!e.icon || !(e.icon.startsWith("/") || Quickshell.iconPath(e.icon, true) !== ""))
                continue;
            const id = e.id.toLowerCase().replace(/\.desktop$/, "");
            add(id, e.icon);
            add(id.substring(id.lastIndexOf(".") + 1), e.icon);
            if (e.startupClass)
                add(e.startupClass.toLowerCase(), e.icon);
            const c = e.command || [];
            for (let i = 0; i < c.length; i++) {
                const b = baseName(c[i]);
                if (b && !b.startsWith("-") && !b.includes("=") && !wrappers.includes(b)) {
                    add(b, e.icon);
                    break;
                }
            }
            add((e.name || "").toLowerCase(), e.icon);
        }
        iconIndex = idx;
        iconCache = {};
        iconRev++;
    }
    Connections {
        target: DesktopEntries.applications
        function onValuesChanged() { pop.buildIndex(); }
    }
    Component.onCompleted: buildIndex()

    // Symbol nach Art, wenn nichts aufgelöst wurde
    function genericGlyph(name: string, cmd: string, own: bool): string {
        const n = name.toLowerCase();
        if (/^(bash|zsh|fish|sh|dash|nu|tmux|screen)$/.test(n) || n.endsWith(".sh"))
            return "terminal";
        if (/^(python[\d.]*|node|bun|deno|perl|ruby|java)$/.test(n) || /\.(py|js|ts|rb|pl)$/.test(n))
            return "code";
        if (/chrome|chromium|firefox|helium|brave|vivaldi|webkit/.test(n))
            return "public";
        if (cmd === "")
            return "memory";                                   // Kernel-Thread
        if (/^(systemd|dbus|polkit|udev|pipewire|wireplumber|pulse|avahi|cups|chrony|crond|auditd|NetworkManager|ModemManager)/i.test(n) || /d$/.test(n))
            return own ? "settings_suggest" : "settings";
        return own ? "deployed_code" : "settings";
    }
    function iconFor(name: string, cmd: string, own: bool): string {
        iconRev;                                                // Abhängigkeit: nach dem Aufbau des Index neu bewerten
        const hit = iconCache[name];
        if (hit !== undefined)
            return hit;
        const lower = name.toLowerCase();
        let icon = iconIndex[lower] || iconIndex[baseName(cmd)];
        if (!icon && Quickshell.iconPath(lower, true) !== "")
            icon = lower;
        const res = icon ? "icon:" + icon : "glyph:" + genericGlyph(name, cmd, own);
        // erst merken, wenn der Index da ist (sonst wäre ein früher Fehlgriff dauerhaft)
        if (Object.keys(iconIndex).length > 0)
            iconCache[name] = res;
        return res;
    }

    // ---------- Bausteine ----------
    // Textknopf (End / Force / Cancel / Copy)
    // Knopf = der gemeinsame Button (Design-System light); tone bleibt die Sprache dieses Popouts
    component Btn: Button {
        property string tone: "plain"                  // plain | on | danger | primary
        kind: tone === "danger" ? "danger" : tone === "primary" ? "primary" : tone === "on" ? "on" : "secondary"
    }

    // Spaltenkopf: aktive Sortierspalte als Pille mit Pfeil; align = left | center | right
    component HeadCell: Item {
        id: hc
        property string text
        property string key
        property string align: "center"
        readonly property bool sorted: pop.sortKey === key
        height: 28
        Rectangle {
            id: hcPill
            anchors.verticalCenter: parent.verticalCenter
            x: hc.align === "left" ? 0 : hc.align === "right" ? hc.width - width : (hc.width - width) / 2
            width: hcRow.implicitWidth + 18
            height: 24
            radius: 12
            color: hc.sorted ? Theme.accentFill : hcArea.containsMouse ? Theme.surfaceSunken : "transparent"
            Behavior on color { ColorAnimation { duration: pop.quick } }
            Row {
                id: hcRow
                anchors.centerIn: parent
                spacing: 3
                Txt {
                    anchors.verticalCenter: parent.verticalCenter
                    text: hc.text
                    color: hc.sorted ? Theme.accentText : Theme.textFaint
                    font.pixelSize: Theme.fontSm
                    font.weight: Font.DemiBold
                }
                Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: hc.sorted
                    name: pop.sortAsc ? "arrow_upward" : "arrow_downward"
                    size: 13
                    color: Theme.accentText
                }
            }
        }
        MouseArea {
            id: hcArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: pop.sortBy(hc.key)
        }
    }

    // Wert-Pille (CPU / Memory): ruhig deckend, ab Schwelle amber, dann rot
    component ValuePill: Rectangle {
        property string text
        property int level: 0
        property bool onSunken: false
        width: 66
        height: 24
        radius: 12
        color: level === 2 ? Theme.flat(Qt.alpha(Theme.error, 0.3)) : level === 1 ? Theme.flat(Qt.alpha(Theme.warning, 0.22)) : onSunken ? Theme.surfaceRaised : Theme.surfaceSunken
        MonoTxt {
            anchors.centerIn: parent
            text: parent.text
            font.pixelSize: Theme.fontSm
            color: parent.level === 2 ? Theme.text : parent.level === 1 ? Theme.warning : Theme.textMuted
        }
    }

    // Faktenzeile in der aufgeklappten Zeile
    component Fact: Row {
        property string label
        property string value
        spacing: 6
        Txt {
            text: parent.label
            color: Theme.textFaint
            font.pixelSize: Theme.fontSm
            font.weight: Font.Normal
        }
        MonoTxt {
            text: parent.value
            color: Theme.textMuted
            font.pixelSize: Theme.fontSm
        }
    }

    // ---------- Karte ----------
    Glass {
        id: card
        // offen bis zum Weghovern (PopoutGuard.qml)
        PopoutGuard { id: guard; popout: pop; chip: pop.chip; name: "resources" }
        // Tastatur: Pfeile/Tab/Enter, Bar-Modus (Super+Leertaste, KeyNav.qml)
        Keys.onPressed: e => nav.key(e)
        KeyNav { id: nav; root: card; scope: null; popout: pop; guard: guard; name: "resources" }
        width: pop.cardW
        height: pop.cardH
        strong: true
        opacity: pop.appear
        transform: Translate { y: (1 - pop.appear) * -6 }

        // ---------- Titelzeile: Symbol, Titel, Reiter, Suche ----------
        Item {
            id: titleRow
            x: 24
            y: 20
            width: parent.width - 48
            height: 36

            Row {
                id: titleLeft
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8
                PopoutTitle {
                    anchors.verticalCenter: parent.verticalCenter
                    icon: "monitor_heart"
                    text: "Processes"
                }
            }
            Row {
                id: tabs
                anchors.left: titleLeft.right
                anchors.leftMargin: 18
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2
                Tab { text: "All"; current: pop.tab === "all"; onPicked: pop.tab = "all" }
                Tab { text: "User"; current: pop.tab === "user"; onPicked: pop.tab = "user" }
                Tab { text: "System"; current: pop.tab === "system"; onPicked: pop.tab = "system" }
            }

            Rectangle {
                id: search
                property alias input: ti
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: 214
                height: 36
                radius: Theme.radiusMd
                color: Theme.surfaceSunken
                border.width: 1
                border.color: ti.activeFocus ? Qt.alpha(Theme.accent, 0.5) : "transparent"
                Behavior on border.color { ColorAnimation { duration: pop.quick } }
                Icon {
                    id: searchIcon
                    x: 12
                    anchors.verticalCenter: parent.verticalCenter
                    name: "search"
                    size: 17
                    color: Theme.textFaint
                }
                TextInput {
                    id: ti
                    anchors.left: searchIcon.right
                    anchors.leftMargin: 8
                    anchors.right: clearBtn.left
                    anchors.rightMargin: 6
                    anchors.verticalCenter: parent.verticalCenter
                    color: Theme.text
                    selectionColor: Theme.accentSoft
                    selectedTextColor: Theme.text
                    font.family: Theme.fontUi
                    font.pixelSize: Theme.fontMd
                    clip: true
                    onTextChanged: pop.rebuild(true)
                    Keys.onEscapePressed: {
                        if (pop.confirm)
                            pop.confirm = null;
                        else if (text !== "")
                            text = "";
                        else
                            pop.close();
                    }
                    Txt {
                        anchors.fill: parent
                        visible: ti.text === ""
                        text: "Search…"
                        color: Theme.textFaint
                        font.pixelSize: Theme.fontMd
                        font.weight: Font.Normal
                    }
                }
                Icon {
                    id: clearBtn
                    anchors.right: parent.right
                    anchors.rightMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    visible: ti.text !== ""
                    name: "close"
                    size: 16
                    color: Theme.textFaint
                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -6
                        cursorShape: Qt.PointingHandCursor
                        onClicked: ti.text = ""
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

        // ---------- Systemkarte ----------
        Rectangle {
            id: sys
            x: 24
            y: titleRow.y + titleRow.height + 16
            width: parent.width - 48
            // Höhe aus dem Inhalt (Ringe + Beschriftung), oben und unten gleich viel Luft
            height: Math.max(rings.height, avatar.height) + 40
            radius: Theme.radiusLg
            color: Theme.surfaceSunken

            Rectangle {
                id: avatar
                x: 18
                anchors.verticalCenter: parent.verticalCenter
                width: 56
                height: 56
                radius: Theme.radiusMd
                color: Theme.accentFill
                Icon {
                    anchors.centerIn: parent
                    name: "computer"
                    size: 30
                    color: Theme.accentText
                }
            }
            Column {
                anchors.left: avatar.right
                anchors.leftMargin: 16
                anchors.right: rings.left
                anchors.rightMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                spacing: 3
                Txt {
                    width: parent.width
                    text: Procs.host || "…"
                    font.pixelSize: Theme.fontXl
                    font.weight: Font.DemiBold
                }
                Txt {
                    width: parent.width
                    text: Procs.osName.replace(/\s*\(.*\)\s*$/, "")
                    color: Theme.textMuted
                    font.pixelSize: Theme.fontSm
                    font.weight: Font.Normal
                }
                MonoTxt {
                    width: parent.width
                    text: "up " + pop.fmtUp(Procs.uptime) + " · " + Procs.procCount + " procs"
                    color: Theme.textFaint
                    font.pixelSize: Theme.fontSm
                    elide: Text.ElideRight
                }
            }

            // Ringblock mit fester Breite: jeder Ring hat seine eigene einzeilige Beschriftung (elidiert statt überlaufend);
            // Zahl in der Ringmitte und in der Beschriftung kommen aus derselben Variable (usedGb)
            Row {
                id: rings
                readonly property string usedGb: (Procs.memUsed / 1073741824).toFixed(1)
                anchors.right: parent.right
                anchors.rightMargin: 20
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8

                Column {
                    width: 112
                    spacing: 5
                    Ring {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 64
                        height: 64
                        stroke: 6
                        value: Procs.cpu / 100
                        color: Procs.cpu >= 85 ? Theme.warning : Theme.accent
                        track: Theme.surface
                        MonoTxt {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: Math.round(Procs.cpu) + "%"
                            font.pixelSize: Theme.fontLg
                            font.weight: Font.DemiBold
                        }
                    }
                    MonoTxt {
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideRight
                        text: "CPU" + (Cpu.temp >= 0 ? " · " + Cpu.temp + "°" : "")
                        color: Cpu.temp >= Config.cpuHot ? Theme.warning : Theme.textFaint
                        font.pixelSize: Theme.fontXs
                    }
                }
                Column {
                    width: 152
                    spacing: 5
                    Ring {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 64
                        height: 64
                        stroke: 6
                        value: Procs.memTotal > 0 ? Procs.memUsed / Procs.memTotal : 0
                        color: Procs.memTotal > 0 && Procs.memUsed / Procs.memTotal >= 0.9 ? Theme.warning : Theme.woodLight
                        track: Theme.surface
                        MonoTxt {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: rings.usedGb
                            font.pixelSize: Theme.fontLg
                            font.weight: Font.DemiBold
                        }
                    }
                    MonoTxt {
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideRight
                        text: "Memory · " + rings.usedGb + " of " + Math.round(Procs.memTotal / 1073741824) + " GB"
                        color: Theme.textFaint
                        font.pixelSize: Theme.fontXs
                    }
                    // Zusatz (Cache = frei verfügbar, Swap nur wenn genutzt) klein darunter, nur beim Memory-Ring
                    MonoTxt {
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideRight
                        text: "+" + (Procs.memCache / 1073741824).toFixed(0) + " cache"
                            + (Procs.swapUsed > 104857600 ? " · " + (Procs.swapUsed / 1073741824).toFixed(1) + " swap" : "")
                        color: Qt.alpha(Theme.textFaint, 0.8)
                        font.pixelSize: Theme.fontXs
                    }
                }
            }
        }

        // ---------- Spaltenköpfe ----------
        Item {
            id: cols
            x: 24
            y: sys.y + sys.height + 14
            width: parent.width - 48
            height: 28

            HeadCell {
                x: pop.nameX - 9
                width: 100
                text: "Name"
                key: "name"
                align: "left"
            }
            HeadCell {
                x: parent.width - pop.chevW - pop.pidW
                width: pop.pidW
                text: "PID"
                key: "pid"
                align: "right"
            }
            HeadCell {
                x: parent.width - pop.chevW - pop.pidW - pop.memW
                width: pop.memW
                text: "Memory"
                key: "rss"
            }
            HeadCell {
                x: parent.width - pop.chevW - pop.pidW - pop.memW - pop.cpuW
                width: pop.cpuW
                text: "CPU"
                key: "cpu"
            }
        }

        // ---------- Liste ----------
        ListView {
            id: list
            x: 24
            y: cols.y + cols.height + 6
            width: parent.width - 48
            height: footer.y - y - 6
            clip: true
            interactive: false
            model: rows
            boundsBehavior: Flickable.StopAtBounds
            cacheBuffer: 400

            delegate: Item {
                id: d

                required property int index
                required property string key
                required property string name
                required property string user
                required property bool own
                required property int pid
                required property int ppid
                required property int n
                required property real cpu
                required property real rss
                required property int threads
                required property string pstate
                required property real start
                required property real st
                required property string cmd
                required property string kidsJson

                readonly property bool open: pop.expandedKey === key
                readonly property var kids: kidsJson !== "" ? JSON.parse(kidsJson) : []
                readonly property int shownKids: Math.min(kids.length, 8)

                width: ListView.view.width
                height: pop.rowH + 2 + (open ? detail.contentH + 18 : 0)

                // Zeilenfläche: nur beim Drüberfahren / aufgeklappt hervorgehoben, keine Linien
                Rectangle {
                    x: 0
                    y: 1
                    width: parent.width
                    height: d.height - 2
                    radius: Theme.radiusMd
                    color: d.open ? Theme.surfaceSunken : rowArea.containsMouse ? Theme.raise : "transparent"
                    Behavior on color { ColorAnimation { duration: pop.quick } }
                }
                MouseArea {
                    id: rowArea
                    y: 1
                    width: parent.width
                    height: pop.rowH
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: pop.expandedKey = d.open ? "" : d.key
                }

                // Aufklapp-Pfeil vorn: ▸ dreht beim Aufklappen nach ▾ (ganze Zeile ist klickbar)
                Icon {
                    x: 10
                    y: 1 + (pop.rowH - height) / 2
                    width: 22
                    height: 22
                    name: "chevron_right"
                    size: 20
                    color: d.open ? Theme.textMuted : Theme.textFaint
                    rotation: d.open ? 90 : 0
                    Behavior on rotation { NumberAnimation { duration: pop.quick; easing.type: Easing.OutCubic } }
                }
                // App-Symbol: feste 24-px-Kachel in jeder Zeile (Desktop-Symbol oder Symbol nach Art)
                Item {
                    x: 38
                    y: 1 + (pop.rowH - 24) / 2
                    width: 24
                    height: 24
                    readonly property string res: pop.iconFor(d.name, d.cmd, d.own)
                    Kirigami.Icon {
                        anchors.fill: parent
                        visible: parent.res.startsWith("icon:")
                        source: parent.res.startsWith("icon:") ? parent.res.substring(5) : ""
                        fallback: "application-x-executable"
                    }
                    Icon {
                        anchors.fill: parent
                        visible: parent.res.startsWith("glyph:")
                        name: parent.res.startsWith("glyph:") ? parent.res.substring(6) : "deployed_code"
                        size: 22
                        color: Theme.textFaint
                    }
                }
                Row {
                    x: pop.nameX
                    y: 1
                    height: pop.rowH
                    width: parent.width - pop.nameX - pop.chevW - pop.pidW - pop.memW - pop.cpuW - 8
                    spacing: 8
                    clip: true
                    Txt {
                        anchors.verticalCenter: parent.verticalCenter
                        width: Math.min(implicitWidth, parent.width - (cnt.visible ? cnt.width + 8 : 0))
                        text: d.name
                        color: d.own ? Theme.text : Theme.textMuted
                        font.weight: Font.Medium
                    }
                    MonoTxt {
                        id: cnt
                        anchors.verticalCenter: parent.verticalCenter
                        visible: d.n > 1
                        text: "×" + d.n
                        color: Theme.textFaint
                        font.pixelSize: Theme.fontSm
                    }
                }
                ValuePill {
                    x: d.width - pop.chevW - pop.pidW - pop.memW - pop.cpuW + (pop.cpuW - width) / 2
                    y: 1 + (pop.rowH - height) / 2
                    text: pop.fmtCpu(d.cpu)
                    level: pop.cpuLevel(d.cpu)
                    onSunken: d.open
                }
                ValuePill {
                    x: d.width - pop.chevW - pop.pidW - pop.memW + (pop.memW - width) / 2
                    y: 1 + (pop.rowH - height) / 2
                    width: 76
                    text: pop.fmtMem(d.rss)
                    level: pop.memLevel(d.rss)
                    onSunken: d.open
                }
                MonoTxt {
                    x: d.width - pop.chevW - pop.pidW
                    y: 1
                    width: pop.pidW - 4
                    height: pop.rowH
                    horizontalAlignment: Text.AlignRight
                    text: d.pid
                    color: Theme.textFaint
                    font.pixelSize: Theme.fontSm
                }
                // ---------- aufgeklappt ----------
                Loader {
                    id: detail
                    active: d.open
                    x: 0
                    y: pop.rowH + 4
                    width: d.width
                    readonly property real contentH: item ? item.implicitHeight : 0
                    sourceComponent: Column {
                        id: dc
                        spacing: 12
                        property bool copied: false

                        // Befehlszeile mit Kopieren
                        Item {
                            x: pop.nameX
                            width: parent.width - pop.nameX - 20
                            height: cmdBox.y + cmdBox.height
                            visible: d.cmd !== ""
                            Txt {
                                text: "Full Command"
                                color: Theme.textFaint
                                font.pixelSize: Theme.fontSm
                                font.weight: Font.DemiBold
                            }
                            Btn {
                                anchors.right: parent.right
                                y: -4
                                small: true
                                icon: dc.copied ? "check" : "content_copy"
                                text: dc.copied ? "Copied" : "Copy"
                                onClicked: {
                                    Quickshell.execDetached(["wl-copy", "--", d.cmd]);
                                    dc.copied = true;
                                    copyTimer.restart();
                                }
                                Timer {
                                    id: copyTimer
                                    interval: 1500
                                    onTriggered: dc.copied = false
                                }
                            }
                            Rectangle {
                                id: cmdBox
                                y: 26
                                width: parent.width
                                height: cmdTxt.implicitHeight + 20
                                radius: Theme.radiusSm
                                color: Theme.surfaceRaised
                                Txt {
                                    id: cmdTxt
                                    x: 12
                                    y: 10
                                    width: parent.width - 24
                                    text: d.cmd
                                    color: Theme.textMuted
                                    font.family: Theme.fontMono
                                    font.pixelSize: Theme.fontSm
                                    font.weight: Font.Normal
                                    wrapMode: Text.WrapAnywhere
                                    maximumLineCount: 4
                                    elide: Text.ElideRight
                                }
                            }
                        }

                        // Fakten
                        Flow {
                            x: pop.nameX
                            width: parent.width - pop.nameX - 20
                            spacing: 22
                            Fact { label: "PPID"; value: String(d.ppid) }
                            Fact { label: "Mem"; value: (Procs.memTotal > 0 ? d.rss / Procs.memTotal * 100 : 0).toFixed(1) + "%" }
                            Fact { label: d.n > 1 ? "Processes" : "Threads"; value: d.n > 1 ? d.n + " · " + d.threads + " threads" : String(d.threads) }
                            Fact { label: "State"; value: d.pstate }
                            Fact { label: "Started"; value: pop.fmtStart(d.start) }
                            Fact { label: "User"; value: d.user }
                        }

                        // Einzelprozesse der Gruppe (in der Reihenfolge der Liste)
                        Column {
                            width: parent.width
                            visible: d.kids.length > 0
                            Repeater {
                                model: d.shownKids
                                Item {
                                    id: kr
                                    required property int index
                                    readonly property var kid: d.kids[index] || ({ pid: 0, st: 0, name: "", cmd: "", cpu: 0, rss: 0 })
                                    width: parent.width
                                    height: 32

                                    Rectangle {
                                        x: pop.nameX - 8
                                        width: parent.width - pop.nameX
                                        height: parent.height
                                        radius: Theme.radiusSm
                                        color: kArea.containsMouse ? Theme.surfaceRaised : "transparent"
                                    }
                                    MouseArea {
                                        id: kArea
                                        anchors.fill: parent
                                        hoverEnabled: true
                                    }
                                    Txt {
                                        x: pop.nameX
                                        width: 90
                                        height: parent.height
                                        text: kr.kid.name
                                        color: Theme.textMuted
                                        font.pixelSize: Theme.fontSm
                                        font.weight: Font.Normal
                                    }
                                    Txt {
                                        x: pop.nameX + 96
                                        width: parent.width - pop.nameX - 96 - pop.chevW - pop.pidW - pop.memW - pop.cpuW - 8 - (actions.visible ? actions.width + 8 : 0)
                                        height: parent.height
                                        text: kr.kid.cmd
                                        color: Theme.textFaint
                                        font.family: Theme.fontMono
                                        font.pixelSize: Theme.fontXs
                                        font.weight: Font.Normal
                                    }
                                    // End / Force pro Prozess, nur beim Drüberfahren und nur für eigene
                                    Row {
                                        id: actions
                                        x: parent.width - pop.chevW - pop.pidW - pop.memW - pop.cpuW - width - 8
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: 4
                                        visible: kArea.containsMouse && d.own
                                        Btn {
                                            small: true
                                            text: "End"
                                            onClicked: pop.ask("TERM", kr.kid.name + " " + kr.kid.pid, [{ pid: kr.kid.pid, st: kr.kid.st }], d.key)
                                        }
                                        Btn {
                                            small: true
                                            text: "Force"
                                            onClicked: pop.ask("KILL", kr.kid.name + " " + kr.kid.pid, [{ pid: kr.kid.pid, st: kr.kid.st }], d.key)
                                        }
                                    }
                                    MonoTxt {
                                        x: parent.width - pop.chevW - pop.pidW - pop.memW - pop.cpuW
                                        width: pop.cpuW - 12
                                        height: parent.height
                                        horizontalAlignment: Text.AlignRight
                                        text: pop.fmtCpu(kr.kid.cpu)
                                        color: Theme.textMuted
                                        font.pixelSize: Theme.fontSm
                                    }
                                    MonoTxt {
                                        x: parent.width - pop.chevW - pop.pidW - pop.memW
                                        width: pop.memW - 12
                                        height: parent.height
                                        horizontalAlignment: Text.AlignRight
                                        text: pop.fmtMem(kr.kid.rss)
                                        color: Theme.textMuted
                                        font.pixelSize: Theme.fontSm
                                    }
                                    MonoTxt {
                                        x: parent.width - pop.chevW - pop.pidW
                                        width: pop.pidW - 4
                                        height: parent.height
                                        horizontalAlignment: Text.AlignRight
                                        text: kr.kid.pid
                                        color: Theme.textFaint
                                        font.pixelSize: Theme.fontSm
                                    }
                                }
                            }
                            Txt {
                                visible: d.n > d.shownKids
                                x: pop.nameX
                                topPadding: 4
                                text: "+ " + (d.n - d.shownKids) + " more"
                                color: Theme.textFaint
                                font.pixelSize: Theme.fontSm
                                font.weight: Font.Normal
                            }
                        }

                        // Aktionen – oder die schlanke Rückfrage direkt darunter
                        Item {
                            x: pop.nameX
                            width: parent.width - pop.nameX - 20
                            height: asking ? askBox.height : 34
                            readonly property bool asking: pop.confirm !== null && pop.confirm.rowKey === d.key

                            Row {
                                visible: !parent.asking
                                spacing: 8
                                Btn {
                                    visible: d.own
                                    text: d.n > 1 ? "End all" : "End"
                                    onClicked: pop.askRow("TERM", d.name, d.pid, d.st, d.kidsJson, d.n, d.key)
                                }
                                Btn {
                                    visible: d.own
                                    tone: "danger"
                                    text: d.n > 1 ? "Force all" : "Force"
                                    onClicked: pop.askRow("KILL", d.name, d.pid, d.st, d.kidsJson, d.n, d.key)
                                }
                                Txt {
                                    visible: !d.own
                                    height: 34
                                    text: "Owned by " + d.user + " – view only"
                                    color: Theme.textFaint
                                    font.pixelSize: Theme.fontSm
                                    font.weight: Font.Normal
                                }
                            }
                            Rectangle {
                                id: askBox
                                visible: parent.asking
                                width: parent.width
                                height: askCol.implicitHeight + 24
                                radius: Theme.radiusMd
                                color: Theme.surfaceRaised
                                Column {
                                    id: askCol
                                    x: 14
                                    y: 12
                                    width: parent.width - 28
                                    spacing: 6
                                    Txt {
                                        width: parent.width
                                        text: pop.confirm ? pop.confirm.title : ""
                                        font.weight: Font.DemiBold
                                        wrapMode: Text.WordWrap
                                        elide: Text.ElideNone
                                    }
                                    Txt {
                                        width: parent.width
                                        text: pop.confirm ? pop.confirm.hint : ""
                                        color: Theme.textMuted
                                        font.pixelSize: Theme.fontSm
                                        font.weight: Font.Normal
                                        wrapMode: Text.WordWrap
                                        elide: Text.ElideNone
                                    }
                                    Txt {
                                        width: parent.width
                                        visible: text !== ""
                                        text: pop.confirm ? pop.confirm.warn : ""
                                        color: Theme.warning
                                        font.pixelSize: Theme.fontSm
                                        font.weight: Font.Normal
                                        wrapMode: Text.WordWrap
                                        elide: Text.ElideNone
                                    }
                                    Row {
                                        anchors.right: parent.right
                                        spacing: 8
                                        Btn {
                                            text: "Cancel"
                                            onClicked: pop.confirm = null
                                        }
                                        Btn {
                                            tone: pop.confirm && pop.confirm.sig === "KILL" ? "danger" : "primary"
                                            text: pop.confirm && pop.confirm.sig === "KILL" ? "Force quit" : "End"
                                            onClicked: pop.doConfirm()
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // dünner Rollbalken (nur Anzeige, Rad scrollt)
            Rectangle {
                visible: list.contentHeight > list.height
                x: list.width - 4
                y: list.height * list.visibleArea.yPosition
                width: 3
                height: Math.max(24, list.height * list.visibleArea.heightRatio)
                radius: 2
                color: Theme.borderStrong
            }

            Txt {
                anchors.centerIn: parent
                visible: rows.count === 0
                text: !Procs.ready ? "Reading processes…" : "No match"
                color: Theme.textFaint
                font.weight: Font.Normal
            }
        }
        WheelScroll {
            flick: list
            step: 120
        }

        // ---------- Fuß: Rückmeldung ----------
        Item {
            id: footer
            x: 24
            y: parent.height - 40
            width: parent.width - 48
            height: 28
            Txt {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width
                text: pop.note !== "" ? pop.note : rows.count + " shown · updates every 2 s · memory counts shared pages once, split between processes"
                color: pop.note !== "" ? Theme.accentText : Theme.textFaint
                font.pixelSize: Theme.fontSm
                font.weight: Font.Normal
            }
        }
    }
}

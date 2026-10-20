import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.services
import qs.components

// Dev-Dienste-Popout unter dem Dev-Chip (Klick öffnet, Klick daneben / Esc schließt).
// Reiter: Services (pro Projekt: Dev-Server + Container, unbekannte unter „Other“, darunter „Not running“ mit Start),
// Containers (alle podman/docker-Container außer Distrobox/Toolbox), Ports (alle eigenen lauschenden Ports, auch Apps),
// Server (Web-Konsolen aus config/consoles.json + Server aus scripts/sshs mit Upload / Files / Terminal; früher eigener Chip).
//   Pro sshs-Server: Benutzer-Pille (Anmelde-Benutzer ↔ root per su, Root-Login per SSH bleibt aus) und Container-Knopf,
//   der die Container des Servers darunter aufklappt – nach Projekt (Compose-/Stack-Name), laufend/gestoppt, Ports.
// Zeile anklicken = im Browser öffnen (Helium). Stoppen immer mit schlanker Rückfrage in der Zeile.
// Daten + Aktionen: DevServices.qml → scripts/devservices, Servers.qml → scripts/sshs.
// Doku: docs/knowledge/shell-features.md, docs/knowledge/shell-features.md
PopupWindow {
    id: pop

    property var barWindow
    property Item chip
    readonly property int cardW: 720
    readonly property int maxCardH: 680
    readonly property int quick: Math.round(Theme.fade * 0.6)
    readonly property int rowH: 44
    property real appear: 0
    property real _closedAt: 0

    property string tab: "services"                    // services | containers | ports | server
    // Reiter fürs nächste Öffnen (Super+Alt+H, IPC servers); sonst öffnet es immer auf Services (Bastian: nicht merken)
    property string nextTab: ""
    property string query: ""
    property var confirm: null                         // { key, kind: server|container, title, hint, warn, item }
    property string sshPs: ""                          // sshs-Server, dessen Container aufgeklappt sind

    anchor.window: barWindow
    anchor.edges: Edges.Bottom | Edges.Right
    anchor.gravity: Edges.Bottom | Edges.Left
    grabFocus: true
    implicitWidth: cardW
    implicitHeight: maxCardH + 8
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
        openWith(true);
    }
    // grab = false nur für IPC (ohne vorherigen Klick lässt der Compositor keinen Klick-Fang zu)
    function openWith(grab: bool): void {
        if (visible)
            return;
        grabFocus = grab;
        placeUnderBar();
        ti.text = "";
        confirm = null;
        DevServices.note = "";
        tab = nextTab !== "" ? nextTab : "services";
        nextTab = "";
        if (tab === "server")
            Servers.refresh();
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
            Popouts.claim("devservices");
            ti.forceActiveFocus();
        } else {
            Popouts.release("devservices");
            _closedAt = Date.now();
            appearAnim.stop();
            confirm = null;
        }
    }
    onTabChanged: {
        confirm = null;
        if (tab === "server" && visible)
            Servers.refresh();
    }
    // Super+Alt+H / Bar-Modus H: gleich auf den Reiter Server (BarKeys.aliases)
    Connections {
        target: BarKeys
        function onTabRequested(name, t) {
            if (name !== "devservices")
                return;
            if (pop.visible)
                pop.tab = t;
            else
                pop.nextTab = t;
        }
    }
    // Aktion im Reiter Server: erst zu (Wähler/Fenster brauchen die Tastatur), dann auslösen
    function run(fn: var): void {
        close();
        Qt.callLater(fn);
    }
    // nur ein Bar-Popout gleichzeitig
    Connections {
        target: Popouts
        function onCurrentChanged() {
            if (Popouts.current !== "devservices" && pop.visible)
                pop.visible = false;
        }
    }
    // schnell prüfen, solange offen
    Binding {
        target: DevServices
        property: "active"
        value: pop.visible
    }
    Connections {
        target: DevServices
        function onActed(text, ok) {
            noteTimer.restart();
        }
    }
    Timer {
        id: noteTimer
        interval: 6000
        onTriggered: DevServices.note = ""
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

    // ---------- Daten ----------
    function projectName(id: string): string {
        const e = Projects.settings[id];
        return e && e.name ? e.name : id;
    }
    function projectColor(id: string): color {
        const e = Projects.settings[id];
        const c = e ? String(e.color || "") : "";
        if (/^#[0-9a-f]{6}$/i.test(c))
            return c;
        return Theme.projectAccents[c] || Theme.textFaint;
    }
    function hit(parts: var): bool {
        const q = query.trim().toLowerCase();
        return q === "" || parts.some(p => String(p ?? "").toLowerCase().includes(q));
    }
    function serverHit(s: var): bool {
        return hit([s.port, s.label, s.cmd, s.cwd, s.project ? projectName(s.project) : "other"]);
    }
    function containerHit(c: var): bool {
        return hit([c.name, c.image, c.status, c.compose, c.project ? projectName(c.project) : "other", c.ports.map(p => p.host).join(" ")]);
    }
    function unitFor(id: string): var {
        return DevServices.units.find(u => u.project === id) || null;
    }

    // Services: [{ id, name, color, other, servers, containers, unit }] – nur Projekte, in denen etwas läuft; Other zuletzt
    readonly property var groups: {
        const g = {};
        const get = id => g[id] || (g[id] = { id: id, other: id === "", servers: [], containers: [], unit: id ? unitFor(id) : null });
        for (const s of DevServices.devServers)
            if (serverHit(s))
                get(s.project || "").servers.push(s);
        for (const c of DevServices.containers) {
            if (!containerHit(c))
                continue;
            if (c.project && (c.running || DevServices.containers.some(o => o.running && o.project === c.project) || DevServices.devServers.some(s => s.project === c.project)))
                get(c.project).containers.push(c);
            else if (!c.project && c.running && !c.background)
                get("").containers.push(c);          // Hintergrund-Container (systemd/Quadlet) nur im Reiter Containers
        }
        for (const u of DevServices.units)
            if (u.active !== "failed" && hit([u.project, projectName(u.project)]))
                get(u.project);
        return Object.values(g).map(x => Object.assign(x, {
            name: x.other ? "Other" : projectName(x.id),
            color: x.other ? Theme.textFaint : projectColor(x.id)
        })).sort((a, b) => a.other - b.other || a.name.localeCompare(b.name));
    }
    // Not running: Projekte mit Dev-Befehl, in denen nichts läuft
    readonly property var idle: {
        const busy = {};
        for (const x of groups)
            busy[x.id] = true;
        const out = [];
        for (const id in Projects.settings) {
            const e = Projects.settings[id];
            if (busy[id] || !e.dev || !e.dev.command)
                continue;
            if (DevServices.devServers.some(s => s.project === id) || DevServices.containers.some(c => c.running && c.project === id))
                continue;
            if (!hit([id, e.name, e.dev.command]))
                continue;
            out.push({ id: id, name: e.name || id, color: projectColor(id), command: e.dev.command, services: e.dev.services || "",
                port: Object.values(e.dev.ports || {})[0] || 0 });
        }
        return out.sort((a, b) => a.name.localeCompare(b.name));
    }
    readonly property var allContainers: DevServices.containers.filter(c => containerHit(c))
    // Ports: eigene lauschende Prozesse + Container-Weiterleitungen, nach Port
    readonly property var allPorts: {
        const out = DevServices.servers.filter(s => serverHit(s)).map(s => ({
            key: "p" + s.pid + ":" + s.port, port: s.port, title: s.label, sub: s.cwd, project: s.project, kind: s.kind, lan: s.lan
        }));
        for (const c of DevServices.containers)
            if (c.running)
                for (const p of c.ports)
                    if (p.proto === "tcp" && hit([p.host, c.name, c.image, c.project ? projectName(c.project) : ""]))
                        out.push({ key: "c" + c.id + ":" + p.host, port: p.host, title: c.name, sub: c.image + " → " + p.container,
                            project: c.project, kind: "container", lan: p.ip === "" || p.ip === "0.0.0.0" });
        return out.sort((a, b) => a.port - b.port);
    }

    // Server: feste Web-Konsolen + sshs-Server, beide durchsucht
    readonly property var consoleRows: Servers.consoles.filter(c => hit([c.name, c.label, c.url]))
    readonly property var sshRows: Servers.list.filter(s => hit([s.name, s.host, s.user]))

    // ---------- Aktionen ----------
    function askServer(s: var): void {
        const st = s.stop || { mode: "pid" };
        confirm = {
            key: "s" + s.pid + ":" + s.port,
            kind: "server",
            title: "Stop " + s.label + "?",
            hint: st.mode === "unit" ? "Stops " + st.unit + " (systemctl --user stop)."
                : st.mode === "group" ? "Sends SIGTERM to process group " + st.pgid + " (" + st.leader + ", " + st.size + " processes)."
                : "Sends SIGTERM to PID " + s.pid + ".",
            warn: "",
            item: s
        };
    }
    function askContainer(c: var): void {
        confirm = {
            key: "c" + c.id,
            kind: "container",
            title: "Stop container " + c.name + "?",
            hint: c.engine + " stop " + c.name,
            warn: c.systemd ? "Managed by " + c.systemd + " – systemd may start it again." : "",
            item: c
        };
    }
    function doConfirm(): void {
        if (!confirm)
            return;
        if (confirm.kind === "server")
            DevServices.stop(confirm.item);
        else
            DevServices.container(confirm.item, "stop");
        confirm = null;
    }

    // ---------- Bausteine ----------
    // Textknopf (Start / Stop / Cancel)
    component Btn: Rectangle {
        id: bt
        property string text
        property string icon
        property string tone: "plain"                  // plain | danger | primary
        property bool small: false
        signal clicked()
        width: btRow.implicitWidth + (small ? 20 : 30)
        height: small ? 28 : 34
        radius: height / 2
        opacity: enabled ? 1 : 0.5
        color: tone === "danger" ? Theme.flat(Qt.alpha(Theme.error, btArea.containsMouse ? 0.42 : 0.3))
             : tone === "primary" ? Theme.accentFill
             : btArea.containsMouse ? Theme.surfaceRaised : Theme.surface
        Behavior on color { ColorAnimation { duration: pop.quick } }
        Row {
            id: btRow
            anchors.centerIn: parent
            spacing: 5
            Icon {
                anchors.verticalCenter: parent.verticalCenter
                visible: bt.icon !== ""
                name: bt.icon
                size: 15
                color: bt.tone === "primary" ? Theme.accentText : Theme.textMuted
            }
            Txt {
                anchors.verticalCenter: parent.verticalCenter
                visible: bt.text !== ""
                text: bt.text
                font.pixelSize: bt.small ? 12 : 13
                color: bt.tone === "primary" ? Theme.accentText : Theme.text
            }
        }
        MouseArea {
            id: btArea
            anchors.fill: parent
            enabled: bt.enabled
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: bt.clicked()
        }
    }

    // runder Symbolknopf in einer Zeile (Öffnen, Log, Neustart, Stopp)
    component IconBtn: Rectangle {
        id: ib
        property string icon
        property string tip
        property bool danger: false
        signal clicked()
        width: 30
        height: 30
        radius: 15
        opacity: enabled ? 1 : 0.5
        color: ibArea.containsMouse ? (danger ? Theme.flat(Qt.alpha(Theme.error, 0.3)) : Theme.surfaceRaised) : "transparent"
        Behavior on color { ColorAnimation { duration: pop.quick } }
        Icon {
            anchors.centerIn: parent
            name: ib.icon
            size: 17
            color: ibArea.containsMouse ? Theme.text : Theme.textMuted
        }
        MouseArea {
            id: ibArea
            anchors.fill: parent
            enabled: ib.enabled
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: ib.clicked()
        }
    }

    // Port als Mono-Pille
    component PortPill: Rectangle {
        property int port: 0
        property bool onSunken: true
        width: 62
        height: 24
        radius: 12
        color: onSunken ? Theme.surface : Theme.surfaceSunken
        MonoTxt {
            anchors.centerIn: parent
            text: parent.port > 0 ? ":" + parent.port : "–"
            color: Theme.textMuted
            font.pixelSize: 12
        }
    }

    // Zustands-Pille (läuft / gestoppt …)
    component StatePill: Rectangle {
        property string text
        property bool on: false
        width: spTxt.implicitWidth + 18
        height: 22
        radius: 11
        color: on ? Theme.flat(Qt.alpha(Theme.success, 0.2)) : Theme.surface
        Txt {
            id: spTxt
            anchors.centerIn: parent
            text: parent.text
            color: parent.on ? Theme.success : Theme.textFaint
            font.pixelSize: 11
        }
    }

    component Dot: Rectangle {
        property color tint: Theme.textFaint
        width: 10
        height: 10
        radius: 5
        color: tint
    }

    component Section: Item {
        property string text
        width: parent ? parent.width : 0
        height: 30
        Label {
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 6
            text: parent.text
        }
    }

    // schlanke Rückfrage unter einer Zeile
    component AskBox: Rectangle {
        width: parent ? parent.width : 0
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
                font.pixelSize: 13
                font.weight: Font.Normal
                wrapMode: Text.WordWrap
                elide: Text.ElideNone
            }
            Txt {
                width: parent.width
                visible: text !== ""
                text: pop.confirm ? pop.confirm.warn : ""
                color: Theme.warning
                font.pixelSize: 13
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
                    tone: "danger"
                    text: "Stop"
                    onClicked: pop.doConfirm()
                }
            }
        }
    }

    // Port eines Server-Containers: „:8080→80“ nach außen offen, „80“ (gerahmt) nur im Container
    component SrvPort: Rectangle {
        property var p: ({})
        readonly property bool open: (p.host || 0) > 0
        width: spt.implicitWidth + 16
        height: 22
        radius: 11
        color: open ? Theme.surface : "transparent"
        border.width: open ? 0 : 1
        border.color: Theme.border
        MonoTxt {
            id: spt
            anchors.centerIn: parent
            text: parent.open ? ":" + parent.p.host + (parent.p.host === parent.p.container ? "" : "→" + parent.p.container)
                : String(parent.p.container)
            color: parent.open ? Theme.textMuted : Theme.textFaint
            font.pixelSize: 11
        }
    }

    // Benutzer-Pille in der sshs-Zeile: Klick schaltet Anmelde-Benutzer ↔ root (sshs tippt nach der Anmeldung su)
    component UserPill: Rectangle {
        id: up
        property string name
        property string login
        readonly property bool on: Servers.isRoot(name)
        width: upRow.implicitWidth + 14
        height: 20
        radius: 10
        color: on ? Theme.accentFill : upArea.containsMouse ? Theme.surfaceRaised : Theme.surface
        Behavior on color { ColorAnimation { duration: pop.quick } }
        Row {
            id: upRow
            anchors.centerIn: parent
            spacing: 3
            Icon {
                anchors.verticalCenter: parent.verticalCenter
                name: up.on ? "shield_person" : "person"
                size: 13
                color: up.on ? Theme.accentText : Theme.textFaint
            }
            Txt {
                anchors.verticalCenter: parent.verticalCenter
                text: up.on ? "root" : (up.login || "user")
                font.pixelSize: 11
                font.weight: Font.Normal
                color: up.on ? Theme.accentText : Theme.textMuted
            }
        }
        MouseArea {
            id: upArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: Servers.setRoot(up.name, !up.on)
        }
    }

    // Container eines sshs-Servers (aufgeklappt unter der Zeile): Projekt-Gruppen aus `sshs ps --json`
    component ServerContainers: Column {
        id: sc
        property string name
        readonly property var d: Servers.psHost === name ? Servers.ps : null
        width: parent ? parent.width : 0
        spacing: 0
        bottomPadding: 6
        // Kopf: Zustand + neu laden
        Item {
            width: parent.width
            height: 32
            Txt {
                x: 82
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - x - scBtns.width - 16
                text: !sc.d ? "Reading containers…"
                    : !sc.d.ok ? sc.d.error
                    : sc.d.groups.length === 0 ? "No containers"
                    : sc.d.groups.reduce((n, g) => n + g.running, 0) + " of " + sc.d.groups.reduce((n, g) => n + g.total, 0)
                        + " running · " + sc.d.engines.join(", ") + " as " + sc.d.user
                color: sc.d && !sc.d.ok ? Theme.warning : Theme.textFaint
                elide: Text.ElideRight
                font.pixelSize: 12
                font.weight: Font.Normal
            }
            Row {
                id: scBtns
                anchors.right: parent.right
                anchors.rightMargin: 6
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6
                // ohne Docker-Rechte des Anmelde-Benutzers: Terminal, su, docker ps
                Btn {
                    visible: !!sc.d && !sc.d.ok && (sc.d.denied || []).length > 0
                    small: true
                    icon: "shield_person"
                    text: "As root in terminal"
                    onClicked: pop.run(() => Servers.rootRun(sc.name, (sc.d.denied[0] || "docker")
                        + " ps -a --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'"))
                }
                IconBtn {
                    icon: "refresh"
                    enabled: !Servers.psLoading
                    onClicked: Servers.loadContainers(sc.name)
                }
            }
        }
        Repeater {
            model: sc.d && sc.d.ok ? sc.d.groups : []
            Column {
                id: cg
                required property var modelData
                width: sc.width
                spacing: 0
                Item {
                    width: parent.width
                    height: 28
                    Row {
                        x: 82
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 8
                        Txt {
                            anchors.verticalCenter: parent.verticalCenter
                            text: cg.modelData.name
                            font.weight: Font.DemiBold
                            font.pixelSize: 13
                        }
                        Txt {
                            anchors.verticalCenter: parent.verticalCenter
                            text: cg.modelData.running + "/" + cg.modelData.total + " running"
                            color: cg.modelData.running > 0 ? Theme.success : Theme.textFaint
                            font.pixelSize: 11
                            font.weight: Font.Normal
                        }
                    }
                }
                Repeater {
                    model: cg.modelData.containers
                    Rectangle {
                        id: ct
                        required property var modelData
                        readonly property var c: modelData
                        width: cg.width
                        height: 40
                        radius: Theme.radiusSm
                        color: ctHov.hovered ? Theme.surface : "transparent"
                        Behavior on color { ColorAnimation { duration: pop.quick } }
                        HoverHandler {
                            id: ctHov
                        }
                        Dot {
                            x: 82
                            anchors.verticalCenter: parent.verticalCenter
                            width: 8
                            height: 8
                            radius: 4
                            tint: ct.c.running ? Theme.success : Theme.textFaint
                        }
                        Column {
                            anchors.left: parent.left
                            anchors.leftMargin: 100
                            anchors.right: ctRight.left
                            anchors.rightMargin: 10
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 1
                            Txt {
                                width: parent.width
                                text: ct.c.name
                                elide: Text.ElideRight
                                font.pixelSize: 13
                                color: ct.c.running ? Theme.text : Theme.textMuted
                            }
                            MonoTxt {
                                width: parent.width
                                text: (ct.c.image || "").replace(/^docker\.io\/(library\/)?/, "") + " · " + ct.c.status
                                elide: Text.ElideRight
                                color: Theme.textFaint
                                font.pixelSize: 11
                            }
                        }
                        Row {
                            id: ctRight
                            anchors.right: parent.right
                            anchors.rightMargin: 8
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 4
                            Repeater {
                                model: (ct.c.ports || []).slice(0, 3)
                                SrvPort {
                                    required property var modelData
                                    p: modelData
                                }
                            }
                            Txt {
                                anchors.verticalCenter: parent.verticalCenter
                                visible: (ct.c.ports || []).length > 3
                                text: "+" + ((ct.c.ports || []).length - 3)
                                color: Theme.textFaint
                                font.pixelSize: 11
                            }
                        }
                    }
                }
            }
        }
    }

    // Dev-Server-Zeile: Port, Name + Befehl, Aktionen (Öffnen, Log, Stopp); Klick = öffnen
    component ServerRow: Column {
        id: sr
        property var s: ({})
        readonly property bool asking: pop.confirm !== null && pop.confirm.key === "s" + s.pid + ":" + s.port
        width: parent ? parent.width : 0
        spacing: 4
        Rectangle {
            width: parent.width
            height: pop.rowH
            radius: Theme.radiusSm
            color: srArea.containsMouse ? Theme.surface : "transparent"
            Behavior on color { ColorAnimation { duration: pop.quick } }
            MouseArea {
                id: srArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: DevServices.openPort(sr.s.port)
            }
            PortPill {
                id: srPort
                x: 8
                anchors.verticalCenter: parent.verticalCenter
                port: sr.s.port
            }
            Column {
                anchors.left: srPort.right
                anchors.leftMargin: 12
                anchors.right: srActions.left
                anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                spacing: 1
                Row {
                    width: parent.width
                    spacing: 8
                    Txt {
                        id: srName
                        width: Math.min(implicitWidth, parent.width - (srLan.visible ? srLan.width + 8 : 0))
                        text: sr.s.label || ""
                    }
                    StatePill {
                        id: srLan
                        anchors.verticalCenter: parent.verticalCenter
                        visible: !!sr.s.lan
                        text: "LAN"
                    }
                }
                MonoTxt {
                    width: parent.width
                    text: (sr.s.cmd || "") + (sr.s.how === "port" ? "   · by port" : "")
                    elide: Text.ElideRight
                    color: Theme.textFaint
                    font.pixelSize: 11
                }
            }
            Row {
                id: srActions
                anchors.right: parent.right
                anchors.rightMargin: 6
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2
                IconBtn {
                    icon: "open_in_new"
                    onClicked: DevServices.openPort(sr.s.port)
                }
                IconBtn {
                    visible: !!sr.s.stop && sr.s.stop.mode === "unit"
                    icon: "article"
                    onClicked: DevServices.logs(sr.s.stop.unit)
                }
                IconBtn {
                    icon: "stop_circle"
                    danger: true
                    enabled: !DevServices.busy
                    onClicked: {
                        if (sr.asking)
                            pop.confirm = null;
                        else
                            pop.askServer(sr.s);
                    }
                }
            }
        }
        AskBox {
            visible: sr.asking
        }
    }

    // Container-Zeile: Symbol, Name + Image, Ports, Zustand, Start/Neustart/Stopp
    component ContainerRow: Column {
        id: cr
        property var c: ({})
        property bool showProject: false
        readonly property bool asking: pop.confirm !== null && pop.confirm.key === "c" + c.id
        width: parent ? parent.width : 0
        spacing: 4
        Rectangle {
            width: parent.width
            height: pop.rowH
            radius: Theme.radiusSm
            color: crArea.containsMouse ? Theme.surface : "transparent"
            Behavior on color { ColorAnimation { duration: pop.quick } }
            readonly property var firstPort: (cr.c.ports || []).find(p => p.proto === "tcp")
            MouseArea {
                id: crArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: parent.firstPort && cr.c.running ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: if (parent.firstPort && cr.c.running) DevServices.openPort(parent.firstPort.host)
            }
            Item {
                id: crIcon
                x: 8
                width: 62
                height: parent.height
                Icon {
                    anchors.centerIn: parent
                    name: "deployed_code"
                    size: 20
                    color: cr.c.running ? Theme.textMuted : Theme.textFaint
                }
                Dot {
                    visible: cr.showProject && !!cr.c.project
                    anchors.right: parent.right
                    anchors.rightMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    tint: cr.c.project ? pop.projectColor(cr.c.project) : Theme.textFaint
                }
            }
            Column {
                anchors.left: crIcon.right
                anchors.leftMargin: 12
                anchors.right: crRight.left
                anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                spacing: 1
                Txt {
                    width: parent.width
                    text: cr.c.name || ""
                    color: cr.c.running ? Theme.text : Theme.textMuted
                }
                MonoTxt {
                    width: parent.width
                    text: (cr.showProject && cr.c.project ? pop.projectName(cr.c.project) + " · " : "") + (cr.c.image || "").replace(/^docker\.io\/(library\/)?/, "")
                    elide: Text.ElideRight
                    color: Theme.textFaint
                    font.pixelSize: 11
                }
            }
            Row {
                id: crRight
                anchors.right: parent.right
                anchors.rightMargin: 6
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6
                Repeater {
                    model: (cr.c.ports || []).filter(p => p.proto === "tcp").slice(0, 2)
                    PortPill {
                        required property var modelData
                        anchors.verticalCenter: parent.verticalCenter
                        port: modelData.host
                    }
                }
                StatePill {
                    anchors.verticalCenter: parent.verticalCenter
                    on: !!cr.c.running
                    text: cr.c.running ? (cr.c.background ? "background" : "running") : cr.c.state || "stopped"
                }
                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2
                    IconBtn {
                        visible: !cr.c.running
                        icon: "play_arrow"
                        enabled: !DevServices.busy
                        onClicked: DevServices.container(cr.c, "start")
                    }
                    IconBtn {
                        visible: !!cr.c.running
                        icon: "restart_alt"
                        enabled: !DevServices.busy
                        onClicked: DevServices.container(cr.c, "restart")
                    }
                    IconBtn {
                        visible: !!cr.c.running
                        icon: "stop_circle"
                        danger: true
                        enabled: !DevServices.busy
                        onClicked: {
                            if (cr.asking)
                                pop.confirm = null;
                            else
                                pop.askContainer(cr.c);
                        }
                    }
                }
            }
        }
        AskBox {
            visible: cr.asking
        }
    }

    // ---------- Karte ----------
    Glass {
        id: card
        // offen bis zum Weghovern (PopoutGuard.qml)
        PopoutGuard { id: guard; popout: pop; chip: pop.chip; name: "devservices" }
        // Tastatur: Pfeile/Tab/Enter, Bar-Modus (Super+Leertaste, KeyNav.qml)
        Keys.onPressed: e => nav.key(e)
        KeyNav { id: nav; root: card; scope: null; popout: pop; guard: guard; name: "devservices" }
        width: pop.cardW
        height: Math.min(pop.maxCardH, flick.y + flick.height + footer.height + 20)
        strong: true
        opacity: pop.appear
        transform: Translate { y: (1 - pop.appear) * -6 }

        WheelScroll {
            flick: flick
        }

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
                Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    name: "dns"
                    size: 22
                    color: Theme.accentText
                }
                Txt {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Dev services"
                    font.pixelSize: 18
                    font.weight: Font.DemiBold
                }
            }
            Row {
                id: tabsRow
                anchors.left: titleLeft.right
                anchors.leftMargin: 18
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2
                Tab { text: "Services"; count: DevServices.count > 0 ? DevServices.count : -1; current: pop.tab === "services"; onPicked: { pop.tab = "services"; pop.confirm = null; } }
                Tab { text: "Containers"; current: pop.tab === "containers"; onPicked: { pop.tab = "containers"; pop.confirm = null; } }
                Tab { text: "Ports"; current: pop.tab === "ports"; onPicked: { pop.tab = "ports"; pop.confirm = null; } }
                Tab { text: "Server"; current: pop.tab === "server"; onPicked: pop.tab = "server" }
            }

            Rectangle {
                id: search
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: Math.max(120, Math.min(170, parent.width - tabsRow.x - tabsRow.width - 12))
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
                    font.pixelSize: 14
                    clip: true
                    onTextChanged: pop.query = text
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
                        font.pixelSize: 14
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

        Flickable {
            id: flick
            x: 0
            y: titleRow.y + titleRow.height + 10
            width: card.width
            height: Math.min(body.implicitHeight, pop.maxCardH - y - footer.height - 20)
            contentWidth: width
            contentHeight: body.implicitHeight
            interactive: false
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            Column {
                id: body
                x: 24
                width: card.width - 48
                spacing: 8

                // ---------- Services ----------
                Column {
                    visible: pop.tab === "services"
                    width: parent.width
                    spacing: 8

                    Txt {
                        visible: pop.groups.length === 0
                        width: parent.width
                        height: 40
                        text: !DevServices.ready ? "Looking for services…" : pop.query !== "" ? "No match" : "Nothing running"
                        color: Theme.textFaint
                        font.weight: Font.Normal
                    }

                    Repeater {
                        model: pop.groups
                        Rectangle {
                            id: grp
                            required property var modelData
                            readonly property var unit: modelData.unit
                            readonly property var proj: Projects.settings[modelData.id] || null
                            readonly property bool canStart: !modelData.other && modelData.servers.length === 0 && !unit
                                && !!proj && !!proj.dev && !!proj.dev.command
                            width: parent.width
                            height: grpCol.implicitHeight + 16
                            radius: Theme.radiusMd
                            color: Theme.surfaceSunken

                            Column {
                                id: grpCol
                                x: 8
                                y: 8
                                width: parent.width - 16
                                spacing: 2

                                // Kopf: Farbpunkt, Name, Ordner, Start/Log
                                Item {
                                    width: parent.width
                                    height: 34
                                    Row {
                                        x: 8
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: 10
                                        Dot {
                                            anchors.verticalCenter: parent.verticalCenter
                                            tint: grp.modelData.color
                                        }
                                        Txt {
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: grp.modelData.name
                                            font.weight: Font.DemiBold
                                        }
                                        Txt {
                                            anchors.verticalCenter: parent.verticalCenter
                                            visible: !!grp.unit
                                            text: grp.unit ? (grp.unit.sub === "running" && grp.modelData.servers.length === 0 ? "starting…" : "via " + grp.unit.unit) : ""
                                            color: Theme.textFaint
                                            font.pixelSize: 12
                                            font.weight: Font.Normal
                                        }
                                    }
                                    Row {
                                        anchors.right: parent.right
                                        anchors.rightMargin: 4
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: 6
                                        Btn {
                                            visible: !!grp.unit
                                            small: true
                                            icon: "article"
                                            text: "Logs"
                                            onClicked: DevServices.logs(grp.unit.unit)
                                        }
                                        Btn {
                                            visible: grp.canStart
                                            small: true
                                            tone: "primary"
                                            icon: "play_arrow"
                                            text: "Start dev"
                                            enabled: !DevServices.busy
                                            onClicked: DevServices.start(grp.modelData.id)
                                        }
                                    }
                                }
                                Repeater {
                                    model: grp.modelData.servers
                                    ServerRow {
                                        required property var modelData
                                        s: modelData
                                    }
                                }
                                Repeater {
                                    model: grp.modelData.containers
                                    ContainerRow {
                                        required property var modelData
                                        c: modelData
                                    }
                                }
                            }
                        }
                    }

                    // nichts läuft: Dev-Befehl starten (als eigene User-Unit, siehe scripts/devservices)
                    Section {
                        visible: pop.idle.length > 0
                        text: "Not running"
                    }
                    Repeater {
                        model: pop.idle
                        Rectangle {
                            id: idleRow
                            required property var modelData
                            width: parent.width
                            height: 40
                            radius: Theme.radiusSm
                            color: idleArea.hovered ? Theme.surfaceSunken : "transparent"
                            Behavior on color { ColorAnimation { duration: pop.quick } }
                            HoverHandler {
                                id: idleArea
                            }
                            Dot {
                                id: idleDot
                                x: 16
                                anchors.verticalCenter: parent.verticalCenter
                                tint: idleRow.modelData.color
                            }
                            Txt {
                                id: idleName
                                anchors.left: idleDot.right
                                anchors.leftMargin: 10
                                anchors.verticalCenter: parent.verticalCenter
                                width: Math.min(implicitWidth, 200)
                                text: idleRow.modelData.name
                            }
                            MonoTxt {
                                anchors.left: idleName.right
                                anchors.leftMargin: 12
                                anchors.right: idleBtn.left
                                anchors.rightMargin: 10
                                anchors.verticalCenter: parent.verticalCenter
                                text: (idleRow.modelData.services ? idleRow.modelData.services + " && " : "") + idleRow.modelData.command
                                    + (idleRow.modelData.port ? "  · :" + idleRow.modelData.port : "")
                                elide: Text.ElideRight
                                color: Theme.textFaint
                                font.pixelSize: 11
                            }
                            Btn {
                                id: idleBtn
                                anchors.right: parent.right
                                anchors.rightMargin: 6
                                anchors.verticalCenter: parent.verticalCenter
                                small: true
                                icon: "play_arrow"
                                text: "Start"
                                enabled: !DevServices.busy
                                onClicked: DevServices.start(idleRow.modelData.id)
                            }
                        }
                    }
                }

                // ---------- Containers ----------
                Column {
                    visible: pop.tab === "containers"
                    width: parent.width
                    spacing: 2

                    Txt {
                        visible: pop.allContainers.length === 0
                        width: parent.width
                        height: 40
                        text: DevServices.engines.length === 0 ? "No podman or docker found" : pop.query !== "" ? "No match" : "No containers"
                        color: Theme.textFaint
                        font.weight: Font.Normal
                    }
                    Rectangle {
                        visible: pop.allContainers.length > 0
                        width: parent.width
                        height: ctrCol.implicitHeight + 16
                        radius: Theme.radiusMd
                        color: Theme.surfaceSunken
                        Column {
                            id: ctrCol
                            x: 8
                            y: 8
                            width: parent.width - 16
                            spacing: 2
                            Repeater {
                                model: pop.allContainers
                                ContainerRow {
                                    required property var modelData
                                    c: modelData
                                    showProject: true
                                }
                            }
                        }
                    }
                }

                // ---------- Ports ----------
                Column {
                    visible: pop.tab === "ports"
                    width: parent.width
                    spacing: 2

                    Txt {
                        visible: pop.allPorts.length === 0
                        width: parent.width
                        height: 40
                        text: pop.query !== "" ? "No match" : "No listening ports"
                        color: Theme.textFaint
                        font.weight: Font.Normal
                    }
                    Rectangle {
                        visible: pop.allPorts.length > 0
                        width: parent.width
                        height: portCol.implicitHeight + 16
                        radius: Theme.radiusMd
                        color: Theme.surfaceSunken
                        Column {
                            id: portCol
                            x: 8
                            y: 8
                            width: parent.width - 16
                            spacing: 0
                            Repeater {
                                model: pop.allPorts
                                Rectangle {
                                    id: pr
                                    required property var modelData
                                    width: parent.width
                                    height: 38
                                    radius: Theme.radiusSm
                                    color: prArea.containsMouse ? Theme.surface : "transparent"
                                    Behavior on color { ColorAnimation { duration: pop.quick } }
                                    MouseArea {
                                        id: prArea
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: DevServices.openPort(pr.modelData.port)
                                    }
                                    PortPill {
                                        id: prPort
                                        x: 8
                                        anchors.verticalCenter: parent.verticalCenter
                                        port: pr.modelData.port
                                    }
                                    Txt {
                                        id: prTitle
                                        anchors.left: prPort.right
                                        anchors.leftMargin: 12
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: 170
                                        text: pr.modelData.title
                                        color: pr.modelData.kind === "app" ? Theme.textMuted : Theme.text
                                    }
                                    MonoTxt {
                                        anchors.left: prTitle.right
                                        anchors.leftMargin: 8
                                        anchors.right: prRight.left
                                        anchors.rightMargin: 10
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: pr.modelData.sub || ""
                                        elide: Text.ElideMiddle
                                        color: Theme.textFaint
                                        font.pixelSize: 11
                                    }
                                    Row {
                                        id: prRight
                                        anchors.right: parent.right
                                        anchors.rightMargin: 10
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: 8
                                        StatePill {
                                            anchors.verticalCenter: parent.verticalCenter
                                            visible: !!pr.modelData.lan
                                            text: "LAN"
                                        }
                                        Dot {
                                            anchors.verticalCenter: parent.verticalCenter
                                            visible: !!pr.modelData.project
                                            tint: pr.modelData.project ? pop.projectColor(pr.modelData.project) : Theme.textFaint
                                        }
                                        Txt {
                                            anchors.verticalCenter: parent.verticalCenter
                                            width: Math.min(implicitWidth, 150)
                                            text: pr.modelData.project ? pop.projectName(pr.modelData.project)
                                                : pr.modelData.kind === "app" ? "app" : pr.modelData.kind === "container" ? "container" : "other"
                                            color: Theme.textFaint
                                            font.pixelSize: 12
                                            font.weight: Font.Normal
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // ---------- Server: Web-Konsolen (config/consoles.json) + sshs ----------
                Column {
                    visible: pop.tab === "server"
                    width: parent.width
                    spacing: 2

                    Section {
                        text: "Consoles"
                    }
                    Txt {
                        visible: pop.consoleRows.length === 0
                        width: parent.width
                        height: 40
                        text: pop.query !== "" ? "No match" : "No consoles in config/consoles.json"
                        color: Theme.textFaint
                        font.weight: Font.Normal
                    }
                    Rectangle {
                        visible: pop.consoleRows.length > 0
                        width: parent.width
                        height: conCol.implicitHeight + 16
                        radius: Theme.radiusMd
                        color: Theme.surfaceSunken
                        Column {
                            id: conCol
                            x: 8
                            y: 8
                            width: parent.width - 16
                            spacing: 0
                            // wie die Ports-Zeilen: Symbol, Name, Adresse, rechts kleine Angabe
                            Repeater {
                                model: pop.consoleRows
                                Rectangle {
                                    id: cn
                                    required property var modelData
                                    readonly property bool ok: !!modelData.url
                                    width: parent.width
                                    height: 38
                                    radius: Theme.radiusSm
                                    color: cnArea.containsMouse && ok ? Theme.surface : "transparent"
                                    Behavior on color { ColorAnimation { duration: pop.quick } }
                                    MouseArea {
                                        id: cnArea
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: cn.ok ? Qt.PointingHandCursor : Qt.ArrowCursor
                                        onClicked: if (cn.ok) Servers.openConsole(cn.modelData)
                                    }
                                    Item {
                                        id: cnIcon
                                        x: 8
                                        width: 62
                                        height: parent.height
                                        Icon {
                                            anchors.centerIn: parent
                                            name: cn.modelData.icon || "public"
                                            size: 18
                                            color: cn.ok ? Theme.textMuted : Theme.textFaint
                                        }
                                    }
                                    Txt {
                                        id: cnTitle
                                        anchors.left: cnIcon.right
                                        anchors.leftMargin: 12
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: 170
                                        text: cn.modelData.name || cn.modelData.id
                                        color: cn.ok ? Theme.text : Theme.textMuted
                                    }
                                    MonoTxt {
                                        anchors.left: cnTitle.right
                                        anchors.leftMargin: 8
                                        anchors.right: cnLabel.left
                                        anchors.rightMargin: 10
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: cn.ok ? Servers.host(cn.modelData.url) : "no URL yet · ~/.config/desktop/consoles.json"
                                        elide: Text.ElideMiddle
                                        color: cn.ok ? Theme.textFaint : Theme.warning
                                        font.pixelSize: 11
                                    }
                                    Txt {
                                        id: cnLabel
                                        anchors.right: parent.right
                                        anchors.rightMargin: 10
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: Math.min(implicitWidth, 150)
                                        text: cn.modelData.label || ""
                                        color: Theme.textFaint
                                        font.pixelSize: 12
                                        font.weight: Font.Normal
                                    }
                                }
                            }
                        }
                    }

                    // sshs-Server: zuletzt benutzter oben; Upload / Files / Terminal (Servers.qml, docs/knowledge/shell-features.md)
                    Item {
                        width: parent.width
                        height: 40
                        Label {
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: 6
                            text: "SSH"
                        }
                        Btn {
                            anchors.right: parent.right
                            anchors.rightMargin: 4
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: 2
                            small: true
                            icon: "add"
                            text: "New server"
                            onClicked: {
                                pop.close();
                                Launch.cmd(["kitty", "--class", "sshs", "--title", "sshs · new server", "-e", Servers.sshs, "add"]);
                            }
                        }
                    }
                    Txt {
                        visible: pop.sshRows.length === 0
                        width: parent.width
                        height: 40
                        text: !Servers.ready ? "Reading…" : Servers.error !== "" ? Servers.error
                            : pop.query !== "" ? "No match" : "No servers yet · “New server” or sshs add in a terminal"
                        color: Theme.textFaint
                        font.weight: Font.Normal
                    }
                    Rectangle {
                        visible: pop.sshRows.length > 0
                        width: parent.width
                        height: sshCol.implicitHeight + 16
                        radius: Theme.radiusMd
                        color: Theme.surfaceSunken
                        Column {
                            id: sshCol
                            x: 8
                            y: 8
                            width: parent.width - 16
                            spacing: 2
                            Repeater {
                                model: pop.sshRows
                                Column {
                                    id: sh
                                    required property var modelData
                                    required property int index
                                    readonly property var s: modelData
                                    readonly property bool recent: index === 0 && s.last > 0 && pop.query === ""
                                    readonly property bool busy: Servers.upHost === s.name
                                    readonly property bool open: pop.sshPs === s.name
                                    width: parent.width
                                    spacing: 0
                                    Rectangle {
                                        width: parent.width
                                        height: pop.rowH
                                        radius: Theme.radiusSm
                                        color: shHov.hovered || sh.open ? Theme.surface : "transparent"
                                        Behavior on color { ColorAnimation { duration: pop.quick } }
                                        HoverHandler {
                                            id: shHov
                                        }
                                        Item {
                                            id: shIcon
                                            x: 8
                                            width: 62
                                            height: parent.height
                                            Icon {
                                                anchors.centerIn: parent
                                                name: sh.busy ? "cloud_upload" : "dns"
                                                size: 19
                                                color: sh.busy || sh.recent ? Theme.accentText : Theme.textMuted
                                            }
                                        }
                                        Column {
                                            anchors.left: shIcon.right
                                            anchors.leftMargin: 12
                                            anchors.right: shActions.left
                                            anchors.rightMargin: 8
                                            anchors.verticalCenter: parent.verticalCenter
                                            spacing: 1
                                            Row {
                                                width: parent.width
                                                spacing: 8
                                                Txt {
                                                    id: shName
                                                    width: Math.min(implicitWidth, parent.width - shUser.width - 8 - (shAgo.visible ? shAgo.implicitWidth + 8 : 0))
                                                    text: sh.s.name
                                                }
                                                UserPill {
                                                    id: shUser
                                                    anchors.verticalCenter: shName.verticalCenter
                                                    name: sh.s.name
                                                    login: sh.s.user
                                                }
                                                Txt {
                                                    id: shAgo
                                                    anchors.baseline: shName.baseline
                                                    visible: sh.s.last > 0
                                                    text: Servers.ago(sh.s.last)
                                                    color: Theme.textFaint
                                                    font.pixelSize: 11
                                                    font.weight: Font.Normal
                                                }
                                            }
                                            MonoTxt {
                                                width: parent.width
                                                text: sh.busy ? "Uploading " + Servers.upCount + (Servers.upCount === 1 ? " item…" : " items…")
                                                    : Servers.where(sh.s) + (shUser.on ? " · then su" : "")
                                                elide: Text.ElideMiddle
                                                color: sh.busy ? Theme.accentText : Theme.textFaint
                                                font.pixelSize: 11
                                            }
                                        }
                                        Row {
                                            id: shActions
                                            anchors.right: parent.right
                                            anchors.rightMargin: 6
                                            anchors.verticalCenter: parent.verticalCenter
                                            spacing: 6
                                            Btn {
                                                small: true
                                                icon: "upload"
                                                text: "Upload"
                                                tone: sh.recent ? "primary" : "plain"
                                                enabled: !Servers.uploading
                                                onClicked: pop.run(() => Servers.upload(sh.s.name))
                                            }
                                            Btn {
                                                small: true
                                                icon: "folder_open"
                                                text: "Files"
                                                onClicked: pop.run(() => Servers.files(sh.s.name))
                                            }
                                            Btn {
                                                small: true
                                                icon: "terminal"
                                                text: "Terminal"
                                                onClicked: pop.run(() => Servers.terminal(sh.s.name))
                                            }
                                            IconBtn {
                                                icon: sh.open ? "expand_less" : "deployed_code"
                                                onClicked: {
                                                    pop.sshPs = sh.open ? "" : sh.s.name;
                                                    if (pop.sshPs !== "")
                                                        Servers.loadContainers(sh.s.name);
                                                }
                                            }
                                        }
                                    }
                                    ServerContainers {
                                        visible: sh.open
                                        name: sh.s.name
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
            visible: flick.contentHeight > flick.height
            x: card.width - 8
            y: flick.y + flick.height * flick.visibleArea.yPosition
            width: 3
            height: Math.max(24, flick.height * flick.visibleArea.heightRatio)
            radius: 2
            color: Theme.borderStrong
        }

        // ---------- Fuß: Rückmeldung ----------
        Item {
            id: footer
            x: 24
            y: flick.y + flick.height + 8
            width: parent.width - 48
            height: 28
            Txt {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width
                readonly property bool srv: pop.tab === "server"
                text: srv ? (Servers.note !== "" ? Servers.note
                        : Servers.uploading ? "Uploading to " + Servers.upHost + "…"
                        : Servers.list.length + (Servers.list.length === 1 ? " server" : " servers")
                            + " · click a console to open it in the browser · upload goes to ~")
                    : DevServices.note !== "" ? DevServices.note
                    : DevServices.count + " running · checks every 5 s while open · click a row to open it in the browser"
                color: srv ? (Servers.note !== "" || Servers.uploading ? Theme.accentText : Theme.textFaint)
                    : DevServices.note === "" ? Theme.textFaint : DevServices.noteOk ? Theme.accentText : Theme.warning
                elide: Text.ElideRight
                font.pixelSize: 12
                font.weight: Font.Normal
            }
        }
    }
}

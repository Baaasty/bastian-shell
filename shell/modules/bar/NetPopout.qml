import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.services
import qs.components

// Netz-Popout unter dem Netz-Chip (Klick öffnet, Klick daneben / Esc schließt). Bewusst schlicht:
//  - Kopf: Online / No internet / Offline in einer Zeile (+ Ping ins Internet), „Details“ klappt Name/IP/Router/Link auf
//  - Reachability: Ping zu Internet (1.1.1.1), Router, GitHub, Discord (Ziele: ~/.config/desktop/net.json) – nur solange offen
//  - Last hour: Ø-Durchsatz ↓/↑ (Minutenmittel, Net.qml) als kleines Diagramm + Speedtest-Knopf (nur auf Knopfdruck). Doku: docs/NET.md
PopupWindow {
    id: pop

    property var barWindow
    property Item chip
    readonly property int cardW: 360
    readonly property int maxCardH: 640
    readonly property int quick: Math.round(Theme.fade * 0.6)
    property real appear: 0
    property real _closedAt: 0

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
    // grab = false nur für den IPC-Test (ohne vorherigen Klick lässt der Compositor keinen Klick-Fang zu)
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
            Popouts.claim("net");
            keys.forceActiveFocus();
        } else {
            Popouts.release("net");
            _closedAt = Date.now();
            details = false;
            appearAnim.stop();
        }
    }
    // nur ein Bar-Popout gleichzeitig
    Connections {
        target: Popouts
        function onCurrentChanged() {
            if (Popouts.current !== "net" && pop.visible)
                pop.visible = false;
        }
    }
    // Ping nur abfragen, solange offen
    Binding {
        target: NetInfo
        property: "active"
        value: pop.visible
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

    // ---------- Bausteine ----------
    property bool details: false          // Details (Name, IP, Router, Link) aufgeklappt
    property real now: Date.now()         // für „vor 3 min“, nur bei offenem Popout nachgeführt
    Timer {
        interval: 30000
        repeat: true
        running: pop.visible
        triggeredOnStart: true
        onTriggered: pop.now = Date.now()
    }

    function ago(t: real): string {
        const m = Math.round((pop.now - t) / 60000);
        return m < 1 ? "just now" : m < 60 ? m + " min ago" : Math.round(m / 60) + " h ago";
    }
    // Ping-Zustand: 0 gut, 1 langsam/Verlust, 2 keine Antwort
    function level(p: var): int {
        if (!p || p.ms === null || p.ms === undefined)
            return 2;
        return p.ms >= 150 || p.loss > 0 ? 1 : 0;
    }
    function levelColor(l: int): color {
        return l === 0 ? Theme.success : l === 1 ? Theme.warning : Theme.error;
    }

    component Section: Item {
        property string text
        width: parent ? parent.width : 0
        height: 30
        Label {
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 4
            text: parent.text
        }
    }

    // Zeile „Bezeichnung  Wert“ (Details)
    component Fact: Item {
        property string label
        property string value
        width: parent ? parent.width : 0
        height: visible ? 24 : 0
        Txt {
            anchors.verticalCenter: parent.verticalCenter
            width: 84
            text: parent.label
            color: Theme.textFaint
            font.pixelSize: 12
            font.weight: Font.Normal
        }
        MonoTxt {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - 90
            horizontalAlignment: Text.AlignRight
            elide: Text.ElideRight
            text: parent.value
            color: Theme.textMuted
            font.pixelSize: 12
        }
    }

    // Erreichbarkeit: Punkt, Name, ms
    component PingRow: Item {
        id: pr
        property var p: ({})
        readonly property int lv: pop.level(p)
        width: parent ? parent.width : 0
        height: 30
        Rectangle {
            id: dot
            anchors.verticalCenter: parent.verticalCenter
            width: 8
            height: 8
            radius: 4
            color: pop.levelColor(pr.lv)
        }
        Txt {
            anchors.left: dot.right
            anchors.leftMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            text: pr.p.name || ""
        }
        MonoTxt {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: pr.lv === 2 ? "no reply" : Math.round(pr.p.ms) + " ms" + (pr.p.loss > 0 ? " · " + pr.p.loss + "% loss" : "")
            font.pixelSize: 12
            color: pr.lv === 0 ? Theme.textMuted : pop.levelColor(pr.lv)
        }
    }

    // ---------- Karte ----------
    Glass {
        id: card
        // offen bis zum Weghovern (PopoutGuard.qml)
        PopoutGuard { id: guard; popout: pop; chip: pop.chip; name: "net" }
        // Tastatur: Pfeile/Tab/Enter, Bar-Modus (Super+B, KeyNav.qml)
        Keys.onPressed: e => nav.key(e)
        KeyNav { id: nav; root: card; scope: keys; popout: pop; guard: guard; name: "net" }
        width: pop.cardW
        height: flick.y + flick.height + 16
        strong: true
        opacity: pop.appear
        transform: Translate { y: (1 - pop.appear) * -6 }

        WheelScroll {
            flick: flick
        }

        FocusScope {
            id: keys
            anchors.fill: parent
            Keys.onEscapePressed: pop.close()
        }

        // ---------- Kopf: Status in einer Zeile + „Details“ ----------
        Item {
            id: head
            readonly property var inet: NetInfo.pings.length ? NetInfo.pings[0] : null
            readonly property int lv: !NetInfo.up ? 2 : NetInfo.pings.length === 0 ? 0 : !NetInfo.online ? 2 : pop.level(inet)
            x: 20
            y: 18
            width: parent.width - 40
            height: 32
            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 10
                Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    name: !NetInfo.up ? "cloud_off" : NetInfo.kind === "wifi" ? "wifi" : "lan"
                    size: 22
                    color: NetInfo.up && NetInfo.online ? Theme.accentText : Theme.warning
                }
                Txt {
                    anchors.verticalCenter: parent.verticalCenter
                    text: !NetInfo.up ? "Offline" : NetInfo.online ? "Online" : "No internet"
                    font.pixelSize: 18
                    font.weight: Font.DemiBold
                }
                MonoTxt {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: NetInfo.up && head.inet !== null && head.inet.ms !== null
                    text: head.inet ? Math.round(head.inet.ms) + " ms" : ""
                    color: head.lv === 1 ? Theme.warning : Theme.textFaint
                    font.pixelSize: 12
                }
            }
            // Details auf/zu (fokussierbar wie alle Knöpfe)
            Rectangle {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: detRow.implicitWidth + 18
                height: 28
                radius: Theme.radiusSm
                color: pop.details || detArea.containsMouse ? Theme.surfaceRaised : "transparent"
                Behavior on color { ColorAnimation { duration: pop.quick } }
                Row {
                    id: detRow
                    anchors.centerIn: parent
                    spacing: 2
                    Txt {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Details"
                        color: Theme.textFaint
                        font.pixelSize: 12
                        font.weight: Font.Normal
                    }
                    Icon {
                        anchors.verticalCenter: parent.verticalCenter
                        name: pop.details ? "expand_less" : "expand_more"
                        size: 16
                        color: Theme.textFaint
                    }
                }
                MouseArea {
                    id: detArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: pop.details = !pop.details
                }
            }
        }

        Flickable {
            id: flick
            x: 0
            y: head.y + head.height + 4
            width: card.width
            height: Math.min(body.implicitHeight, pop.maxCardH - y - 16)
            contentWidth: width
            contentHeight: body.implicitHeight
            interactive: false
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            Column {
                id: body
                x: 20
                width: card.width - 40
                spacing: 4

                // ---------- Details (aufklappbar) ----------
                Rectangle {
                    visible: pop.details
                    width: body.width
                    height: visible ? facts.implicitHeight + 16 : 0
                    radius: Theme.radiusMd
                    color: Theme.surfaceSunken
                    Column {
                        id: facts
                        x: 14
                        y: 8
                        width: parent.width - 28
                        Fact { label: NetInfo.kind === "wifi" ? "Wi-Fi" : "Connection"; value: NetInfo.up ? NetInfo.name : "No link" }
                        Fact { visible: NetInfo.up && NetInfo.speed > 0; label: "Link"; value: NetInfo.fmtSpeed(NetInfo.speed) }
                        Fact { visible: NetInfo.up && NetInfo.ip !== ""; label: "IP address"; value: NetInfo.ip }
                        Fact { visible: NetInfo.up && NetInfo.gateway !== ""; label: "Router"; value: NetInfo.gateway }
                        Fact { visible: NetInfo.signalDbm !== null; label: "Signal"; value: NetInfo.signalDbm + " dBm" }
                        Fact { visible: NetInfo.up && Net.iface !== ""; label: "Now"; value: "↓ " + Net.fmtMbit(Net.rxRate) + "   ↑ " + Net.fmtMbit(Net.txRate) }
                    }
                }

                // ---------- Erreichbarkeit ----------
                Section { text: "Reachability" }

                Rectangle {
                    width: body.width
                    height: pings.implicitHeight + 12
                    radius: Theme.radiusMd
                    color: Theme.surfaceSunken
                    Column {
                        id: pings
                        x: 14
                        y: 6
                        width: parent.width - 28
                        Txt {
                            visible: NetInfo.pings.length === 0
                            width: parent.width
                            height: visible ? 30 : 0
                            text: NetInfo.up ? "Measuring…" : "No connection"
                            color: Theme.textFaint
                            font.weight: Font.Normal
                        }
                        Repeater {
                            model: NetInfo.pings
                            PingRow {
                                required property var modelData
                                p: modelData
                            }
                        }
                    }
                }

                // ---------- Letzte Stunde: Durchsatz (Minutenmittel) + Speedtest ----------
                Section { text: "Last hour" }

                Rectangle {
                    width: body.width
                    height: hour.implicitHeight + 24
                    radius: Theme.radiusMd
                    color: Theme.surfaceSunken
                    Column {
                        id: hour
                        x: 14
                        y: 12
                        width: parent.width - 28
                        spacing: 8

                        // Ø-Werte
                        Item {
                            width: parent.width
                            height: 20
                            Row {
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 14
                                MonoTxt {
                                    text: "Ø ↓ " + Net.fmtMbit(Net.rxAvg)
                                    color: Theme.woodLight
                                    font.pixelSize: 13
                                }
                                MonoTxt {
                                    text: "↑ " + Net.fmtMbit(Net.txAvg)
                                    color: Theme.textFaint
                                    font.pixelSize: 13
                                }
                            }
                            MonoTxt {
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                visible: Net.rxSeries.length > 1
                                text: "peak " + Net.fmtMbit(Net.rxPeak)
                                color: Theme.textFaint
                                font.pixelSize: 11
                            }
                        }

                        // Diagramm (↓ Fläche, ↑ Linie)
                        Item {
                            width: parent.width
                            height: 56
                            Graph {
                                anchors.fill: parent
                                visible: Net.rxSeries.length > 1
                                values: Net.rxSeries
                                secondary: Net.txSeries
                                color: Theme.woodLight
                                secondaryColor: Theme.textFaint
                            }
                            Txt {
                                anchors.centerIn: parent
                                visible: Net.rxSeries.length <= 1
                                text: "Collecting – one point per minute"
                                color: Theme.textFaint
                                font.pixelSize: 12
                                font.weight: Font.Normal
                            }
                        }
                        Item {
                            width: parent.width
                            height: 14
                            visible: Net.rxSeries.length > 1
                            MonoTxt {
                                text: "−" + (Net.rxSeries.length - 1) + " min"
                                color: Theme.textFaint
                                font.pixelSize: 10
                            }
                            MonoTxt {
                                anchors.right: parent.right
                                text: "now"
                                color: Theme.textFaint
                                font.pixelSize: 10
                            }
                        }

                        Rectangle {
                            width: parent.width
                            height: 1
                            color: Theme.border
                        }

                        // Speedtest: nur auf Knopfdruck
                        Item {
                            width: parent.width
                            height: 38
                            Column {
                                anchors.left: parent.left
                                anchors.right: speedBtn.left
                                anchors.rightMargin: 10
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 1
                                Txt {
                                    text: Net.testing ? "Testing…" : Net.speedMbit >= 0 ? "↓ " + (Net.speedMbit >= 100 ? Math.round(Net.speedMbit) : Net.speedMbit.toFixed(1)) + " Mbit/s" : "Speed test"
                                    font.pixelSize: Net.speedMbit >= 0 && !Net.testing ? 15 : 14
                                    font.weight: Font.DemiBold
                                }
                                Txt {
                                    width: parent.width
                                    text: Net.speedError !== "" ? Net.speedError : Net.testing ? "Downloading 25 MB from Cloudflare" : Net.speedMbit >= 0 ? "Download · " + pop.ago(Net.speedAt) : "25 MB download, only on demand"
                                    color: Net.speedError !== "" ? Theme.warning : Theme.textFaint
                                    font.pixelSize: 12
                                    font.weight: Font.Normal
                                }
                            }
                            Button {
                                id: speedBtn
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                implicitHeight: 32
                                icon: "speed"
                                text: Net.testing ? "Running" : "Run"
                                enabled: !Net.testing && NetInfo.up
                                opacity: enabled ? 1 : 0.5
                                onClicked: Net.speedtest()
                            }
                        }
                    }
                }
            }
        }
    }
}

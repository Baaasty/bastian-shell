import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import qs.config
import qs.services
import qs.components

// Sound-Popout unter dem Lautsprecher-Chip (Klick öffnet, Klick daneben / Esc schließt).
// Gliederung: oben Routing, darunter die Apps:
//   1) Routing: „Speakers“ (System/Music/Chat) und „Discord hears“ (System/Music) als zwei gleiche Chip-Zeilen, einmal der Lock-Hinweis
//   2) Channels: GoXLR-Pegel System, Music, Chat, Mic (nur ansehen); Game/Sample/Headphones (> 0) eingeklappt darunter
//   3) Apps: alle App-Streams mit Lautstärke + Stumm und dem Kanal, auf dem sie landen (Mixer.group: Spotify -> Music, Discord -> Chat, Rest -> System)
// Alle Zeilen fluchten: Name links, Regler/Balken/Chips ab colX. Routing und Pegel kommen aus den gemeinsamen Komponenten
// components/GoxlrPanel.qml + GoxlrLevel.qml (auch in der Dashboard-Kachel).
// Ausgang/Eingang werden hier nicht gewechselt. Doku: docs/knowledge/shell-features.md
PopupWindow {
    id: pop

    property var barWindow
    property Item chip
    readonly property int cardW: 420
    readonly property int maxCardH: 760
    readonly property int quick: Math.round(Theme.fade * 0.6)
    property real appear: 0
    property real _closedAt: 0

    // Spalte, ab der Chips, Pegel-Balken und App-Regler-Spur beginnen (Slider-Knopf 16 px: Regler startet colX - 8)
    readonly property int colX: 132
    // rechter Rand von Pegel-Zeilen = rechter Rand der App-Prozente (links vom Stumm-Knopf)
    readonly property int trailW: 24
    // Hauptkanäle (Chat zuletzt, dann Mic)
    readonly property var mainKeys: ["System", "Music", "Chat", "Mic"]

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
    // grab = false nur für den IPC-Test (ohne vorherigen Klick lässt der Compositor keinen Klick-Fang zu)
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
            Popouts.claim("mixer");
            keys.forceActiveFocus();
        } else {
            Popouts.release("mixer");
            _closedAt = Date.now();
            appearAnim.stop();
        }
    }
    // nur ein Bar-Popout gleichzeitig
    Connections {
        target: Popouts
        function onCurrentChanged() {
            if (Popouts.current !== "mixer" && pop.visible)
                pop.visible = false;
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
        Region { item: pop.appear > 0.4 ? card : null; radius: Theme.radiusLg }
    }

    // ---------- Bausteine ----------
    // Abschnittstitel; spaced = mehr Luft nach oben (alle außer dem ersten)
    component Section: Item {
        property string text
        property bool spaced: false
        width: parent ? parent.width : 0
        height: visible ? (spaced ? 40 : 30) : 0
        Label {
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 4
            text: parent.text
        }
    }

    // kleiner Symbol-Knopf (Stumm)
    component MuteBtn: Chip {
        id: mb
        property bool muted: false
        padding: 5
        Icon {
            anchors.verticalCenter: parent.verticalCenter
            name: mb.muted ? "volume_off" : "volume_up"
            size: 18
            color: mb.muted ? Theme.warning : Theme.textMuted
            Behavior on color { ColorAnimation { duration: pop.quick } }
        }
    }

    // eine App: Symbol, Name + Kanal, Lautstärke, Prozent, Stumm
    component AppRow: Item {
        id: row
        property var app
        readonly property string iconName: Mixer.appIcon(app)
        readonly property bool muted: Mixer.appMuted(app)
        readonly property real vol: AudioOut.appVolume(app)
        readonly property string channel: app ? ({ music: "Music", chat: "Chat", system: "System" })[Mixer.group(app)] || "" : ""
        width: parent ? parent.width : 0
        height: 44

        IconImage {
            anchors.verticalCenter: parent.verticalCenter
            implicitSize: 24
            visible: row.iconName !== ""
            source: row.iconName !== "" ? Quickshell.iconPath(row.iconName, true) : ""
        }
        Icon {
            anchors.verticalCenter: parent.verticalCenter
            width: 24
            visible: row.iconName === ""
            name: "graphic_eq"
            size: 20
            color: Theme.textFaint
        }
        Column {
            x: 34
            anchors.verticalCenter: parent.verticalCenter
            width: pop.colX - 8 - 34 - 6
            Txt {
                width: parent.width
                text: row.app ? row.app.name : ""
                color: row.muted ? Theme.textFaint : Theme.text
            }
            // auf welchem GoXLR-Kanal die App landet
            Txt {
                width: parent.width
                text: row.channel
                color: Theme.textFaint
                font.pixelSize: 11
                font.weight: Font.Normal
            }
        }
        Slider {
            x: pop.colX - 8
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - x - 40 - 6 - 30
            value: row.vol
            fill: row.muted ? Theme.textFaint : Theme.woodLight
            onMoved: v => Mixer.setAppVolume(row.app, v)
        }
        MonoTxt {
            anchors.right: muteBtn.left
            anchors.rightMargin: 2
            anchors.verticalCenter: parent.verticalCenter
            width: 40
            horizontalAlignment: Text.AlignRight
            text: Math.round(row.vol * 100) + "%"
            color: Theme.textMuted
            font.pixelSize: 12
        }
        MuteBtn {
            id: muteBtn
            anchors.right: parent.right
            anchors.rightMargin: -6
            anchors.verticalCenter: parent.verticalCenter
            muted: row.muted
            onClicked: Mixer.setAppMuted(row.app, !row.muted)
        }
    }

    // ---------- Karte ----------
    Glass {
        id: card
        // offen bis zum Weghovern (PopoutGuard.qml)
        PopoutGuard { id: guard; popout: pop; chip: pop.chip; name: "mixer" }
        // Tastatur: Pfeile/Tab/Enter, Bar-Modus (Super+B, KeyNav.qml)
        Keys.onPressed: e => nav.key(e)
        KeyNav { id: nav; root: card; scope: keys; popout: pop; guard: guard; name: "mixer" }
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

        Row {
            id: head
            x: 20
            y: 18
            height: 30
            spacing: 8
            Icon {
                anchors.verticalCenter: parent.verticalCenter
                name: "tune"
                size: 22
                color: Theme.accentText
            }
            Txt {
                anchors.verticalCenter: parent.verticalCenter
                text: "Sound"
                font.pixelSize: 18
                font.weight: Font.DemiBold
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

                // ---------- 1) Routing: zwei gleich gebaute Zeilen, darunter einmal der Lock-Hinweis ----------
                Section { text: "Routing" }
                GoxlrPanel {
                    width: body.width
                    compact: true
                    outlined: true
                    title: ""
                    showLevels: false
                    nameW: pop.colX - 12
                }
                // kleiner, ruhiger Hinweis (kein Regler für den Ausgang)
                Row {
                    visible: Audio.guarding
                    height: 28
                    spacing: 6
                    Icon {
                        anchors.verticalCenter: parent.verticalCenter
                        name: "lock"
                        size: 13
                        color: Theme.textFaint
                    }
                    Txt {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "System volume is locked at 100 % (GoXLR)"
                        color: Theme.textFaint
                        font.pixelSize: 12
                        font.weight: Font.Normal
                    }
                }

                // ---------- 2) Channels: GoXLR-Pegel (nur ansehen) ----------
                Section {
                    visible: GoXLR.online
                    spaced: true
                    text: "Channels"
                }
                Repeater {
                    model: pop.mainKeys
                    GoxlrLevel {
                        required property string modelData
                        key: modelData
                        width: body.width - pop.trailW
                        nameW: pop.colX - 12
                    }
                }

                // ---------- 3) Apps: alle Streams, mit Kanal-Hinweis ----------
                Section {
                    spaced: true
                    text: "Apps"
                }
                Txt {
                    visible: AudioOut.apps.length === 0
                    width: parent.width
                    height: 30
                    text: "No app is playing sound"
                    color: Theme.textFaint
                    font.pixelSize: 13
                    font.weight: Font.Normal
                }
                Repeater {
                    model: AudioOut.apps
                    AppRow {
                        required property var modelData
                        app: modelData
                    }
                }
            }
        }
    }
}

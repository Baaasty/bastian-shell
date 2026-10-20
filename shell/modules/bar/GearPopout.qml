import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.services
import qs.components

// Gear-Popout unter dem Gear-Chip (Muster wie LightPopout: Klick daneben / Esc schließt, offen bis zum Weghovern).
// PC-Licht (scripts/rgb): an/aus, Farbe aus Palette-Tokens, Sättigung/Helligkeit der LEDs, letzter Lauf + neu setzen.
// Maus G502 X PLUS (scripts/mouse, Solaar): Akku, Profil, DPI-Stufen, Farbe – Entwurf, erst „Save to mouse“ schreibt (Flash).
// Tastatur (Drop ALT): nur Hinweis. (Systemeinstellungen: eigener Chip, SettingsChip.qml)
// Abfragen laufen nur, solange es offen ist (Devices.watch).
PopupWindow {
    id: pop

    property var barWindow
    property Item chip
    readonly property int cardW: 620
    readonly property int maxCardH: 520
    property real appear: 0
    property real _closedAt: 0
    // DPI-Stufe, deren Wert der Balken zeigt (Klick auf eine Stufe wählt sie)
    property int stage: 0
    readonly property real cardH: card.height

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
        stage = Devices.shownDefault;
        appear = 0;
        visible = true;
        appearAnim.restart();
    }
    function close(): void {
        guard.intended = true;
        visible = false;
    }
    function toggle(): void {
        if (visible || Date.now() - _closedAt < 400)
            close();
        else
            open();
    }

    onVisibleChanged: {
        if (barWindow && barWindow.openMenus !== undefined)
            barWindow.openMenus += visible ? 1 : -1;
        Devices.watch(visible);
        if (visible) {
            Popouts.claim("gear");
            keys.forceActiveFocus();
        } else {
            Popouts.release("gear");
            _closedAt = Date.now();
            appearAnim.stop();
        }
    }
    Component.onDestruction: if (visible) Devices.watch(false)
    Connections {
        target: Popouts
        function onCurrentChanged() {
            if (Popouts.current !== "gear" && pop.visible)
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

    // ---------- Bausteine (Raster wie LightPanel: Name 96 · Vorne 44 · Haupt · Hinten 196) ----------
    component Name: Txt {
        Layout.preferredWidth: 96
        Layout.maximumWidth: 96
        color: Theme.textMuted
        font.pixelSize: 13
        font.weight: Font.Normal
    }
    component Front: Item {
        Layout.preferredWidth: 44
        Layout.minimumWidth: 44
        Layout.preferredHeight: 30
    }
    component Hint: Txt {
        Layout.fillWidth: true
        color: Theme.textFaint
        font.pixelSize: 13
        font.weight: Font.Normal
    }
    component Sep: Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 1
        color: Theme.border
    }
    // Knopf-Chip: aktiv = Glut-Ton (wie LightPanel)
    component Pick: Chip {
        id: pk
        property string label
        property string iconName
        padding: 12
        color: active ? Theme.accentSoft : hovered && enabled ? Qt.alpha(Theme.text, 0.1) : Theme.raise
        opacity: enabled ? 1 : 0.45
        Icon {
            anchors.verticalCenter: parent.verticalCenter
            visible: pk.iconName !== ""
            name: pk.iconName
            size: 15
            color: pk.active ? Theme.accentText : Theme.textMuted
        }
        Txt {
            anchors.verticalCenter: parent.verticalCenter
            visible: pk.label !== ""
            text: pk.label
            color: pk.active ? Theme.accentText : Theme.textMuted
        }
    }
    // Farbpunkt (26 px): Farbe aus den Palette-Tokens, gewählt = Glut-Rand
    component Dot: Rectangle {
        id: dt
        property bool selected: false
        property string tip: ""
        signal picked()
        implicitWidth: 26
        implicitHeight: 26
        radius: 13
        border.width: 2
        border.color: selected ? Theme.accent : dtArea.containsMouse && enabled ? Theme.text : Theme.borderStrong
        opacity: enabled ? 1 : 0.4
        scale: dtArea.containsMouse && enabled ? 1.08 : 1
        Behavior on border.color { ColorAnimation { duration: Theme.fade } }
        Behavior on scale { NumberAnimation { duration: Theme.fade; easing.type: Easing.OutCubic } }
        MouseArea {
            id: dtArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: dt.picked()
        }
    }
    component Spinner: Icon {
        id: sp
        name: "progress_activity"
        size: 15
        color: Theme.accentText
        RotationAnimator on rotation {
            running: sp.visible
            from: 0
            to: 360
            duration: 900
            loops: Animation.Infinite
        }
    }

    // ---------- Karte ----------
    Glass {
        id: card
        PopoutGuard { id: guard; popout: pop; chip: pop.chip; name: "gear" }
        // Tastatur: Pfeile/Tab/Enter, ←/→ an Balken (nach Enter), Bar-Modus „G“ (KeyNav.qml)
        Keys.onPressed: e => nav.key(e)
        KeyNav { id: nav; root: card; scope: keys; popout: pop; guard: guard; name: "gear" }
        width: pop.cardW
        height: rows.y + rows.height + 20
        strong: true
        opacity: pop.appear
        transform: Translate { y: (1 - pop.appear) * -6 }

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
                name: "mouse"
                size: 22
                color: Theme.accentText
            }
            Txt {
                anchors.verticalCenter: parent.verticalCenter
                text: "Gear"
                font.pixelSize: 18
                font.weight: Font.DemiBold
            }
        }

        ColumnLayout {
            id: rows
            readonly property int backW: 196
            x: 20
            y: head.y + head.height + 14
            width: card.width - 40
            spacing: 12

            // ---------- PC-Licht ----------
            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 30
                spacing: 12
                Name {
                    text: "PC light"
                }
                Front {
                    ToggleSwitch {
                        anchors.centerIn: parent
                        enabled: Devices.rgbReady && Devices.rgbInstalled
                        checked: Devices.rgbOn
                        onToggled: Devices.toggleRgb()
                    }
                }
                Row {
                    Layout.fillWidth: true
                    spacing: 8
                    visible: Devices.rgbInstalled
                    Repeater {
                        model: Devices.rgbTokens
                        Dot {
                            required property var modelData
                            color: modelData.led
                            enabled: Devices.rgbOn
                            selected: Devices.rgbOn && Devices.rgbToken === modelData.name
                            onPicked: Devices.setRgb(modelData.name)
                        }
                    }
                }
                Hint {
                    visible: !Devices.rgbInstalled
                    text: "OpenRGB missing (docs/knowledge/hardware.md)"
                }
                // Hinten: letzter Lauf oder Spinner, dazu „neu setzen“
                Item {
                    Layout.preferredWidth: rows.backW
                    Layout.preferredHeight: 30
                    visible: Devices.rgbInstalled
                    Row {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 8
                        Spinner {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: Devices.rgbRunning
                        }
                        Txt {
                            anchors.verticalCenter: parent.verticalCenter
                            color: Theme.textFaint
                            font.pixelSize: 12
                            font.weight: Font.Normal
                            readonly property string when: Devices.rgbLast.at > 0 ? " · " + Qt.formatTime(new Date(Devices.rgbLast.at * 1000), "HH:mm") : ""
                            text: Devices.rgbRunning ? "setting … (~25 s)"
                                : Devices.rgbLast.aborted ? "interrupted" + when
                                : Devices.rgbLast.at > 0 ? Devices.rgbLast.ok + " of " + Devices.rgbLast.total + " set" + when
                                : "not set yet"
                        }
                        Pick {
                            visible: !Devices.rgbRunning
                            iconName: "refresh"
                            padding: 8
                            onClicked: Devices.reapplyRgb()
                        }
                    }
                }
            }
            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 30
                spacing: 12
                visible: Devices.rgbInstalled
                Name {}
                Front {}
                LevelBar {
                    Layout.fillWidth: true
                    enabled: Devices.rgbOn
                    from: 0
                    to: 100
                    stepSize: 5
                    wheelStep: 5
                    value: Math.round(Devices.shownSat * 100)
                    iconName: "palette"
                    label: "Saturation " + Math.round(Devices.shownSat * 100) + "%"
                    onMoved: v => Devices.tuneRgb(v / 100, Devices.shownBri)
                }
                LevelBar {
                    Layout.preferredWidth: rows.backW
                    enabled: Devices.rgbOn
                    from: 10
                    to: 100
                    stepSize: 5
                    wheelStep: 5
                    value: Math.round(Devices.shownBri * 100)
                    iconName: "light_mode"
                    label: Math.round(Devices.shownBri * 100) + "%"
                    onMoved: v => Devices.tuneRgb(Devices.shownSat, v / 100)
                }
            }

            Sep {}

            // ---------- Maus ----------
            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 30
                spacing: 12
                Name {
                    text: "Mouse"
                }
                Front {
                    Icon {
                        anchors.centerIn: parent
                        name: Devices.battery < 0 ? "battery_unknown" : Devices.charging ? "battery_charging_full"
                            : Devices.lowBattery ? "battery_alert" : Devices.battery >= 60 ? "battery_full" : "battery_3_bar"
                        size: 20
                        color: Devices.lowBattery ? Theme.warning : Devices.mouseOk ? Theme.textMuted : Theme.textFaint
                    }
                }
                Txt {
                    Layout.fillWidth: true
                    color: Devices.mouseOk ? Theme.text : Theme.textFaint
                    font.pixelSize: 13
                    font.weight: Font.Normal
                    text: {
                        const s = Devices.mouseState;
                        if (s === "nosolaar")
                            return "Solaar missing (sudo dnf install solaar)";
                        if (s === "absent")
                            return "Mouse not connected";
                        if (s === "")
                            return "…";
                        const parts = [];
                        if (Devices.battery >= 0)
                            parts.push(Devices.battery + " %" + (Devices.charging ? ", charging" : ""));
                        if (Devices.profile > 0)
                            parts.push("Profile " + Devices.profile);
                        else if (s === "ok")
                            parts.push("onboard profiles off");
                        if (Devices.dpi > 0)
                            parts.push(Devices.dpi + " DPI");
                        if (s === "asleep")
                            parts.push("asleep – move it to wake");
                        if (s === "error")
                            parts.push(Devices.mouseError || "error");
                        return parts.join(" · ");
                    }
                }
                // Hinten: verwerfen + speichern (nur mit Entwurf oder Meldung, sonst hat der Text die Breite)
                Item {
                    visible: Devices.mouseDirty || Devices.saving || Devices.saveNote !== ""
                    Layout.preferredWidth: rows.backW
                    Layout.preferredHeight: 30
                    Row {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 6
                        Spinner {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: Devices.saving
                        }
                        Txt {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: !Devices.mouseDirty && !Devices.saving && Devices.saveNote !== ""
                            text: Devices.saveNote
                            color: Theme.textFaint
                            font.pixelSize: 12
                            font.weight: Font.Normal
                        }
                        Pick {
                            visible: Devices.mouseDirty && !Devices.saving
                            iconName: "undo"
                            padding: 8
                            onClicked: Devices.revertMouse()
                        }
                        Pick {
                            visible: Devices.mouseDirty || Devices.saving
                            enabled: Devices.mouseOk && !Devices.saving
                            active: true
                            iconName: "save"
                            label: Devices.saving ? "Saving…" : "Save to mouse"
                            onClicked: Devices.saveMouse()
                        }
                    }
                }
            }
            // DPI-Stufen: Klick wählt die Stufe für den Balken, Stern an der Stufe = Standardstufe;
            // der Stern vorne macht die gewählte Stufe zur Standardstufe
            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 30
                spacing: 12
                visible: Devices.mouseLoaded
                Name {
                    text: "DPI"
                }
                Front {
                    Pick {
                        anchors.centerIn: parent
                        enabled: Devices.mouseOk && pop.stage !== Devices.shownDefault
                        tip: "Make default stage"
                        padding: 7
                        iconName: "star"
                        onClicked: Devices.setDefaultStage(pop.stage)
                    }
                }
                RowLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 30
                    spacing: 6
                    Repeater {
                        model: Devices.shownRes
                        Pick {
                            required property var modelData
                            required property int index
                            Layout.fillWidth: true
                            Layout.minimumWidth: 0
                            padding: 8
                            enabled: Devices.mouseOk
                            active: pop.stage === index
                            iconName: Devices.shownDefault === index ? "star" : ""
                            label: String(modelData)
                            onClicked: pop.stage = index
                        }
                    }
                }
                LevelBar {
                    Layout.preferredWidth: rows.backW
                    enabled: Devices.mouseOk && pop.stage < Devices.shownRes.length
                    from: 100
                    to: 6400
                    stepSize: 50
                    wheelStep: 50
                    value: Devices.shownRes[pop.stage] ?? 0
                    iconName: "speed"
                    label: (Devices.shownRes[pop.stage] ?? 0) + " DPI"
                    onMoved: v => Devices.setStageDpi(pop.stage, v)
                }
            }
            // Farbe des Logos (Onboard-Profil): Palette-Tokens wie das PC-Licht, „Same as PC“ = genau die PC-Farbe
            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 30
                spacing: 12
                visible: Devices.mouseLoaded
                Name {
                    text: "Color"
                }
                Front {}
                Row {
                    Layout.fillWidth: true
                    spacing: 8
                    Repeater {
                        model: Devices.rgbTokens
                        Dot {
                            required property var modelData
                            anchors.verticalCenter: parent.verticalCenter
                            color: modelData.led
                            enabled: Devices.mouseOk
                            selected: Devices.shownColor.toUpperCase() === String(modelData.led).toUpperCase()
                            onPicked: Devices.setMouseColor(modelData.led)
                        }
                    }
                    Pick {
                        enabled: Devices.mouseOk && Devices.rgbLed !== ""
                        active: Devices.rgbLed !== "" && Devices.shownColor.toUpperCase() === Devices.rgbLed.toUpperCase()
                        iconName: "link"
                        label: "Same as PC"
                        onClicked: Devices.setMouseColor(Devices.rgbLed)
                    }
                }
                Txt {
                    Layout.preferredWidth: rows.backW
                    horizontalAlignment: Text.AlignRight
                    color: Theme.textFaint
                    font.pixelSize: 12
                    font.weight: Font.Normal
                    text: Devices.mouseDirty ? "not saved yet" : Devices.shownColor !== "" ? Devices.shownColor : "no static color"
                }
            }

            Sep {}

            // ---------- Tastatur ----------
            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 30
                spacing: 12
                Name {
                    text: "Keyboard"
                }
                Front {}
                Hint {
                    text: "Drop ALT – not controllable"
                }
            }
        }
    }
}

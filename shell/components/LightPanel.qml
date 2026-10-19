import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.config
import qs.services

// Licht-Teil, gemeinsam genutzt von der Dashboard-Kachel „Light & Sound“ und dem Licht-Popout der Bar (LightPopout.qml):
// Key Light (an/aus, Helligkeit, Farbtemperatur), Hue (Raum, Farbwähler, Szenen, Aus / Andere · n), Kamera-Belichtung.
// Farbwähler und Kontextmenü liegen als Overlay über den Zeilen darunter (in der Kachel auch über dem GoXLR-Teil).
// Fragt Key Light, Hue und Kamera nur ab, solange sichtbar (watch(): mehrere Panels können gleichzeitig offen sein).
Item {
    id: panel

    // Abstand der 30-px-Zeilen (Kachel: gleichmäßig über die Höhe verteilt, siehe ControlsTile.qml)
    property real rowSpacing: 12
    // Breite der Spalte „Hinten“ (Kelvin-Balken, Aus-Chips)
    property int backW: 196
    // Unterkante, bis zu der der Farbwähler reicht (Kachel: ganze Kachel; Popout: das Panel selbst)
    property real pickerBottom: height
    // Mindesthöhe des Farbwählers: reicht der Platz darunter nicht, wächst das Panel, solange er offen ist (Popout)
    property real pickerRoom: 0
    // Fläche, auf der ein Klick daneben das Kontextmenü schließt (Kachel/Karte); ohne = nur das Panel
    property Item catchArea: null

    readonly property bool shown: visible && !!QsWindow.window && QsWindow.window.visible

    // Hue-Farbwähler und Kontextmenü
    property bool pickerOpen: false
    property string menuKind: ""      // "" | scene | off (sichtbar)
    property string menuShown: ""     // Inhalt bleibt beim Ausblenden stehen
    property string menuScene: ""
    property real menuX: 0
    property rect catchRect: Qt.rect(0, 0, 0, 0)
    readonly property var menuEntries: {
        if (menuShown === "scene") {
            const ids = Hue.groupScenes.map(s => s.id);
            const i = ids.indexOf(menuScene);
            return [
                { act: "front", icon: "first_page", label: "Move to front", ok: i > 0 },
                { act: "left", icon: "chevron_left", label: "Move left", ok: i > 0 },
                { act: "right", icon: "chevron_right", label: "Move right", ok: i >= 0 && i < ids.length - 1 }
            ];
        }
        if (menuShown === "off")
            return [
                { act: "others", icon: "light_off", label: "Turn off other rooms", ok: Hue.othersOn },
                { act: "all", icon: "power_settings_new", label: "Turn off everything", ok: Hue.anyOn }
            ];
        return [];
    }
    function openMenu(kind: string, sceneId: string, chip: Item): void {
        menuScene = sceneId;
        menuX = chip.mapToItem(rows, 0, 0).x;
        const a = catchArea || panel;
        const p = a.mapToItem(panel, 0, 0);
        catchRect = Qt.rect(p.x, p.y, a.width, a.height);
        menuShown = kind;
        menuKind = kind;
    }
    function runMenu(act: string): void {
        const id = menuScene;
        menuKind = "";
        if (act === "front" || act === "left" || act === "right") {
            sceneStrip.animateNext();
            Hue.moveScene(id, act === "left" ? -1 : 1, act === "front");
        } else if (act === "others") {
            Hue.offOthers();
        } else if (act === "all") {
            Hue.allOff();
        }
    }

    // Platz unter der Hue-Zeile bis zur Unterkante; fehlt etwas zur Mindesthöhe des Farbwählers, kommt es solange dazu
    readonly property real pickerTop: hueRow.y + hueRow.height + 8
    // Popout (pickerRoom > 0): mindestens so hoch, wie der Farbwähler gern wäre; Kachel: bis zur Unterkante
    readonly property real pickerNeed: pickerRoom > 0 ? Math.max(pickerRoom, picker.implicitHeight) : 0
    readonly property real pickerGrow: pickerOpen ? Math.max(0, pickerNeed - (rows.implicitHeight + 14 - pickerTop)) : 0

    implicitWidth: 560
    implicitHeight: rows.implicitHeight + pickerGrow

    // Zuschauer melden (Dienste zählen mit)
    property bool _watching: false
    onShownChanged: {
        if (!shown) {
            pickerOpen = false;
            menuKind = "";
        }
        sync();
    }
    Component.onCompleted: sync()
    Component.onDestruction: {
        if (_watching) {
            KeyLight.watch(false);
            Hue.watch(false);
            Camera.watch(false);
        }
    }
    function sync(): void {
        if (shown !== _watching) {
            _watching = shown;
            KeyLight.watch(shown);
            Hue.watch(shown);
            Camera.watch(shown);
        }
    }

    component Name: Txt {
        Layout.preferredWidth: 96
        Layout.maximumWidth: 96
        color: Theme.textMuted
        font.pixelSize: 13
        font.weight: Font.Normal
    }

    // Spalte "Vorne": Schalter / Farbpunkt, zentriert; leer = Platzhalter, damit die Hauptspalte fluchtet
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

    // Schalter 40 × 24
    component Toggle: Rectangle {
        id: tg
        property bool checked
        signal toggled()
        implicitWidth: 40
        implicitHeight: 24
        radius: 12
        color: checked ? Theme.accent : Theme.borderStrong
        opacity: enabled ? 1 : 0.4
        Behavior on color { ColorAnimation { duration: Theme.fade } }
        Rectangle {
            y: 3
            x: tg.checked ? tg.width - width - 3 : 3
            width: 18
            height: 18
            radius: 9
            color: Theme.text
            Behavior on x { NumberAnimation { duration: Theme.stateChange; easing.type: Easing.OutCubic } }
        }
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: tg.toggled()
        }
    }

    // Balken-Regler (30 px, wie die Chips): Holz-Füllung, Icon links, Wert rechts im Balken.
    // Klicken/Ziehen setzt den Wert direkt (stepSize-Raster), Mausrad in wheelStep-Schritten; moved(v) wie beim Slider.
    component Bar: Rectangle {
        id: bar
        property real from: 0
        property real to: 1
        property real value: 0
        property real stepSize: 1
        property real wheelStep: stepSize   // Mausrad: feiner als Ziehen
        property real wheelAcc: 0
        property string iconName
        property string label
        property string extraIcon       // kleines Zusatz-Icon vor dem Wert (z. B. Kamera aus)
        signal moved(real value)

        // beim Ziehen eigener Wert, damit die Füllung nicht auf Antworten wartet
        property real dragValue: 0
        readonly property real shown: barArea.pressed ? dragValue : value
        readonly property real ratio: to > from ? Math.max(0, Math.min(1, (shown - from) / (to - from))) : 0

        function clamp(v: real): real {
            return Math.max(from, Math.min(to, v));
        }
        function fromX(x: real): real {
            const v = from + (to - from) * Math.max(0, Math.min(1, x / Math.max(1, width)));
            return clamp(Math.round(v / stepSize) * stepSize);
        }

        implicitWidth: 160
        implicitHeight: 30
        radius: Theme.radiusSm
        color: barArea.containsMouse && enabled ? Qt.alpha(Theme.text, 0.1) : Theme.raise
        opacity: enabled ? 1 : 0.4
        Behavior on color { ColorAnimation { duration: Theme.fade } }
        Behavior on opacity { NumberAnimation { duration: Theme.fade } }

        // Füllung: mindestens ein runder Stummel, damit auch der Minimalwert sichtbar ist
        Rectangle {
            width: bar.radius * 2 + (bar.width - bar.radius * 2) * bar.ratio
            height: parent.height
            radius: bar.radius
            color: Qt.alpha(Theme.woodLight, barArea.pressed ? 0.7 : 0.55)
            Behavior on width {
                enabled: !barArea.pressed
                NumberAnimation { duration: Theme.fade; easing.type: Easing.OutCubic }
            }
            Behavior on color { ColorAnimation { duration: Theme.fade } }
        }
        Icon {
            x: 10
            anchors.verticalCenter: parent.verticalCenter
            visible: bar.iconName !== ""
            name: bar.iconName
            size: 16
            color: Theme.text
        }
        Row {
            anchors.right: parent.right
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6
            Icon {
                anchors.verticalCenter: parent.verticalCenter
                visible: bar.extraIcon !== ""
                name: bar.extraIcon
                size: 14
                color: Theme.textFaint
            }
            MonoTxt {
                anchors.verticalCenter: parent.verticalCenter
                text: bar.label
                color: Theme.textMuted
                font.pixelSize: 12
            }
        }
        MouseArea {
            id: barArea
            anchors.fill: parent
            hoverEnabled: true
            preventStealing: true
            cursorShape: bar.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            onPressed: mouse => {
                bar.dragValue = bar.fromX(mouse.x);
                bar.moved(bar.dragValue);
            }
            onPositionChanged: mouse => {
                if (!pressed)
                    return;
                const v = bar.fromX(mouse.x);
                if (v !== bar.dragValue) {
                    bar.dragValue = v;
                    bar.moved(v);
                }
            }
            onWheel: wheel => {
                const d = wheel.angleDelta.y !== 0 ? wheel.angleDelta.y : -wheel.angleDelta.x;
                if (d === 0)
                    return;
                // nach Rasten zählen (120 = eine Raste): hochauflösende Mausräder schicken pro Raste mehrere Ereignisse
                bar.wheelAcc += d;
                const n = Math.trunc(bar.wheelAcc / 120);
                if (n === 0)
                    return;
                bar.wheelAcc -= n * 120;
                bar.moved(bar.clamp(bar.value + n * bar.wheelStep));
            }
        }
    }

    // Szenen-/Ausgang-Chip: aktiv = Glut-Ton
    component Pick: Chip {
        id: pk
        property string label
        property string iconName
        padding: 12
        color: active ? Theme.accentSoft : hovered ? Qt.alpha(Theme.text, 0.1) : Theme.raise
        Icon {
            anchors.verticalCenter: parent.verticalCenter
            visible: pk.iconName !== ""
            name: pk.iconName
            size: 15
            color: pk.active ? Theme.accentText : Theme.textMuted
        }
        Txt {
            anchors.verticalCenter: parent.verticalCenter
            text: pk.label
            color: pk.active ? Theme.accentText : Theme.textMuted
        }
    }

    ColumnLayout {
        id: rows

        // Raster je Zeile: Name (96) · Vorne (44) · Haupt (füllt) · Hinten (backW, rechtsbündig)
        readonly property int backW: panel.backW
        width: panel.width
        spacing: panel.rowSpacing

        // Key Light: an/aus · Helligkeit · Farbtemperatur
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 30
            spacing: 12
            Name {
                text: "Key Light"
            }
            Front {
                Toggle {
                    anchors.centerIn: parent
                    enabled: KeyLight.online
                    checked: KeyLight.on
                    onToggled: KeyLight.toggle()
                }
            }
            Bar {
                Layout.fillWidth: true
                enabled: KeyLight.online
                from: 3
                to: 100
                stepSize: 5
                wheelStep: 1
                value: KeyLight.brightness
                iconName: "light_mode"
                label: !KeyLight.configured ? "not set up" : !KeyLight.ready ? "…" : !KeyLight.online ? "offline" : KeyLight.brightness + "%"
                onMoved: v => KeyLight.setBrightness(v)
            }
            Bar {
                Layout.preferredWidth: rows.backW
                enabled: KeyLight.online
                from: KeyLight.kelvinMin
                to: KeyLight.kelvinMax
                stepSize: 100
                wheelStep: 50
                value: KeyLight.kelvin
                iconName: "device_thermostat"
                label: KeyLight.online ? KeyLight.kelvin + " K" : ""
                onMoved: v => KeyLight.setKelvin(v)
            }
        }

        // Hue: Raum (Klick = nächster), Farbpunkt (Farbwähler), Szenen (ziehen = sortieren), Aus / Andere · n
        RowLayout {
            id: hueRow
            Layout.fillWidth: true
            Layout.preferredHeight: 30
            spacing: 12
            Name {
                text: Hue.group ? Hue.group.name : "Hue"
                MouseArea {
                    anchors.fill: parent
                    enabled: Hue.groups.length > 1
                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: Hue.cycleGroup()
                }
            }
            // aktuelle Lichtfarbe; Klick öffnet den Farbwähler
            Front {
                Rectangle {
                    id: dot
                    readonly property bool lit: !!Hue.group && Hue.group.on
                    anchors.centerIn: parent
                    visible: Hue.status === "ok"
                    enabled: !!Hue.group && Hue.group.lightId !== ""
                    width: 26
                    height: 26
                    radius: 13
                    // Lampen ohne Farbe: Creme
                    color: !lit ? Theme.raise : Hue.group.color ? Hue.group.color : Theme.text
                    border.width: 2
                    border.color: panel.pickerOpen ? Theme.accent : dotArea.containsMouse ? Theme.text : Theme.borderStrong
                    opacity: enabled ? 1 : 0.4
                    scale: dotArea.containsMouse ? 1.08 : 1
                    Behavior on color { ColorAnimation { duration: Theme.fade } }
                    Behavior on border.color { ColorAnimation { duration: Theme.fade } }
                    Behavior on scale { NumberAnimation { duration: Theme.fade; easing.type: Easing.OutCubic } }
                    Icon {
                        anchors.centerIn: parent
                        visible: !dot.lit
                        name: "palette"
                        size: 14
                        color: Theme.textFaint
                    }
                    MouseArea {
                        id: dotArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: panel.pickerOpen = !panel.pickerOpen
                    }
                }
            }
            Hint {
                visible: Hue.status !== "ok"
                text: Hue.status === "unpaired" ? "Pair Hue: scripts/hue-pair"
                    : Hue.status === "unauthorized" ? "Invalid Hue key: scripts/hue-pair --force"
                    : Hue.status === "offline" ? "Bridge unreachable"
                    : "Loading…"
            }
            HueScenes {
                id: sceneStrip
                visible: Hue.status === "ok"
                Layout.fillWidth: true
                Layout.preferredHeight: 30
                scenes: Hue.groupScenes
                groupKey: Hue.groupId
                onRecalled: id => Hue.recall(id)
                onReordered: ids => Hue.setOrder(Hue.groupId, ids)
                onMenuRequested: (id, chip) => panel.openMenu("scene", id, chip)
            }
            // Spalte "Hinten": Chips rechtsbündig, Breite wie der Kelvin-Balken darüber
            Item {
                visible: Hue.status === "ok"
                Layout.preferredWidth: Math.max(rows.backW, offRow.implicitWidth)
                Layout.preferredHeight: 30
                Row {
                    id: offRow
                    anchors.right: parent.right
                    spacing: 6
                    Pick {
                        id: offChip
                        visible: !!Hue.group && Hue.group.lightId !== ""
                        label: "Off"
                        iconName: "power_settings_new"
                        active: !!Hue.group && !Hue.group.on
                        onClicked: mouse => {
                            if (mouse && mouse.button === Qt.RightButton)
                                panel.openMenu("off", "", offChip);
                            else
                                Hue.off(Hue.groupId);
                        }
                    }
                    // Befehl mit Zähler: brennende Lampen außerhalb des Raums, Klick = aus.
                    // Bei 0 leise und ohne Wirkung; Rechtsklick: Menü mit "Alles aus"
                    Pick {
                        id: othersChip
                        readonly property bool live: Hue.othersCount > 0
                        label: "Others · " + Hue.othersCount
                        iconName: "light_off"
                        color: live && hovered ? Qt.alpha(Theme.text, 0.1) : Theme.raise
                        opacity: live ? 1 : 0.45
                        Behavior on opacity { NumberAnimation { duration: Theme.fade } }
                        onClicked: mouse => {
                            if (mouse && mouse.button === Qt.RightButton)
                                panel.openMenu("off", "", othersChip);
                            else if (live)
                                Hue.offOthers();
                        }
                    }
                }
            }
        }

        // Kamera: Auto-Belichtung immer an, Balken = Helligkeit (greift sofort bzw. beim nächsten Einschalten der Kamera)
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 30
            spacing: 12
            // unter dem Farbwähler ausblenden
            opacity: panel.pickerOpen ? 0 : 1
            Behavior on opacity { NumberAnimation { duration: Theme.fade; easing.type: Easing.OutCubic } }
            Name {
                text: "Camera"
            }
            Front {}
            Bar {
                Layout.fillWidth: true
                enabled: Camera.present
                from: Camera.brightnessMin
                to: Camera.brightnessMax
                stepSize: 5
                wheelStep: 3                    // 0–255 roh, 3 ≈ 1 %
                value: Camera.wantBrightness
                iconName: "brightness_6"
                label: !Camera.ready ? "…" : !Camera.present ? "not found" : Camera.percent + "%"
                onMoved: v => Camera.setBrightness(v)
            }
            // Spalte "Hinten": bei ausgeschalteter Kamera leiser Hinweis, sonst leer (Balken fluchtet mit Key Light)
            Item {
                Layout.preferredWidth: rows.backW
                Layout.preferredHeight: 30
                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 6
                    visible: Camera.present && !Camera.busy
                    Icon {
                        anchors.verticalCenter: parent.verticalCenter
                        name: "videocam_off"
                        size: 14
                        color: Theme.textFaint
                    }
                    Txt {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "applies when camera is on"
                        color: Theme.textFaint
                        font.pixelSize: 12
                        font.weight: Font.Normal
                    }
                }
            }
        }
    }

    // Farbwähler: über den unteren Zeilen (in der Kachel bis zur Unterkante)
    HueColorPicker {
        id: picker
        x: -12
        y: panel.pickerTop + (1 - opacity) * -6
        width: rows.width + 24
        height: Math.max(panel.pickerNeed, panel.pickerBottom + 14 - panel.pickerTop)
        z: 5
        group: Hue.group
        opacity: panel.pickerOpen && Hue.status === "ok" ? 1 : 0
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: Theme.fade; easing.type: Easing.OutCubic } }
        onClosed: panel.pickerOpen = false
    }

    // Kontextmenü: Klick daneben schließt
    MouseArea {
        x: panel.catchRect.x
        y: panel.catchRect.y
        width: panel.catchRect.width
        height: panel.catchRect.height
        z: 9
        visible: panel.menuKind !== ""
        acceptedButtons: Qt.AllButtons
        onPressed: panel.menuKind = ""
        onWheel: wheel => panel.menuKind = ""
    }
    // opak (Theme: surface = Menüs ohne Blur), damit die Zeilen darunter nicht durchscheinen
    Rectangle {
        id: menu
        z: 10
        color: Theme.surface
        radius: Theme.radiusMd
        border.width: 1
        border.color: Theme.border
        width: 190
        height: menuCol.implicitHeight + 12
        x: Math.max(-12, Math.min(rows.width + 12 - width, panel.menuX))
        y: hueRow.y + hueRow.height + 4 + (1 - opacity) * -4
        opacity: panel.menuKind !== "" ? 1 : 0
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: Theme.fade; easing.type: Easing.OutCubic } }

        Column {
            id: menuCol
            x: 6
            y: 6
            width: parent.width - 12
            Repeater {
                model: panel.menuEntries
                Chip {
                    required property var modelData
                    width: menuCol.width
                    alignLeft: true
                    enabled: modelData.ok
                    opacity: enabled ? 1 : 0.4
                    onClicked: panel.runMenu(modelData.act)
                    Icon {
                        anchors.verticalCenter: parent.verticalCenter
                        name: modelData.icon
                        size: 16
                        color: Theme.textMuted
                    }
                    Txt {
                        anchors.verticalCenter: parent.verticalCenter
                        text: modelData.label
                        color: Theme.text
                    }
                }
            }
        }
    }
}

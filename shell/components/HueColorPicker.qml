import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services
import qs.components

// Eigene Farbe für den gewählten Hue-Raum: runder Farbkreis (Farbton × Sättigung -> CIE xy), Helligkeit,
// Weißton (warm ↔ kalt, mirek) und gemütliche Vorlagen. Liegt als Overlay im Licht-Teil
// (LightPanel.qml: Dashboard-Kachel und Licht-Popout). Ziehen sendet live, Hue.live() drosselt (150 ms, letzter Wert kommt an).
// Tastatur (sobald offen, hat der Wähler den Fokus): ←/→ Farbton, ↑/↓ Sättigung, [ / ] wärmer/kälter,
// −/+ Helligkeit, 1–9/0 Vorlagen, Enter fertig, Esc zu.
// Farbkreis, Knöpfe und Vorlagen zeigen Lichtfarben (Daten, leicht gedämpft: kein Neon), keine Theme-Farben.
Glass {
    id: picker

    property var group: null
    signal closed()

    // eigener Stand, damit die Knöpfe nicht auf die Bridge warten
    property real hue: 0.08
    property real sat: 0.7
    property real mirek: 366
    property string mode: "ct"        // ct | xy
    readonly property bool canColor: !!group && group.hasColor
    readonly property bool canCt: !!group && group.hasCt
    readonly property bool canDim: !!group && group.lightId !== ""
    readonly property real mirekMin: group ? group.mirekMin : 153
    readonly property real mirekMax: group ? group.mirekMax : 500
    readonly property real bri: group && group.on ? group.bri : 0

    // gemütliche Vorlagen: Weißtöne (Kelvin) und gedämpfte Farben (Farbton/Sättigung 0..1)
    readonly property var presets: [
        { key: 1, name: "Candle", k: 2000 },
        { key: 2, name: "Warm white", k: 2700 },
        { key: 3, name: "Reading", k: 3500 },
        { key: 4, name: "Daylight", k: 5000 },
        { key: 5, name: "Fireplace", h: 0.055, s: 0.92 },
        { key: 6, name: "Ember", h: 0.012, s: 0.85 },
        { key: 7, name: "Amber", h: 0.1, s: 0.85 },
        { key: 8, name: "Dusk", h: 0.93, s: 0.45 },
        { key: 9, name: "Forest", h: 0.3, s: 0.45 },
        { key: 0, name: "Moonlight", h: 0.6, s: 0.5 }
    ]
    property string hoverName: ""

    // gewünschte Höhe (Popout: LightPanel lässt so viel Platz)
    implicitHeight: 212
    strong: true
    radius: Theme.radiusMd
    activeFocusOnTab: true

    // ---------- Stand ----------

    // aus dem Raum übernehmen (beim Öffnen und Raumwechsel)
    function load(): void {
        if (!group)
            return;
        if (group.mode === "ct" && group.mirek > 0) {
            mode = "ct";
            mirek = group.mirek;
        } else if (group.mode === "xy" && group.xy) {
            mode = "xy";
            const c = Hue.xyToColor(group.xy.x, group.xy.y);
            if (c.hsvHue >= 0)
                hue = c.hsvHue;
            sat = c.hsvSaturation;
        }
    }
    property string loadedId: ""
    onGroupChanged: {
        if (group && group.id !== loadedId) {
            loadedId = group.id;
            load();
        }
    }

    // Fokus: beim Öffnen holen, beim Schließen dem vorherigen Halter zurückgeben (Popout: Esc schließt dann wieder das Popout)
    property Item prevFocus: null
    onVisibleChanged: {
        if (visible) {
            load();
            prevFocus = Window.activeFocusItem;
            forceActiveFocus();
        } else {
            giveBackFocus();
        }
    }
    function giveBackFocus(): void {
        const p = prevFocus;
        prevFocus = null;
        if (p && p !== picker && p.visible)
            p.forceActiveFocus();
    }
    function finish(): void {
        giveBackFocus();
        closed();
    }

    // Anzeige etwas zurückgenommen (kein Neon), Sättigung 0 = Creme
    function shade(h: real, s: real): color {
        return Qt.tint(Theme.text, Qt.hsva(h, 0.72, 0.86, s));
    }
    function kToMirek(k: real): real {
        return Math.max(mirekMin, Math.min(mirekMax, 1e6 / k));
    }
    readonly property color current: mode === "ct" ? Hue.mirekToColor(mirek) : shade(hue, sat)

    function pickColor(): void {
        if (!canColor)
            return;
        mode = "xy";
        Hue.setColor(group.id, hue, sat);
    }
    function pickMirek(): void {
        if (!canCt)
            return;
        mode = "ct";
        Hue.setMirek(group.id, mirek);
    }
    function setBri(pct: real): void {
        if (canDim)
            Hue.setBrightness(group.id, Math.max(1, Math.min(100, pct)));
    }

    // Vorlagen
    function presetColor(p: var): color {
        return p.k ? Hue.mirekToColor(1e6 / p.k) : shade(p.h, p.s);
    }
    function presetOk(p: var): bool {
        return p.k ? canCt : canColor;
    }
    // aktiv = der Raum steht gerade (ungefähr) auf dieser Vorlage; misst am Raum, nicht am eigenen Stand
    function presetActive(p: var): bool {
        if (!group || !group.on)
            return false;
        if (p.k)
            return group.mode === "ct" && Math.abs(group.mirek - Math.round(kToMirek(p.k))) <= 3;
        if (group.mode !== "xy" || !group.xy)
            return false;
        const q = Hue.hsvToXy(p.h, p.s, group.gamut);
        return Math.hypot(q.x - group.xy.x, q.y - group.xy.y) < 0.006;
    }
    function applyPreset(p: var): void {
        if (!presetOk(p))
            return;
        if (p.k) {
            mirek = kToMirek(p.k);
            pickMirek();
        } else {
            hue = p.h;
            sat = p.s;
            pickColor();
        }
    }
    readonly property var activePreset: {
        for (const p of presets)
            if (presetActive(p))
                return p;
        return null;
    }

    // ---------- Tastatur ----------
    function nudgeHue(d: real): void {
        if (!canColor)
            return;
        hue = ((hue + d) % 1 + 1) % 1;
        pickColor();
    }
    function nudgeSat(d: real): void {
        if (!canColor)
            return;
        sat = Math.max(0, Math.min(1, sat + d));
        pickColor();
    }
    function nudgeMirek(d: real): void {
        if (!canCt)
            return;
        mirek = Math.max(mirekMin, Math.min(mirekMax, mirek + d));
        pickMirek();
    }
    Keys.onPressed: event => {
        const big = (event.modifiers & Qt.ShiftModifier) ? 3 : 1;
        const k = event.key;
        if (k === Qt.Key_Left)
            nudgeHue(-big / 72);
        else if (k === Qt.Key_Right)
            nudgeHue(big / 72);
        else if (k === Qt.Key_Up)
            nudgeSat(big * 0.05);
        else if (k === Qt.Key_Down)
            nudgeSat(-big * 0.05);
        else if (k === Qt.Key_BracketLeft)
            nudgeMirek(big * 15);         // mehr mirek = wärmer
        else if (k === Qt.Key_BracketRight)
            nudgeMirek(-big * 15);
        else if (k === Qt.Key_Plus || k === Qt.Key_Equal)
            setBri(bri + 5 * big);
        else if (k === Qt.Key_Minus)
            setBri(bri - 5 * big);
        else if (k >= Qt.Key_0 && k <= Qt.Key_9) {
            const i = k === Qt.Key_0 ? 9 : k - Qt.Key_1;
            if (i < presets.length)
                applyPreset(presets[i]);
        } else if (k === Qt.Key_Return || k === Qt.Key_Enter || k === Qt.Key_Escape)
            finish();
        else
            return;
        event.accepted = true;
    }

    // Klicks nicht an die Kachel darunter durchreichen; Klick auf leere Fläche holt den Tastaturfokus
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.AllButtons
        onPressed: picker.forceActiveFocus()
        onWheel: wheel => wheel.accepted = true
    }

    // ---------- Bausteine ----------

    // weicher Knopf: Creme-Ring, Lichtfarbe innen, ruhiger Schatten
    component Knob: Item {
        id: kn
        property color fill: Theme.text
        property bool active: true
        property bool pressed: false
        property bool hovered: false
        width: 22
        height: 22
        scale: pressed ? 1.18 : hovered ? 1.06 : 1
        Behavior on scale { NumberAnimation { duration: Theme.fade; easing.type: Easing.OutCubic } }
        Rectangle {
            y: 1.5
            width: parent.width
            height: parent.height
            radius: width / 2
            color: Theme.shadow
            visible: kn.active
        }
        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: kn.fill
            border.width: kn.active ? 3 : 2
            border.color: kn.active ? Theme.text : Theme.textFaint
            Behavior on border.color { ColorAnimation { duration: Theme.fade } }
        }
    }

    // Verlaufsleiste mit Knopf; value 0..1, beim Ziehen eigener Wert
    component Bar: Item {
        id: bar
        property real value: 0
        property bool current: true
        property color knob: Theme.text
        property alias gradient: track.gradient
        property real dragValue: 0
        readonly property real shown: area.pressed ? dragValue : value
        signal moved(real v)

        Layout.fillWidth: true
        Layout.preferredHeight: 26
        opacity: enabled ? 1 : 0.35

        function at(x: real): real {
            return Math.max(0, Math.min(1, (x - track.x) / Math.max(1, track.width)));
        }
        function send(v: real): void {
            dragValue = v;
            moved(v);
        }

        Rectangle {
            id: track
            anchors.verticalCenter: parent.verticalCenter
            x: 11
            width: parent.width - 22
            height: 12
            radius: 6
            opacity: bar.current ? 1 : 0.6
            Behavior on opacity { NumberAnimation { duration: Theme.fade; easing.type: Easing.OutCubic } }
            border.width: 1
            border.color: Theme.border
        }
        Knob {
            anchors.verticalCenter: parent.verticalCenter
            x: track.x + bar.shown * track.width - width / 2
            visible: bar.enabled
            fill: bar.knob
            active: bar.current
            pressed: area.pressed
            hovered: area.containsMouse
        }
        MouseArea {
            id: area
            anchors.fill: parent
            hoverEnabled: true
            preventStealing: true
            cursorShape: bar.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            onPressed: mouse => {
                picker.forceActiveFocus();
                bar.send(bar.at(mouse.x));
            }
            onPositionChanged: mouse => {
                if (pressed)
                    bar.send(bar.at(mouse.x));
            }
            onWheel: wheel => {
                const d = wheel.angleDelta.y !== 0 ? wheel.angleDelta.y : -wheel.angleDelta.x;
                if (d !== 0)
                    bar.moved(Math.max(0, Math.min(1, bar.value + (d > 0 ? 0.03 : -0.03))));
            }
        }
    }

    component Value: MonoTxt {
        Layout.preferredWidth: 52
        horizontalAlignment: Text.AlignRight
        color: Theme.textFaint
        font.pixelSize: 12
    }
    component RowIcon: Icon {
        Layout.preferredWidth: 18
        size: 16
        color: Theme.textFaint
    }

    component Swatch: Item {
        id: sw
        required property var modelData
        readonly property bool ok: picker.presetOk(modelData)
        readonly property bool on: !!picker.activePreset && picker.activePreset.name === modelData.name
        width: presetRow.cell
        height: presetRow.cell
        opacity: ok ? 1 : 0.3

        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: "transparent"
            border.width: 2
            border.color: sw.on ? Theme.accent : swArea.containsMouse && sw.ok ? Theme.borderStrong : "transparent"
            Behavior on border.color { ColorAnimation { duration: Theme.fade } }
        }
        Rectangle {
            anchors.centerIn: parent
            width: parent.width - 8
            height: parent.height - 8
            radius: width / 2
            color: picker.presetColor(sw.modelData)
            border.width: 1
            border.color: Theme.border
            scale: swArea.pressed ? 0.92 : swArea.containsMouse && sw.ok ? 1.08 : 1
            Behavior on scale { NumberAnimation { duration: Theme.fade; easing.type: Easing.OutCubic } }
        }
        MouseArea {
            id: swArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: sw.ok ? Qt.PointingHandCursor : Qt.ArrowCursor
            onContainsMouseChanged: {
                if (containsMouse)
                    picker.hoverName = sw.modelData.name + "  ·  " + sw.modelData.key;
                else if (picker.hoverName.indexOf(sw.modelData.name) === 0)
                    picker.hoverName = "";
            }
            onClicked: {
                picker.forceActiveFocus();
                picker.applyPreset(sw.modelData);
            }
        }
    }

    // ---------- Farbkreis ----------
    Item {
        id: wheelBox
        readonly property real d: Math.max(110, Math.min(picker.height - 32, 220))
        x: 16
        anchors.verticalCenter: parent.verticalCenter
        width: d
        height: d

        // Mulde um den Kreis; Fokus = Akzent-Linie
        Rectangle {
            anchors.centerIn: parent
            width: parent.width + 10
            height: parent.height + 10
            radius: width / 2
            color: Theme.surfaceSunken
            border.width: picker.activeFocus ? 2 : 1
            border.color: picker.activeFocus ? Theme.accent : Theme.border
            Behavior on border.color { ColorAnimation { duration: Theme.fade } }
        }

        Canvas {
            id: wheel
            anchors.fill: parent
            opacity: picker.canColor ? (picker.mode === "xy" ? 1 : 0.7) : 0.3
            Behavior on opacity { NumberAnimation { duration: Theme.fade; easing.type: Easing.OutCubic } }
            readonly property color center: Theme.text
            onCenterChanged: requestPaint()
            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()
            onPaint: {
                const ctx = getContext("2d");
                const r = width / 2;
                ctx.reset();
                ctx.clearRect(0, 0, width, height);
                // Farbton rundherum (gegen den Uhrzeigersinn ab 3 Uhr, wie die Knopf-Rechnung unten)
                const cone = ctx.createConicalGradient(r, r, 0);
                for (let i = 0; i <= 12; i++)
                    cone.addColorStop(i / 12, Qt.hsva((i / 12) % 1, 0.72, 0.86, 1));
                ctx.beginPath();
                ctx.arc(r, r, r, 0, Math.PI * 2);
                ctx.closePath();
                ctx.fillStyle = cone;
                ctx.fill();
                // Sättigung: zur Mitte hin Creme
                const rad = ctx.createRadialGradient(r, r, 0, r, r, r);
                rad.addColorStop(0, Qt.alpha(center, 1));
                rad.addColorStop(1, Qt.alpha(center, 0));
                ctx.fillStyle = rad;
                ctx.fill();
            }
        }

        Knob {
            id: wheelKnob
            readonly property real r: wheelBox.d / 2
            readonly property real a: picker.hue * Math.PI * 2
            x: r + Math.cos(a) * picker.sat * r - width / 2
            y: r - Math.sin(a) * picker.sat * r - height / 2
            visible: picker.canColor
            width: 24
            height: 24
            fill: picker.shade(picker.hue, picker.sat)
            active: picker.mode === "xy"
            opacity: active ? 1 : 0.6
            pressed: wheelArea.pressed
            hovered: wheelArea.onKnob
            // weich gleiten (Vorlagen, Tastatur), beim Ziehen direkt folgen
            Behavior on x { enabled: !wheelArea.pressed; NumberAnimation { duration: Theme.fade; easing.type: Easing.OutCubic } }
            Behavior on y { enabled: !wheelArea.pressed; NumberAnimation { duration: Theme.fade; easing.type: Easing.OutCubic } }
        }

        MouseArea {
            id: wheelArea
            property bool grabbing: false
            property bool onKnob: false
            anchors.fill: parent
            anchors.margins: -6
            enabled: picker.canColor
            hoverEnabled: true
            preventStealing: true
            cursorShape: picker.canColor ? Qt.PointingHandCursor : Qt.ArrowCursor
            property real wheelAcc: 0

            function pick(mx: real, my: real): void {
                const r = wheelBox.d / 2;
                const dx = mx - 6 - r, dy = r - (my - 6);
                let a = Math.atan2(dy, dx) / (Math.PI * 2);
                if (a < 0)
                    a += 1;
                picker.hue = Math.min(a, 0.999);
                picker.sat = Math.min(1, Math.hypot(dx, dy) / r);
                picker.pickColor();
            }
            onPressed: mouse => {
                picker.forceActiveFocus();
                const r = wheelBox.d / 2;
                grabbing = Math.hypot(mouse.x - 6 - r, mouse.y - 6 - r) <= r + 6;
                if (grabbing)
                    pick(mouse.x, mouse.y);
            }
            onReleased: grabbing = false
            onPositionChanged: mouse => {
                onKnob = Math.hypot(mouse.x - 6 - (wheelKnob.x + 12), mouse.y - 6 - (wheelKnob.y + 12)) < 16;
                if (pressed && grabbing)
                    pick(mouse.x, mouse.y);
            }
            onExited: onKnob = false
            // Mausrad dreht den Farbton
            onWheel: wheel => {
                const d = wheel.angleDelta.y !== 0 ? wheel.angleDelta.y : -wheel.angleDelta.x;
                wheelAcc += d;
                const n = Math.trunc(wheelAcc / 120);
                if (n === 0)
                    return;
                wheelAcc -= n * 120;
                picker.nudgeHue(n / 72);
            }
        }
    }

    // ---------- rechts: Vorschau, Helligkeit, Weißton, Vorlagen ----------
    ColumnLayout {
        anchors.left: wheelBox.right
        anchors.leftMargin: 24
        anchors.right: parent.right
        anchors.rightMargin: 12
        anchors.top: parent.top
        anchors.topMargin: 12
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 12
        spacing: 6

        // Vorschau + Name + Wert, Schließen
        RowLayout {
            Layout.fillWidth: true
            spacing: 12
            Rectangle {
                Layout.preferredWidth: 34
                Layout.preferredHeight: 34
                radius: 17
                color: picker.group && picker.group.on ? picker.current : Theme.raise
                border.width: 2
                border.color: Theme.borderStrong
                Behavior on color { ColorAnimation { duration: Theme.fade } }
                Icon {
                    anchors.centerIn: parent
                    visible: !(picker.group && picker.group.on)
                    name: "light_off"
                    size: 16
                    color: Theme.textFaint
                }
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0
                Txt {
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                    text: picker.hoverName !== "" ? picker.hoverName
                        : !(picker.group && picker.group.on) ? "Off"
                        : picker.activePreset ? picker.activePreset.name
                        : picker.mode === "ct" ? "White" : "Custom color"
                    color: Theme.text
                    font.pixelSize: 14
                    font.weight: Font.DemiBold
                }
                MonoTxt {
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                    text: !picker.group ? ""
                        : picker.mode === "ct" ? Math.round(1e6 / picker.mirek / 50) * 50 + " K"
                        : Math.round(picker.hue * 360) + "° · " + Math.round(picker.sat * 100) + " %"
                    color: Theme.textFaint
                    font.pixelSize: 12
                }
            }
            Rectangle {
                Layout.preferredWidth: 26
                Layout.preferredHeight: 26
                Layout.alignment: Qt.AlignTop
                radius: Theme.radiusSm
                color: closeArea.containsMouse ? Theme.raise : "transparent"
                Behavior on color { ColorAnimation { duration: Theme.fade } }
                Icon {
                    anchors.centerIn: parent
                    name: "close"
                    size: 16
                    color: closeArea.containsMouse ? Theme.text : Theme.textFaint
                }
                MouseArea {
                    id: closeArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: picker.finish()
                }
            }
        }

        Item {
            Layout.fillHeight: true
        }

        // Helligkeit: dunkel -> aktuelle Lichtfarbe
        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            RowIcon {
                name: "brightness_6"
            }
            Bar {
                enabled: picker.canDim
                value: (Math.max(1, picker.bri) - 1) / 99
                current: !!picker.group && picker.group.on
                knob: Qt.tint(Theme.surfaceSunken, Qt.alpha(picker.current, 0.25 + 0.75 * picker.bri / 100))
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0; color: Qt.tint(Theme.surfaceSunken, Qt.alpha(picker.current, 0.2)) }
                    GradientStop { position: 1; color: picker.current }
                }
                onMoved: v => picker.setBri(1 + v * 99)
            }
            Value {
                text: picker.group && picker.group.on ? Math.round(picker.bri) + " %" : "off"
            }
        }

        // Weißton: links warm, rechts kalt
        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            RowIcon {
                name: "device_thermostat"
            }
            Bar {
                readonly property real span: Math.max(1, picker.mirekMax - picker.mirekMin)
                enabled: picker.canCt
                value: (picker.mirekMax - picker.mirek) / span
                current: picker.mode === "ct"
                knob: Hue.mirekToColor(picker.mirek)
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0; color: Hue.mirekToColor(picker.mirekMax) }
                    GradientStop { position: 0.25; color: Hue.mirekToColor(picker.mirekMax - (picker.mirekMax - picker.mirekMin) * 0.25) }
                    GradientStop { position: 0.5; color: Hue.mirekToColor(picker.mirekMax - (picker.mirekMax - picker.mirekMin) * 0.5) }
                    GradientStop { position: 0.75; color: Hue.mirekToColor(picker.mirekMax - (picker.mirekMax - picker.mirekMin) * 0.75) }
                    GradientStop { position: 1; color: Hue.mirekToColor(picker.mirekMin) }
                }
                onMoved: v => {
                    picker.mirek = picker.mirekMax - v * span;
                    picker.pickMirek();
                }
            }
            Value {
                text: picker.canCt ? Math.round(1e6 / picker.mirek / 50) * 50 + " K" : ""
            }
        }

        Item {
            Layout.preferredHeight: 2
        }

        // Vorlagen: runde Chips (Weißtöne | Farben), aktiv = Akzent-Ring; Überfahren zeigt den Namen oben
        Row {
            id: presetRow
            // schmale Kachel: Chips werden etwas kleiner statt überzulaufen
            readonly property real cell: Math.max(20, Math.min(30, (width - 6 * 10) / 10))
            Layout.fillWidth: true
            spacing: 6
            Repeater {
                model: picker.presets.slice(0, 4)
                Swatch {}
            }
            Item {
                width: 6
                height: 1
            }
            Repeater {
                model: picker.presets.slice(4)
                Swatch {}
            }
        }

        // Tastenhilfe, nur mit Fokus
        MonoTxt {
            Layout.fillWidth: true
            elide: Text.ElideRight
            text: "←→ hue  ↑↓ sat  [ ] white  −+ dim  1–0 presets  ↵ done"
            color: Theme.textFaint
            font.pixelSize: 11
            opacity: picker.activeFocus ? 0.85 : 0
            Behavior on opacity { NumberAnimation { duration: Theme.fade } }
        }
    }
}

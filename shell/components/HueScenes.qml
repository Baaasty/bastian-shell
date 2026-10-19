import QtQuick
import qs.config
import qs.components

// Hue-Szenen als waagerechte Chip-Leiste. Klick = aktivieren, Ziehen = umsortieren
// (die anderen rücken weich zur Seite), Rechtsklick = Menü (menuRequested).
// Mausrad scrollt, beim Ziehen an den Rand scrollt die Leiste mit.
Item {
    id: strip

    property var scenes: []            // [{ id, name, active }] in gespeicherter Reihenfolge
    property string groupKey: ""       // Raumwechsel -> an den Anfang bzw. zur aktiven Szene scrollen
    signal recalled(string id)
    signal reordered(var ids)
    signal menuRequested(string id, Item chip)

    readonly property int spacing: 6
    readonly property int edge: 28     // Randzone fürs Mitscrollen beim Ziehen

    // Ziehzustand
    property string dragId: ""
    property bool held: false          // gezogener Chip folgt der Maus (ohne Animation)
    property string dropId: ""         // eben losgelassen: bleibt beim Hineingleiten oben
    property real dragX: 0
    property var preview: []           // Reihenfolge während des Ziehens
    readonly property var ids: dragId !== "" ? preview : scenes.map(s => s.id)

    property var widths: ({})
    readonly property real contentWidth: {
        let w = 0;
        for (const id of ids)
            w += (widths[id] || 0) + spacing;
        return Math.max(0, w - spacing);
    }
    // passt nicht alles rein -> Pfeile links/rechts, dazwischen der sichtbare Ausschnitt
    readonly property bool overflow: contentWidth > width + 0.5
    readonly property int arrowW: 22
    readonly property real viewW: overflow ? width - arrowW * 2 : width
    readonly property real maxScroll: Math.max(0, contentWidth - viewW)
    property real scroll: 0
    onMaxScrollChanged: scroll = Math.min(scroll, maxScroll)

    function xOf(id: string): real {
        let x = 0;
        for (const i of ids) {
            if (i === id)
                return x;
            x += (widths[i] || 0) + spacing;
        }
        return x;
    }
    function setWidth(id: string, w: real): void {
        if (widths[id] === w)
            return;
        const o = Object.assign({}, widths);
        o[id] = w;
        widths = o;
    }

    function beginDrag(id: string, x: real): void {
        preview = scenes.map(s => s.id);
        dragX = x;
        held = true;
        dragId = id;
    }
    // Einfügeplatz = Lücke, die am nächsten an der linken Chip-Kante liegt
    function dragTo(x: real): void {
        const w = widths[dragId] || 0;
        dragX = Math.max(0, Math.min(contentWidth - w, x));
        const others = scenes.map(s => s.id).filter(i => i !== dragId);
        let best = 0, bd = 1e9, acc = 0;
        for (let k = 0; k <= others.length; k++) {
            const d = Math.abs(acc - dragX);
            if (d < bd) {
                bd = d;
                best = k;
            }
            if (k < others.length)
                acc += (widths[others[k]] || 0) + spacing;
        }
        others.splice(best, 0, dragId);
        if (others.join() !== preview.join())
            preview = others;
    }
    function endDrag(): void {
        if (dragId === "")
            return;
        settle.restart();
        dropId = dragId;
        held = false;              // ab hier gleitet auch der gezogene Chip
        const order = preview.slice();
        const changed = order.join() !== scenes.map(s => s.id).join();
        if (changed)
            strip.reordered(order);
        dragId = "";
    }
    // Menü-Verschiebung soll ebenfalls gleiten
    function animateNext(): void {
        settle.restart();
    }

    // Szenen in ein ListModel spiegeln: Chips bleiben beim Nachladen erhalten
    ListModel {
        id: sceneModel
    }
    function sync(): void {
        const want = scenes.map(s => s.id);
        for (let i = sceneModel.count - 1; i >= 0; i--)
            if (want.indexOf(sceneModel.get(i).sid) < 0)
                sceneModel.remove(i);
        for (const s of scenes) {
            let i = -1;
            for (let j = 0; j < sceneModel.count; j++)
                if (sceneModel.get(j).sid === s.id) {
                    i = j;
                    break;
                }
            if (i < 0)
                sceneModel.append({ sid: s.id, name: s.name, live: s.active });
            else {
                if (sceneModel.get(i).name !== s.name)
                    sceneModel.setProperty(i, "name", s.name);
                if (sceneModel.get(i).live !== s.active)
                    sceneModel.setProperty(i, "live", s.active);
            }
        }
        if (dragId !== "" && want.indexOf(dragId) < 0) {
            held = false;
            dragId = "";
        }
    }
    onScenesChanged: sync()
    Component.onCompleted: sync()
    onGroupKeyChanged: {
        scroll = 0;
        Qt.callLater(showActive);
    }
    function showActive(): void {
        const s = scenes.find(x => x.active);
        if (!s)
            return;
        const x = xOf(s.id), w = widths[s.id] || 0;
        if (x + w > scroll + viewW)
            scroll = Math.min(maxScroll, x + w - viewW + edge);
    }

    Timer {
        id: settle
        interval: Theme.stateChange + 60
        onTriggered: strip.dropId = ""
    }
    readonly property bool animating: dragId !== "" || settle.running

    // Mitscrollen, solange der gezogene Chip am Rand steht
    Timer {
        interval: 16
        repeat: true
        running: strip.held && strip.maxScroll > 0
        onTriggered: {
            const vx = strip.dragX - strip.scroll;
            const w = strip.widths[strip.dragId] || 0;
            let d = 0;
            if (vx < strip.edge && strip.scroll > 0)
                d = -Math.min(6, strip.scroll);
            else if (vx + w > strip.viewW - strip.edge && strip.scroll < strip.maxScroll)
                d = Math.min(6, strip.maxScroll - strip.scroll);
            if (d !== 0) {
                strip.scroll += d;
                strip.dragTo(strip.dragX + d);
            }
        }
    }

    implicitHeight: 30

    WheelHandler {
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        enabled: strip.maxScroll > 0
        onWheel: event => {
            const d = event.pixelDelta.x !== 0 ? -event.pixelDelta.x : event.pixelDelta.y !== 0 ? -event.pixelDelta.y
                : -(event.angleDelta.y !== 0 ? event.angleDelta.y : event.angleDelta.x) / 120 * 80;
            strip.scrollBy(d);
        }
    }

    function scrollBy(d: real): void {
        scroll = Math.max(0, Math.min(maxScroll, scroll + d));
    }

    component Arrow: Rectangle {
        id: arr
        property string icon
        signal clicked()
        visible: strip.overflow
        width: strip.arrowW
        height: 30
        radius: Theme.radiusSm
        color: arrArea.containsMouse && enabled ? Theme.raise : "transparent"
        Behavior on color { ColorAnimation { duration: Theme.fade } }
        Icon {
            anchors.centerIn: parent
            name: arr.icon
            size: 18
            color: Theme.textMuted
            opacity: arr.enabled ? 1 : 0.3
            Behavior on opacity { NumberAnimation { duration: Theme.fade } }
        }
        MouseArea {
            id: arrArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: arr.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: arr.clicked()
        }
    }
    Arrow {
        x: 0
        icon: "chevron_left"
        enabled: strip.scroll > 0.5
        onClicked: strip.scrollBy(-strip.viewW * 0.6)
    }
    Arrow {
        x: strip.width - width
        icon: "chevron_right"
        enabled: strip.scroll < strip.maxScroll - 0.5
        onClicked: strip.scrollBy(strip.viewW * 0.6)
    }

    Item {
        id: view
        x: strip.overflow ? strip.arrowW : 0
        width: strip.viewW
        height: strip.height
        clip: true

        Item {
            id: content
            x: -strip.scroll
            width: strip.contentWidth
            height: strip.height
            Behavior on x {
                enabled: !strip.held
                NumberAnimation { duration: Theme.fade; easing.type: Easing.OutCubic }
            }

            Repeater {
                model: sceneModel

                delegate: Rectangle {
                    id: chip

                    required property string sid
                    required property string name
                    required property bool live
                    readonly property bool dragging: strip.dragId === sid
                readonly property bool lifted: dragging || strip.dropId === sid
                    property real pressX: 0
                    property bool moved: false

                    x: dragging && strip.held ? strip.dragX : strip.xOf(sid)
                    z: lifted ? 2 : 0
                    width: label.implicitWidth + 24
                    height: 30
                    radius: Theme.radiusSm
                    // gezogen: deckend, damit darunterliegende Chips nicht durchscheinen
                    color: lifted ? Qt.tint(Theme.surface, live ? Theme.accentSoft : Qt.alpha(Theme.text, 0.12))
                        : live ? Theme.accentSoft : area.containsMouse ? Qt.alpha(Theme.text, 0.1) : Theme.raise
                    border.width: dragging ? 1 : 0
                    border.color: Theme.borderStrong
                    scale: dragging && strip.held ? 1.04 : 1
                    onWidthChanged: strip.setWidth(sid, width)
                    Component.onCompleted: strip.setWidth(sid, width)

                    Behavior on x {
                        enabled: strip.animating && !(chip.dragging && strip.held)
                        NumberAnimation { duration: Theme.stateChange; easing.type: Easing.OutCubic }
                    }
                    Behavior on color { ColorAnimation { duration: Theme.fade } }
                    Behavior on scale { NumberAnimation { duration: Theme.fade; easing.type: Easing.OutCubic } }

                    Txt {
                        id: label
                        anchors.centerIn: parent
                        text: chip.name
                        color: chip.live ? Theme.accentText : Theme.textMuted
                        Behavior on color { ColorAnimation { duration: Theme.fade } }
                    }

                    MouseArea {
                        id: area
                        anchors.fill: parent
                        hoverEnabled: true
                        preventStealing: true
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        cursorShape: chip.dragging ? Qt.ClosedHandCursor : Qt.PointingHandCursor
                        onPressed: mouse => {
                            chip.pressX = mouse.x;
                            chip.moved = false;
                        }
                        onPositionChanged: mouse => {
                            if (!(mouse.buttons & Qt.LeftButton))
                                return;
                            const p = mapToItem(content, mouse.x, mouse.y);
                            if (strip.dragId === "") {
                                if (Math.abs(mouse.x - chip.pressX) < 6 || strip.scenes.length < 2)
                                    return;
                                chip.moved = true;
                                strip.beginDrag(chip.sid, chip.x);
                            }
                            if (chip.dragging)
                                strip.dragTo(p.x - chip.pressX);
                        }
                        onReleased: strip.endDrag()
                        onCanceled: strip.endDrag()
                        onClicked: mouse => {
                            if (mouse && mouse.button === Qt.RightButton)
                                strip.menuRequested(chip.sid, chip);
                            else if (!chip.moved)
                                strip.recalled(chip.sid);
                        }
                    }
                }
            }
        }
    }
}

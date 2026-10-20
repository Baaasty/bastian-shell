import QtQuick
import qs.config
import qs.services

// Tastatur in Popouts/Panels (AP 22): Pfeile/Tab bewegen eine sichtbare Markierung (Glut-Rahmen), Enter/Leertaste löst aus,
// ←/→ stellen Schieberegler, Esc bleibt beim Popout. Sucht die Ziele selbst im Baum unter `root`:
//   - klickbare Flächen = MouseArea mit Hand-Cursor (so markiert die Shell überall „klickbar“), Chips, Knöpfe
//   - Schieberegler (components/Slider.qml), Eingabefelder (TextInput)
// Ein Ziel ausblenden: `property bool kbSkip: true` am Item (oder an einem Vorfahren).
// Einbau in ein Bar-Popout (Karte = root):
//   Glass { id: card; Keys.onPressed: e => nav.key(e) …
//       KeyNav { id: nav; root: card; scope: keys; popout: pop; guard: guard; name: "net" } }
// popout/guard/name sind optional: mit `name` öffnet der Bar-Modus (BarKeys) das Popout per Tastatur – dann mit
// Tastaturfokus und ohne Schließen durch Weghovern.
Item {
    id: nav

    required property Item root
    property Item scope: null          // Fokus-Halter des Popouts (FocusScope mit Esc-Logik)
    property var popout: null          // PopupWindow mit openWith(grab) / close()
    property Item guard: null          // PopoutGuard: aus, solange per Taste geöffnet
    property string name: ""           // Kennung im Bar-Modus (BarKeys.entries)
    property var openFn: null          // eigenes Öffnen (sonst openWith(true) / open() / toggle())
    // eigene Tasten vorweg (e) => true = erledigt; gilt auch für die von der Bar weitergereichten (BarKeys.forward),
    // z. B. Tippen ins Eingabefeld, solange das Popout ohne Fokus-Griff offen ist (TodoPopout.qml)
    property var preKey: null
    property bool byKeys: false        // per Tastatur geöffnet
    property Item current: null        // markiertes Ziel
    property string currentKind: ""
    property bool ringOn: false        // Markierung erst zeigen, wenn die Tastatur benutzt wird
    // Schieberegler stellen erst nach Enter (bewusst gewählt), sonst würden Pfeile beim Durchlaufen Licht/Ton ändern
    property bool adjusting: false
    property real activatedAt: 0       // Enter auf ein Ziel: schließt das Popout dadurch, nicht zurück in den Bar-Modus
    property bool closeIntended: false // Popout bewusst geschlossen (Esc, close()) statt Klick daneben

    anchors.fill: parent
    z: 1000

    Component.onCompleted: if (name !== "") BarKeys.register(name, nav)

    // ---------- Popout per Tastatur öffnen (Bar-Modus / Einzelkürzel) ----------
    Connections {
        target: nav.name !== "" ? BarKeys : null
        function onOpenRequested(n, grab) {
            if (n !== nav.name || !nav.popout)
                return;
            nav.byKeys = true;
            nav.closeIntended = false;
            if (nav.guard)
                nav.guard.keyOpened = true;
            if (!nav.popout.visible) {
                // ohne Fokus-Griff (Einzelkürzel ohne Tasten-Ereignis): die Bar reicht die Tasten weiter
                if (nav.popout.grabFocus !== undefined)
                    nav.popout.grabFocus = grab;
                if (nav.openFn)
                    nav.openFn();
                else if (typeof nav.popout.openWith === "function")
                    nav.popout.openWith(grab);
                else if (typeof nav.popout.open === "function")
                    nav.popout.open();
                else
                    nav.popout.toggle();
            }
            Qt.callLater(() => nav.start());
        }
    }
    Connections {
        target: nav.popout
        ignoreUnknownSignals: true
        function onVisibleChanged() {
            if (nav.popout.visible)
                return;
            // erst nach PopoutGuard entscheiden: holt er das Popout zurück (Compositor hatte es geschlossen), bleibt alles
            Qt.callLater(nav.closed);
        }
    }
    function closed(): void {
        if (nav.guard && (nav.guard.pending || nav.popout.visible)) {
            // ohne Klick-Fang wieder offen: die Bar reicht die Tasten weiter
            if (nav.byKeys && nav.name !== "")
                BarKeys.keepKeys(nav.name);
            return;
        }
        if (nav.popout.visible)
            return;
        nav.reset();
        // per Taste geöffnet und mit Esc zu (nicht durch Auslösen oder Klick daneben): zurück zum Chip im Bar-Modus
        const back = nav.byKeys && Date.now() - nav.activatedAt > 600 && (nav.guard ? nav.closeIntended : true);
        nav.byKeys = false;
        if (nav.guard)
            nav.guard.keyOpened = false;
        if (nav.name !== "")
            BarKeys.released(nav.name, back);
    }
    Connections {
        target: nav.guard
        ignoreUnknownSignals: true
        function onIntendedChanged() {
            if (nav.guard.intended && nav.popout && nav.popout.visible)
                nav.closeIntended = true;
        }
    }

    // erstes Ziel markieren (nach dem Öffnen per Taste)
    function start(): void {
        const list = targets();
        if (!list.length)
            return;
        const input = list.find(t => t.kind === "input" && t.item.activeFocus);
        select(input ?? list[0]);
    }
    function reset(): void {
        current = null;
        currentKind = "";
        ringOn = false;
        adjusting = false;
    }

    // ---------- Ziele finden ----------
    function kindOf(c) {
        if (c instanceof TextInput || c instanceof TextEdit)
            return c.readOnly ? "" : "input";
        if (typeof c.dragValue === "number" && typeof c.stepSize === "number" && typeof c.moved === "function")
            return "slider";
        if (c instanceof MouseArea)
            return c.cursorShape === Qt.PointingHandCursor && (c.acceptedButtons & Qt.LeftButton) ? "area" : "";
        return "";
    }
    // Lage im root, Scrollen herausgerechnet (damit die Reihenfolge beim Scrollen gleich bleibt)
    function geoOf(c) {
        const p = c.mapToItem(nav.root, 0, 0);
        let x = p.x, y = p.y;
        for (let a = c.parent; a && a !== nav.root; a = a.parent) {
            if (a instanceof Flickable) {
                x += a.contentX;
                y += a.contentY;
            }
        }
        return { x: x, y: y, w: c.width, h: c.height, cx: x + c.width / 2, cy: y + c.height / 2 };
    }
    function walk(it, out) {
        const kids = it.children;
        for (let i = 0; i < kids.length; i++) {
            const c = kids[i];
            if (!c || c === nav || !c.visible || c.opacity <= 0.01 || c.kbSkip === true)
                continue;
            const kind = kindOf(c);
            if (kind !== "" && c.enabled !== false && c.width > 2 && c.height > 2) {
                // Chip/Knopf: Markierung um den ganzen Chip (die MouseArea füllt ihn)
                const shown = kind === "area" && c.parent && c.parent !== nav.root && Math.abs(c.parent.width - c.width) < 2 && Math.abs(c.parent.height - c.height) < 2 ? c.parent : c;
                const g = geoOf(shown);
                // seitlich weggeschobene Seiten (Stapel, Animationen) zählen nicht
                if (g.x + g.w > 0 && g.x < nav.root.width)
                    out.push({ item: c, shown: shown, kind: kind, g: g });
                if (kind === "slider" || kind === "input")
                    continue;
            }
            walk(c, out);
        }
    }
    function targets() {
        const out = [];
        if (nav.root)
            walk(nav.root, out);
        out.sort((a, b) => Math.abs(a.g.y - b.g.y) > 6 ? a.g.y - b.g.y : a.g.x - b.g.x);
        return out;
    }

    // ---------- Markieren, Scrollen, Auslösen ----------
    function select(t) {
        if (!t)
            return;
        current = t.item;
        currentKind = t.kind;
        ringOn = true;
        adjusting = false;
        scrollTo(t.shown);
        if (t.kind === "input")
            t.item.forceActiveFocus();
        else if (activeInput())
            (nav.scope ?? nav).forceActiveFocus();
        place();
    }
    function scrollTo(c) {
        for (let a = c.parent; a && a !== nav.root; a = a.parent) {
            if (!(a instanceof Flickable))
                continue;
            const p = c.mapToItem(a.contentItem, 0, 0);
            const pad = 8;
            let y = a.contentY;
            if (p.y - pad < y)
                y = p.y - pad;
            else if (p.y + c.height + pad > y + a.height)
                y = p.y + c.height + pad - a.height;
            a.contentY = Math.max(0, Math.min(y, Math.max(0, a.contentHeight - a.height)));
        }
    }
    function activeInput() {
        const w = nav.root.Window.window;
        const f = w ? w.activeFocusItem : null;
        return f && (f instanceof TextInput || f instanceof TextEdit) ? f : null;
    }
    function indexOf(list) {
        return list.findIndex(t => t.item === nav.current);
    }
    function step(d) {
        const list = targets();
        if (!list.length)
            return;
        const i = indexOf(list);
        if (i < 0 || !ringOn)
            return select(d > 0 ? list[0] : list[list.length - 1]);
        select(list[(i + d + list.length) % list.length]);
    }
    // räumlich: nächstes Ziel in Richtung dx/dy (Überlappung quer zur Richtung zählt als 0 Abstand)
    function spatial(dx, dy) {
        const list = targets();
        if (!list.length)
            return;
        const i = indexOf(list);
        if (i < 0 || !ringOn)
            return select(dy < 0 || dx < 0 ? list[list.length - 1] : list[0]);
        const c = list[i].g;
        let best = null, bestScore = Infinity;
        for (let j = 0; j < list.length; j++) {
            if (j === i)
                continue;
            const g = list[j].g;
            let main, cross;
            if (dy !== 0) {
                main = dy > 0 ? g.cy - c.cy : c.cy - g.cy;
                if (main < 4 || (dy > 0 ? g.y + g.h <= c.y + c.h - 2 && g.y < c.y + 2 : g.y >= c.y + 2 && g.y + g.h > c.y + c.h - 2))
                    continue;
                cross = Math.max(0, Math.max(g.x, c.x) - Math.min(g.x + g.w, c.x + c.w));
            } else {
                main = dx > 0 ? g.cx - c.cx : c.cx - g.cx;
                if (main < 4)
                    continue;
                cross = Math.max(0, Math.max(g.y, c.y) - Math.min(g.y + g.h, c.y + c.h));
            }
            const score = main + cross * 3;
            if (score < bestScore) {
                bestScore = score;
                best = list[j];
            }
        }
        if (best)
            select(best);
        else if (dx !== 0)
            step(dx);     // nichts mehr links/rechts: in der Reihenfolge weiter
    }
    function activate() {
        const c = nav.current;
        if (!c || !c.visible)
            return false;
        if (currentKind === "input") {
            c.forceActiveFocus();
            return true;
        }
        // Schieberegler: Enter schaltet „Stellen“ an/aus (dann ←/→)
        if (currentKind === "slider") {
            adjusting = !adjusting;
            return true;
        }
        activatedAt = Date.now();
        const p = c.parent;
        // Chip (components/Chip.qml): eigenes clicked(mouse) mit Maus-Ersatz
        if (p && typeof p.alignLeft === "boolean" && typeof p.clicked === "function")
            p.clicked({ button: Qt.LeftButton, buttons: Qt.LeftButton, modifiers: Qt.NoModifier, x: c.width / 2, y: c.height / 2, accepted: true });
        else
            c.clicked(null);      // Handler mit Maus-Argument prüfen auf null (mouse?.button)
        Qt.callLater(() => nav.place());
        return true;
    }
    function nudge(d) {
        const s = nav.current;
        if (!s || currentKind !== "slider" || !adjusting)
            return false;
        const st = typeof s.wheelStep === "number" && s.wheelStep > 0 ? s.wheelStep : s.stepSize;
        s.moved(s.clamp(s.value + d * st));
        return true;
    }

    // Tasten vom Popout (Keys.onPressed der Karte); Esc nur als Rückfall (die Popouts schließen selbst)
    function key(e) {
        if (nav.preKey && nav.preKey(e)) {
            e.accepted = true;
            return;
        }
        const k = e.key;
        const shift = !!(e.modifiers & Qt.ShiftModifier);
        const enter = k === Qt.Key_Return || k === Qt.Key_Enter;
        if (k === Qt.Key_Tab || k === Qt.Key_Backtab) {
            step(shift || k === Qt.Key_Backtab ? -1 : 1);
        } else if (k === Qt.Key_Down) {
            adjusting = false;
            spatial(0, 1);
        } else if (k === Qt.Key_Up) {
            adjusting = false;
            spatial(0, -1);
        } else if (k === Qt.Key_Left || k === Qt.Key_Right) {
            const d = k === Qt.Key_Left ? -1 : 1;
            if (!nudge(d))
                spatial(d, 0);
        } else if (k === Qt.Key_Home || k === Qt.Key_End) {
            const list = targets();
            if (list.length)
                select(k === Qt.Key_Home ? list[0] : list[list.length - 1]);
        } else if (enter || k === Qt.Key_Space) {
            if (!ringOn || !activate())
                return;
        } else if (k === Qt.Key_Escape) {
            if (adjusting) {
                adjusting = false;
            } else if (activeInput() && nav.scope) {
                nav.scope.forceActiveFocus();
            } else if (nav.popout) {
                if (typeof nav.popout.close === "function")
                    nav.popout.close();
                else
                    nav.popout.visible = false;
            } else {
                return;
            }
        } else {
            return;
        }
        e.accepted = true;
    }

    // ---------- Markierung ----------
    function place() {
        const c = nav.current;
        if (!c || !c.visible || !ringOn) {
            ring.visible = false;
            return;
        }
        const s = c.parent && Math.abs(c.parent.width - c.width) < 2 && Math.abs(c.parent.height - c.height) < 2 && currentKind === "area" ? c.parent : c;
        const p = s.mapToItem(nav, 0, 0);
        ring.x = Math.round(p.x) - 3;
        ring.y = Math.round(p.y) - 3;
        ring.width = Math.round(s.width) + 6;
        ring.height = Math.round(s.height) + 6;
        ring.radius = (typeof s.radius === "number" && s.radius > 0 ? s.radius : Theme.radiusSm) + 3;
        ring.visible = true;
    }
    // Lage nachziehen (Inhalt bewegt/scrollt sich), nur solange markiert ist
    Timer {
        running: nav.ringOn && nav.current !== null && nav.visible
        interval: 120
        repeat: true
        onTriggered: nav.place()
    }

    Rectangle {
        id: ring
        visible: false
        color: "transparent"
        border.width: 2
        border.color: Theme.accent
        // Schieberegler im Stellen-Modus: leise Glut-Fläche dazu
        Rectangle {
            anchors.fill: parent
            anchors.margins: 2
            radius: parent.radius - 2
            visible: nav.adjusting
            color: Theme.accentSoft
        }
    }
}

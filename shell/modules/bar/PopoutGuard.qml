import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import qs.services

// Bar-Popouts: offen bleiben, bis man weghovert (Bastian: „nach Knopfdruck nicht zu, erst beim Weghovern“).
// In die Karte des Popouts legen (füllt sie aus, fängt nichts ab – nur Hover):
//   PopoutGuard { id: guard; popout: pop; chip: pop.chip; name: "net" }
// und in close() des Popouts `guard.intended = true` setzen (Esc, Chip-Klick, Weghovern = gewollt).
// Regel (AP 22, für alle Bar-Popouts): zu geht ein Popout nur durch
//  1. Weghovern aus der Hitbox (Karte, Chip, Streifen zwischen Bar und Popout), nachdem die Maus drin war – erst nach
//     `delay` ms, Maustaste gedrückt (Regler ziehen) zählt als drin,
//  2. Esc / close(), 3. Chip-Klick, Umschalt-Taste oder ein anderes Popout (Popouts.claim), 4. Klick daneben.
// Schließt der Compositor es von sich aus, während die Maus drin ist (Klick ins Popout unter Hyprland, Fenster wird
// geholt/fokussiert, Discord-Ereignis), geht es sofort wieder auf – ohne Klick-Fang; scharf erst wieder, wenn die Maus
// sich darin gezeigt hat. War es per Taste offen (keyOpened), reicht danach die Bar die Tasten weiter (KeyNav.qml / BarKeys.fwd).
Item {
    id: g

    required property var popout
    property Item chip: null
    property string name: ""
    property int delay: 800
    property bool intended: false
    property bool armed: false
    // per Tastatur geöffnet (KeyNav setzt das): kein Schließen über den Chip-Hover, erst nachdem die Maus drin war
    property bool keyOpened: false
    // gerade wieder geöffnet (Compositor hatte geschlossen) – KeyNav prüft das, bevor es die Tastatur abgibt
    property bool pending: false

    readonly property bool inside: hover.hovered
    readonly property bool overChip: chip !== null && chip.hovered === true

    anchors.fill: parent

    // Hover an der Karte (Eltern-Item) statt am Guard: der Guard liegt als Geschwister unter den Knöpfen, und Knöpfe
    // mit eigenem Hover (MouseArea hoverEnabled) schlucken das Hover für alles darunter – dann galt die Maus über einem
    // Knopf als „draußen“ und das Popout ging nach `delay` zu. Eltern bekommen das Hover auch über den Knöpfen.
    HoverHandler {
        id: hover
        parent: g.parent
    }
    // Maustaste im Popout gedrückt (Regler ziehen, Farbwähler): bleibt offen, auch wenn der Zeiger dabei hinausrutscht.
    // PointHandler greift nur passiv – Knöpfe und Regler bekommen den Klick wie bisher.
    PointHandler {
        id: press
        parent: g.parent
        acceptedButtons: Qt.AllButtons
    }
    readonly property bool holding: press.active
    // Streifen zwischen Bar und Popout (BarWindow „bridge“) zählt als drin – nur für das offene Popout
    readonly property bool onBridge: Popouts.bridge && Popouts.current === name
    readonly property bool near: inside || overChip || holding || onBridge || inStrip

    // wann die Maus zuletzt im Popout war: schließt der Compositor es kurz danach (Klick hinein), kommt es wieder
    property real lastInside: 0
    property bool wasInside: false
    onInsideChanged: {
        if (inside)
            armed = true;
        else
            lastInside = Date.now();
    }
    function reopen(): void {
        pending = true;
        reopenTimer.start();
    }
    function restoreGrab(): void {
        if (popout.grabFocus === false)
            popout.grabFocus = true;        // nächstes Öffnen per Klick wieder mit Klick-Fang
    }
    onOverChipChanged: if (overChip && !keyOpened) armed = true
    onOnBridgeChanged: if (onBridge) armed = true
    onInStripChanged: if (inStrip && !keyOpened) armed = true

    // ---------- Hyprland: echte Mausposition ----------
    // Mit Klick-Fang (grabFocus) bekommt unter Hyprland nur das Popout die Maus: Bar und Chip melden sofort „weg“, auch
    // wenn die Maus noch auf dem Knopf steht. Solange die Maus nicht im Popout ist, fragt der Guard deshalb alle 200 ms
    // `hyprctl cursorpos` ab: oberer Streifen des Monitors (Rand + Bar + windowGap) = noch dran, darunter = weg.
    readonly property bool hypr: (Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE") || "") !== ""
    property bool inStrip: false
    readonly property var barScreen: g.popout.anchor && g.popout.anchor.window ? g.popout.anchor.window.screen : null
    Timer {
        interval: 200
        repeat: true
        triggeredOnStart: true
        running: g.hypr && g.enabled && g.popout.visible && !g.inside && !g.holding
        onRunningChanged: if (!running && !g.popout.visible) g.inStrip = false
        onTriggered: if (!cursor.running) cursor.running = true
    }
    Process {
        id: cursor
        command: ["hyprctl", "cursorpos", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                const sc = g.barScreen;
                try {
                    const c = JSON.parse(text);
                    g.inStrip = !!sc && c.x >= sc.x && c.x < sc.x + sc.width && c.y >= sc.y
                        && c.y < sc.y + Theme.barMargin + Theme.barHeight + Theme.windowGap + 2;
                } catch (e) {
                    g.inStrip = false;
                }
            }
        }
    }

    // ---------- Hyprland: Hand-Zeiger über den Bar-Chips ----------
    // Mit Klick-Fang behält das Popout den Zeiger-Fokus, auch über der Bar (Hyprland: „absolute“ xdg_popup-Grabs, die
    // Bar ist als Layer-Fläche nicht Teil des Grabs). Den Zeiger setzt dann nur das Popout – über den Chips also der
    // Pfeil des Popouts. Deshalb liegen im Popout-Fenster unsichtbare Flächen genau über den Chips der Bar (außerhalb
    // des Fensters, das Popout bekommt die Bewegungen dort trotzdem), die nur den Zeiger setzen und keine Klicks nehmen.
    property var chipRects: []
    function syncChipCursors(): void {
        const win = g.popout.anchor ? g.popout.anchor.window : null;
        if (!g.hypr || !g.popout.visible || !win) {
            if (chipRects.length)
                chipRects = [];
            return;
        }
        const out = [];
        for (const ch of Popouts.chips) {
            if (ch.hostWindow !== win || !ch.visible || ch.width <= 0)
                continue;
            const p = ch.mapToItem(chipCursors, 0, 0);
            out.push({ x: Math.round(p.x), y: Math.round(p.y), w: Math.round(ch.width), h: Math.round(ch.height) });
        }
        if (JSON.stringify(out) !== JSON.stringify(chipRects))
            chipRects = out;
    }
    // Lage des Popouts steht erst nach dem configure des Compositors fest, Chips ändern ihre Breite (Titel, Zähler)
    Timer {
        interval: 250
        repeat: true
        triggeredOnStart: true
        running: g.hypr && g.popout.visible
        onTriggered: g.syncChipCursors()
        onRunningChanged: if (!running) g.syncChipCursors()
    }
    Item {
        id: chipCursors
        parent: g.popout.contentItem
        visible: g.hypr && g.popout.visible
        Repeater {
            model: g.chipRects
            MouseArea {
                required property var modelData
                x: modelData.x
                y: modelData.y
                width: modelData.w
                height: modelData.h
                acceptedButtons: Qt.NoButton
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
            }
        }
    }

    Timer {
        id: leave
        interval: g.delay
        running: g.enabled && g.popout.visible && g.armed && !g.near
        onTriggered: {
            if (g.popout.visible && !g.near)
                g.popout.close();
        }
    }

    Connections {
        target: g.popout
        function onVisibleChanged() {
            if (g.popout.visible) {
                if (!g.pending)
                    g.armed = g.inside || (g.overChip && !g.keyOpened);
                g.pending = false;
                g.intended = false;
                return;
            }
            // Vom Compositor geschlossen (nicht gewollt) und kein anderes Popout dran: entscheiden, ob es wiederkommt.
            const byCompositor = !g.intended;
            g.intended = false;
            if (!g.enabled || !byCompositor || (Popouts.current !== "" && Popouts.current !== g.name)) {
                g.restoreGrab();
                return;
            }
            if (g.keyOpened) {
                g.reopen();
                return;
            }
            // Hyprland meldet beim Klick ins Popout erst „Maus weg“ und schließt dann – daher „eben noch drin“ (400 ms)
            g.wasInside = g.inside || g.holding || Date.now() - g.lastInside < 400;
            if (g.hypr) {
                decideProc.running = true;      // Entscheidung nach der echten Mausposition (unten)
                return;
            }
            // KWin: Hover der Bar ist verlässlich
            if (g.wasInside && !g.overChip && !Popouts.overBar)
                g.reopen();
            else
                g.restoreGrab();
        }
    }
    // Hyprland, vom Compositor geschlossen: echte Mausposition entscheidet
    //  - auf einem anderen Chip der Bar: Hyprland hat dessen Klick geschluckt → Klick selbst auslösen (Menü wechselt sofort)
    //  - sonst auf der Bar (eigener Chip, Lücke): zu lassen
    //  - eben noch im Popout (Klick hinein): wieder auf, sonst (Klick in den Bildschirm): zu lassen
    Process {
        id: decideProc
        command: ["hyprctl", "cursorpos", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                const sc = g.barScreen, win = g.popout.anchor ? g.popout.anchor.window : null;
                let c = null;
                try {
                    c = JSON.parse(text);
                } catch (e) {
                    g.restoreGrab();
                    return;
                }
                if (g.popout.visible || (Popouts.current !== "" && Popouts.current !== g.name))
                    return;
                const strip = !!sc && c.x >= sc.x && c.x < sc.x + sc.width && c.y >= sc.y
                    && c.y < sc.y + Theme.barMargin + Theme.barHeight + Theme.windowGap + 2;
                if (strip) {
                    g.restoreGrab();
                    for (const ch of Popouts.chips) {
                        if (ch === g.chip || ch.hostWindow !== win || !ch.visible || ch.width <= 0)
                            continue;
                        const p = ch.mapToItem(null, 0, 0);
                        if (c.x >= sc.x + p.x && c.x < sc.x + p.x + ch.width && c.y >= sc.y + p.y && c.y < sc.y + p.y + ch.height) {
                            Popouts.synthChip = ch;
                            Popouts.synthAt = Date.now();
                            ch.clicked({ button: Qt.LeftButton, buttons: Qt.LeftButton, modifiers: 0, x: ch.width / 2, y: ch.height / 2, accepted: true });
                            return;
                        }
                    }
                    return;
                }
                if (g.wasInside)
                    g.reopen();
                else
                    g.restoreGrab();
            }
        }
    }

    Timer {
        id: reopenTimer
        interval: 0
        onTriggered: {
            // inzwischen ein anderes Popout dran oder gewollt geschlossen: nicht zurückholen
            if (Popouts.current !== "" && Popouts.current !== g.name) {
                g.pending = false;
                g.popout.grabFocus = true;
                return;
            }
            g.popout.grabFocus = false;
            // Das neue Fenster kennt die Maus erst nach der nächsten Bewegung (inside = false, obwohl sie drin ist):
            // nicht scharf, bis sie wirklich drin/auf Chip/Brücke war – dann gilt wieder Weghovern
            g.armed = false;
            if (typeof g.popout.reopen === "function")
                g.popout.reopen();      // Popouts mit eigener Öffnen-Logik (Discord)
            else
                g.popout.visible = true;
        }
    }
}

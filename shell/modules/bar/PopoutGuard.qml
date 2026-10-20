import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs.config
import qs.services

// Auf/Zu aller Bar-Popouts an einer Stelle (Regeln: docs/knowledge/shell-features.md „Bar-Popouts“).
// In die Karte des Popouts legen (füllt sie aus, fängt nichts ab – nur Hover):
//   PopoutGuard { id: guard; popout: pop; chip: pop.chip; name: "net" }
// und in close() des Popouts `guard.intended = true` setzen (Esc, Chip-Klick, Weghovern = gewollt).
//
// Hyprland, per Maus geöffnet (ownGrab): statt des xdg-Popup-Grabs (Qt grabFocus) ein eigener Klick-Fang über
// hyprland_focus_grab mit Popout UND Bar in der Liste. Dadurch
//  - bekommt die Bar weiter die Maus: Hand-Zeiger, Hover, Tooltip, ein Klick auf einen anderen Chip wechselt direkt,
//  - schließt das Popout nie „von selbst“: endet der Fang, bleibt das Fenster stehen (kein Zu→Auf-Flackern).
// Zu geht es nur durch: Klick außerhalb (Fang-Flächen unten bzw. Ende des Fangs ohne Anlass), Esc / close(),
// Klick auf den eigenen Chip, ein anderes Popout (Popouts.claim), Weghovern nach `delay` ms, wenn die Maus drin war.
// Endet der Fang ohne Klick (Fenster/Ebene geht auf/zu, Arbeitsfläche – Popouts.changedAt), bleibt es offen und fängt neu.
// Hat ein anderes Shell-Fenster die Tastatur genommen (Launcher …) oder hat etwas Vorrang (Popouts.modal, Share-Picker),
// geht es zu statt zurückzukommen.
// Per Taste geöffnet (keyOpened, KeyNav.qml / BarKeys): Qt-Grab wie bisher, schließt der Compositor es, kommt es ohne
// Klick-Fang wieder (die Bar reicht dann die Tasten weiter, BarKeys.fwd). KWin: alter Weg mit Hover der Bar.
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

    property real lastInside: 0
    property bool wasInside: false
    onInsideChanged: {
        if (inside) {
            armed = true;
            // ohne Fang offen (Fang war weg, Grenze erreicht): sobald die Maus wieder drin ist, neu fangen
            if (ownGrab && popout.visible && !grabOn)
                regrab(true);
        } else {
            lastInside = Date.now();
        }
    }
    onOverChipChanged: if (overChip && !keyOpened) armed = true
    onOnBridgeChanged: if (onBridge) armed = true
    onInStripChanged: if (inStrip && !keyOpened) armed = true

    function closeNow(): void {
        if (!popout.visible)
            return;
        intended = true;
        if (typeof popout.close === "function")
            popout.close();
        else
            popout.visible = false;
    }

    // ---------- Hyprland: eigener Klick-Fang (Maus-Weg) ----------
    readonly property bool hypr: Popouts.hypr
    readonly property var barWin: popout.anchor ? popout.anchor.window : null
    property bool ownGrab: false        // dieses Öffnen läuft über den eigenen Fang
    property bool grabOn: false         // Fang soll aktiv sein
    property bool withBar: false        // Bar erst kurz danach dazu: so landet die Tastatur sicher im Popout
    property real outsideAt: 0          // letzter Klick außerhalb (Fang-Flächen)
    property var regrabTimes: []        // Neu-Fänge der letzten 10 s (gegen Fokus-Kampf mit fremden Ebenen)

    // Qt-Grab für den Maus-Weg abschalten (sonst ersetzt der xdg-Grab unseren Fang). Die Popouts setzen grabFocus beim
    // Öffnen (openWith) oder fest auf true; per Taste (keyOpened) bleibt es, wie KeyNav es setzt.
    function dropQtGrab(): void {
        if (hypr && !keyOpened && popout.grabFocus === true)
            popout.grabFocus = false;
    }
    Component.onCompleted: dropQtGrab()
    // Tasten-Weg vorbei (KeyNav setzt keyOpened erst danach zurück): nächstes Öffnen per Maus wieder ohne Qt-Grab
    onKeyOpenedChanged: if (!keyOpened && !popout.visible) dropQtGrab()
    Connections {
        target: g.hypr ? g.popout : null
        ignoreUnknownSignals: true
        function onGrabFocusChanged() {
            g.dropQtGrab();
        }
    }

    HyprlandFocusGrab {
        id: focusGrab
        active: g.ownGrab && g.grabOn && g.popout.visible && Popouts.modal === 0
        windows: g.withBar && g.barWin ? [g.popout, g.barWin] : [g.popout]
        onCleared: g.grabCleared()
    }
    // erst fangen, wenn das Popout-Fenster steht; die Bar etwas später dazu
    Timer {
        id: grabStart
        interval: 30
        onTriggered: {
            if (g.ownGrab && g.popout.visible) {
                g.grabOn = true;
                barAdd.restart();
            }
        }
    }
    Timer {
        id: barAdd
        interval: 60
        onTriggered: g.withBar = g.grabOn && g.popout.visible
    }
    function grabCleared(): void {
        grabOn = false;
        withBar = false;
        if (popout.visible && !intended)
            decide.restart();
    }
    // Ende des Fangs: kurz warten (das Drücken außerhalb und Hyprlands Ereignisse kommen gleich hinterher), dann entscheiden
    Timer {
        id: decide
        interval: 150
        onTriggered: {
            if (!g.popout.visible || g.intended || g.grabOn)
                return;
            if (Date.now() - g.outsideAt < 800)
                return g.closeNow();                     // Klick außerhalb (die Fang-Fläche hat ihn gesehen)
            if (Popouts.modal > 0 || (Popouts.current !== "" && Popouts.current !== g.name))
                return g.closeNow();                     // Vorrang / anderes Popout
            // Klick in ein nicht fokussiertes Fenster: Hyprland fokussiert vor dem Klick um, der Fang endet ohne dass
            // wir den Klick sehen – erkennbar daran, dass sich sonst nichts geändert hat
            if (Date.now() - Popouts.changedAt > 1200)
                return g.closeNow();
            // ein anderes Shell-Fenster (Launcher, Dashboard …) hat die Tastatur: nicht zurückholen
            if (Qt.application.state === Qt.ApplicationActive && !g.Window.active)
                return g.closeNow();
            g.regrab(false);
        }
    }
    function regrab(byUser: bool): void {
        const now = Date.now();
        const recent = regrabTimes.filter(t => now - t < 10000);
        if (!byUser && recent.length >= 4) {
            regrabTimes = recent;
            armed = true;           // Grenze: offen ohne Fang, Weghovern schließt
            return;
        }
        recent.push(now);
        regrabTimes = recent;
        grabStart.restart();
    }
    function outsideClick(): void {
        outsideAt = Date.now();
        closeNow();
    }

    // Fang-Flächen: während des Fangs bekommt das zuletzt berührte Fenster der Liste (Popout oder Bar) auch die Klicks
    // außerhalb – mit Koordinaten außerhalb des Fensters. Qt reicht sie an Kinder außerhalb weiter (kein Clipping),
    // also liegt unter allem je eine riesige Fläche: Klick dort = außerhalb.
    MouseArea {
        parent: g.popout.contentItem
        z: -1000
        x: -100000
        y: -100000
        width: 200000
        height: 200000
        enabled: g.ownGrab && g.popout.visible
        acceptedButtons: Qt.AllButtons
        onPressed: mouse => {
            const p = mapToItem(g, mouse.x, mouse.y);
            if (p.x >= 0 && p.y >= 0 && p.x < g.width && p.y < g.height) {
                mouse.accepted = false;      // leere Stelle in der Karte
                return;
            }
            g.outsideClick();
        }
    }
    MouseArea {
        parent: g.barWin ? g.barWin.contentItem : null
        z: -1000
        x: -100000
        y: -100000
        width: 200000
        height: 200000
        enabled: !!parent && g.ownGrab && g.popout.visible && g.withBar
        acceptedButtons: Qt.AllButtons
        onPressed: mouse => {
            const p = mapToItem(parent, mouse.x, mouse.y);
            const strip = Theme.barMargin + Theme.barHeight + Theme.windowGap + 2;
            if (p.x >= 0 && p.x < parent.width && p.y >= 0 && p.y < strip) {
                mouse.accepted = false;      // Lücke in der Bar: kein Klick „außerhalb“
                return;
            }
            g.outsideClick();
        }
    }

    // ---------- Hyprland, Tasten-Weg: echte Mausposition ----------
    // Mit Qt-Grab bekommt unter Hyprland nur das Popout die Maus: Bar und Chip melden sofort „weg“. Solange die Maus nicht
    // im Popout ist, fragt der Guard deshalb alle 200 ms `hyprctl cursorpos` ab: oberer Streifen = noch dran.
    property bool inStrip: false
    readonly property var barScreen: barWin ? barWin.screen : null
    Timer {
        interval: 200
        repeat: true
        triggeredOnStart: true
        running: g.hypr && !g.ownGrab && g.enabled && g.popout.visible && !g.inside && !g.holding
        onRunningChanged: if (!running) g.inStrip = false
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

    Timer {
        id: leave
        interval: g.delay
        running: g.enabled && g.popout.visible && g.armed && !g.near
        onTriggered: {
            if (g.popout.visible && !g.near)
                g.popout.close();
        }
    }

    function restoreGrab(): void {
        if (!hypr && popout.grabFocus === false)
            popout.grabFocus = true;        // KWin: nächstes Öffnen per Klick wieder mit Klick-Fang
        else
            dropQtGrab();
    }
    function reopen(): void {
        pending = true;
        reopenTimer.start();
    }

    Connections {
        target: g.popout
        function onVisibleChanged() {
            if (g.popout.visible) {
                if (!g.pending) {
                    g.armed = g.inside || (g.overChip && !g.keyOpened);
                    g.ownGrab = g.hypr && !g.keyOpened;
                    g.regrabTimes = [];
                    if (g.ownGrab)
                        grabStart.restart();
                }
                g.pending = false;
                g.intended = false;
                return;
            }
            g.grabOn = false;
            g.withBar = false;
            grabStart.stop();
            decide.stop();
            const byCompositor = !g.intended;
            g.intended = false;
            // eigener Fang: das Fenster schließt nur, wenn wir es wollen – nie zurückholen
            if (g.ownGrab) {
                g.ownGrab = false;
                return;
            }
            // Qt-Grab (Tasten-Weg, KWin): vom Compositor geschlossen und kein anderes Popout dran → wieder auf
            if (!g.enabled || !byCompositor || Popouts.modal > 0 || (Popouts.current !== "" && Popouts.current !== g.name)) {
                g.restoreGrab();
                return;
            }
            if (g.keyOpened) {
                g.reopen();
                return;
            }
            // KWin: Hover der Bar ist verlässlich; „eben noch drin“ (400 ms) = Klick ins Popout
            g.wasInside = g.inside || g.holding || Date.now() - g.lastInside < 400;
            if (!g.hypr && g.wasInside && !g.overChip && !Popouts.overBar)
                g.reopen();
            else
                g.restoreGrab();
        }
    }

    Timer {
        id: reopenTimer
        interval: 0
        onTriggered: {
            // inzwischen ein anderes Popout dran, Vorrang oder gewollt geschlossen: nicht zurückholen
            if ((Popouts.current !== "" && Popouts.current !== g.name) || Popouts.modal > 0) {
                g.pending = false;
                g.restoreGrab();
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

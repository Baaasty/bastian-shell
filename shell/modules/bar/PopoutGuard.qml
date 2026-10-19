import QtQuick
import qs.services

// Bar-Popouts: offen bleiben, bis man weghovert (Bastian: „nach Knopfdruck nicht zu, erst beim Weghovern“).
// In die Karte des Popouts legen (füllt sie aus, fängt nichts ab – nur Hover):
//   PopoutGuard { id: guard; popout: pop; chip: pop.chip; name: "net" }
// und in close() des Popouts `guard.intended = true` setzen (Esc, Chip-Klick, Weghovern = gewollt).
// Regel (AP 22, für alle Bar-Popouts): zu geht ein Popout nur durch
//  1. Weghovern, nachdem die Maus drin war (bzw. über dem Chip, wenn per Klick geöffnet),
//  2. Esc / close(), 3. Chip-Klick, Umschalt-Taste oder ein anderes Popout (Popouts.claim).
// Schließt der Compositor es von sich aus (Fenster wird geholt/fokussiert, ein Fenster geht auf, Klick daneben,
// Discord-Ereignis), geht es sofort wieder auf – ohne Klick-Fang. War es per Taste offen (keyOpened), reicht danach die
// Bar die Tasten weiter (KeyNav.qml / BarKeys.fwd). Per Maus offen und die Maus ist nicht drin: zu nach `delay` ms.
Item {
    id: g

    required property var popout
    property Item chip: null
    property string name: ""
    property int delay: 500
    property bool intended: false
    property bool armed: false
    // per Tastatur geöffnet (KeyNav setzt das): kein Schließen über den Chip-Hover, erst nachdem die Maus drin war
    property bool keyOpened: false
    // gerade wieder geöffnet (Compositor hatte geschlossen) – KeyNav prüft das, bevor es die Tastatur abgibt
    property bool pending: false

    readonly property bool inside: hover.hovered
    readonly property bool overChip: chip !== null && chip.hovered === true

    anchors.fill: parent

    HoverHandler {
        id: hover
    }

    onInsideChanged: if (inside) armed = true
    onOverChipChanged: if (overChip && !keyOpened) armed = true

    Timer {
        id: leave
        interval: g.delay
        running: g.enabled && g.popout.visible && g.armed && !g.inside && !g.overChip
        onTriggered: {
            if (g.popout.visible && !g.inside && !g.overChip)
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
            // nicht gewollt und kein anderes Popout dran → sofort wieder auf
            // Maus auf dem Chip = Chip-Klick: der Klick entscheidet selbst (zu lassen)
            const reopen = g.enabled && !g.intended && !g.overChip && (Popouts.current === "" || Popouts.current === g.name);
            g.intended = false;
            if (reopen) {
                g.pending = true;
                reopenTimer.start();
            } else if (g.popout.grabFocus === false) {
                g.popout.grabFocus = true;      // nächstes Öffnen per Klick wieder mit Klick-Fang
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
            // per Maus offen, Maus nicht drin: nach `delay` zu (wie Weghovern); per Taste: bleibt (Esc / Umschalt-Taste)
            g.armed = !g.keyOpened;
            if (typeof g.popout.reopen === "function")
                g.popout.reopen();      // Popouts mit eigener Öffnen-Logik (Discord)
            else
                g.popout.visible = true;
        }
    }
}

pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.config
import qs.services

// Leerlauf-Abdunkeln: alle Monitore werden langsam stark dunkler, danach schaltet hypridle sie per DPMS
// ganz aus („clean schwarz“). Kette und Zeiten: hypr/hypridle.conf → scripts/idle → IPC „dim“.
// Doku: docs/knowledge/shell-features.md (Leerlauf-Abdunkeln)
// Klickdurchlässig und ohne Tastaturfokus: jede Eingabe geht an die Fenster darunter und blendet schnell aus
// (hypridle ruft beim Resume „stop“; der eigene IdleMonitor fängt es ab, falls hypridle nicht läuft oder beim Test).
// KEINE Sperre: gesperrt wird weiter von scripts/lock (Lock.qml), die Sperre liegt über diesem Fenster.
// Fenster gibt es nur, solange abgedunkelt wird (kein Dauer-Zeichnen).
Scope {
    id: root

    readonly property bool supported: !!Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE")
    property bool shown: false
    // Einblenddauer; ease-in, damit die erste Hälfte kaum auffällt (beim Lesen nicht stören)
    property int duration: 60000
    // stark dunkel, aber nicht schwarz: man sieht noch, dass der PC an ist. Schwarz macht danach DPMS.
    readonly property real strength: 0.88
    // ausblenden erst beim Wechsel ruhig → Eingabe (beim Test wird beim Start evtl. noch getippt)
    property bool sawIdle: false

    function start(force: bool, ms: int): string {
        if (!supported)
            return "unsupported";
        // Fokus-Block: Lesen/Denken am Bildschirm nicht stören (spätere Listener kommen mit force)
        if (!force && Focus.active)
            return "skip";
        sawIdle = false;
        duration = ms;
        shown = true;
        return "ok";
    }
    function stop(): void {
        testEnd.stop();
        shown = false;
    }

    // Rückfall ohne hypridle: 1 s ruhig, dann jede Eingabe = aus. Inhibitoren egal (Video läuft weiter → trotzdem weg).
    IdleMonitor {
        enabled: root.shown
        timeout: 1
        respectInhibitors: false
        onIsIdleChanged: {
            if (isIdle)
                root.sawIdle = true;
            else if (root.sawIdle)
                root.stop();
        }
    }

    // Test endet von selbst
    Timer {
        id: testEnd
        onTriggered: root.stop()
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: win

            required property var modelData

            function sync(): void {
                if (root.shown) {
                    fadeOut.stop();
                    fadeIn.restart();
                } else {
                    fadeIn.stop();
                    fadeOut.restart();
                }
            }

            screen: modelData
            // OpacityAnimator schreibt die Deckkraft erst am Ende zurück → Sichtbarkeit an den Lauf koppeln
            visible: root.shown || fadeOut.running
            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }
            exclusionMode: ExclusionMode.Ignore
            color: "transparent"
            WlrLayershell.namespace: "desktop-dim"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            // leere Maske: Klicks und Zeiger gehen durch
            mask: Region {}

            Rectangle {
                id: shade
                anchors.fill: parent
                color: Qt.alpha(Theme.dim, 1)
                opacity: 0
            }

            // Animator läuft im Render-Thread: gleichmäßig auf 360 Hz, auch wenn die Shell kurz hängt
            OpacityAnimator {
                id: fadeIn
                target: shade
                to: root.strength
                duration: root.duration
                easing.type: Easing.InQuad
            }
            OpacityAnimator {
                id: fadeOut
                target: shade
                to: 0
                duration: Theme.fade
                easing.type: Easing.OutCubic
            }

            Connections {
                target: root
                function onShownChanged() {
                    win.sync();
                }
            }
        }
    }

    // qs ipc --any-display -p ~/Workspace/bastian-shell/shell call dim start false
    IpcHandler {
        target: "dim"

        // Achtung: „show“ als Funktionsname geht nicht (kollidiert mit dem Unterbefehl „qs ipc show“)
        function start(force: bool): string {
            return root.start(force, 60000);
        }
        function stop(): void {
            root.stop();
        }
        // vor DPMS aus (scripts/idle black): gleiche Fokus-Regel wie beim Abdunkeln
        function black(force: bool): string {
            if (!force && Focus.active)
                return "skip";
            return "ok";
        }
        // Ausprobieren: in ~70 % der Zeit abdunkeln, kurz halten, dann von selbst aus (2–60 s)
        function test(seconds: int): string {
            const s = Math.max(2, Math.min(60, seconds));
            const r = root.start(true, Math.round(s * 700));
            if (r === "ok") {
                testEnd.interval = s * 1000;
                testEnd.restart();
            }
            return r;
        }
        function status(): string {
            return root.shown ? "dimmed" : "clear";
        }
    }
}

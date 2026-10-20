pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "camlight.js" as CL

// Key Light mit der Kamera: läuft die Kamera (irgendeine App, Privacy.camLive) 1,5 s lang, schaltet sich das Key Light
// ein (mit der zuletzt eingestellten Helligkeit/Kelvin); ist sie 5 s aus, wieder aus – aber nur, wenn die Automatik es
// eingeschaltet hat und Bastian es seitdem nicht selbst geschaltet oder verstellt hat. Zustandslogik: camlight.js
// (Test scripts/tests/camlight-test.js). Eigener Dienst statt in KeyLight.qml: KeyLight bleibt reiner Gerätetreiber.
// Nicht einschalten, solange gesperrt oder im Leerlauf (ab Abdunkeln, 4 min); ausschalten geht immer.
// Schalter: ~/.config/desktop/keylight.json { "autoCamera": false } (fehlt = an), live gelesen; oder IPC unten.
// Merkt sich in $XDG_RUNTIME_DIR/desktop-camlight.json, ob das Licht ihr gehört (übersteht Neustarts der Shell).
// Doku: docs/knowledge/shell-features.md (Key Light mit der Kamera)
Singleton {
    id: root

    property bool autoCamera: true
    property var cfg: ({})
    property var cur: CL.initial()
    property bool locked: false
    property string last: ""          // letztes Ereignis -> Aktion (IPC status, zur Fehlersuche)

    // nur zum Laden des Singletons (shell.qml), sonst lädt es erst beim ersten Zugriff
    function init(): void {}

    function setEnabled(v: bool): void {
        cfgFile.setText(JSON.stringify(Object.assign({}, cfg, { autoCamera: v }), null, 2) + "\n");
        apply(v);
    }
    function apply(v: bool): void {
        if (v === autoCamera)
            return;
        autoCamera = v;
        // abgeschaltet: was die Automatik eingeschaltet hat, gehört wieder Bastian (bleibt, wie es ist)
        if (!v)
            dispatch({ type: "manual" });
    }

    function dispatch(ev: var): void {
        const r = CL.step(cur, ev);
        last = ev.type + (ev.phase ? ":" + ev.phase : "") + (ev.type === "light" ? (ev.ok ? (ev.on ? " on" : " off") : " failed") : "")
            + " -> " + (r.action || "-");
        if (JSON.stringify(r.state) !== JSON.stringify(cur)) {
            cur = r.state;
            stateFile.setText(JSON.stringify(cur));
        }
        switch (r.action) {
        case "query-start":
        case "query-stop": {
            const phase = r.action === "query-start" ? "start" : "stop";
            KeyLight.query((ok, l) => root.dispatch({ type: "light", phase: phase, ok: ok, on: !!l && l.on,
                brightness: l ? l.brightness : 0, kelvin: l ? l.kelvin : 0 }));
            break;
        }
        case "on":
            console.log("camlight: camera on -> Key Light on");
            KeyLight.autoSetOn(true);
            break;
        case "off":
            console.log("camlight: camera off -> Key Light off");
            KeyLight.autoSetOn(false);
            break;
        case "unreachable":
            console.warn("camlight: Key Light not reachable, skipped");
            break;
        }
    }

    // Kamera-Zustand entprellen: kurzes Öffnen (Geräte-Abfragen, Vorschau-Test) schaltet nichts
    function sync(): void {
        if (Privacy.camLive) {
            stopDelay.stop();
            if (!cur.session)
                startDelay.restart();
        } else {
            startDelay.stop();
            if (cur.session)
                stopDelay.restart();
        }
    }

    Connections {
        target: Privacy
        function onCamLiveChanged(): void {
            root.sync();
        }
    }
    Connections {
        target: KeyLight
        function onUserChanged(): void {
            if (root.cur.owned)
                root.dispatch({ type: "manual" });
        }
    }
    Timer {
        id: startDelay
        interval: 1500
        onTriggered: root.dispatch({ type: "start", allowed: root.autoCamera && !root.locked && !idle.isIdle })
    }
    Timer {
        id: stopDelay
        interval: 5000
        onTriggered: root.dispatch({ type: "stop" })
    }

    IdleMonitor {
        id: idle
        timeout: 240
    }

    // Sperrzustand der Shell (Lock.qml schreibt „locked“/„unlocked“)
    FileView {
        path: Quickshell.env("XDG_RUNTIME_DIR") + "/desktop-lock"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: root.locked = text().trim() === "locked"
        onLoadFailed: root.locked = false
    }

    FileView {
        id: cfgFile
        path: Quickshell.env("HOME") + "/.config/desktop/keylight.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            let c = {};
            try {
                c = JSON.parse(text()) || {};
            } catch (e) {
                console.warn("camlight: ~/.config/desktop/keylight.json unreadable:", e);
            }
            root.cfg = c;
            root.apply(c.autoCamera !== false);
        }
        onLoadFailed: {
            root.cfg = {};
            root.apply(true);
        }
    }

    FileView {
        id: stateFile
        path: Quickshell.env("XDG_RUNTIME_DIR") + "/desktop-camlight.json"
        blockLoading: true
        printErrors: false
        onLoaded: {
            try {
                root.cur = CL.restore(JSON.parse(text()));
            } catch (e) {}
            root.sync();
        }
        onLoadFailed: root.sync()
    }

    // qs ipc --any-display -p ~/Workspace/bastian-shell/shell call camlight status|enable|disable|toggle
    IpcHandler {
        target: "camlight"
        function status(): string {
            return JSON.stringify({ enabled: root.autoCamera, camera: Privacy.camLive, session: root.cur.session,
                owned: root.cur.owned, locked: root.locked, idle: idle.isIdle, last: root.last });
        }
        function enable(): void {
            root.setEnabled(true);
        }
        function disable(): void {
            root.setEnabled(false);
        }
        function toggle(): void {
            root.setEnabled(!root.autoCamera);
        }
    }
}

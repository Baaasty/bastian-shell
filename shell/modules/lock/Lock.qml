pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Pam
import qs.config
import qs.services

// Sperrbildschirm unter Hyprland (ext-session-lock). Ersetzt das Plasma-Paket plasma/shells/…/lockscreen,
// sieht aus wie dieses (Ablauf und Maße aus LockScreenUi.qml/MainBlock.qml übernommen).
// Herkunft: Ablauf/Maße nach KDE Plasma Workspace (lockscreen), GPL-2.0-or-later – siehe THIRD_PARTY.md.
// Auslösen: scripts/lock now (Super+L, hypridle, Power-Menü) → qs ipc call lock lock.
// Sicherheit: Entsperren nur per PAM (assets/pam.d/desktop-lock), bewusst kein IPC-„unlock“.
// Ausnahme nur lokal: ~/.config/desktop/lock.json { "requirePassword": false } → Leertaste/Enter entsperrt ohne Passwort
// (sinnvoll nur mit verschlüsselter Platte + Autologin; Standard bleibt Passwort, docs/knowledge/hyprland.md).
// Absturz: Hyprland bleibt gesperrt; die neu gestartete Shell sperrt dank Zustandsdatei wieder,
// sonst übernimmt scripts/lock guard mit hyprlock (Ablauf: docs/knowledge/hyprland.md).
// Leerlauf (hypridle → scripts/lock): IPC „idle“ sperrt, beachtet den Fokus-Block (Abdunkeln: modules/idle).
Scope {
    id: root

    // nur unter Hyprland: KWin kennt ext-session-lock nicht (dort sperrt kscreenlocker per loginctl)
    readonly property bool supported: !!Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE")
    readonly property string script: Quickshell.shellDir + "/../scripts/lock"

    // ---- gemeinsamer Zustand aller Monitore ----
    property string buffer: ""
    property bool uiVisible: false       // Passwortfeld, Aktionen, Medien und Unschärfe sichtbar
    property string notification: ""    // „Unlocking failed“ und PAM-Meldungen
    property bool capsLock: false
    property bool unlocking: false       // Auffächern läuft, danach erst wirklich entsperren
    // wie die Plasma-Einstellung desktopAutoSubmitLength: 6 Kästchen, beim 6. Zeichen prüfen (0 = freies Feld)
    readonly property int codeLength: 6
    // aus ~/.config/desktop/lock.json; fehlt die Datei oder ist sie kaputt: Passwort nötig
    property bool requirePassword: true
    readonly property bool graceLocked: graceTimer.running
    readonly property bool checking: pam.active
    // Felder bleiben offen, solange etwas getippt ist oder geprüft wird
    readonly property bool blockUI: buffer.length > 0 || checking

    signal rejected()             // Fehlversuch: Wackeln
    signal notificationRepeated() // gleiche Meldung nochmal: Hüpfen

    function lock(): string {
        if (!supported)
            return "unsupported";
        if (sessionLock.locked)
            return "locked";
        // erst die Zustandsdatei, dann sperren: stirbt die Shell dazwischen, sperrt der Neustart
        stateFile.setText("locked\n");
        reset();
        sessionLock.locked = true;
        Quickshell.execDetached([script, "guard"]);
        return "ok";
    }

    function reset(): void {
        buffer = "";
        notification = "";
        uiVisible = false;
        unlocking = false;
        graceTimer.stop();
    }

    function show(): void {
        uiVisible = true;
        fadeTimer.restart();
    }

    function say(msg: string): void {
        if (!msg)
            return;
        if (!notification)
            notification = msg;
        else if (notification.includes(msg))
            notificationRepeated();
        else
            notification += "\n" + msg;
        notificationTimer.restart();
    }

    function submit(): void {
        if (buffer.length === 0 || pam.active || graceLocked || unlocking)
            return;
        pam.answered = false;
        if (!pam.start())
            fail("Unlocking failed (PAM)");
    }

    function fail(msg: string): void {
        say(msg);
        rejected();
        graceTimer.restart();
    }

    // Tasten aus allen Sperrflächen landen hier (ein Puffer für alle Monitore)
    function key(event: var): void {
        event.accepted = true;
        if (unlocking)
            return;
        const k = event.key;
        if (k === Qt.Key_Escape) {
            // wie kscreenlocker: Esc blendet aus, bei ausgeblendetem Feld gehen die Monitore aus
            if (uiVisible) {
                uiVisible = false;
                if (!pam.active)
                    buffer = "";
            } else {
                Quickshell.execDetached(["hyprctl", "dispatch", "dpms", "off"]);
            }
            return;
        }
        show();
        // ohne Passwort: Leertaste oder Enter entsperrt (gleiche Animation wie nach erfolgreichem PAM)
        if (!requirePassword) {
            if (k === Qt.Key_Space || k === Qt.Key_Return || k === Qt.Key_Enter) {
                unlocking = true;
                unlockTimer.restart();
            }
            return;
        }
        if (k === Qt.Key_CapsLock) {
            capsLock = !capsLock;
            return;
        }
        if (pam.active || graceLocked)
            return;
        if (k === Qt.Key_Return || k === Qt.Key_Enter) {
            submit();
            return;
        }
        if (k === Qt.Key_Backspace) {
            buffer = (event.modifiers & Qt.ControlModifier) ? "" : buffer.slice(0, -1);
            return;
        }
        const t = event.text;
        // nur druckbare Zeichen; Strg ohne Alt = Kürzel (Strg+Alt = AltGr, z. B. @ { } bleibt erlaubt)
        const ctrl = (event.modifiers & Qt.ControlModifier) && !(event.modifiers & Qt.AltModifier);
        if (!t || ctrl || !/^[^\x00-\x1F\x7F-\x9F]+$/.test(t))
            return;
        // Feststelltaste aus Buchstaben ableiten (Qt meldet sie nicht als Modifier)
        if (t.length === 1 && t.toLowerCase() !== t.toUpperCase())
            capsLock = (t === t.toUpperCase()) !== ((event.modifiers & Qt.ShiftModifier) !== 0);
        if (codeLength > 0 && buffer.length >= codeLength)
            return;
        buffer += t;
        if (codeLength > 0 && buffer.length === codeLength)
            submit();
    }

    WlSessionLock {
        id: sessionLock

        // unerwartet entsperrt (Compositor hat abgelehnt) → Zustandsdatei bleibt „locked“, scripts/lock guard übernimmt
        onLockStateChanged: {
            if (!locked)
                root.reset();
            else
                capsProc.running = true;
        }

        LockSurface {
            ctx: root
        }
    }

    PamContext {
        id: pam

        // Antwort nur einmal pro Versuch (eine zweite Frage, z. B. „Passwort abgelaufen“, nie blind beantworten)
        property bool answered: false

        config: "desktop-lock"
        configDirectory: Quickshell.shellDir + "/assets/pam.d"

        onResponseRequiredChanged: {
            if (!responseRequired)
                return;
            if (answered) {
                abort();
                root.fail("Unlocking failed");
                return;
            }
            answered = true;
            respond(root.buffer);
        }
        onMessageChanged: {
            if (messageIsError && !responseRequired)
                root.say(message);
        }
        onCompleted: result => {
            if (result === PamResult.Success) {
                root.buffer = "";
                root.notification = "";
                root.unlocking = true;
                unlockTimer.restart();
            } else {
                root.fail(result === PamResult.MaxTries ? "Too many attempts" : "Unlocking failed");
            }
        }
        onError: err => root.fail("Unlocking failed (" + PamError.toString(err) + ")")
    }

    FileView {
        path: Quickshell.env("HOME") + "/.config/desktop/lock.json"
        blockLoading: true
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            try {
                root.requirePassword = JSON.parse(text()).requirePassword !== false;
            } catch (e) {
                console.warn("lock: ~/.config/desktop/lock.json is not valid JSON, password stays required");
                root.requirePassword = true;
            }
        }
        onLoadFailed: root.requirePassword = true
    }

    // nach dem Auffächern (LockSurface: 140 + 560 ms) wirklich entsperren
    Timer {
        id: unlockTimer
        interval: 760
        onTriggered: {
            stateFile.setText("unlocked\n");
            sessionLock.locked = false;
            root.reset();
        }
    }
    // Plasma: nach 10 s ohne Eingabe Feld ausblenden (nicht, solange etwas getippt ist)
    Timer {
        id: fadeTimer
        interval: 10000
        onTriggered: {
            if (!root.blockUI)
                root.uiVisible = false;
        }
    }
    onBlockUIChanged: if (!blockUI && uiVisible) fadeTimer.restart()
    // Plasma: nach Fehlversuch 3 s gesperrt, dann Feld leeren
    Timer {
        id: graceTimer
        interval: 3000
        onTriggered: root.buffer = ""
    }
    Timer {
        id: notificationTimer
        interval: 3000
        onTriggered: root.notification = ""
    }

    // Zustand für Neustarts und scripts/lock (guard, dpms-if-locked): „locked“ / „unlocked“
    FileView {
        id: stateFile

        property bool checked: false

        path: Quickshell.env("XDG_RUNTIME_DIR") + "/desktop-lock"
        printErrors: false
        onLoaded: {
            // nur beim Start: war gesperrt (Absturz/Neustart) → sofort wieder sperren
            if (checked)
                return;
            checked = true;
            if (text().trim() === "locked")
                root.lock();
        }
        onLoadFailed: checked = true
    }

    // Feststelltaste beim Sperren einmal abfragen (danach aus den Tasten abgeleitet)
    Process {
        id: capsProc
        command: ["sh", "-c", "hyprctl devices -j 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const kb = JSON.parse(text).keyboards || [];
                    const main = kb.find(k => k.main) || kb[0];
                    if (main)
                        root.capsLock = !!main.capsLock;
                } catch (e) {}
            }
        }
    }

    // qs ipc --any-display -p ~/Workspace/bastian-shell/shell call lock lock
    IpcHandler {
        target: "lock"

        function lock(): string {
            return root.lock();
        }
        // für scripts/lock guard: hält die Shell die Sperre wirklich?
        function isLocked(): bool {
            return sessionLock.locked && sessionLock.secure;
        }
    }

    // hypridle (über scripts/lock): im Fokus-Block erst beim zweiten, späteren Aufruf mit force.
    // Abdunkeln davor: shell/modules/idle (IPC „dim“).
    IpcHandler {
        target: "idle"

        function lock(force: bool): string {
            if (!force && Focus.active)
                return "skip";
            return root.lock();
        }
    }
}

pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Bar-Modus (AP 22, Tastatur zuerst): Super+Leertaste, dann ein Buchstabe öffnet das Popout des Chips; Esc oder nochmal = zu.
// Gleiche Logik wie der Workspace-Modus (WorkBar.qml): die Bar holt sich die Tastatur (BarWindow), solange der Modus läuft
// oder ein per Taste geöffnetes Popout offen ist. Die Chips hören auf openRequested(name) und zeigen ihren Buchstaben,
// solange modeOn ist. Einzelkürzel für jeden Eintrag (Super+F/T/A/E/B/I, sonst Super+Alt+<Buchstabe>) gehen über dieselbe
// IPC: `barmode popout <name>`.
// IPC: qs ipc call barmode toggle|open|close|state|key <Buchstabe>|popout <name>
Singleton {
    id: root

    // Buchstabe → Popout (name = Popouts-Kennung des Popouts). Reihenfolge wie in der Bar (links → rechts) = Hinweiszeile,
    // Kürzel-Menü (Super+K) und docs/knowledge/hotkeys.md. Einzelkürzel je Eintrag: hypr/binds.conf, Abschnitt Topbar.
    // Tray = Y (sYstray): T gehört den Tasks (Super+T), Y ist frei und liegt auf QWERTZ links unten bei Super/Alt.
    // action: kein Popout, der Chip tut direkt etwas (actionRequested) – z. B. Dateimanager, Browser
    readonly property var entries: [
        { key: "F", name: "focus", label: "Focus" },
        { key: "T", name: "todo", label: "Tasks" },
        { key: "A", name: "claudehub", label: "Agents" },
        { key: "M", name: "spotify", label: "Music" },
        { key: "C", name: "discord", label: "Chat" },
        { key: "V", name: "devservices", label: "Dev" },
        { key: "H", name: "servers", label: "Servers" },
        { key: "R", name: "resources", label: "Resources" },
        { key: "L", name: "light", label: "Light" },
        { key: "G", name: "gear", label: "Gear" },
        { key: "S", name: "mixer", label: "Sound" },
        { key: "N", name: "net", label: "Network" },
        { key: "E", name: "files", label: "Files", action: true },
        { key: "D", name: "downloads", label: "Downloads" },
        { key: "B", name: "browser", label: "Browser", action: true },
        { key: "I", name: "settings", label: "Settings", action: true },
        { key: "U", name: "updates", label: "Updates" },
        { key: "Y", name: "tray", label: "Tray" },
        { key: "Z", name: "notifs", label: "Notifications" }
    ]

    // Namen, die nur einen Reiter eines anderen Popouts meinen: Server (Konsolen + sshs) lebt im Dev-Popout
    readonly property var aliases: ({ servers: { name: "devservices", tab: "server" } })

    property bool modeOn: false
    // im Modus mit ←/→/Tab markierter Chip (name), Enter/↓ öffnet ihn
    property string sel: ""
    property bool fromMode: false    // Popout kam aus dem Bar-Modus: Esc führt dorthin zurück (Einzelkürzel: ganz zu)
    // Popout, das per Taste aufging: die Bar behält so lange die Tastatur, das Popout schließt nicht durch Weghovern
    property string kbOpen: ""
    property string note: ""
    // Einzelkürzel (Super+Alt+S …): Hyprland schluckt den Tastendruck, die Shell hat also kein Eingabe-Ereignis, mit dem
    // das Popout den Tastaturfokus greifen darf. Darum erst die Tastatur holen („armed“) und beim nächsten Tasten-Ereignis
    // (Loslassen der Kürzel-Tasten) öffnen. Kommt keins, öffnet es ohne Fokus-Griff; dann reicht die Bar die Tasten weiter (fwd).
    property string armed: ""
    property string fwd: ""
    property var navs: ({})          // name → KeyNav (für die Weitergabe)
    readonly property bool wantsKeys: modeOn || kbOpen !== "" || armed !== ""

    // an die Chips: dieses Popout per Tastatur öffnen (grab = mit Fokus-Griff)
    signal openRequested(string name, bool grab)
    // an Chips ohne Popout (entries mit action): jetzt auslösen
    signal actionRequested(string name)
    // an Popouts mit Reitern (aliases): vor dem Öffnen auf diesen Reiter schalten
    signal tabRequested(string name, string tab)
    // an Popups.qml: Benachrichtigungen per Tastatur (an/aus)
    signal notifsRequested()
    // Test ohne Tastatur (IPC step/enter): Chip-Auswahl wie ←/→
    signal stepRequested(int d)

    function isAction(name: string): bool {
        const e = entries.find(x => x.name === name);
        return !!e && e.action === true;
    }
    function keyFor(name: string): string {
        const e = entries.find(x => x.name === name);
        return e ? e.key : "";
    }
    // Einzelkürzel ohne Alt (hypr/binds.conf, Abschnitt Topbar); alle anderen Buchstaben: Super+Alt+<Buchstabe>
    readonly property var superOnly: ["F", "T", "A", "E", "B", "I"]
    // Tooltip für Chips ohne eigenen Text (Chip.tipText): „Resources · Super+Alt+R“
    function tipFor(key: string): string {
        const e = key !== "" ? entries.find(x => x.key === key) : null;
        if (!e)
            return "";
        return e.label + " · " + (superOnly.includes(e.key) ? "Super+" : "Super+Alt+") + e.key;
    }
    function openMode(): void {
        note = "";
        sel = "";
        modeOn = true;
    }
    function closeMode(): void {
        modeOn = false;
    }
    // Buchstabe im Modus: passendes Popout auf
    function pick(letter: string): bool {
        const e = entries.find(x => x.key === letter.toUpperCase());
        if (!e) {
            flash("No popout on " + letter.toUpperCase());
            return false;
        }
        fromMode = true;
        popout(e.name, true);
        return true;
    }
    function register(name: string, nav: var): void {
        navs[name] = nav;
    }
    // Einzelkürzel: erst Tastatur holen, beim nächsten Tasten-Ereignis öffnen (fire)
    function arm(name: string): void {
        if (name === "notifs" || name === "updates" || isAction(name) || kbOpen === (aliases[name] ? aliases[name].name : name))
            return popout(name, true);
        modeOn = false;
        fromMode = false;
        armed = name;
        armTimer.restart();
    }
    function fire(): void {
        if (armed === "")
            return;
        const n = armed;
        armed = "";
        armTimer.stop();
        popout(n, true);
    }
    Timer {
        id: armTimer
        interval: 350
        onTriggered: {
            const n = root.armed;
            root.armed = "";
            if (n !== "")
                root.popout(n, false);
        }
    }
    // Taste an das ohne Fokus-Griff geöffnete Popout (BarWindow ruft das, solange fwd gesetzt ist)
    function forward(e: var): void {
        const nav = navs[fwd];
        if (!nav)
            return;
        nav.key(e);
        if (!e.accepted && e.key === Qt.Key_Escape && nav.popout)
            nav.popout.visible = false;
    }
    function popout(name: string, grab: bool): void {
        modeOn = false;
        const alias = aliases[name];
        if (alias) {
            name = alias.name;
            tabRequested(name, alias.tab);
        }
        // Benachrichtigungen haben kein Bar-Popout: die Popup-Karten selbst gehen in den Tastatur-Modus (Popups.qml)
        if (name === "notifs") {
            notifsRequested();
            return;
        }
        // Aktions-Chips: kein Popout, also auch keine Tastatur behalten
        if (isAction(name)) {
            actionRequested(name);
            return;
        }
        // Updates: der Chip öffnet den Paketmanager (eigenes Panel mit Tastatur)
        if (name === "updates") {
            Updates.openManager();
            return;
        }
        // schon offen (Maus): wieder per Taste zu – wie ein Umschalter
        if (kbOpen === name && Popouts.current === name) {
            Popouts.claim("_");
            return;
        }
        kbOpen = name;
        fwd = grab ? "" : name;
        Popouts.claim("_");
        openRequested(name, grab);
    }
    // Popout meldet: zu (egal wie) → Tastatur zurückgeben
    // Popout wurde vom Compositor geschlossen und ohne Klick-Fang wieder geöffnet (PopoutGuard): Tasten über die Bar
    function keepKeys(name: string): void {
        kbOpen = name;
        fwd = name;
    }
    // back = mit Esc zu (KeyNav): zurück in den Bar-Modus, der Chip bleibt markiert
    function released(name: string, back: bool): void {
        const was = kbOpen === name;
        if (was)
            kbOpen = "";
        if (fwd === name)
            fwd = "";
        if (was && back && fromMode) {
            sel = name;
            note = "";
            modeOn = true;
        }
    }
    function flash(text: string): void {
        note = text;
        noteTimer.restart();
    }
    Timer {
        id: noteTimer
        interval: 2000
        onTriggered: root.note = ""
    }
    // Sicherheitsnetz: meldet sich kein Popout als offen (Chip unsichtbar, Name falsch), Tastatur nach kurzer Zeit zurück
    Timer {
        running: root.kbOpen !== "" && (Popouts.current === "" || Popouts.current === "_")
        interval: 1500
        onTriggered: {
            root.kbOpen = "";
            root.fwd = "";
        }
    }

    IpcHandler {
        target: "barmode"
        function toggle(): void {
            if (root.modeOn || root.kbOpen !== "") {
                root.closeMode();
                const open = root.kbOpen;
                root.kbOpen = "";
                if (open !== "")
                    Popouts.claim("_");      // offenes Popout schließen
            } else {
                root.openMode();
            }
        }
        function open(): void {
            root.openMode();
        }
        function close(): void {
            root.closeMode();
        }
        function key(letter: string): string {
            return root.pick(letter) ? "ok" : root.note;
        }
        // Einzelkürzel: Popout direkt per Tastatur öffnen (mixer, net, light, …, notifs); nochmal = zu
        function popout(name: string): void {
            root.arm(name);
        }
        // wie ←/→ im Modus (d = 1 / -1) und Enter
        function step(d: int): string {
            root.stepRequested(d);
            return root.sel;
        }
        function enter(): void {
            if (root.modeOn && root.sel !== "") {
                root.fromMode = true;
                root.popout(root.sel, false);
            }
        }
        function state(): string {
            return JSON.stringify({ mode: root.modeOn, kbOpen: root.kbOpen, armed: root.armed, fwd: root.fwd, sel: root.sel, current: Popouts.current, note: root.note });
        }
    }
}

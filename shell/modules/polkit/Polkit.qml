import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Services.Polkit
import qs.config

// Eigener Polkit-Agent (AP 17): Passwort-Dialog im Shell-Design statt polkit-kde-authentication-agent-1.
// Es kann nur EIN Agent je Sitzung registriert sein. Wer wann registriert ist, regelt scripts/polkit-agent
// (Wächter: KDE-Agent läuft als Rückfall, solange die Shell nicht registriert ist – kein Aussperren).
// Zustand für den Wächter: $XDG_RUNTIME_DIR/desktop-polkit = „registered <qs-pid>“ | „unregistered <qs-pid>“.
// IPC: qs ipc … call polkit status | register | release | demo
Scope {
    id: root

    property bool wanted: true          // false = Agent abgemeldet (Wächter lässt den KDE-Agent ran)
    property bool demo: false           // Vorschau mit Scheindaten (kein Agent-Ablauf, nichts wird geprüft)
    property string screenName: Config.mainScreen
    readonly property var flow: agentLoader.item ? agentLoader.item.flow : null
    readonly property bool registered: agentLoader.item ? agentLoader.item.isRegistered : false
    readonly property bool active: demo || (flow !== null)

    property bool failed: false         // letzter Versuch war falsch
    property bool checking: false       // Antwort ging raus, PAM prüft
    property string demoNote: ""

    readonly property var names: flow ? flow.identities.map(i => String(i.displayName || i.string || i.name || i.id || "")) : []
    readonly property int identityIndex: flow ? Math.max(0, flow.identities.indexOf(flow.selectedIdentity)) : 0

    // Prompt von PAM: „Password: “ → „Password“
    function cleanPrompt(p: string): string {
        const t = (p || "").trim().replace(/:$/, "").trim();
        return t || (flow && flow.responseVisible ? "Input" : "Password");
    }
    function cleanMessage(m: string): string {
        return (m || "").trim().replace(/\.$/, "");
    }

    function writeState(): void {
        Quickshell.execDetached(["sh", "-c", "printf '%s %s\\n' \"$1\" \"$2\" > \"${XDG_RUNTIME_DIR:-/tmp}/desktop-polkit\"", "sh", registered ? "registered" : "unregistered", String(Quickshell.processId)]);
    }
    onRegisteredChanged: writeState()
    Component.onCompleted: writeState()

    Loader {
        id: agentLoader
        active: root.wanted
        sourceComponent: PolkitAgent {
            onAuthenticationRequestStarted: {
                root.failed = false;
                root.checking = false;
                root.screenName = Hyprland.focusedMonitor?.name ?? Config.mainScreen;
                card.reset();
            }
            onIsRegisteredChanged: root.writeState()
        }
        onItemChanged: root.writeState()
    }

    // Antwort ist raus → bis zum Ergebnis/der nächsten Frage gesperrt
    Connections {
        target: root.flow
        ignoreUnknownSignals: true
        function onAuthenticationFailed(): void {
            root.failed = true;
            root.checking = false;
            card.reset();
        }
        function onIsResponseRequiredChanged(): void {
            if (root.flow && root.flow.isResponseRequired) {
                root.checking = false;
                card.reset();
            }
        }
    }

    function cancel(): void {
        if (demo) {
            demo = false;
            return;
        }
        if (flow)
            flow.cancelAuthenticationRequest();
    }
    function submit(text: string): void {
        if (demo) {
            demoNote = "";
            failed = text === "wrong";   // Vorschau: „wrong“ zeigt den Fehlversuch, alles andere schließt
            if (!failed)
                demo = false;
            return;
        }
        if (!flow || !flow.isResponseRequired)
            return;
        failed = false;
        checking = true;
        flow.submit(text);
    }

    // Neu anmelden (Loader aus/an)
    Timer {
        id: reTimer
        interval: 400
        onTriggered: root.wanted = true
    }

    IpcHandler {
        target: "polkit"

        function status(): string {
            return root.registered ? "registered" : (root.wanted ? "unregistered" : "released");
        }
        function register(): string {
            root.wanted = false;
            reTimer.restart();
            return "ok";
        }
        function release(): string {
            reTimer.stop();
            root.wanted = false;
            return "ok";
        }
        // zum Testen: Dialog mit Scheindaten (Enter schließt, „wrong“ zeigt den Fehlversuch, Esc bricht ab)
        function demo(many: bool): string {
            root.screenName = Hyprland.focusedMonitor?.name ?? Config.mainScreen;
            root.failed = false;
            root.checking = false;
            root.demo = true;
            card.demoMany = many;
            card.reset();
            return "ok";
        }
    }

    PanelWindow {
        id: win

        screen: Quickshell.screens.find(s => s.name === root.screenName) ?? Quickshell.screens[0]
        visible: root.active
        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"
        WlrLayershell.namespace: "dock" // "dock": ohne Öffnen-Animation (Hyprland: layerrule noanim)
        WlrLayershell.layer: WlrLayer.Overlay
        // Exklusiv: Tastatur gehört dem Dialog, bis er zu ist
        WlrLayershell.keyboardFocus: root.active ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

        onVisibleChanged: if (visible) card.reset()

        Rectangle {
            anchors.fill: parent
            color: Theme.dim
            opacity: root.active ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: Theme.fade; easing.type: Easing.OutCubic } }
            MouseArea {
                anchors.fill: parent    // Klicks daneben schlucken, nicht abbrechen
                onPressed: card.focusField()
            }
        }

        PolkitDialog {
            id: card

            property bool demoMany: false
            readonly property var f: root.flow

            anchors.centerIn: parent
            opacity: root.active ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: Theme.fade; easing.type: Easing.OutCubic } }

            message: root.demo ? "Authentication is needed to install packages" : root.cleanMessage(f ? f.message : "")
            actionId: root.demo ? "org.example.packagemanager.install" : (f ? f.actionId : "")
            identities: root.demo ? (demoMany ? ["root", "bastian"] : ["root"]) : root.names
            identityIndex: root.demo ? 0 : root.identityIndex
            prompt: root.demo ? "Password" : root.cleanPrompt(f ? f.inputPrompt : "")
            echo: !root.demo && f ? f.responseVisible : false
            inputEnabled: root.demo ? true : (f ? f.isResponseRequired && !root.checking : false)
            checking: root.checking
            failed: root.failed
            info: root.demo ? "" : (f ? f.supplementaryMessage : "")
            infoIsError: !root.demo && f ? f.supplementaryIsError : false

            onSubmitted: text => root.submit(text)
            onCancelled: root.cancel()
            onIdentityPicked: i => {
                if (f && i >= 0 && i < f.identities.length)
                    f.selectedIdentity = f.identities[i];
            }
        }
    }
}

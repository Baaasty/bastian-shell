pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Hyprland

// Immer nur ein Bar-Popout offen: wer aufgeht, meldet sich hier, die anderen schließen sich.
// claim("_") = alle gewollt zu (Bar-Modus / Umschalt-Taste): PopoutGuard holt dann nichts zurück.
Singleton {
    id: root

    property string current: ""
    // Maus auf der Bar oder im Streifen bis zum Popout (BarWindow „bridge“): zählt für PopoutGuard als drin.
    // overBar = auf der Bar selbst (Chips und Lücken): schließt der Compositor dann ein Popout, war es ein Klick auf die
    // Bar – der Klick entscheidet (anderes Menü auf, gleiches zu), PopoutGuard holt nichts zurück
    property bool bridge: false
    property bool overBar: false

    // Alle Chips (Chip.qml meldet sich an): PopoutGuard sucht darüber den Chip unter der Maus, wenn Hyprland ein offenes
    // Popout per Klick auf einen anderen Chip schließt und den Klick dabei schluckt – dann löst der Guard ihn selbst aus.
    property var chips: []
    property var synthChip: null      // so ausgelöster Chip + Zeitpunkt: kommt der echte Klick doch noch an, zählt er nicht
    property real synthAt: 0
    function addChip(c: var): void {
        chips.push(c);
    }
    function removeChip(c: var): void {
        const i = chips.indexOf(c);
        if (i >= 0)
            chips.splice(i, 1);
    }

    // Vorrang (Share-Picker, Dialoge): solange > 0 holt sich kein Bar-Popout Fokus oder Klick-Fang (PopoutGuard)
    property int modal: 0
    function hold(on: bool): void {
        root.modal = Math.max(0, root.modal + (on ? 1 : -1));
        if (on)
            root.claim("_");          // offene Popouts gewollt zu – sie kämen sonst nach dem Fokuswechsel wieder
    }

    // Hyprland: wann sich zuletzt etwas „von selbst“ geändert hat (Fenster/Ebene auf oder zu, Arbeitsfläche, Vollbild).
    // Danach fokussiert Hyprland neu und beendet dabei den Klick-Fang eines offenen Popouts, obwohl niemand geklickt hat.
    // PopoutGuard unterscheidet so „Fokuswechsel ohne Klick“ (Popout bleibt) von „Klick in ein anderes Fenster“ (zu).
    // Nicht dabei: activewindow/focusedmon – die kommen auch vom Klick selbst.
    property real changedAt: 0
    readonly property bool hypr: (Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE") || "") !== ""
    readonly property var selfEvents: ["openwindow", "closewindow", "movewindow", "openlayer", "closelayer", "workspace",
        "moveworkspace", "activespecial", "fullscreen", "changefloatingmode", "minimized", "createworkspace", "destroyworkspace"]
    Connections {
        target: Hyprland
        enabled: root.hypr
        function onRawEvent(event): void {
            if (root.selfEvents.includes(event.name))
                root.changedAt = Date.now();
        }
    }

    function claim(id: string): void {
        current = id;
    }
    function release(id: string): void {
        if (current === id)
            current = "";
    }
}

pragma Singleton
import QtQuick
import Quickshell

// Immer nur ein Bar-Popout offen: wer aufgeht, meldet sich hier, die anderen schließen sich.
// claim("_") = alle gewollt zu (Bar-Modus / Umschalt-Taste): PopoutGuard holt dann nichts zurück.
Singleton {
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

    function claim(id: string): void {
        current = id;
    }
    function release(id: string): void {
        if (current === id)
            current = "";
    }
}

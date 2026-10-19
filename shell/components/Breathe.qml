import QtQuick

// Leises „Atmen“ (Glut-Puls) für kleine Punkte, mit ~12 Bildern/s statt Bildschirmrate.
// Warum: eine Dauer-NumberAnimation lässt Qt das ganze Fenster mit jeder Bildwiederholung neu zeichnen
// (DP-2: 360 Hz → ~170–360 Bilder/s, solange z. B. eine Claude-Karte wartet). Für einen 7-px-Punkt
// sieht man bei 12 Bildern/s keinen Unterschied, die Shell braucht dabei aber nur einen Bruchteil.
// Verlauf wie vorher: Sinus von `from` nach `to` und zurück, eine Hälfte = halfMs.
// Nutzung: Breathe { id: b; running: … }  →  opacity: b.value
Timer {
    id: breathe

    property real from: 1
    property real to: 0.35
    property int halfMs: 1400
    property real value: from
    property real _start: 0

    interval: 80
    repeat: true
    onRunningChanged: {
        _start = Date.now();
        value = from;
    }
    onTriggered: {
        const p = ((Date.now() - _start) % (2 * halfMs)) / (2 * halfMs);
        value = to + (from - to) * (0.5 + 0.5 * Math.cos(2 * Math.PI * p));
    }
}

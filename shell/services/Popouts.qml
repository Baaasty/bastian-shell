pragma Singleton
import QtQuick
import Quickshell

// Immer nur ein Bar-Popout offen: wer aufgeht, meldet sich hier, die anderen schließen sich.
// claim("_") = alle gewollt zu (Bar-Modus / Umschalt-Taste): PopoutGuard holt dann nichts zurück.
Singleton {
    property string current: ""

    function claim(id: string): void {
        current = id;
    }
    function release(id: string): void {
        if (current === id)
            current = "";
    }
}

pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Emoji-Liste (aus shell/data/gen_emoji.py)
Singleton {
    id: root

    property var list: []

    FileView {
        path: Quickshell.shellDir + "/data/emoji.json"
        blockLoading: true
        // kaputte/halbe Datei (z. B. während gen_emoji.py schreibt): alte Liste behalten statt Fehler
        onLoaded: {
            try {
                const d = JSON.parse(text());
                if (Array.isArray(d))
                    root.list = d;
            } catch (e) {
                console.warn("Emoji: emoji.json not readable");
            }
        }
    }

    function copy(ch: string): void {
        Quickshell.execDetached(["wl-copy", ch]);
    }
}

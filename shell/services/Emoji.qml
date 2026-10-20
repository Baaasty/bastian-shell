pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Emoji-Liste (aus shell/data/gen_emoji.py) und die zuletzt benutzten fürs Emoji-Popup (modules/clip/EmojiPopup.qml)
Singleton {
    id: root

    property var list: []            // [[Zeichen, englischer Name]]
    readonly property var names: {   // Zeichen -> Name
        const m = {};
        for (const [ch, name] of list)
            m[ch] = name;
        return m;
    }
    property var recent: []          // Zeichen, neueste zuerst
    readonly property int recentMax: 18   // zwei Reihen im Popup

    // Zeichen mit Emoji-Darstellung (VS16): viele Symbole (☀, 🌡 …) erscheinen sonst schwarz-weiß als Text –
    // im Popup wie im Zielfenster
    function glyph(ch: string): string {
        return ch.endsWith("\uFE0F") ? ch : ch + "\uFE0F";
    }

    function use(ch: string): void {
        recent = [ch].concat(recent.filter(x => x !== ch)).slice(0, recentMax);
        recentFile.setText(JSON.stringify(recent));
    }

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

    FileView {
        id: recentFile
        path: Quickshell.env("HOME") + "/.local/state/desktop/emoji-recent.json"
        printErrors: false
        onLoaded: {
            try {
                const d = JSON.parse(text());
                if (Array.isArray(d))
                    root.recent = d.filter(x => typeof x === "string").slice(0, root.recentMax);
            } catch (e) {}
        }
    }
}

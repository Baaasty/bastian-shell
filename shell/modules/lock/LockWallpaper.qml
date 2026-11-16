import QtQuick
import Quickshell
import Quickshell.Io

// Bild der Sperre und des Auffächerns nach dem Login: aus kscreenlockerrc (setzt scripts/wallpaper, „mitte“ auf allen
// Monitoren – wie der Login-Bildschirm, der dasselbe Bild bekommt)
Scope {
    id: root

    property string path: Quickshell.env("HOME") + "/.local/share/wallpapers/desktop/desktop-mitte-2560x1440.jpg"

    FileView {
        path: Quickshell.env("HOME") + "/.config/kscreenlockerrc"
        printErrors: false
        onLoaded: {
            let group = "";
            for (const line of text().split("\n")) {
                if (line.startsWith("["))
                    group = line.trim();
                else if (group === "[Greeter][Wallpaper][org.kde.image][General]" && line.startsWith("Image=")) {
                    const p = line.slice(6).trim().replace(/^file:\/\//, "");
                    if (p)
                        root.path = p;
                }
            }
        }
    }
}

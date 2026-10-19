pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.config
import qs.services

// Wallpaper unter Hyprland (unter Plasma malt plasmashell das Wallpaper, dort bleibt das hier aus).
// Gleiche Bilder wie unter Plasma: scripts/wallpaper legt ein Set links/mitte/rechts in einen Ordner und
// trägt das Mittelbild als Lockscreen-Bild in kscreenlockerrc ein – daraus kommt der Ordner.
// Zuordnung wie scripts/wallpaper set: links/rechts nach Lage, der 1440p-Monitor bekommt immer „mitte“.
Scope {
    id: root

    readonly property var files: ({
            links: "desktop-links-1920x1080.jpg",
            mitte: "desktop-mitte-2560x1440.jpg",
            rechts: "desktop-rechts-1920x1080.jpg"
        })
    property string dir: Quickshell.env("HOME") + "/.local/share/wallpapers/desktop"

    function role(screen): string {
        if (!screen)
            return "mitte";
        if (screen.width >= 2560)
            return "mitte";
        const xs = Quickshell.screens.map(s => s.x).sort((a, b) => a - b);
        const i = xs.indexOf(screen.x);
        return i === 0 ? "links" : i === xs.length - 1 ? "rechts" : "mitte";
    }

    FileView {
        path: Quickshell.env("HOME") + "/.config/kscreenlockerrc"
        printErrors: false
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            let group = "";
            for (const line of text().split("\n")) {
                if (line.startsWith("["))
                    group = line.trim();
                else if (group === "[Greeter][Wallpaper][org.kde.image][General]" && line.startsWith("Image=")) {
                    const p = line.slice(6).trim().replace(/^file:\/\//, "");
                    if (p.includes("/"))
                        root.dir = p.slice(0, p.lastIndexOf("/"));
                }
            }
        }
    }

    Variants {
        model: Hypr.running ? Quickshell.screens : []

        PanelWindow {
            id: win

            required property var modelData

            screen: modelData
            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }
            exclusionMode: ExclusionMode.Ignore
            color: Theme.bg
            WlrLayershell.namespace: "desktop-wallpaper"
            WlrLayershell.layer: WlrLayer.Background
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

            Image {
                anchors.fill: parent
                source: "file://" + root.dir + "/" + root.files[root.role(win.modelData)]
                fillMode: Image.PreserveAspectCrop
                sourceSize.width: win.width
                sourceSize.height: win.height
                asynchronous: true
                smooth: true
                // weich einblenden, wenn ein neues Set kommt
                opacity: status === Image.Ready ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: Theme.fade } }
            }
        }
    }
}

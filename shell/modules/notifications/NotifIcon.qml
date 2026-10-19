import QtQuick
import Quickshell
import qs.config
import qs.services
import qs.components

// Einheitliche Icon-Kachel für Benachrichtigungen (Popups + Dashboard-Verlauf).
// Immer dieselbe deckende Kachel; Symbol und Ton kommen aus NotifIcons (shell/config/notif-icons.json).
// Echtes App-Icon/Avatar nur bei Arten mit appIcon und nur, wenn es wirklich geladen wird – sonst das Symbol.
Rectangle {
    id: root

    property string kind: ""
    property string image: ""      // Bild der Meldung (z. B. Avatar), nur Arten mit appIcon
    property string appIcon: ""    // Icon-Name oder Pfad der App
    property string desktop: ""    // desktop-entry, falls kein Icon mitkam
    property int size: 36

    readonly property var st: NotifIcons.style(kind)
    readonly property string iconName: {
        if (appIcon)
            return appIcon;
        const e = desktop ? DesktopEntries.heuristicLookup(desktop) : null;
        return e ? (e.icon || "") : "";
    }
    readonly property string src: {
        if (!st.appIcon)
            return "";
        if (image && !image.startsWith("image://icon/"))
            return image;
        if (!iconName)
            return "";
        return iconName.startsWith("/") ? "file://" + iconName : Quickshell.iconPath(iconName, true);
    }

    width: size
    height: size
    radius: Math.round(size * 0.28)
    color: st.bg

    Image {
        id: pic
        anchors.centerIn: parent
        width: Math.round(root.size * 0.62)
        height: width
        sourceSize: Qt.size(width * 2, width * 2)
        fillMode: Image.PreserveAspectFit
        asynchronous: true
        source: root.src
        visible: status === Image.Ready
    }
    Icon {
        anchors.centerIn: parent
        visible: !pic.visible
        name: root.st.icon
        size: Math.round(root.size * 0.56)
        color: root.st.fg
    }
}

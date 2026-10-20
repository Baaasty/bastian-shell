import QtQuick
import Quickshell
import qs.config
import qs.services
import qs.components

// Update-Chip in der Bar: nur sichtbar, wenn dnf- oder Flatpak-Updates da sind (Updates.qml prüft alle 4 h im Hintergrund).
// Links-Klick öffnet den Paketmanager auf dem Reiter „Updates“ (dort installiert man selbst), Rechts-Klick prüft sofort neu.
// IPC: qs ipc call updates status|check|refresh|open|fake <n>   Doku: docs/knowledge/shell-features.md
Chip {
    id: chip
    hintKey: BarKeys.keyFor("updates")   // Bar-Modus (Super+Leertaste)

    visible: Updates.count > 0
    padding: 8
    onClicked: mouse => {
        if (mouse.button === Qt.RightButton)
            Updates.check(false);
        else
            Updates.openManager();
    }

    Row {
        anchors.verticalCenter: parent.verticalCenter
        spacing: 5
        Icon {
            anchors.verticalCenter: parent.verticalCenter
            name: Updates.checking ? "sync" : "system_update_alt"
            size: 18
            color: Theme.accentText
        }
        MonoTxt {
            anchors.verticalCenter: parent.verticalCenter
            text: Updates.count > 99 ? "99+" : Updates.count
            color: Theme.textMuted
            font.pixelSize: 12
        }
    }
}

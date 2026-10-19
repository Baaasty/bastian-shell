import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.UPower
import qs.config
import qs.services
import qs.components

// Status (klein, ruhig): nur, was nicht in die Bar passt – Updates, Speicherplatz, iCloud, Maus-Akku, Bildschirmzeit, Hörzeit.
// CPU/RAM/GPU/Netz + Prozesse leben im Ressourcen-Chip der Bar (ResourcesPopout); hier läuft kein Poller mehr dafür.
// Die Hörzeit hält zugleich den Stats-Dienst am Leben (er zählt Hören/Calls für „Wrapped“).
Tile {
    id: tile

    title: "Status"

    // Logitech-Maus über UPower (HID++)
    readonly property var mouse: UPower.devices.values.find(d => d.type === UPowerDeviceType.Mouse) || null
    readonly property int mousePct: !mouse ? -1 : Math.round(mouse.percentage > 1 ? mouse.percentage : mouse.percentage * 100)
    readonly property int updates: Status.dnfUpdates + Status.flatpakUpdates

    // eine Zeile: Symbol · Name · Wert rechts; warn = Amber/Rot-Wert; klickbar -> Hover + Hand
    component Line: Rectangle {
        id: line
        property string icon
        property string name
        property string value
        property bool warn: false
        property color tone: Theme.warning
        property bool clickable: false
        signal clicked

        Layout.fillWidth: true
        Layout.fillHeight: true
        radius: Theme.radiusSm
        color: hover.containsMouse && clickable ? Theme.raise : "transparent"
        Behavior on color { ColorAnimation { duration: Theme.fade } }

        Icon {
            id: ico
            x: 10
            anchors.verticalCenter: parent.verticalCenter
            name: line.icon
            size: 20
            color: line.warn ? line.tone : Theme.textMuted
        }
        Txt {
            anchors.left: ico.right
            anchors.leftMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            text: line.name
            color: Theme.textMuted
            font.pixelSize: 13
            font.weight: Font.Normal
        }
        MonoTxt {
            anchors.right: parent.right
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            text: line.value
            color: line.warn ? line.tone : Theme.text
            font.pixelSize: 13
        }
        MouseArea {
            id: hover
            anchors.fill: parent
            enabled: line.clickable
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: line.clicked()
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 2

        Line {
            icon: "system_update_alt"
            name: "Updates"
            value: Status.dnfUpdates < 0 ? "…" : tile.updates === 0 ? "up to date" : String(tile.updates)
            warn: Status.dnfUpdates >= 0 && tile.updates > 0
            tone: Theme.warning
            // Discover macht dnf + Flatpak, fragt selbst nach dem Passwort
            clickable: true
            onClicked: {
                Status.updatesAt = 0;   // beim nächsten Öffnen neu zählen
                Launch.cmd(["plasma-discover", "--mode", "update"]);
            }
        }
        Line {
            icon: "hard_drive"
            name: "System"
            value: Status.fmtGb(Status.rootFreeGb) + " free"
            warn: Status.rootFreeGb > 0 && Status.rootFreeGb < 30
            clickable: true
            onClicked: Status.openFolder(Quickshell.env("HOME"))
        }
        Line {
            icon: "database"
            name: "Data"
            value: Status.fmtGb(Status.dataFreeGb) + " free"
            warn: Status.dataFreeGb > 0 && Status.dataFreeGb < 100
            clickable: true
            onClicked: Status.openFolder(Quickshell.env("HOME") + "/Data")
        }
        Line {
            icon: Status.icloudFailed ? "cloud_off" : "cloud_done"
            name: "iCloud"
            value: Status.icloudFailed ? "error" : (Status.icloudTime ? "synced " + Status.icloudTime : "ok")
            warn: Status.icloudFailed
            tone: Theme.error
            clickable: true
            onClicked: Status.openFolder(Quickshell.env("HOME") + "/Data/iCloud/Drive")
        }
        Line {
            icon: tile.mousePct >= 0 && tile.mousePct <= 20 ? "battery_alert" : "mouse"
            name: "Mouse"
            value: tile.mousePct < 0 ? "–" : tile.mousePct + "%"
            warn: tile.mousePct >= 0 && tile.mousePct <= 20
            tone: tile.mousePct <= 10 ? Theme.error : Theme.warning
        }
        // Bildschirmzeit heute (ohne Leerlauf, aus dem Fokus-Modul)
        Line {
            icon: "desktop_windows"
            name: "Screen time"
            value: Math.floor(Focus.screenMin / 60) + " h " + (Focus.screenMin % 60) + " min"
        }
        Line {
            icon: "headphones"
            name: "Listening"
            value: Stats.loaded ? Stats.fmtDur(Stats.listenToday) : "–"
        }
    }
}

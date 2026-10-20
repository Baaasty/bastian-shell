import QtQuick
import qs.config
import qs.components

// Listenzeile: Icon-/Buchstaben-Kachel · Titel · Benutzer + Domain · 2FA-Symbol
Rectangle {
    id: row

    required property var pw
    required property var modelData
    required property int index
    readonly property bool selected: pw.sel === index
    readonly property string domain: pw.domainOf(modelData)

    height: 54
    radius: Theme.radiusMd
    color: selected ? Theme.accentSoft : area.containsMouse ? Theme.raise : "transparent"
    border.width: selected ? 1 : 0
    border.color: Qt.alpha(Theme.accent, 0.35)
    Behavior on color { ColorAnimation { duration: Theme.fade } }

    FavIcon {
        id: badge
        anchors.left: parent.left
        anchors.leftMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        width: 34
        height: 34
        title: row.modelData.title
        domain: row.domain
        selected: row.selected
    }

    Column {
        anchors.left: badge.right
        anchors.leftMargin: 12
        anchors.right: icons.left
        anchors.rightMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        spacing: 2
        Txt {
            width: parent.width
            text: row.modelData.title
            font.pixelSize: 14
            color: Theme.text
        }
        Txt {
            width: parent.width
            text: [row.modelData.user, row.domain].filter(x => x).join("  ·  ") || "—"
            font.pixelSize: 12
            font.weight: Font.Normal
            color: Theme.textFaint
        }
    }

    Row {
        id: icons
        z: 1
        anchors.right: parent.right
        anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        spacing: 6
        // Änderung wird gerade im Hintergrund nach iCloud gespeichert
        Icon {
            visible: !!row.modelData.saving
            name: "cloud_sync"
            size: 16
            color: Theme.accentText
        }
        // aus einer geteilten Passwort-Gruppe (Name steht in den Details)
        Icon {
            visible: !!row.modelData.group
            name: "group"
            size: 16
            color: Theme.textFaint
        }
        Icon {
            visible: row.modelData.hasTotp
            name: "lock_clock"
            size: 17
            color: row.selected ? Theme.accentText : Theme.woodLight
        }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            row.pw.sel = row.index;
            row.ListView.view.focusSearch();
        }
        onDoubleClicked: row.pw.copy("password")
    }
}

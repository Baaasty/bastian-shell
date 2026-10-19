import QtQuick
import qs.config
import qs.components

// Kleiner Aktionsknopf für Listenzeilen: neutral | accent | danger. Ohne Text = quadratischer Icon-Knopf.
Rectangle {
    id: b

    property string text
    property string icon
    property string tone: "neutral"
    readonly property color fg: tone === "accent" ? Theme.accentText : tone === "danger" ? Theme.error : Theme.text
    signal clicked()

    implicitWidth: text ? row.implicitWidth + 24 : 30
    implicitHeight: 30
    radius: Theme.radiusSm
    opacity: enabled ? 1 : 0.4
    color: {
        const h = area.containsMouse && enabled;
        if (tone === "accent")
            return h ? Qt.alpha(Theme.accent, 0.28) : Theme.accentSoft;
        if (tone === "danger")
            return h ? Qt.alpha(Theme.error, 0.24) : Qt.alpha(Theme.error, 0.10);
        return h ? Qt.alpha(Theme.text, 0.12) : Theme.raise;
    }
    border.width: 1
    border.color: tone === "accent" ? Qt.alpha(Theme.accent, 0.5) : tone === "danger" ? Qt.alpha(Theme.error, 0.4) : Theme.border
    Behavior on color { ColorAnimation { duration: Theme.fade } }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 6
        Icon {
            anchors.verticalCenter: parent.verticalCenter
            visible: b.icon !== ""
            name: b.icon
            size: 16
            color: b.fg
        }
        Txt {
            anchors.verticalCenter: parent.verticalCenter
            visible: b.text !== ""
            text: b.text
            color: b.fg
            font.pixelSize: 12
        }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: b.clicked()
    }
}

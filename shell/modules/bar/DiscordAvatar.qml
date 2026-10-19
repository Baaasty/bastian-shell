import QtQuick
import Quickshell.Widgets
import qs.config
import qs.services
import qs.components

// Rundes Discord-Avatar mit grünem Sprech-Ring (Initialen, solange das Bild lädt oder fehlt).
// edge: Farbe des schmalen Rands um das Bild – beim Überlappen in der Bar trennt er die Köpfe.
Item {
    id: av

    property var member: ({})
    property int size: 26
    property color edge: "transparent"
    // Sprech-Ring weich einblenden? In der Bar aus (DiscordChip): dort wechselt „spricht“ im Call
    // mehrmals pro Sekunde, und jede 150-ms-Blende zeichnet die ganze Bar mit 360 Hz neu
    property bool fade: true
    readonly property bool speaking: member && member.speaking === true
    // Kamera an (nur mit Equicord-Plugin desktopBridge): kleiner Punkt unten rechts, gefüllt = im Kamera-Overlay zu sehen
    property bool badge: false
    // nicht am eigenen Kopf (Bastian will dort kein Symbol; der eigene Status steht im Popout)
    readonly property bool camera: badge && Cams.connected && member && (member.video === true || member.stream === true) && member.isSelf !== true
    readonly property bool pinned: camera && Cams.isPinned(member.id)

    implicitWidth: size + 6
    implicitHeight: size + 6

    function initials(name: string): string {
        const p = (name || "?").trim().split(/\s+/);
        return (p.length > 1 ? p[0][0] + p[1][0] : (p[0] || "?").slice(0, 2)).toUpperCase();
    }

    // Ring außen (2 px) – grün beim Sprechen, sonst Trennrand
    Rectangle {
        anchors.fill: parent
        radius: width / 2
        color: av.edge
        border.width: 2
        border.color: av.speaking ? Theme.success : av.edge
        Behavior on border.color {
            enabled: av.fade
            ColorAnimation { duration: Theme.fade }
        }
    }

    ClippingRectangle {
        anchors.centerIn: parent
        width: av.size
        height: av.size
        radius: av.size / 2
        color: Theme.wood

        Txt {
            anchors.centerIn: parent
            text: av.initials(av.member ? av.member.name : "")
            font.pixelSize: Math.max(8, Math.round(av.size * 0.38))
            font.weight: Font.DemiBold
            visible: img.status !== Image.Ready
        }
        Image {
            id: img
            anchors.fill: parent
            source: (av.member && av.member.avatarUrl) || ""
            sourceSize.width: av.size * 2
            sourceSize.height: av.size * 2
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: true
        }
    }

    // Kamera-Punkt
    Rectangle {
        visible: av.camera
        x: av.width - width - 1
        y: av.height - height - 1
        width: Math.max(9, Math.round(av.size * 0.42))
        height: width
        radius: width / 2
        color: av.pinned ? Theme.accent : Theme.surfaceRaised
        border.width: 1
        border.color: av.edge.a > 0 ? av.edge : Theme.bg

        Icon {
            anchors.centerIn: parent
            name: av.member && av.member.video === true ? "videocam" : "screen_share"
            fill: true
            size: Math.max(6, parent.width - 4)
            color: av.pinned ? Theme.onAccent : Theme.textMuted
        }
    }
}

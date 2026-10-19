import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.services
import qs.components

// Privatsphäre-Punkte in der Bar: je ein kleines Symbol, solange Mikrofon (amber), Kamera (rot/Terrakotta) oder Bildschirmfreigabe (Akzent)
// in Benutzung ist. Nichts aktiv = unsichtbar und ohne Platz. Hovern zeigt, welche App (Tooltip). Daten: Privacy.qml. Doku: docs/knowledge/shell-features.md
Row {
    id: dots

    property var barWindow: QsWindow.window

    spacing: 4
    visible: Privacy.any

    component Dot: Rectangle {
        id: dot
        property string glyph
        property string title
        property var apps: []
        property color tone: Theme.warning
        visible: apps.length > 0
        width: visible ? 28 : 0
        height: 28
        radius: 14
        color: Theme.flat(Qt.alpha(tone, 0.22))

        Icon {
            anchors.centerIn: parent
            name: dot.glyph
            fill: true
            size: 16
            color: dot.tone
        }
        HoverHandler {
            id: hover
            cursorShape: Qt.ArrowCursor
        }

        // Tooltip: kleines Fenster unter dem Punkt (nur beim Hovern)
        PopupWindow {
            id: tip
            anchor.window: dots.barWindow
            anchor.edges: Edges.Bottom
            anchor.gravity: Edges.Bottom
            implicitWidth: tipCard.width + 8
            implicitHeight: tipCard.height + 8
            color: "transparent"
            visible: hover.hovered && dot.visible && !!dots.barWindow
            mask: Region { item: tipCard }

            onVisibleChanged: if (visible) place()
            function place(): void {
                const p = dot.mapToItem(null, dot.width / 2, 0);
                anchor.rect.x = Math.round(p.x);
                anchor.rect.y = Theme.barMargin + Theme.barHeight + 4;
                anchor.rect.width = 1;
                anchor.rect.height = 1;
            }

            BackgroundEffect.blurRegion: Region {
                Region { x: 0; y: 0; width: 1; height: 1 }
            }

            Glass {
                id: tipCard
                x: 4
                y: 4
                width: tipTxt.implicitWidth + 28
                height: 34
                radius: Theme.radiusMd
                strong: true
                Txt {
                    id: tipTxt
                    anchors.centerIn: parent
                    text: dot.title + ": " + dot.apps.join(", ")
                    font.pixelSize: 13
                    font.weight: Font.Normal
                    elide: Text.ElideNone
                }
            }
        }
    }

    Dot {
        anchors.verticalCenter: parent.verticalCenter
        glyph: "mic"
        title: "Microphone in use"
        apps: Privacy.mics
        tone: Theme.warning
    }
    Dot {
        anchors.verticalCenter: parent.verticalCenter
        glyph: "videocam"
        title: "Camera in use"
        apps: Privacy.cams
        tone: Theme.error
    }
    Dot {
        anchors.verticalCenter: parent.verticalCenter
        glyph: "screen_share"
        title: "Sharing your screen"
        apps: Privacy.shares
        tone: Theme.accent
    }
}

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config

// Tooltip unter einem Bar-Chip (Chip.tip): kleines deckendes Fenster, erst nach kurzem Verweilen.
// Nimmt keine Eingaben an (leere Maske) – sonst könnte es Hover/Klicks der Bar oder eines Popouts stören.
PopupWindow {
    id: tip

    property Item chip
    property string text: ""

    anchor.window: chip ? chip.hostWindow : null
    anchor.edges: Edges.Bottom
    anchor.gravity: Edges.Bottom
    implicitWidth: card.width + 8
    implicitHeight: card.height + 8
    color: "transparent"
    visible: false
    mask: Region {}

    // ruhig: erst nach 600 ms Verweilen, nicht schon beim Drüberwischen
    Timer {
        interval: 600
        running: !!tip.chip && tip.text !== ""
        onTriggered: {
            tip.place();
            tip.visible = true;
        }
    }
    function place(): void {
        const p = chip.mapToItem(null, chip.width / 2, 0);
        anchor.rect.x = Math.round(p.x);
        anchor.rect.y = Theme.barMargin + Theme.barHeight + 4;
        anchor.rect.width = 1;
        anchor.rect.height = 1;
    }

    BackgroundEffect.blurRegion: Region {
        Region { x: 0; y: 0; width: 1; height: 1 }
    }

    Glass {
        id: card
        x: 4
        y: 4
        width: tipTxt.implicitWidth + 24
        height: 30
        radius: Theme.radiusMd
        strong: true
        Txt {
            id: tipTxt
            anchors.centerIn: parent
            text: tip.text
            font.pixelSize: 12
            font.weight: Font.Normal
            elide: Text.ElideNone
        }
    }
}

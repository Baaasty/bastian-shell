import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config

// Tooltip unter einem Bar-Chip (Chip.tip): kleines deckendes Fenster mit der gemeinsamen Hinweis-Karte (KeyTip).
// Beim Hovern erst nach kurzem Verweilen, am im Bar-Modus gewählten Chip sofort (delay 0).
// Nimmt keine Eingaben an (leere Maske) – sonst könnte es Hover/Klicks der Bar oder eines Popouts stören.
PopupWindow {
    id: tip

    property Item chip
    property string text: ""
    // ruhig: erst nach 600 ms Verweilen, nicht schon beim Drüberwischen
    property int delay: 600

    anchor.window: chip ? chip.hostWindow : null
    anchor.edges: Edges.Bottom
    anchor.gravity: Edges.Bottom
    implicitWidth: card.width + 8
    implicitHeight: card.height + 8
    color: "transparent"
    visible: false
    mask: Region {}

    Timer {
        interval: tip.delay
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

    KeyTip {
        id: card
        x: 4
        y: 4
        text: tip.text
    }
}

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.services
import qs.components

// Licht-Popout unter dem Licht-Chip (Klick öffnet, Klick daneben / Esc schließt, offen bis zum Weghovern).
// Inhalt = Licht-Teil der Dashboard-Kachel „Light & Sound“ (gemeinsame Komponente components/LightPanel.qml):
// Key Light, Hue-Szenen mit Farbwähler und Kontextmenüs, Kamera-Belichtung. Abfragen laufen nur, solange es offen ist.
PopupWindow {
    id: pop

    property var barWindow
    property Item chip
    readonly property int cardW: 620
    readonly property int maxCardH: 420
    property real appear: 0
    property real _closedAt: 0
    // für IPC (Test: Farbwähler auf/zu)
    property alias panel: light

    anchor.window: barWindow
    anchor.edges: Edges.Bottom | Edges.Right
    anchor.gravity: Edges.Bottom | Edges.Left
    grabFocus: true
    implicitWidth: cardW
    implicitHeight: maxCardH + 8
    color: "transparent"
    visible: false
    mask: Region { item: card }

    // ---------- Öffnen / Schließen ----------
    function placeUnderBar(): void {
        if (!chip)
            return;
        anchor.rect.x = Math.round(chip.mapToItem(null, chip.width, 0).x) - 1;
        anchor.rect.y = Theme.barMargin + Theme.barHeight + Theme.windowGap - 1;
        anchor.rect.width = 1;
        anchor.rect.height = 1;
    }
    function open(): void {
        openWith(true);
    }
    // grab = false nur für den IPC-Test (ohne vorherigen Klick lässt der Compositor keinen Klick-Fang zu)
    function openWith(grab: bool): void {
        if (visible)
            return;
        grabFocus = grab;
        placeUnderBar();
        appear = 0;
        visible = true;
        appearAnim.restart();
    }
    function close(): void {
        guard.intended = true;
        visible = false;
    }
    // Klick auf den Chip bei offenem Popout: der Compositor schließt es schon beim Drücken, der Klick soll es nicht gleich wieder öffnen
    function toggle(): void {
        if (visible || Date.now() - _closedAt < 400)
            close();
        else
            open();
    }

    onVisibleChanged: {
        if (barWindow && barWindow.openMenus !== undefined)
            barWindow.openMenus += visible ? 1 : -1;
        if (visible) {
            Popouts.claim("light");
            keys.forceActiveFocus();
        } else {
            Popouts.release("light");
            _closedAt = Date.now();
            appearAnim.stop();
        }
    }
    // nur ein Bar-Popout gleichzeitig
    Connections {
        target: Popouts
        function onCurrentChanged() {
            if (Popouts.current !== "light" && pop.visible)
                pop.visible = false;
        }
    }
    NumberAnimation {
        id: appearAnim
        target: pop
        property: "appear"
        from: 0
        to: 1
        duration: Theme.fade
        easing.type: Easing.OutCubic
    }

    BackgroundEffect.blurRegion: Region {
        Region { x: 0; y: 0; width: 1; height: 1 }
        Region { item: pop.appear > 0.4 ? card : null; radius: Theme.radiusLg }
    }

    // ---------- Karte ----------
    Glass {
        id: card
        // offen bis zum Weghovern (PopoutGuard.qml)
        PopoutGuard { id: guard; popout: pop; chip: pop.chip; name: "light" }
        // Tastatur: Pfeile/Tab/Enter, Bar-Modus „L“ (KeyNav.qml)
        Keys.onPressed: e => nav.key(e)
        KeyNav { id: nav; root: card; scope: keys; popout: pop; guard: guard; name: "light" }
        width: pop.cardW
        height: light.y + light.height + 20
        strong: true
        opacity: pop.appear
        transform: Translate { y: (1 - pop.appear) * -6 }

        FocusScope {
            id: keys
            anchors.fill: parent
            // Esc: erst Menü/Farbwähler zu, dann das Popout
            Keys.onEscapePressed: {
                if (light.menuKind !== "")
                    light.menuKind = "";
                else if (light.pickerOpen)
                    light.pickerOpen = false;
                else
                    pop.close();
            }
        }

        Row {
            id: head
            x: 20
            y: 18
            height: Theme.iconButton
            PopoutTitle {
                anchors.verticalCenter: parent.verticalCenter
                icon: "lightbulb"
                text: "Light"
            }
        }

        // Key Light, Hue, Kamera – wie in der Dashboard-Kachel; der Farbwähler schiebt die Karte nach unten auf
        LightPanel {
            id: light
            x: 20
            y: head.y + head.height + 14
            width: card.width - 40
            height: implicitHeight
            rowSpacing: 12
            pickerRoom: 140
            catchArea: card
        }
    }
}

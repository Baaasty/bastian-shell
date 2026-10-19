import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.components

// Angepinntes Referenz-Bild: kleines Fenster mit deckendem Rahmen, immer über allem.
// Ziehen = verschieben · Mausrad = Größe · Rechtsklick/Esc/× = schließen · Mittelklick = Originalgröße.
// Das Bild liegt nur in $XDG_RUNTIME_DIR (RAM); Snip.qml löscht die Datei beim Schließen.
PanelWindow {
    id: win

    property string path: ""
    property real natW: 100        // Größe des Ausschnitts in logischen Pixeln
    property real natH: 100
    property real startX: 0        // Position auf dem Monitor beim Anpinnen
    property real startY: 0
    property real startZoom: 1
    signal unpinRequested

    readonly property int pad: 5
    property real zoom: startZoom
    property real posX: startX
    property real posY: startY

    function close(): void {
        unpinRequested();
    }

    anchors {
        top: true
        left: true
    }
    margins.left: Math.round(posX)
    margins.top: Math.round(posY)
    implicitWidth: Math.round(natW * zoom) + 2 * pad
    implicitHeight: Math.round(natH * zoom) + 2 * pad
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.namespace: "dock" // "dock": ohne Öffnen-Animation (Hyprland: layerrule noanim)
    WlrLayershell.layer: WlrLayer.Overlay
    // nur auf Klick Tastatur (Esc), sonst nie Fokus stehlen
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

    Rectangle {
        anchors.fill: parent
        radius: Theme.radiusSm
        color: Theme.surface
        border.width: 2
        border.color: area.pressed ? Theme.accent : Theme.woodLight
    }
    Image {
        anchors.fill: parent
        anchors.margins: win.pad
        source: win.path ? "file://" + win.path : ""
        fillMode: Image.Stretch
        smooth: true
        mipmap: true
        cache: false
    }

    // schließen-Knopf, nur beim Darüberfahren
    Rectangle {
        visible: area.containsMouse || closeArea.containsMouse
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: win.pad + 4
        width: 24
        height: 24
        radius: 12
        color: closeArea.containsMouse ? Theme.accent : Theme.surfaceRaised
        border.width: 1
        border.color: Theme.borderStrong
        Icon {
            anchors.centerIn: parent
            name: "close"
            size: 16
            color: closeArea.containsMouse ? Theme.onAccent : Theme.text
        }
        MouseArea {
            id: closeArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: win.close()
        }
    }

    Item {
        anchors.fill: parent
        focus: true
        Keys.onEscapePressed: win.close()
    }

    MouseArea {
        id: area
        z: -1
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
        property real gx: 0
        property real gy: 0
        onPressed: mouse => {
            if (mouse.button === Qt.RightButton) {
                win.close();
                return;
            }
            if (mouse.button === Qt.MiddleButton) {
                win.zoom = 1;
                return;
            }
            gx = mouse.x;
            gy = mouse.y;
        }
        onPositionChanged: mouse => {
            if (!pressed || !(mouse.buttons & Qt.LeftButton))
                return;
            win.posX += mouse.x - gx;
            win.posY += mouse.y - gy;
        }
        onWheel: wheel => {
            const f = wheel.angleDelta.y > 0 ? 1.1 : 1 / 1.1;
            const sw = win.screen ? win.screen.width : 1920, sh = win.screen ? win.screen.height : 1080;
            // nicht kleiner als 48 px, nicht größer als der Monitor
            const lo = Math.max(48 / win.natW, 48 / win.natH);
            const hi = Math.min(sw / win.natW, sh / win.natH);
            const z = Math.max(Math.min(lo, hi), Math.min(hi, win.zoom * f));
            // Punkt unter der Maus bleibt stehen
            const r = z / win.zoom;
            win.posX += (wheel.x - win.pad) * (1 - r);
            win.posY += (wheel.y - win.pad) * (1 - r);
            win.zoom = z;
        }
    }
}

import QtQuick

// Mausrad-Scrollen, das sich nicht zäh anfühlt: pro Raste ein fester Weg, weich animiert.
// Ins Eltern-Item der Liste legen und bei der Liste "interactive: false" setzen
// (sonst schluckt die Liste das Rad selbst).
WheelHandler {
    id: wh

    required property Flickable flick
    property real step: 140   // px pro Raste

    target: null
    acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad

    onWheel: event => {
        const f = flick;
        if (!f || f.contentHeight <= f.height)
            return;
        const min = f.originY;
        const max = f.originY + f.contentHeight - f.height;
        // Touchpad liefert Pixel (direkt folgen), Mausrad Rasten (animiert)
        if (event.pixelDelta.y !== 0) {
            anim.stop();
            f.contentY = Math.max(min, Math.min(max, f.contentY - event.pixelDelta.y));
            return;
        }
        const from = anim.running ? anim.to : f.contentY;
        anim.stop();
        anim.from = f.contentY;
        anim.to = Math.max(min, Math.min(max, from - event.angleDelta.y / 120 * step));
        anim.start();
    }

    property NumberAnimation anim: NumberAnimation {
        target: wh.flick
        property: "contentY"
        duration: 160
        easing.type: Easing.OutCubic
    }
}

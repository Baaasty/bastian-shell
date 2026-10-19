import QtQuick
import qs.config
import qs.services
import qs.components

// Hintergrund-App (Spotify/Discord) nach vorn holen bzw. wieder wegräumen – wie im Bar-Popout.
// Nach vorn holen öffnet ein Fenster -> Dashboard geht zu (Launch.launched).
Chip {
    id: btn

    property string part        // "spotify" | "discord"
    readonly property bool isOut: Parked.out[part] === true

    padding: 6
    active: isOut
    onClicked: {
        const wasOut = isOut;
        Parked.toggle(part);
        if (!wasOut)
            Launch.launched();
    }

    Icon {
        anchors.verticalCenter: parent.verticalCenter
        name: btn.isOut ? "close_fullscreen" : "open_in_new"
        size: 16
        color: btn.hovered || btn.isOut ? Theme.text : Theme.textMuted
    }
}

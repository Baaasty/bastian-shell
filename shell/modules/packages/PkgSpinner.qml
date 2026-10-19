import QtQuick
import qs.config
import qs.components

// Drehendes Lade-Symbol
Icon {
    id: sp
    property bool spinning: true

    name: "progress_activity"
    size: 18
    color: Theme.accentText
    RotationAnimator on rotation {
        running: sp.spinning && sp.visible
        from: 0
        to: 360
        duration: 900
        loops: Animation.Infinite
    }
}

import QtQuick
import qs.config

// Fläche: deckend, 1-px-Rand, ruhiger harter Schatten (ein Rechteck, kein Blur, kein Leuchten).
// Mit Theme.blurEnabled (nur ältere Varianten) sind Töne wieder durchsichtig; der Blur selbst kommt vom Compositor
// über BackgroundEffect.blurRegion in den Modulen (hypr/look.conf: decoration.blur.enabled folgt dem Flag).
// strong = eine Stufe heller (Bar, Leisten, dringende Popups). shadow:false für Flächen ohne Schatten.
Rectangle {
    property bool strong: false
    property bool shadow: true

    color: strong ? Theme.glassStrong : Theme.glass
    radius: Theme.radiusLg
    border.width: 1
    border.color: Theme.border

    // Schatten: eine einzige, gleich runde Kopie 2 px tiefer (z < 0) – gibt eine klare Unterkante statt verschmierter Ecken.
    // Das Fenster schneidet ihn dort ab, wo kein Platz ist
    Rectangle {
        visible: parent.shadow && Theme.shadow.a > 0
        z: -1
        y: 2
        width: parent.width
        height: parent.height
        radius: parent.radius
        color: Qt.alpha(Theme.shadow, Theme.shadow.a * 0.6)
    }
}

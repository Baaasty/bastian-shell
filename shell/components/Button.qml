import QtQuick
import qs.config

// Der eine Knopf der Shell (Design-System light). Art über kind (oder kurz primary: true):
//   primary   – volle Glut, onAccent-Text: die Hauptaktion (Enter), höchstens einer pro Fläche
//   secondary – deckend surfaceRaised mit Rand (Standard)
//   on        – gewählter Umschalter / laufende Sache: accentFill, Text accentText, ohne Rand
//   ghost     – nur Text, Fläche erst beim Hover
//   danger    – zerstörend: Rand und Text in error
// small = 32 statt 36 px (Popouts, Zeilen). compact = wenig Polster + kleine Schrift für gleich breite Knopfreihen
// (Discord-Steuerung), Höhe bleibt. Ohne text = quadratischer Symbolknopf (iconButton).
// focused = Tastatur-Markierung (KeyNav u. a.): 2 px Glut-Rahmen, wie jede Auswahl
Rectangle {
    id: btn

    property string text
    property string icon
    property bool primary: false
    property string kind: primary ? "primary" : "secondary"
    property bool small: false
    property bool compact: false
    property bool focused: false
    property color iconColor: fg
    property bool iconFill: false
    readonly property alias hovered: btnArea.containsMouse
    readonly property alias pressed: btnArea.pressed
    // die klickbare Fläche (KeyNav markiert sie; Popouts vergleichen nav.current === knopf.area)
    readonly property Item area: btnArea
    signal clicked()

    readonly property bool iconOnly: text === "" && icon !== ""
    readonly property color fg: kind === "primary" ? Theme.onAccent
        : kind === "on" ? Theme.accentText
        : kind === "danger" ? Theme.error
        : kind === "ghost" && !btnArea.containsMouse ? Theme.textMuted : Theme.text

    implicitHeight: small ? Theme.buttonHeightSm : Theme.buttonHeight
    readonly property int pad: compact ? Theme.space2 : small ? Theme.space3 : Theme.space4
    readonly property int gap: compact ? Theme.space1 : Theme.space2
    readonly property real iconPart: icon !== "" ? Theme.iconSize + (text !== "" ? gap : 0) : 0
    // natürliche Breite aus implicitWidth des Texts (nicht aus der Row), sonst schaukeln sich Text- und Knopfbreite auf
    implicitWidth: iconOnly ? implicitHeight : iconPart + label.implicitWidth + 2 * pad
    radius: small ? Theme.radiusSm : Theme.radiusMd
    opacity: enabled ? 1 : 0.5
    color: {
        switch (kind) {
        case "primary":
            return btnArea.pressed ? Theme.accentPressed : btnArea.containsMouse ? Theme.accentHover : Theme.accent;
        case "on":
            return Theme.accentFill;
        case "ghost":
            return btnArea.containsMouse ? Theme.surfaceRaised : "transparent";
        default:
            return btnArea.pressed ? Theme.surfaceSunken : btnArea.containsMouse ? Qt.lighter(Theme.surfaceRaised, 1.12) : Theme.surfaceRaised;
        }
    }
    border.width: focused ? 2 : (kind === "secondary" || kind === "danger") ? 1 : 0
    border.color: focused ? Theme.accent
        : kind === "danger" ? Qt.alpha(Theme.error, 0.5)
        : btnArea.containsMouse ? Theme.borderStrong : Theme.border
    Behavior on color { ColorAnimation { duration: Theme.fade } }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: btn.gap
        Icon {
            anchors.verticalCenter: parent.verticalCenter
            visible: btn.icon !== ""
            name: btn.icon
            size: Theme.iconSize
            fill: btn.iconFill
            color: btn.iconColor
        }
        Txt {
            id: label
            anchors.verticalCenter: parent.verticalCenter
            visible: btn.text !== ""
            // schmaler gesetzter Knopf (feste Breite): Text kürzen statt überlaufen
            width: Math.max(0, Math.min(implicitWidth, btn.width - 2 * btn.pad - btn.iconPart))
            text: btn.text
            color: btn.fg
            font.pixelSize: btn.small || btn.compact ? Theme.fontSm : Theme.fontMd
            font.weight: btn.kind === "primary" ? Font.DemiBold : Font.Medium
        }
    }

    MouseArea {
        id: btnArea
        anchors.fill: parent
        hoverEnabled: true
        enabled: btn.enabled
        cursorShape: Qt.PointingHandCursor
        onClicked: btn.clicked()
    }
}

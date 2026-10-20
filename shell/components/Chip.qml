import QtQuick
import Quickshell
import qs.config
import qs.services

// Klickbarer Bereich in der Bar (30 px hoch); Inhalt kommt als Kinder in die Row
Rectangle {
    id: chip

    property bool active: false
    property alias hovered: area.containsMouse
    property alias pressed: area.pressed
    default property alias content: row.data
    property int padding: 10
    property bool alignLeft: false   // in Menüs: Inhalt linksbündig
    property string hintKey: ""      // Bar-Modus (Super+Leertaste): Buchstabe, der dieses Popout öffnet (BarKeys.qml)
    property string tip: ""          // Tooltip beim Verweilen (ChipTip.qml); leer = Name + Kürzel aus dem Bar-Modus
    property bool _tipOff: false     // nach einem Klick bis zum Verlassen keiner mehr
    // Hover, den ein offenes Popout meldet (PopoutGuard): mit Klick-Fang bekommt unter Hyprland nur das Popout die Maus,
    // die Bar sieht dann kein containsMouse – sonst gäbe es neben einem offenen Popout nie einen Tooltip
    property bool tipHover: false
    readonly property bool _hovered: area.containsMouse || tipHover
    on_HoveredChanged: if (!_hovered) _tipOff = false
    // ohne eigenen Text: „Resources · Super+Alt+R“ aus BarKeys (nur Chips mit Bar-Buchstaben)
    readonly property string tipText: tip !== "" ? tip : BarKeys.tipFor(hintKey)
    signal clicked(var mouse)
    signal doubleClicked(var mouse)

    implicitWidth: row.implicitWidth + padding * 2
    implicitHeight: 30
    radius: Theme.radiusSm
    // aktiv deutlich, Hover leise (beides deckend auf der Fläche darunter)
    color: active ? Qt.alpha(Theme.text, 0.14) : area.containsMouse ? Theme.raise : "transparent"
    Behavior on color { ColorAnimation { duration: Theme.fade } }

    Row {
        id: row
        x: chip.alignLeft ? chip.padding + 4 : (chip.width - width) / 2
        anchors.verticalCenter: parent.verticalCenter
        spacing: 10
    }

    KeyHint {
        key: chip.hintKey
    }

    LazyLoader {
        active: chip.tipText !== "" && chip._hovered && !chip.active && !chip._tipOff && !BarKeys.modeOn
        ChipTip {
            // die eigene Property „chip“ verdeckt hier die id → Chip über die MouseArea holen
            chip: area.parent
            text: area.parent.tipText
        }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        cursorShape: Qt.PointingHandCursor
        onPressed: chip._tipOff = true
        onClicked: mouse => {
            // schon von PopoutGuard ausgelöst (Hyprland hatte den Klick geschluckt) – nicht doppelt
            if (Popouts.synthChip === chip && Date.now() - Popouts.synthAt < 700)
                return;
            chip.clicked(mouse);
        }
        onDoubleClicked: mouse => chip.doubleClicked(mouse)
    }

    // Fenster, in dem der Chip liegt (PopoutGuard: nur Chips der Bar zählen)
    readonly property var hostWindow: QsWindow.window
    Component.onCompleted: Popouts.addChip(chip)
    Component.onDestruction: Popouts.removeChip(chip)
}

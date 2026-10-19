import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components

// Licht & Ton: Key Light, Hue-Szenen, Kamera-Belichtung (gemeinsame Komponente components/LightPanel.qml, auch im Licht-Popout),
// GoXLR (Pegel + Routing: components/GoxlrPanel.qml, auch im Sound-Popout)
Tile {
    id: tile

    title: "Light & Sound"

    ColumnLayout {
        id: rows

        anchors.fill: parent
        // Raster je Zeile: Name (96) · Vorne (44) · Haupt (füllt) · Hinten (backW, rechtsbündig)
        readonly property int backW: 196
        // Zeilen à 30 px gleichmäßig über die ganze Höhe verteilen
        readonly property int count: 4
        spacing: Math.max(4, (height - 3 * 30 - goxlr.implicitHeight) / (count - 1))

        // Licht: Key Light, Hue, Kamera – gemeinsame Komponente mit dem Licht-Popout der Bar
        LightPanel {
            id: light
            Layout.fillWidth: true
            Layout.preferredHeight: implicitHeight
            rowSpacing: rows.spacing
            backW: rows.backW
            // Farbwähler über GoXLR bis zur Unterkante, Klick daneben schließt das Menü auf der ganzen Kachel
            pickerBottom: rows.height
            catchArea: tile
            z: 2
        }

        // GoXLR: Pegel (nur ansehen) + Routing (Lautsprecher, was Discord hört) – gemeinsame Komponente mit dem Sound-Popout
        GoxlrPanel {
            id: goxlr
            Layout.fillWidth: true
            Layout.preferredHeight: implicitHeight
            // Namensspalte so breit wie Name + Vorne der anderen Zeilen (96 + 12 + 44), damit die Chips fluchten
            nameW: 152
            // unter dem Farbwähler ausblenden
            opacity: light.pickerOpen ? 0 : 1
            Behavior on opacity { NumberAnimation { duration: Theme.fade; easing.type: Easing.OutCubic } }
        }

        Item {
            Layout.fillHeight: true
        }
    }
}

import QtQuick
import qs.config
import qs.components

// Passwortfeld wie im Plasma-Paket (MainBlock.qml): Code-Modus = 6 Kästchen wie bei einer Auth-Code-Eingabe,
// beim 6. Zeichen wird geprüft. codeLength 0 = rundes Feld mit Punkten, Auge und Pfeil-Knopf.
// Eingabe kommt nicht von hier, sondern aus Lock.qml (ein Puffer für alle Monitore).
Item {
    id: pw

    required property var ctx
    property bool focused: false   // diese Fläche hat die Tastatur
    property bool showPassword: false

    readonly property int len: ctx.buffer.length
    readonly property bool codeMode: ctx.codeLength > 0

    implicitWidth: codeMode ? ctx.codeLength * 50 - 10 : 288
    implicitHeight: codeMode ? 50 : 52

    // ---- Code-Modus ----
    Row {
        visible: pw.codeMode
        anchors.centerIn: parent
        spacing: 10

        Repeater {
            model: pw.codeMode ? pw.ctx.codeLength : 0

            Rectangle {
                required property int index
                readonly property bool filled: index < pw.len
                readonly property bool current: index === pw.len && pw.focused && !pw.ctx.checking

                width: 40
                height: 50
                radius: 12
                color: Theme.glassStrong
                border.width: current ? 2 : 1
                border.color: current ? Theme.accent : filled ? Theme.woodLight : Theme.borderStrong
                Behavior on border.color { ColorAnimation { duration: 120 } }

                MonoTxt {
                    anchors.centerIn: parent
                    text: !parent.filled ? "" : pw.showPassword ? pw.ctx.buffer.charAt(parent.index) : "•"
                    font.pixelSize: 22
                }
            }
        }
    }

    // ---- freies Feld (codeLength 0) ----
    Rectangle {
        id: field
        visible: !pw.codeMode
        anchors.left: parent.left
        anchors.right: go.left
        anchors.rightMargin: 6
        height: 52
        radius: height / 2
        color: Theme.glassStrong
        border.width: pw.focused ? 2 : 1
        border.color: pw.focused ? Theme.accent : Theme.borderStrong

        Txt {
            anchors.left: parent.left
            anchors.leftMargin: 22
            anchors.right: eye.left
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            text: pw.len === 0 ? "Password" : pw.showPassword ? pw.ctx.buffer : "•".repeat(pw.len)
            color: pw.len === 0 ? Theme.textFaint : Theme.text
            font.pixelSize: 15
            font.weight: Font.Normal
            elide: Text.ElideLeft
        }
        Icon {
            id: eye
            anchors.right: parent.right
            anchors.rightMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            name: pw.showPassword ? "visibility_off" : "visibility"
            color: eyeArea.containsMouse ? Theme.textMuted : Theme.textFaint
            MouseArea {
                id: eyeArea
                anchors.fill: parent
                anchors.margins: -8
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: pw.showPassword = !pw.showPassword
            }
        }
    }
    // runder Knopf, Glut nur beim Drücken
    Rectangle {
        id: go
        visible: !pw.codeMode
        anchors.right: parent.right
        width: 52
        height: 52
        radius: 26
        color: goArea.pressed ? Theme.accent : Theme.accentSoft
        border.width: 1
        border.color: Theme.border
        Icon {
            anchors.centerIn: parent
            name: "arrow_forward"
            color: Theme.accentText
        }
        MouseArea {
            id: goArea
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: pw.ctx.submit()
        }
    }

    // Plasma: Augen-Schalter fällt zurück, wenn das Feld ausgeblendet wird
    Connections {
        target: pw.ctx
        function onUiVisibleChanged(): void {
            if (!pw.ctx.uiVisible)
                pw.showPassword = false;
        }
    }
}

import QtQuick
import qs.config
import qs.components

// Freitext auf der Antwort-Karte („Other…“, Notiz, Text-/Zahlfrage). Bricht um, Enter = accepted, Esc = cancelled.
// Keine Längenbegrenzung hier: zu lange Texte meldet die Karte (dann „Answer in VS Code“ statt abgeschnitten senden).
Rectangle {
    id: field

    property alias text: input.text
    property string placeholder
    property string icon
    property bool invalid: false
    property bool marked: false   // zählt als Antwort (Glut-Rand)
    property bool autoFocus: false
    readonly property bool typing: input.activeFocus
    signal accepted()
    signal cancelled()

    function focusNow(): void {
        input.forceActiveFocus();
        input.cursorPosition = input.text.length;
    }

    // höchstens ~6 Zeilen, darüber scrollt das Feld (lange Texte sprengen sonst die Karte)
    implicitHeight: Math.max(34, flick.height + 16)
    radius: Theme.radiusMd
    color: Theme.raise
    border.width: 1
    border.color: invalid ? Qt.alpha(Theme.error, 0.6) : (input.activeFocus || marked) ? Qt.alpha(Theme.accent, 0.55) : Theme.border
    Behavior on border.color { ColorAnimation { duration: Theme.fade } }

    onVisibleChanged: if (visible && autoFocus) Qt.callLater(field.focusNow)
    Component.onCompleted: if (visible && autoFocus) Qt.callLater(field.focusNow)

    // Klick neben den Text: trotzdem ins Feld
    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.IBeamCursor
        onClicked: field.focusNow()
    }

    Icon {
        x: 10
        y: 8
        height: 17
        visible: field.icon !== ""
        name: field.icon
        size: 15
        color: Theme.textFaint
    }

    Flickable {
        id: flick
        x: field.icon !== "" ? 33 : 12
        y: 8
        width: parent.width - x - 12
        height: Math.min(input.contentHeight, 104)
        contentWidth: width
        contentHeight: input.contentHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        interactive: contentHeight > height

        function follow(r: rect): void {
            if (r.y < contentY)
                contentY = r.y;
            else if (r.y + r.height > contentY + height)
                contentY = r.y + r.height - height;
        }

        TextInput {
            id: input
            width: flick.width
            onCursorRectangleChanged: flick.follow(cursorRectangle)
            wrapMode: TextInput.Wrap
            color: Theme.text
            selectionColor: Theme.accentSoft
            selectedTextColor: Theme.text
            font.family: Theme.fontUi
            font.pixelSize: 13
            Keys.onReturnPressed: event => {
                event.accepted = true;
                field.accepted();
            }
            Keys.onEnterPressed: event => {
                event.accepted = true;
                field.accepted();
            }
            Keys.onEscapePressed: event => {
                event.accepted = true;
                field.cancelled();
            }

            Txt {
                anchors.fill: parent
                visible: input.text === ""
                text: field.placeholder
                color: Theme.textFaint
                font.weight: Font.Normal
                verticalAlignment: Text.AlignTop
            }
        }
    }
}

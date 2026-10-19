import QtQuick
import Quickshell
import qs.config
import qs.services
import qs.components

// Rechner-Tasten zum Klicken (Modus "="): schreibt in dasselbe Suchfeld, Tastatur geht parallel weiter
Glass {
    id: pad

    required property var launcher
    property var input: null
    readonly property var result: Calc.evaluate(launcher.term, true)

    readonly property int keyW: 58
    readonly property int keyH: 46
    readonly property int gap: 6
    // [Beschriftung, eingefügter Text oder Befehl, Art]
    readonly property var keys: [
        ["sin", "sin(", "fn"], ["cos", "cos(", "fn"], ["tan", "tan(", "fn"], ["√", "√(", "fn"], ["⌫", "@back", "cmd"],
        ["ln", "ln(", "fn"], ["log", "log(", "fn"], ["xʸ", "^", "op"], ["n!", "!", "op"], ["C", "@clear", "cmd"],
        ["(", "(", "op"], [")", ")", "op"], ["π", "π", "fn"], ["e", "e", "fn"], ["%", "%", "op"],
        ["7", "7", "num"], ["8", "8", "num"], ["9", "9", "num"], ["÷", "÷", "op"], ["x²", "^2", "op"],
        ["4", "4", "num"], ["5", "5", "num"], ["6", "6", "num"], ["×", "×", "op"], ["1/x", "@inv", "op"],
        ["1", "1", "num"], ["2", "2", "num"], ["3", "3", "num"], ["−", "-", "op"], ["±", "@neg", "op"],
        ["0", "0", "num"], [".", ".", "num"], ["ans", "@ans", "fn"], ["+", "+", "op"], ["=", "@eq", "eq"]
    ]
    property var ans: null   // letztes Ergebnis von "="

    function press(cmd: string): void {
        const t = launcher.query.startsWith("=") ? launcher.query.slice(1) : launcher.query;
        let n = t;
        if (cmd === "@back")
            n = t.slice(0, -1);
        else if (cmd === "@clear")
            n = "";
        else if (cmd === "@eq") {
            if (result !== null) {
                ans = result;
                n = Calc.format(result);
            }
        } else if (cmd === "@inv")
            n = "1/(" + t + ")";
        else if (cmd === "@neg")
            n = "-(" + t + ")";
        else if (cmd === "@ans")
            n = t + (ans !== null ? Calc.format(ans) : "");
        else
            n = t + cmd;
        launcher.query = "=" + n;
        if (input) {
            input.forceActiveFocus();
            input.cursorPosition = input.text.length;
        }
    }

    width: grid.width + 32
    height: col.implicitHeight + 32
    radius: Theme.radiusXl

    Column {
        id: col
        x: 16
        y: 16
        spacing: 12

        // Anzeige: Ergebnis groß, Klick kopiert
        Rectangle {
            width: grid.width
            height: 64
            radius: Theme.radiusMd
            color: Theme.raise
            border.width: 1
            border.color: Theme.border

            MonoTxt {
                anchors.right: parent.right
                anchors.rightMargin: 14
                anchors.left: parent.left
                anchors.leftMargin: 14
                anchors.verticalCenter: parent.verticalCenter
                horizontalAlignment: Text.AlignRight
                elide: Text.ElideLeft
                text: pad.result !== null ? Calc.format(pad.result) : "–"
                color: pad.result !== null ? Theme.text : Theme.textFaint
                font.pixelSize: 26
            }
            MouseArea {
                anchors.fill: parent
                cursorShape: pad.result !== null ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: if (pad.result !== null) Quickshell.execDetached(["wl-copy", Calc.format(pad.result)])
            }
        }

        Grid {
            id: grid
            columns: 5
            spacing: pad.gap

            Repeater {
                model: pad.keys

                Rectangle {
                    id: key
                    required property var modelData
                    readonly property string kind: modelData[2]

                    width: pad.keyW
                    height: pad.keyH
                    radius: Theme.radiusSm
                    color: kind === "eq" ? (area.containsMouse ? Qt.alpha(Theme.accent, 0.32) : Theme.accentSoft)
                         : area.pressed ? Qt.alpha(Theme.text, 0.14)
                         : area.containsMouse ? Qt.alpha(Theme.text, 0.08)
                         : kind === "num" ? Theme.raise : "transparent"
                    border.width: 1
                    border.color: kind === "eq" ? Qt.alpha(Theme.accent, 0.55) : Theme.border
                    Behavior on color { ColorAnimation { duration: 90 } }

                    Txt {
                        anchors.centerIn: parent
                        text: key.modelData[0]
                        font.pixelSize: key.kind === "num" ? 18 : 15
                        font.weight: key.kind === "num" ? Font.Medium : Font.Normal
                        color: key.kind === "eq" ? Theme.accentText : key.kind === "num" ? Theme.text : key.kind === "cmd" ? Theme.textMuted : Theme.woodLight
                    }
                    MouseArea {
                        id: area
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: pad.press(key.modelData[1])
                    }
                }
            }
        }

        Txt {
            text: "Angles in degrees · ↵ copies"
            color: Theme.textFaint
            font.pixelSize: 12
            font.weight: Font.Normal
        }
    }
}

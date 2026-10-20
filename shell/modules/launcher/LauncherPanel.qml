import QtQuick
import Quickshell
import Quickshell.Widgets
import qs.config
import qs.services
import qs.components

// Such-Panel (Feld, Modi, Treffer, Rechner-Tasten) – steckt im Launcher-Fenster und im Dashboard.
// Der Zustand (query, results, …) liegt im Launcher-Scope.
Item {
    id: panelRoot

    required property var launcher
    property string placeholder: "Search…"
    // compact (Dashboard): ohne Eingabe nur das Feld, Treffer erst beim Tippen
    property bool compact: false
    readonly property bool idle: compact && launcher.query === ""
    readonly property alias input: input
    readonly property alias card: card
    readonly property alias pad: pad
    readonly property bool padShown: launcher.mode === "="
    // Höhe ohne Treffer (Feld + Modus-Chips): das Dashboard setzt seine Kacheln darunter
    readonly property real restHeight: modeFlow.y + modeFlow.height + 36

    signal dismissed()
    signal activated()

    function run(i: int): void {
        launcher.activate(i);
        activated();
    }

    width: Theme.layout.launcherWidth || 760
    height: card.height

    Glass {
        id: card
        width: parent.width
        height: col.implicitHeight + 36
        radius: Theme.radiusXl

        // Luft oben, zwischen den Teilen und unten gleich (18)
        Column {
            id: col
            x: 16
            y: 18
            width: parent.width - 32
            spacing: 18

            // Suchfeld
            Rectangle {
                width: parent.width
                height: 56
                radius: Theme.radiusMd
                color: Theme.raise
                border.width: 1
                border.color: Qt.alpha(Theme.accent, 0.5)

                Icon {
                    id: searchIcon
                    anchors.left: parent.left
                    anchors.leftMargin: 16
                    anchors.verticalCenter: parent.verticalCenter
                    name: "search"
                    size: 22
                    color: Theme.textFaint
                }
                TextInput {
                    id: input
                    anchors.left: searchIcon.right
                    anchors.leftMargin: 12
                    anchors.right: parent.right
                    anchors.rightMargin: 16
                    anchors.verticalCenter: parent.verticalCenter
                    text: launcher.query
                    onTextChanged: launcher.query = text
                    // Feld folgt dem Suchtext auch dann, wenn die Bindung durch input.text = … gerissen ist
                    // (z. B. nach Klick auf einen Modus-Chip) – sonst bliebe beim nächsten Öffnen Text stehen
                    Connections {
                        target: panelRoot.launcher
                        function onQueryChanged() {
                            if (input.text !== panelRoot.launcher.query)
                                input.text = panelRoot.launcher.query;
                        }
                    }
                    color: Theme.text
                    selectionColor: Theme.accentSoft
                    font.family: Theme.fontUi
                    font.pixelSize: Theme.fontXl
                    focus: true
                    Keys.onEscapePressed: panelRoot.dismissed()
                    Keys.onReturnPressed: panelRoot.run(launcher.selected)
                    Keys.onEnterPressed: panelRoot.run(launcher.selected)
                    Keys.onDownPressed: launcher.selected = Math.min(launcher.results.length - 1, launcher.selected + 1)
                    Keys.onUpPressed: launcher.selected = Math.max(0, launcher.selected - 1)
                    Keys.onTabPressed: {
                        const i = launcher.modes.findIndex(m => m.prefix === launcher.mode);
                        const nextMode = launcher.modes[(i + 1) % launcher.modes.length].prefix;
                        text = nextMode + launcher.term;
                    }
                    Txt {
                        anchors.fill: parent
                        visible: input.text === ""
                        text: panelRoot.placeholder
                        color: Theme.textFaint
                        font.pixelSize: Theme.fontXl
                        font.weight: Font.Normal
                    }
                }
            }

            // Modi (mehrere Zeilen, wenn es viele sind) – auch ohne Eingabe sichtbar, damit die Präfixe (# Projects, = Calculator …) sofort da sind
            Flow {
                id: modeFlow
                width: parent.width
                spacing: 8
                Repeater {
                    model: launcher.modes
                    Rectangle {
                        required property var modelData
                        readonly property bool on: modelData.prefix === launcher.mode
                        width: modeRow.implicitWidth + 20
                        height: 28
                        radius: Theme.radiusSm
                        color: on ? Theme.accentFill : "transparent"
                        border.width: on ? 0 : 1
                        border.color: Theme.border
                        Row {
                            id: modeRow
                            anchors.centerIn: parent
                            spacing: 6
                            MonoTxt {
                                visible: modelData.prefix !== ""
                                text: modelData.prefix
                                color: Theme.textFaint
                                font.pixelSize: Theme.fontSm
                            }
                            Txt {
                                text: modelData.label
                                color: parent.parent.on ? Theme.accentText : Theme.textMuted
                                font.pixelSize: Theme.fontSm
                            }
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                input.text = modelData.prefix + launcher.term;
                                input.forceActiveFocus();
                            }
                        }
                    }
                }
            }

            // Treffer: höchstens maxRows Zeilen hoch, darüber scrollt die Liste und folgt der Auswahl
            ListView {
                id: hits
                readonly property int rowH: 60
                readonly property int maxRows: 10
                visible: !panelRoot.idle
                width: parent.width
                height: Math.max(0, Math.min(count, maxRows) * (rowH + spacing) - spacing)
                spacing: 2
                clip: true
                interactive: count > maxRows
                boundsBehavior: Flickable.StopAtBounds
                model: launcher.results
                function follow(): void {
                    if (launcher.selected >= 0 && launcher.selected < count)
                        positionViewAtIndex(launcher.selected, ListView.Contain);
                }
                Connections {
                    target: panelRoot.launcher
                    function onSelectedChanged() { hits.follow(); }
                    function onResultsChanged() { hits.positionViewAtBeginning(); }
                }
                delegate: Rectangle {
                    id: row
                    required property var modelData
                    required property int index
                    readonly property bool on: index === launcher.selected
                    width: ListView.view.width
                    height: hits.rowH
                    radius: Theme.radiusMd
                    color: on ? Theme.accentFill : rowArea.containsMouse ? Theme.raise : "transparent"

                    Rectangle {
                        id: tileIcon
                        x: 12
                        anchors.verticalCenter: parent.verticalCenter
                        width: 40
                        height: 40
                        radius: Theme.radiusSm
                        color: row.modelData.icon ? "transparent" : Theme.wood
                        clip: true
                        IconImage {
                            anchors.centerIn: parent
                            visible: !!row.modelData.icon
                            implicitSize: 32
                            source: row.modelData.icon ? Quickshell.iconPath(row.modelData.icon, "application-x-executable") : ""
                        }
                        Icon {
                            anchors.centerIn: parent
                            visible: !row.modelData.icon
                            name: row.modelData.glyph || ""
                            size: 22
                            color: Theme.text
                        }
                    }
                    Column {
                        anchors.left: tileIcon.right
                        anchors.leftMargin: 14
                        anchors.right: kind.left
                        anchors.rightMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 2
                        Text {
                            width: parent.width
                            text: Fuzzy.highlight(launcher.term, row.modelData.title, Theme.accentText)
                            textFormat: Text.StyledText
                            elide: Text.ElideRight
                            color: Theme.text
                            font.family: Theme.fontUi
                            font.pixelSize: Theme.fontLg
                            font.weight: Font.Medium
                            linkColor: Theme.accentText
                        }
                        Txt {
                            width: parent.width
                            visible: text !== ""
                            text: row.modelData.sub
                            color: Theme.textMuted
                            font.pixelSize: Theme.fontSm
                            font.weight: Font.Normal
                        }
                    }
                    Txt {
                        id: kind
                        anchors.right: rowKey.visible ? rowKey.left : parent.right
                        anchors.rightMargin: rowKey.visible ? Theme.space2 : 14
                        anchors.verticalCenter: parent.verticalCenter
                        width: Math.min(implicitWidth, 220)   // lange Bezeichnungen gekürzt
                        text: row.modelData.kind
                        color: row.on ? Theme.accentText : Theme.textFaint
                        font.pixelSize: Theme.fontSm
                        font.weight: Font.Normal
                    }
                    // gewählte Zeile: ihre Taste als kleine Kappe
                    KeyHintRow {
                        id: rowKey
                        visible: row.on
                        anchors.right: parent.right
                        anchors.rightMargin: 14
                        anchors.verticalCenter: parent.verticalCenter
                        small: true
                        hints: [["↵", ""]]
                    }
                    MouseArea {
                        id: rowArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: panelRoot.run(row.index, false)
                    }
                }
            }

            // Tastenzeile: dieselbe Hinweiszeile wie überall (KeyHintRow)
            KeyHintRow {
                visible: !panelRoot.idle
                x: Theme.space1
                hints: launcher.mode === "c " ? [["↵", "ask Claude"], ["Tab", "mode"], ["Esc", "close"]]
                         : [["↵", "open"], ["↑↓", "select"], ["Tab", "mode"], ["Esc", "close"]]
            }
        }
    }

    // Wissenschaftlicher Rechner zum Klicken (nur im Modus "=")
    CalcPad {
        id: pad
        launcher: panelRoot.launcher
        input: input
        x: card.width + 16
        y: 0
        visible: panelRoot.padShown
    }
}

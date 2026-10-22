import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components
import qs.services

// Das Fenster: links Suche + Liste, rechts Details (Benutzer, Passwort, 2FA, Websites)
Glass {
    id: panel

    required property var pw

    function focusSearch(): void {
        input.forceActiveFocus();
    }

    radius: Theme.radiusXl
    strong: true

    // ================================================================ links: Kopf, Suche, Liste
    Item {
        id: left
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.margins: 22
        width: Math.round(parent.width * 0.44)

        // Kopf: Titel + Zähler, kein Knopf mehr (Sync läuft automatisch, Logos laden selbst nach)
        RowLayout {
            id: head
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            height: 34
            spacing: 10
            PopoutTitle {
                Layout.fillWidth: true
                icon: "key"
                text: "Passwords"
                textSize: Theme.fontXl
                metaMono: true
                meta: {
                    const total = panel.pw.groupItems.length;
                    return panel.pw.query.trim() ? panel.pw.rows.length + " / " + total : String(total || "");
                }
            }
        }

        // neuer Login (wie Ctrl+N), rechts neben dem Suchfeld
        Button {
            id: newBtn
            anchors.right: parent.right
            anchors.verticalCenter: sf.verticalCenter
            height: sf.height
            text: "New login"
            icon: "add"
            enabled: !panel.pw.editing
            onClicked: panel.pw.startCreate()
        }
        // Suchfeld
        Rectangle {
            id: sf
            anchors.top: head.bottom
            anchors.topMargin: 14
            anchors.left: parent.left
            anchors.right: newBtn.left
            anchors.rightMargin: 10
            height: 46
            radius: Theme.radiusMd
            color: Theme.raise
            border.width: 1
            border.color: input.activeFocus ? Qt.alpha(Theme.accent, 0.5) : Theme.border
            Behavior on border.color { ColorAnimation { duration: Theme.fade } }

            Icon {
                id: sIcon
                anchors.left: parent.left
                anchors.leftMargin: 14
                anchors.verticalCenter: parent.verticalCenter
                name: "search"
                size: 20
                color: Theme.textFaint
            }
            TextInput {
                id: input
                anchors.left: sIcon.right
                anchors.leftMargin: 10
                anchors.right: parent.right
                anchors.rightMargin: 14
                anchors.verticalCenter: parent.verticalCenter
                clip: true
                text: panel.pw.query
                onTextChanged: panel.pw.query = text
                Connections {
                    target: panel.pw
                    function onQueryChanged() {
                        if (input.text !== panel.pw.query)
                            input.text = panel.pw.query;
                    }
                }
                color: Theme.text
                selectionColor: Theme.accentSoft
                font.family: Theme.fontUi
                font.pixelSize: Theme.fontLg
                focus: true

                function step(d: int): void {
                    panel.pw.moveSel(d);
                    list.positionViewAtIndex(panel.pw.sel, ListView.Contain);
                }
                Keys.onEscapePressed: {
                    if (panel.pw.query !== "")
                        panel.pw.query = "";
                    else if (panel.pw.group !== "")
                        panel.pw.group = "";
                    else
                        panel.pw.close();
                }
                // Tab / Shift+Tab: Gruppen-Chips (All · Personal · geteilte Gruppen)
                Keys.onTabPressed: panel.pw.stepGroup(1)
                Keys.onBacktabPressed: panel.pw.stepGroup(-1)
                Keys.onReturnPressed: panel.pw.copy("password")
                Keys.onEnterPressed: panel.pw.copy("password")
                Keys.onDownPressed: step(1)
                Keys.onUpPressed: step(-1)
                Keys.onPressed: event => {
                    if (event.key === Qt.Key_PageDown) {
                        step(8);
                        event.accepted = true;
                    } else if (event.key === Qt.Key_PageUp) {
                        step(-8);
                        event.accepted = true;
                    } else if (event.modifiers & Qt.ControlModifier) {
                        if (event.key === Qt.Key_U) {
                            panel.pw.copy("user");
                            event.accepted = true;
                        } else if (event.key === Qt.Key_P) {
                            panel.pw.copy("password");
                            event.accepted = true;
                        } else if (event.key === Qt.Key_T) {
                            panel.pw.copy("totp");
                            event.accepted = true;
                        } else if (event.key === Qt.Key_E) {
                            panel.pw.toggleReveal();
                            event.accepted = true;
                        }
                    } else if (event.key === Qt.Key_F2) {
                        panel.pw.startEdit();
                        event.accepted = true;
                    }
                    if (event.modifiers & Qt.ControlModifier && event.key === Qt.Key_N) {
                        panel.pw.startCreate();
                        event.accepted = true;
                    }
                }

                Txt {
                    anchors.fill: parent
                    visible: input.text === ""
                    text: "Search logins…"
                    color: Theme.textFaint
                    font.pixelSize: Theme.fontLg
                    font.weight: Font.Normal
                }
            }
        }

        // Gruppen-Chips: nur wenn es geteilte Gruppen gibt; brechen um, statt rechts abgeschnitten zu werden
        Flow {
            id: chips
            anchors.top: sf.bottom
            anchors.topMargin: 10
            anchors.left: parent.left
            anchors.right: parent.right
            spacing: 4
            visible: panel.pw.groups.length > 0
            height: visible ? implicitHeight : 0
            Repeater {
                model: panel.pw.groups
                delegate: Tab {
                    required property string modelData
                    text: panel.pw.groupLabel(modelData)
                    icon: modelData === "" ? "" : modelData === panel.pw.ownGroup ? "person" : "group"
                    count: panel.pw.groupCount(modelData)
                    current: panel.pw.group === modelData
                    onPicked: {
                        panel.pw.group = modelData;
                        panel.pw.sel = 0;
                        panel.focusSearch();
                    }
                }
            }
        }

        WheelScroll {
            flick: list
            step: 160
        }

        ListView {
            id: list

            function focusSearch(): void {
                panel.focusSearch();
            }

            anchors.top: chips.visible ? chips.bottom : sf.bottom
            anchors.topMargin: chips.visible ? 8 : 12
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: syncLine.visible ? syncLine.top : hideLine.top
            anchors.bottomMargin: 6
            clip: true
            spacing: 2
            boundsBehavior: Flickable.StopAtBounds
            interactive: false   // Mausrad macht WheelScroll (fester Weg pro Raste statt Qt-Kriechen)
            model: panel.pw.rows
            currentIndex: panel.pw.sel
            highlightFollowsCurrentItem: false
            reuseItems: true
            delegate: PwRow {
                width: list.width
                pw: panel.pw
            }

            Column {
                anchors.centerIn: parent
                spacing: 10
                visible: list.count === 0
                Icon {
                    anchors.horizontalCenter: parent.horizontalCenter
                    name: panel.pw.loadState.startsWith("error") ? "error" : panel.pw.loadState === "loading" ? "hourglass_top" : "search_off"
                    size: 34
                    color: panel.pw.loadState.startsWith("error") ? Theme.error : Theme.textFaint
                }
                Txt {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: Math.min(implicitWidth, list.width - 40)
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.Wrap
                    text: panel.pw.loadState.startsWith("error") ? panel.pw.loadState.slice(6) : panel.pw.loadState === "loading" ? "Opening the keychain…" : "No logins found"
                    color: Theme.textFaint
                    font.weight: Font.Normal
                }
            }
        }

        // Tastenzeile, bricht in der schmalen Spalte um statt abzuschneiden
        KeyHintRow {
            id: keysHint
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            small: true
            gap: Theme.space3
            hints: [["↵", "copy password"], ["Ctrl+U", "user"], ["Ctrl+T", "2FA"], ["Ctrl+E", "show"], ["F2", "edit"], ["Ctrl+N", "new"]].concat(panel.pw.groups.length ? [["Tab", "group"]] : [])
        }

        // Logos rechts
        RowLayout {
            id: hideLine
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: keysHint.top
            anchors.bottomMargin: 6
            height: 20
            spacing: 6
            Item {
                Layout.fillWidth: true
            }
            // Logos: Fortschritt beim Laden, sonst „Refresh icons“ (alle neu holen)
            Txt {
                text: Favicons.running ? "Icons " + Favicons.done + "/" + Favicons.total : "Refresh icons"
                font.pixelSize: Theme.fontSm
                font.weight: Font.Normal
                color: refArea.containsMouse ? Theme.text : Theme.textFaint
                MouseArea {
                    id: refArea
                    anchors.fill: parent
                    anchors.margins: -4
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        panel.pw.loadIcons(!Favicons.running);
                        panel.focusSearch();
                    }
                }
            }
        }

        // Sync-Stand: „Updated 3 min ago“, „iCloud login needed …“, „Update failed · next try 14:20“
        RowLayout {
            id: syncLine
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: hideLine.top
            anchors.bottomMargin: 2
            height: 20
            spacing: 6
            visible: panel.pw.syncText !== ""
            Icon {
                name: panel.pw.syncBusy ? "sync" : panel.pw.syncProblem ? "cloud_off" : "cloud_done"
                size: 14
                color: panel.pw.syncProblem ? Theme.warning : Theme.textFaint
            }
            Txt {
                Layout.fillWidth: true
                elide: Text.ElideRight
                text: panel.pw.syncText
                font.pixelSize: Theme.fontSm
                font.weight: Font.Normal
                color: panel.pw.syncProblem ? Theme.warning : Theme.textFaint
            }
        }
    }

    // Trennlinie
    Rectangle {
        anchors.left: left.right
        anchors.leftMargin: 20
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.topMargin: 22
        anchors.bottomMargin: 22
        width: 1
        color: Theme.border
    }

    // ================================================================ rechts: Details
    PwDetail {
        id: detail
        anchors.left: left.right
        anchors.leftMargin: 41
        anchors.right: parent.right
        anchors.rightMargin: 24
        anchors.top: parent.top
        anchors.topMargin: 22
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 22
        visible: !panel.pw.editing
        pw: panel.pw
    }

    // Bearbeiten (F2) an derselben Stelle
    PwEdit {
        id: editForm
        anchors.fill: detail
        visible: panel.pw.editing
        pw: panel.pw
    }
    Connections {
        target: panel.pw
        function onEditingChanged() {
            if (panel.pw.editing)
                editForm.begin();
        }
        function onEditEnded() {
            panel.focusSearch();
        }
    }

    // Rückmeldung (kopiert, Fehler)
    Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 18
        visible: opacity > 0
        opacity: panel.pw.toast ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.fade } }
        width: toastRow.implicitWidth + 32
        height: 38
        radius: height / 2
        color: Theme.surface
        border.width: 1
        border.color: Qt.alpha(Theme.accent, 0.45)
        Row {
            id: toastRow
            anchors.centerIn: parent
            spacing: 8
            Icon {
                anchors.verticalCenter: parent.verticalCenter
                name: "content_paste"
                size: 17
                color: Theme.accentText
            }
            Txt {
                anchors.verticalCenter: parent.verticalCenter
                text: panel.pw.toast
            }
        }
    }
}

import QtQuick
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

        Item {
            id: head
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            height: 34

            Row {
                anchors.verticalCenter: parent.verticalCenter
                x: 2
                spacing: 10
                Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    name: "key"
                    size: 22
                    color: Theme.accentText
                }
                Txt {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Passwords"
                    font.pixelSize: 18
                    font.weight: Font.DemiBold
                }
                MonoTxt {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.verticalCenterOffset: 1
                    text: {
                        const total = panel.pw.showHidden ? panel.pw.items.length : panel.pw.liveItems.length;
                        return panel.pw.query.trim() ? panel.pw.rows.length + " / " + total : total || "";
                    }
                    font.pixelSize: 12
                    color: Theme.textFaint
                }
                MonoTxt {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.verticalCenterOffset: 1
                    visible: panel.pw.hiddenCount > 0 && !panel.pw.showHidden
                    text: "+ " + panel.pw.hiddenCount + " hidden"
                    font.pixelSize: 12
                    color: Theme.textFaint
                    opacity: 0.7
                }
            }
            PwBtn {
                id: iconsBtn
                anchors.right: syncBtn.left
                anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                icon: Favicons.running ? "stop_circle" : "imagesearch_roller"
                text: Favicons.running ? Favicons.done + "/" + Favicons.total : "Icons"
                enabled: panel.pw.items.length > 0
                onClicked: panel.pw.loadIcons(false)
            }
            PwBtn {
                id: syncBtn
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                icon: "sync"
                text: panel.pw.syncBusy ? "Syncing…" : "Sync"
                enabled: !panel.pw.syncBusy
                onClicked: panel.pw.sync()
            }
        }

        // Suchfeld
        Rectangle {
            id: sf
            anchors.top: head.bottom
            anchors.topMargin: 14
            anchors.left: parent.left
            anchors.right: parent.right
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
                font.pixelSize: 16
                focus: true

                function step(d: int): void {
                    panel.pw.moveSel(d);
                    list.positionViewAtIndex(panel.pw.sel, ListView.Contain);
                }
                Keys.onEscapePressed: {
                    if (panel.pw.query !== "")
                        panel.pw.query = "";
                    else
                        panel.pw.close();
                }
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
                        } else if (event.key === Qt.Key_H) {
                            panel.pw.toggleHide(panel.pw.cur);
                            event.accepted = true;
                        }
                    }
                }

                Txt {
                    anchors.fill: parent
                    visible: input.text === ""
                    text: "Search logins…"
                    color: Theme.textFaint
                    font.pixelSize: 16
                    font.weight: Font.Normal
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

            anchors.top: sf.bottom
            anchors.topMargin: 12
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: hideLine.top
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

        Txt {
            id: keysHint
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            text: "Ctrl+U user  ·  Ctrl+P / ↵ password  ·  Ctrl+T 2FA  ·  Ctrl+E show  ·  Ctrl+H hide"
            font.pixelSize: 11
            font.weight: Font.Normal
            color: Theme.textFaint
        }

        // Ausgeblendete (WLAN & Co.): Zähler, Anzeigen-Schalter, Filter an/aus
        Row {
            id: hideLine
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: iconsLine.top
            anchors.bottomMargin: 4
            height: 20
            spacing: 6
            Txt {
                anchors.verticalCenter: parent.verticalCenter
                text: {
                    const w = panel.pw.hiddenWifiCount, m = panel.pw.hiddenManualCount;
                    if (w + m === 0)
                        return "Nothing hidden";
                    return [w > 0 ? w + " Wi-Fi" : "", m > 0 ? m + " manual" : ""].filter(x => x).join(" + ") + " hidden";
                }
                font.pixelSize: 11
                font.weight: Font.Normal
                color: Theme.textFaint
            }
            Txt {
                anchors.verticalCenter: parent.verticalCenter
                visible: panel.pw.hiddenCount > 0
                text: "·"
                font.pixelSize: 11
                color: Theme.textFaint
            }
            Txt {
                anchors.verticalCenter: parent.verticalCenter
                visible: panel.pw.hiddenCount > 0
                text: panel.pw.showHidden ? "Hide again" : "Show"
                font.pixelSize: 11
                font.weight: Font.Normal
                color: showArea.containsMouse ? Theme.text : Theme.accentText
                MouseArea {
                    id: showArea
                    anchors.fill: parent
                    anchors.margins: -4
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        panel.pw.showHidden = !panel.pw.showHidden;
                        panel.focusSearch();
                    }
                }
            }
            Txt {
                anchors.verticalCenter: parent.verticalCenter
                text: "·"
                font.pixelSize: 11
                color: Theme.textFaint
            }
            Txt {
                anchors.verticalCenter: parent.verticalCenter
                text: "Wi-Fi filter " + (panel.pw.hideWifi ? "on" : "off")
                font.pixelSize: 11
                font.weight: Font.Normal
                color: wifiArea.containsMouse ? Theme.text : panel.pw.hideWifi ? Theme.accentText : Theme.textFaint
                MouseArea {
                    id: wifiArea
                    anchors.fill: parent
                    anchors.margins: -4
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        panel.pw.setHideWifi(!panel.pw.hideWifi);
                        panel.focusSearch();
                    }
                }
            }
        }

        // Icons: Stand + Einstellungen (Abruf direkt bei den Websites, nur die Domain)
        Row {
            id: iconsLine
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: keysHint.top
            anchors.bottomMargin: 6
            height: 20
            spacing: 6
            Txt {
                anchors.verticalCenter: parent.verticalCenter
                text: Favicons.running ? "Loading icons " + Favicons.done + "/" + Favicons.total + "…" : Favicons.haveCount + " icons" + (Favicons.failed > 0 ? " · " + Favicons.failed + " unreachable" : "")
                font.pixelSize: 11
                font.weight: Font.Normal
                color: Theme.textFaint
            }
            Txt {
                anchors.verticalCenter: parent.verticalCenter
                text: "·"
                font.pixelSize: 11
                color: Theme.textFaint
            }
            Txt {
                id: autoTxt
                anchors.verticalCenter: parent.verticalCenter
                text: "Auto-load " + (Favicons.auto ? "on" : "off")
                font.pixelSize: 11
                font.weight: Font.Normal
                color: autoArea.containsMouse ? Theme.text : Favicons.auto ? Theme.accentText : Theme.textFaint
                MouseArea {
                    id: autoArea
                    anchors.fill: parent
                    anchors.margins: -4
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        Favicons.setAuto(!Favicons.auto);
                        panel.focusSearch();
                    }
                }
            }
            Txt {
                anchors.verticalCenter: parent.verticalCenter
                visible: !Favicons.running && Favicons.haveCount > 0
                text: "·"
                font.pixelSize: 11
                color: Theme.textFaint
            }
            Txt {
                anchors.verticalCenter: parent.verticalCenter
                visible: !Favicons.running && Favicons.haveCount > 0
                text: "Refresh all"
                font.pixelSize: 11
                font.weight: Font.Normal
                color: refArea.containsMouse ? Theme.text : Theme.textFaint
                MouseArea {
                    id: refArea
                    anchors.fill: parent
                    anchors.margins: -4
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        panel.pw.loadIcons(true);
                        panel.focusSearch();
                    }
                }
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
        pw: panel.pw
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

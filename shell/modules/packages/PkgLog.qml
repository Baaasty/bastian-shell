import QtQuick
import qs.config
import qs.components

// Log-Leiste unten: Status + letzte Zeile, aufklappbar zur Live-Ausgabe. Fortschrittsbalken läuft, solange die Aktion arbeitet.
Rectangle {
    id: bar

    property var pk
    readonly property bool failed: !pk.busy && !pk.doneOk

    height: pk.logOpen ? 230 : 40
    radius: Theme.radiusMd
    color: Theme.surfaceSunken
    border.width: 1
    border.color: failed ? Qt.alpha(Theme.error, 0.5) : Theme.border
    clip: true
    Behavior on height { NumberAnimation { duration: Theme.fade; easing.type: Easing.OutCubic } }

    // unbestimmter Fortschritt
    Rectangle {
        id: track
        visible: bar.pk.busy
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 2
        color: "transparent"
        Rectangle {
            id: runner
            width: track.width * 0.25
            height: parent.height
            radius: 1
            color: Theme.accent
            SequentialAnimation on x {
                running: bar.pk.busy
                loops: Animation.Infinite
                NumberAnimation { from: -runner.width; to: track.width; duration: 1400; easing.type: Easing.InOutQuad }
            }
        }
    }

    Item {
        id: head
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 40

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: bar.pk.logOpen = !bar.pk.logOpen
        }
        PkgSpinner {
            id: sp
            anchors.left: parent.left
            anchors.leftMargin: 14
            anchors.verticalCenter: parent.verticalCenter
            visible: bar.pk.busy
        }
        Icon {
            anchors.left: parent.left
            anchors.leftMargin: 14
            anchors.verticalCenter: parent.verticalCenter
            visible: !bar.pk.busy
            name: bar.failed ? "error" : "check_circle"
            size: 18
            color: bar.failed ? Theme.error : Theme.success
        }
        Txt {
            anchors.left: parent.left
            anchors.leftMargin: 42
            anchors.right: btns.left
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            text: bar.pk.busy ? (bar.pk.authWait ? "Waiting for authentication · " : "") + bar.pk.busyTitle + (bar.pk.log.count > 1 ? "  ·  " + bar.pk.log.get(bar.pk.log.count - 1).line : "") : bar.pk.busyTitle + (bar.failed ? " failed" : " done")
            font.pixelSize: Theme.fontSm
            color: bar.failed ? Theme.error : Theme.textMuted
        }
        Row {
            id: btns
            anchors.right: parent.right
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            spacing: 4
            Button {
                small: true
                icon: bar.pk.logOpen ? "expand_more" : "expand_less"
                onClicked: bar.pk.logOpen = !bar.pk.logOpen
            }
            Button {
                small: true
                visible: !bar.pk.busy
                icon: "close"
                onClicked: {
                    bar.pk.logShown = false;
                    bar.pk.logOpen = false;
                }
            }
        }
    }

    ListView {
        id: lv
        anchors.top: head.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.leftMargin: 14
        anchors.rightMargin: 14
        anchors.bottomMargin: 8
        clip: true
        model: bar.pk.log
        boundsBehavior: Flickable.StopAtBounds
        onCountChanged: Qt.callLater(() => lv.positionViewAtEnd())
        delegate: MonoTxt {
            required property string line
            required property string kind
            width: ListView.view.width
            text: line
            elide: Text.ElideRight
            font.pixelSize: Theme.fontSm
            color: kind === "err" ? Theme.error : kind === "ok" ? Theme.success : kind === "cmd" || kind === "head" ? Theme.accentText : Theme.textMuted
        }
    }
}

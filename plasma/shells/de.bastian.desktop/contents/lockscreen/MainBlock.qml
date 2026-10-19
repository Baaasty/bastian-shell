/*
    SPDX-FileCopyrightText: 2016 David Edmundson <davidedmundson@kde.org>

    SPDX-License-Identifier: LGPL-2.0-or-later
*/

import QtQuick

import QtQuick.Layouts
import QtQuick.Controls as QQC2

import org.kde.plasma.components as PlasmaComponents3
import org.kde.plasma.extras as PlasmaExtras
import org.kde.kirigami as Kirigami
import org.kde.kscreenlocker as ScreenLocker

import org.kde.breeze.components

SessionManagementScreen {
    id: sessionManager

    readonly property alias mainPasswordBox: passwordBox
    property bool lockScreenUiVisible: false
    property alias showPassword: passwordBox.showPassword

    //the y position that should be ensured visible when the on screen keyboard is visible
    property int visibleBoundary: mapFromItem(loginButton, 0, 0).y
    onHeightChanged: visibleBoundary = mapFromItem(loginButton, 0, 0).y + loginButton.height + Kirigami.Units.smallSpacing
    /*
     * Login has been requested with the following username and password
     * If username field is visible, it will be taken from that, otherwise from the "name" property of the currentIndex
     */
    signal passwordResult(string password)

    onUserSelected: {
        const nextControl = (passwordBox.visible ? passwordBox : loginButton);
        // Don't startLogin() here, because the signal is connected to the
        // Escape key as well, for which it wouldn't make sense to trigger
        // login. Using TabFocusReason, so that the loginButton gets the
        // visual highlight.
        nextControl.forceActiveFocus(Qt.TabFocusReason);
    }

    function startLogin() {
        const password = passwordBox.text

        // This is partly because it looks nicer, but more importantly it
        // works round a Qt bug that can trigger if the app is closed with a
        // TextField focused.
        //
        // See https://bugreports.qt.io/browse/QTBUG-55460
        loginButton.forceActiveFocus();
        passwordResult(password);
    }

    RowLayout {
        Layout.fillWidth: true

        QQC2.TextField {
            id: passwordBox
            // Desktop: eigenes Feld statt PlasmaExtras.PasswordField (dessen Augen-Knopf bringt einen Plasma-Rahmen mit)
            property bool showPassword: false
            // Desktop: Code-Modus = 6 Kästchen wie bei einer Auth-Code-Eingabe
            // Standard 6; überschreibbar über die Lockscreen-Einstellung desktopAutoSubmitLength (0 = aus)
            readonly property int codeLength: typeof config.desktopAutoSubmitLength === "number" ? config.desktopAutoSubmitLength : 6
            readonly property bool codeMode: codeLength > 0
            echoMode: showPassword ? TextInput.Normal : TextInput.Password
            passwordCharacter: "•"
            inputMethodHints: Qt.ImhHiddenText | Qt.ImhSensitiveData | Qt.ImhNoAutoUppercase | Qt.ImhNoPredictiveText
            selectionColor: DesktopTheme.accentSoft
            selectedTextColor: DesktopTheme.text
            rightPadding: 48
            verticalAlignment: TextInput.AlignVCenter

            Row {
                visible: passwordBox.codeMode
                anchors.centerIn: parent
                spacing: 10

                Repeater {
                    model: passwordBox.codeLength

                    Rectangle {
                        required property int index
                        readonly property bool filled: index < passwordBox.length
                        readonly property bool current: index === passwordBox.length && passwordBox.activeFocus

                        width: 40
                        height: 50
                        radius: 12
                        color: DesktopTheme.glassStrong
                        border.width: current ? 2 : 1
                        border.color: current ? DesktopTheme.accent : filled ? DesktopTheme.woodLight : DesktopTheme.borderStrong

                        Behavior on border.color { ColorAnimation { duration: 120 } }

                        Text {
                            anchors.centerIn: parent
                            text: !parent.filled ? "" : passwordBox.showPassword ? passwordBox.text.charAt(parent.index) : "•"
                            color: DesktopTheme.text
                            font.family: DesktopTheme.fontMono
                            font.pixelSize: 22
                        }
                    }
                }
            }

            Text {
                visible: !passwordBox.codeMode
                anchors.right: parent.right
                anchors.rightMargin: 16
                anchors.verticalCenter: parent.verticalCenter
                text: passwordBox.showPassword ? "visibility_off" : "visibility"
                color: eyeArea.containsMouse ? DesktopTheme.textMuted : DesktopTheme.textFaint
                font.family: "Material Symbols Rounded"
                font.pixelSize: 18

                MouseArea {
                    id: eyeArea
                    anchors.fill: parent
                    anchors.margins: -8
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: passwordBox.showPassword = !passwordBox.showPassword
                }
            }

            font.family: DesktopTheme.fontUi
            font.pixelSize: 15
            color: codeMode ? "transparent" : DesktopTheme.text
            implicitWidth: codeMode ? codeLength * 50 - 10 : 200
            maximumLength: codeMode ? codeLength : 32767
            placeholderTextColor: DesktopTheme.textFaint
            implicitHeight: 52
            leftPadding: 22
            background: Rectangle {
                visible: !passwordBox.codeMode
                radius: height / 2
                color: DesktopTheme.glassStrong
                border.width: passwordBox.activeFocus ? 2 : 1
                border.color: passwordBox.activeFocus ? DesktopTheme.accent : DesktopTheme.borderStrong
            }
            Layout.fillWidth: !codeMode
            Layout.alignment: Qt.AlignHCenter
            text: PasswordSync.password

            placeholderText: codeMode ? "" : "Password"
            focus: true
            enabled: !authenticator.graceLocked

            // In Qt this is implicitly active based on focus rather than visibility
            // in any other application having a focussed invisible object would be weird
            // but here we are using to wake out of screensaver mode
            // We need to explicitly disable cursor flashing to avoid unnecessary renders
            cursorVisible: visible && !codeMode

            // Desktop: wie beim iPhone – bei voller Länge automatisch prüfen (nur im fokussierten Feld,
            // sonst würden alle Monitore gleichzeitig senden, weil PasswordSync den Text teilt)
            onTextChanged: {
                if (codeMode && text.length === codeLength
                        && activeFocus && sessionManager.lockScreenUiVisible) {
                    sessionManager.startLogin();
                }
            }

            onAccepted: {
                if (sessionManager.lockScreenUiVisible) {
                    sessionManager.startLogin();
                }
            }

            //if empty and left or right is pressed change selection in user switch
            //this cannot be in keys.onLeftPressed as then it doesn't reach the password box
            Keys.onPressed: event => {
                if (event.key === Qt.Key_Left && !text) {
                    sessionManager.userList.decrementCurrentIndex();
                    event.accepted = true
                }
                if (event.key === Qt.Key_Right && !text) {
                    sessionManager.userList.incrementCurrentIndex();
                    event.accepted = true
                }
            }

            Connections {
                target: root
                function onClearPassword() {
                    passwordBox.forceActiveFocus()
                    passwordBox.text = "";
                    passwordBox.text = Qt.binding(() => PasswordSync.password);
                }
                function onNotificationRepeated() {
                    sessionManager.playHighlightAnimation();
                }
            }
        }
        Binding {
            target: PasswordSync
            property: "password"
            value: passwordBox.text
        }

        PlasmaComponents3.Button {
            id: loginButton
            visible: !passwordBox.codeMode // Desktop: im Code-Modus prüft das 6. Zeichen
            // Desktop: runder Knopf, Glut nur beim Drücken
            icon.color: DesktopTheme.accentText
            icon.width: 18
            icon.height: 18
            background: Rectangle {
                radius: height / 2
                color: loginButton.down ? DesktopTheme.accent : DesktopTheme.accentSoft
                border.width: 1
                border.color: loginButton.activeFocus ? DesktopTheme.accent : DesktopTheme.border
            }
            Accessible.name: "Unlock"
            Layout.preferredHeight: passwordBox.implicitHeight
            Layout.preferredWidth: loginButton.Layout.preferredHeight

            icon.name: LayoutMirroring.enabled ? "go-previous" : "go-next"

            onClicked: sessionManager.startLogin()
            Keys.onEnterPressed: clicked()
            Keys.onReturnPressed: clicked()
        }
    }

    component FailableLabel : PlasmaComponents3.Label {
        id: _failableLabel
        required property int kind
        required property string label

        visible: authenticator.authenticatorTypes & kind
        text: label
        textFormat: Text.PlainText
        horizontalAlignment: Text.AlignHCenter
        Layout.fillWidth: true

        RejectPasswordAnimation {
            id: _rejectAnimation
            target: _failableLabel
            onFinished: _timer.restart()
        }

        Connections {
            target: authenticator
            function onNoninteractiveError(kind, authenticator) {
                if (kind & _failableLabel.kind) {
                    _failableLabel.text = Qt.binding(() => authenticator.errorMessage)
                    _rejectAnimation.start()
                }
            }
        }
        Timer {
            id: _timer
            interval: Kirigami.Units.humanMoment
            onTriggered: {
                _failableLabel.text = Qt.binding(() => _failableLabel.label)
            }
        }
    }

    FailableLabel {
        kind: ScreenLocker.Authenticator.Fingerprint
        label: "(or scan your fingerprint)"
    }
    FailableLabel {
        kind: ScreenLocker.Authenticator.Smartcard
        label: "(or scan your smartcard)"
    }
}

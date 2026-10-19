/*
    SPDX-FileCopyrightText: 2014 Aleix Pol Gonzalez <aleixpol@blue-systems.com>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQml
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects

import org.kde.plasma.components as PlasmaComponents3
import org.kde.plasma.workspace.components as PW
import org.kde.plasma.private.keyboardindicator as KeyboardIndicator
import org.kde.kirigami as Kirigami
import org.kde.kscreenlocker as ScreenLocker

import org.kde.plasma.private.sessions
import org.kde.breeze.components

Item {
    id: lockScreenUi

    // If we're using software rendering, draw outlines instead of shadows
    // See https://bugs.kde.org/show_bug.cgi?id=398317
    readonly property bool softwareRendering: GraphicsInfo.api === GraphicsInfo.Software

    // Desktop: Passwortfeld immer auf dem Hauptmonitor. Das Original nimmt den Monitor unter der Maus,
    // kennt unter Wayland beim Start aber keine Mausposition und fällt auf den ersten Monitor zurück.
    readonly property string desktopMainScreen: "DP-2"
    readonly property bool isMainScreen: Screen.name === desktopMainScreen

    Timer {
        id: desktopFocusTimer
        // nach kscreenlockers eigenem getFocus() (läuft nach dem ersten Frame)
        interval: 400
        running: lockScreenUi.isMainScreen && root.viewVisible
        // Window-Attached gibt es nur an Items, nicht am Timer
        onTriggered: lockScreenUi.Window.window.requestActivate()
    }

    function handleMessage(msg) {
        if (!root.notification) {
            root.notification += msg;
        } else if (root.notification.includes(msg)) {
            root.notificationRepeated();
        } else {
            root.notification += "\n" + msg
        }
    }

    Kirigami.Theme.inherit: false
    Kirigami.Theme.colorSet: Kirigami.Theme.Complementary

    Connections {
        target: authenticator
        function onFailed(kind) {
            if (kind != 0) { // if this is coming from the noninteractive authenticators
                return;
            }
            const msg = "Unlocking failed"; // Desktop: fest Englisch statt Plasma-Übersetzung
            lockScreenUi.handleMessage(msg);
            graceLockTimer.restart();
            notificationRemoveTimer.restart();
            rejectPasswordAnimation.start();
        }

        function onSucceeded() {
            if (authenticator.hadPrompt) {
                desktopUnlock.start(); // Desktop: Auffächern von der Mitte, dann Qt.quit()
            } else {
                mainStack.replace(null, Qt.resolvedUrl("NoPasswordUnlock.qml"),
                    {
                        userListModel: users
                    },
                    StackView.Immediate,
                );
                mainStack.forceActiveFocus();
            }
        }

        function onInfoMessageChanged() {
            lockScreenUi.handleMessage(authenticator.infoMessage);
        }

        function onErrorMessageChanged() {
            lockScreenUi.handleMessage(authenticator.errorMessage);
        }

        function onPromptChanged(msg) {
            lockScreenUi.handleMessage(authenticator.prompt);
        }
        function onPromptForSecretChanged(msg) {
            mainBlock.showPassword = false;
            mainBlock.mainPasswordBox.forceActiveFocus();
        }
    }

    SessionManagement {
        id: sessionManagement
    }

    KeyboardIndicator.KeyState {
        id: capsLockState
        key: Qt.Key_CapsLock
    }

    Connections {
        target: sessionManagement
        function onAboutToSuspend() {
            root.clearPassword();
        }
    }

    RejectPasswordAnimation {
        id: rejectPasswordAnimation
        target: mainBlock
    }

    MouseArea {
        id: lockScreenRoot

        property bool uiVisible: false
        property bool seenPositionChange: false
        property bool blockUI: containsMouse && (mainStack.depth > 1 || mainBlock.mainPasswordBox.text.length > 0 || inputPanel.keyboardActive)

        x: parent.x
        y: parent.y
        width: parent.width
        height: parent.height
        hoverEnabled: true
        cursorShape: uiVisible ? Qt.ArrowCursor : Qt.BlankCursor

        // Desktop: Farben aus theme/palette.json statt aus dem globalen Plasma-Farbschema
        Kirigami.Theme.inherit: false
        Kirigami.Theme.colorSet: Kirigami.Theme.Complementary
        Kirigami.Theme.textColor: DesktopTheme.text
        Kirigami.Theme.disabledTextColor: DesktopTheme.textFaint
        Kirigami.Theme.backgroundColor: DesktopTheme.surface
        Kirigami.Theme.alternateBackgroundColor: DesktopTheme.bg
        Kirigami.Theme.highlightColor: DesktopTheme.accent
        Kirigami.Theme.highlightedTextColor: DesktopTheme.text
        Kirigami.Theme.focusColor: DesktopTheme.accent
        Kirigami.Theme.hoverColor: DesktopTheme.accentText
        Kirigami.Theme.linkColor: DesktopTheme.accentText
        Kirigami.Theme.negativeTextColor: DesktopTheme.error
        Kirigami.Theme.positiveTextColor: DesktopTheme.success
        Kirigami.Theme.neutralTextColor: DesktopTheme.warning
        drag.filterChildren: true
        onPressed: uiVisible = true;
        onPositionChanged: {
            uiVisible = seenPositionChange;
            seenPositionChange = true;
        }
        onUiVisibleChanged: {
            if (uiVisible) {
                Window.window.requestActivate();
            }

            if (blockUI) {
                fadeoutTimer.running = false;
            } else if (uiVisible) {
                fadeoutTimer.restart();
            }
            authenticator.startAuthenticating();
        }
        onBlockUIChanged: {
            if (blockUI) {
                fadeoutTimer.running = false;
                uiVisible = true;
            } else {
                fadeoutTimer.restart();
            }
        }
        onExited: {
            uiVisible = false;
        }
        Keys.onEscapePressed: {
            // If the escape key is pressed, kscreenlocker will turn off the screen.
            // We do not want to show the password prompt in this case.
            if (uiVisible) {
                uiVisible = false;
                if (inputPanel.keyboardActive) {
                    inputPanel.showHide();
                }
                root.clearPassword();
            }
        }
        Keys.onPressed: event => {
            uiVisible = true;
            event.accepted = false;
        }
        Timer {
            id: fadeoutTimer
            interval: 10000
            onTriggered: {
                if (!lockScreenRoot.blockUI) {
                    mainBlock.mainPasswordBox.showPassword = false;
                    lockScreenRoot.uiVisible = false;
                }
            }
        }
        Timer {
            id: notificationRemoveTimer
            interval: 3000
            onTriggered: root.notification = ""
        }
        Timer {
            id: graceLockTimer
            interval: 3000
            onTriggered: {
                root.clearPassword();
                authenticator.startAuthenticating();
            }
        }

        PropertyAnimation {
            id: launchAnimation
            target: lockScreenRoot
            property: "opacity"
            from: 0
            to: 1
            duration: Kirigami.Units.veryLongDuration * 2
        }

        Component.onCompleted: launchAnimation.start();


        WallpaperFader {
            anchors.fill: parent
            state: lockScreenRoot.uiVisible ? "on" : "off"
            source: wallpaper
            mainStack: mainStack
            footer: footer
            clock: clock
            alwaysShowClock: config.alwaysShowClock && !config.hideClockWhenIdle
        }

        DropShadow {
            id: clockShadow
            anchors.fill: clock
            source: clock
            visible: lockScreenUi.isMainScreen && !lockScreenUi.softwareRendering && config.alwaysShowClock
            radius: 7
            verticalOffset: 0.8
            samples: 15
            spread: 0.2
            color : Qt.rgba(0, 0, 0, 0.7)
            opacity: lockScreenRoot.uiVisible ? 0 : 1
            Behavior on opacity {
                OpacityAnimator {
                    duration: Kirigami.Units.veryLongDuration * 2
                    easing.type: Easing.InOutQuad
                }
            }
        }

        Loader {
            id: desktopInfo
            source: "DesktopLockInfo.qml"
        }

        DesktopClock {
            id: clock
            property Item shadow: clockShadow
            // die Shell schreibt DesktopLockInfo.qml (Lockscreen kann keine Dateien lesen, aber QML laden)
            task: desktopInfo.item ? desktopInfo.item.task : ""
            visible: lockScreenUi.isMainScreen && y > 0 && config.alwaysShowClock
            anchors.horizontalCenter: parent.horizontalCenter
            // Desktop: Unterkante 56 px über dem Passwortfeld (das sitzt knapp unter der Mitte des StackViews)
            y: Math.max(parent.height * 0.06, mainStack.y + mainStack.height / 2 - height - 56)
        }

        ListModel {
            id: users

            Component.onCompleted: {
                users.append({
                    name: kscreenlocker_userName,
                    realName: kscreenlocker_userName,
                    icon: kscreenlocker_userImage !== ""
                          ? "file://" + kscreenlocker_userImage.split("/").map(encodeURIComponent).join("/")
                          : "",
                })
            }
        }

        StackView {
            id: mainStack
            anchors {
                left: parent.left
                right: parent.right
            }
            height: lockScreenRoot.height + Kirigami.Units.gridUnit * 3
            focus: true //StackView is an implicit focus scope, so we need to give this focus so the item inside will have it

            // this isn't implicit, otherwise items still get processed for the scenegraph
            visible: opacity > 0

            initialItem: MainBlock {
                id: mainBlock
                lockScreenUiVisible: lockScreenRoot.uiVisible

                showUserList: false // Desktop: ein Nutzer, ruhiger ohne Avatar

                enabled: !graceLockTimer.running

                StackView.onStatusChanged: {
                    // prepare for presenting again to the user
                    if (StackView.status === StackView.Activating) {
                        mainPasswordBox.clear();
                        mainPasswordBox.focus = true;
                        root.notification = "";
                    }
                }
                userListModel: users


                notificationMessage: {
                    const parts = [];
                    if (capsLockState.locked) {
                        parts.push("Caps Lock is on");
                    }
                    if (root.notification) {
                        parts.push(root.notification);
                    }
                    return parts.join(" • ");
                }

                onPasswordResult: password => {
                    authenticator.respond(password)
                }

                actionItems: [
                    DesktopActionButton {
                        text: "Standby"
                        glyph: "bedtime"
                        onClicked: sessionManagement.suspend()
                        visible: sessionManagement.canSuspend
                    },
                    DesktopActionButton {
                        text: "Hibernate"
                        glyph: "mode_standby"
                        onClicked: sessionManagement.hibernate()
                        visible: sessionManagement.canHibernate
                    },
                    DesktopActionButton {
                        text: "Switch user"
                        glyph: "switch_account"
                        onClicked: {
                            sessionManagement.switchUser();
                        }
                        visible: sessionManagement.canSwitchUser
                    }
                ]

                Loader {
                    Layout.topMargin: Kirigami.Units.smallSpacing // some distance to the password field
                    Layout.fillWidth: true
                    Layout.preferredHeight: item ? item.implicitHeight : 0
                    active: config.showMediaControls
                    source: "MediaControls.qml"
                }
            }
        }

        VirtualKeyboardLoader {
            id: inputPanel

            z: 1

            screenRoot: lockScreenRoot
            mainStack: mainStack
            mainBlock: mainBlock
            passwordField: mainBlock.mainPasswordBox
        }

        Loader {
            z: 2
            active: root.viewVisible
            source: "LockOsd.qml"
            anchors {
                horizontalCenter: parent.horizontalCenter
                bottom: parent.bottom
                bottomMargin: Kirigami.Units.gridUnit
            }
        }

        // Note: Containment masks stretch clickable area of their buttons to
        // the screen edges, essentially making them adhere to Fitts's law.
        // Due to virtual keyboard button having an icon, buttons may have
        // different heights, so fillHeight is required.
        //
        // Note for contributors: Keep this in sync with SDDM Main.qml footer.
        RowLayout {
            id: footer
            anchors {
                bottom: parent.bottom
                left: parent.left
                right: parent.right
                margins: Kirigami.Units.smallSpacing
            }
            spacing: Kirigami.Units.smallSpacing

            PlasmaComponents3.ToolButton {
                id: virtualKeyboardButton

                focusPolicy: Qt.TabFocus
                text: "Virtual Keyboard"
                icon.name: inputPanel.keyboardActive ? "input-keyboard-virtual-on" : "input-keyboard-virtual-off"
                onClicked: {
                    // Otherwise the password field loses focus and virtual keyboard
                    // keystrokes get eaten
                    mainBlock.mainPasswordBox.forceActiveFocus();
                    inputPanel.showHide()
                }

                visible: false // Desktop: kein Touchscreen

                Layout.fillHeight: true
                containmentMask: Item {
                    parent: virtualKeyboardButton
                    anchors.fill: parent
                    anchors.leftMargin: -footer.anchors.margins
                    anchors.bottomMargin: -footer.anchors.margins
                }
            }

            PlasmaComponents3.ToolButton {
                id: keyboardButton

                focusPolicy: Qt.TabFocus
                Accessible.description: "Switch layout"
                icon.name: "input-keyboard"

                PW.KeyboardLayoutSwitcher {
                    id: keyboardLayoutSwitcher

                    anchors.fill: parent
                    acceptedButtons: Qt.NoButton
                }

                text: keyboardLayoutSwitcher.layoutNames.longName
                onClicked: keyboardLayoutSwitcher.keyboardLayout.switchToNextLayout()

                visible: keyboardLayoutSwitcher.hasMultipleKeyboardLayouts

                Layout.fillHeight: true
                containmentMask: Item {
                    parent: keyboardButton
                    anchors.fill: parent
                    anchors.leftMargin: virtualKeyboardButton.visible ? 0 : -footer.anchors.margins
                    anchors.bottomMargin: -footer.anchors.margins
                }
            }

            Item {
                Layout.fillWidth: true
            }

            Battery {}
        }
    }

    // Desktop: Entsperren – der Sperrbildschirm teilt sich in der Mitte und gleitet nach oben/unten weg.
    // Darunter liegt das (scharfe) Wallpaper, das dem Desktop-Wallpaper entspricht.
    ShaderEffectSource {
        id: desktopTop
        visible: false
        width: lockScreenUi.width
        height: Math.ceil(lockScreenUi.height / 2)
        sourceItem: lockScreenRoot
        sourceRect: Qt.rect(0, 0, width, height)
        live: false
        hideSource: visible
    }

    ShaderEffectSource {
        id: desktopBottom
        visible: false
        y: desktopTop.height
        width: lockScreenUi.width
        height: lockScreenUi.height - desktopTop.height
        sourceItem: lockScreenRoot
        sourceRect: Qt.rect(0, desktopTop.height, width, height)
        live: false
        hideSource: visible
    }

    Rectangle {
        id: desktopSeam
        anchors.verticalCenter: parent.verticalCenter
        anchors.horizontalCenter: parent.horizontalCenter
        width: 0
        height: 2
        radius: 1
        opacity: 0
        color: DesktopTheme.accent
    }

    SequentialAnimation {
        id: desktopUnlock
        ScriptAction {
            script: {
                desktopTop.scheduleUpdate();
                desktopBottom.scheduleUpdate();
                desktopTop.visible = true;
                desktopBottom.visible = true;
            }
        }
        // Glut-Linie in der Mitte
        ParallelAnimation {
            NumberAnimation { target: desktopSeam; property: "opacity"; to: 1; duration: 140; easing.type: Easing.OutCubic }
            NumberAnimation { target: desktopSeam; property: "width"; to: lockScreenUi.width * 0.6; duration: 180; easing.type: Easing.OutCubic }
        }
        // auffächern
        ParallelAnimation {
            NumberAnimation { target: desktopTop; property: "y"; to: -desktopTop.height; duration: 560; easing.type: Easing.InOutCubic }
            NumberAnimation { target: desktopBottom; property: "y"; to: lockScreenUi.height; duration: 560; easing.type: Easing.InOutCubic }
            NumberAnimation { target: desktopSeam; property: "width"; to: lockScreenUi.width; duration: 300; easing.type: Easing.OutCubic }
            NumberAnimation { target: desktopSeam; property: "opacity"; to: 0; duration: 420; easing.type: Easing.InCubic }
        }
        ScriptAction { script: Qt.quit() }
    }
}

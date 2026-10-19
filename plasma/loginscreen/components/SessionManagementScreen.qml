/*
    SPDX-FileCopyrightText: 2016 David Edmundson <davidedmundson@kde.org>

    SPDX-License-Identifier: LGPL-2.0-or-later

    Desktop: Kopie von org.kde.breeze.components.SessionManagementScreen (plasma-workspace 6.7.5)
    für den Plasma-Login-Greeter, im Look des Lockscreens (MainBlock.qml):
      - Farben aus DesktopTheme (theme/palette.json), Schrift Inter
      - Passwort als Code-Kästchen (wie der Lockscreen, Länge = desktopAutoSubmitLength, automatisch
        prüfen bei voller Länge) für den eigenen Nutzer (LoginConfig.codeUser), sonst Pillen-Feld
      - runder Pfeil-Knopf, Glut nur beim Drücken
    Login.qml (fest im Greeter-Binary) bringt seine eigenen Felder mit (PlasmaExtras.PasswordField,
    PlasmaComponents.TextField/Button). Die werden hier nur umgestylt – Logik, Fokus und Login bleiben
    beim Original. Fehlt etwas (andere Version), bleibt das Feld einfach im Plasma-Look.
*/

import QtQuick

import QtQuick.Layouts

import org.kde.plasma.components as PlasmaComponents3
import org.kde.kirigami as Kirigami

FocusScope {
    id: root

    /*
     * Any message to be displayed to the user, visible above the text fields
     */
    property alias notificationMessage: notificationsLabel.text

    /*
     * A list of Items (typically ActionButtons) to be shown in a Row beneath the prompts
     */
    property alias actionItems: actionItemsLayout.children

    /*
     * Whether to show or hide the list of action items as a whole.
     */
    property alias actionItemsVisible: actionItemsLayout.visible

    /*
     * A model with a list of users to show in the view (see UserList.qml).
     */
    property alias userListModel: userListView.model

    /*
     * Self explanatory
     */
    property alias userListCurrentIndex: userListView.currentIndex
    property alias userListCurrentItem: userListView.currentItem
    property bool showUserList: true

    property alias userList: userListView

    property real fontSize: Kirigami.Theme.defaultFont.pointSize + 2

    default property alias _children: innerLayout.children

    signal userSelected()

    function playHighlightAnimation() {
        bounceAnimation.start();
    }

    // Desktop: Farben aus theme/palette.json statt aus dem Plasma-Farbschema (wie LockScreenUi.qml)
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

    // ---- Desktop: Felder aus Login.qml finden und umstylen -------------------------------------
    property Item desktopPasswordBox: null
    property Item desktopUserBox: null
    property Item desktopLoginButton: null

    readonly property int desktopCodeLength: LoginConfig.codeLength
    // Code-Kästchen nur für den eigenen Nutzer in der Nutzerliste (andere Passwörter sind länger)
    readonly property bool desktopCodeMode: desktopCodeLength > 0
        && desktopPasswordBox !== null && desktopPasswordBox.visible
        && !(desktopUserBox !== null && desktopUserBox.visible)
        && userListView.selectedUser !== ""
        && userListView.selectedUser === LoginConfig.codeUser

    function desktopScan(items, depth) {
        for (let i = 0; i < items.length; ++i) {
            const it = items[i];
            if (!it) {
                continue;
            }
            if (it.echoMode !== undefined && it.showPassword !== undefined) {
                desktopPasswordBox = it;
            } else if (it.echoMode !== undefined) {
                desktopUserBox = it;
            } else if (it.clicked !== undefined && it.icon !== undefined && it.background !== undefined) {
                desktopLoginButton = it;
            } else if (depth < 3 && it.children) {
                desktopScan(it.children, depth + 1);
            }
        }
    }

    function desktopStyleField(field, isPassword) {
        if (field.background !== undefined) {
            field.background = desktopPillComponent.createObject(field, { field: field, isPassword: isPassword });
        }
        if (isPassword) {
            desktopCodeBoxesComponent.createObject(field, { field: field });
            // automatisch prüfen, sobald alle Kästchen voll sind (nur im fokussierten Fenster)
            field.textChanged.connect(() => {
                if (root.desktopCodeMode && field.text.length === root.desktopCodeLength && field.activeFocus) {
                    field.accepted();
                }
            });
            // Augen-Knopf der PasswordField im Code-Modus ausblenden
            if (field.rightActions !== undefined) {
                for (let i = 0; i < field.rightActions.length; ++i) {
                    const action = field.rightActions[i];
                    const wasEnabled = action.enabled;
                    action.visible = Qt.binding(() => wasEnabled && !root.desktopCodeMode);
                }
            }
        }
    }

    function desktopStyleButton(button) {
        button.background = desktopButtonBackground.createObject(button, { button: button });
        if (button.icon !== undefined) {
            button.icon.color = DesktopTheme.accentText;
        }
    }

    Component.onCompleted: {
        desktopScan(innerLayout.children, 0);
        if (desktopPasswordBox) {
            desktopStyleField(desktopPasswordBox, true);
        }
        if (desktopUserBox) {
            desktopStyleField(desktopUserBox, false);
        }
        if (desktopLoginButton) {
            desktopStyleButton(desktopLoginButton);
        }
    }

    // Eigenschaften, die sich mit dem Code-Modus ändern (Bindings stellen beim Abschalten das Original her)
    Binding {
        when: root.desktopPasswordBox !== null
        target: root.desktopPasswordBox
        property: "color"
        value: root.desktopCodeMode ? "transparent" : DesktopTheme.text
        restoreMode: Binding.RestoreBindingOrValue
    }
    Binding {
        when: root.desktopPasswordBox !== null
        target: root.desktopPasswordBox
        property: "maximumLength"
        value: root.desktopCodeMode ? root.desktopCodeLength : 32767
        restoreMode: Binding.RestoreBindingOrValue
    }
    Binding {
        when: root.desktopPasswordBox !== null
        target: root.desktopPasswordBox
        property: "placeholderText"
        value: root.desktopCodeMode ? "" : "Password"
        restoreMode: Binding.RestoreBindingOrValue
    }
    Binding {
        when: root.desktopUserBox !== null
        target: root.desktopUserBox
        property: "color"
        value: DesktopTheme.text
        restoreMode: Binding.RestoreBindingOrValue
    }
    Binding {
        when: root.desktopUserBox !== null
        target: root.desktopUserBox
        property: "placeholderText"
        value: "Username"
        restoreMode: Binding.RestoreBindingOrValue
    }
    Binding {
        // im Code-Modus prüft das letzte Zeichen, der Knopf fällt weg (wie beim Lockscreen)
        when: root.desktopLoginButton !== null
        target: root.desktopLoginButton
        property: "visible"
        value: !root.desktopCodeMode
        restoreMode: Binding.RestoreBindingOrValue
    }

    Component {
        id: desktopPillComponent
        Rectangle {
            required property Item field
            property bool isPassword: false
            visible: !(isPassword && root.desktopCodeMode)
            implicitWidth: 200
            implicitHeight: 52
            radius: height / 2
            color: DesktopTheme.glassStrong
            border.width: field.activeFocus ? 2 : 1
            border.color: field.activeFocus ? DesktopTheme.accent : DesktopTheme.borderStrong
            Component.onCompleted: {
                field.leftPadding = 22;
                field.rightPadding = Qt.binding(() => isPassword ? 16 : 22);
                field.font.family = DesktopTheme.fontUi;
                field.placeholderTextColor = DesktopTheme.textFaint;
                field.selectionColor = DesktopTheme.accentSoft;
                field.selectedTextColor = DesktopTheme.text;
                field.verticalAlignment = Text.AlignVCenter;
            }
        }
    }

    Component {
        id: desktopCodeBoxesComponent
        // Code-Modus = Kästchen wie bei einer Auth-Code-Eingabe (wie MainBlock.qml des Lockscreens)
        Row {
            id: boxes
            required property Item field
            visible: root.desktopCodeMode
            anchors.centerIn: parent
            spacing: 10

            Repeater {
                model: root.desktopCodeLength

                Rectangle {
                    required property int index
                    readonly property bool filled: index < boxes.field.length
                    readonly property bool current: index === boxes.field.length && boxes.field.activeFocus

                    width: 40
                    height: 50
                    radius: 12
                    color: DesktopTheme.glassStrong
                    border.width: current ? 2 : 1
                    border.color: current ? DesktopTheme.accent : filled ? DesktopTheme.woodLight : DesktopTheme.borderStrong

                    Behavior on border.color { ColorAnimation { duration: 120 } }

                    Text {
                        anchors.centerIn: parent
                        text: !parent.filled ? "" : boxes.field.showPassword ? boxes.field.text.charAt(parent.index) : "•"
                        color: DesktopTheme.text
                        font.family: DesktopTheme.fontMono
                        font.pixelSize: 22
                    }
                }
            }
        }
    }

    Component {
        id: desktopButtonBackground
        // runder Knopf, Glut nur beim Drücken
        Rectangle {
            required property Item button
            implicitWidth: 52
            implicitHeight: 52
            radius: height / 2
            color: button.down ? DesktopTheme.accent : DesktopTheme.accentSoft
            border.width: 1
            border.color: button.activeFocus ? DesktopTheme.accent : DesktopTheme.border
        }
    }
    // --------------------------------------------------------------------------------------------

    // FIXME: move this component into a layout, rather than abusing
    // anchors and implicitly relying on other components' built-in
    // whitespace to avoid items being overlapped.
    UserList {
        id: userListView
        visible: root.showUserList && y > 0
        anchors {
            bottom: parent.verticalCenter
            // We only need an extra bottom margin when text is constrained,
            // since only in this case can the username label be a multi-line
            // string that would otherwise overflow.
            bottomMargin: constrainText ? Kirigami.Units.gridUnit * 3 : 0
            left: parent.left
            right: parent.right
        }
        fontSize: root.fontSize
        // bubble up the signal
        onUserSelected: root.userSelected()
    }

    //goal is to show the prompts, in ~16 grid units high, then the action buttons
    //but collapse the space between the prompts and actions if there's no room
    //ui is constrained to 16 grid units wide, or the screen
    ColumnLayout {
        id: prompts
        anchors.top: parent.verticalCenter
        anchors.topMargin: Kirigami.Units.largeSpacing
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        spacing: Kirigami.Units.largeSpacing

        Text {
            id: notificationsLabel
            Layout.maximumWidth: Kirigami.Units.gridUnit * 16
            Layout.alignment: Qt.AlignHCenter
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            textFormat: Text.PlainText
            wrapMode: Text.WordWrap
            color: DesktopTheme.accentText
            font.family: DesktopTheme.fontUi
            font.pixelSize: 14
            visible: text !== ""

            SequentialAnimation {
                id: bounceAnimation
                loops: 1
                PropertyAnimation {
                    target: notificationsLabel
                    properties: "scale"
                    from: 1.0
                    to: 1.1
                    duration: Kirigami.Units.longDuration
                    easing.type: Easing.OutQuad
                }
                PropertyAnimation {
                    target: notificationsLabel
                    properties: "scale"
                    from: 1.1
                    to: 1.0
                    duration: Kirigami.Units.longDuration
                    easing.type: Easing.InQuad
                }
            }
        }
        ColumnLayout {
            Layout.minimumHeight: implicitHeight
            Layout.maximumHeight: Kirigami.Units.gridUnit * 10
            Layout.maximumWidth: Kirigami.Units.gridUnit * 18
            Layout.alignment: Qt.AlignHCenter
            ColumnLayout {
                id: innerLayout
                Layout.alignment: Qt.AlignHCenter
                Layout.fillWidth: true
                spacing: Kirigami.Units.largeSpacing
            }
            Item {
                Layout.fillHeight: true
            }
        }
        Item {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: Kirigami.Units.gridUnit
            implicitHeight: actionItemsLayout.implicitHeight
            implicitWidth: actionItemsLayout.implicitWidth
            GridLayout {
                id: actionItemsLayout
                anchors.centerIn: parent

                readonly property int spacing: Kirigami.Units.largeSpacing
                rowSpacing: spacing
                columnSpacing: spacing

                readonly property int buttonCount: visibleChildren.length
                readonly property int singleRowWidth: buttonCount > 0 ? (children[0].implicitWidth * buttonCount) + (spacing * (buttonCount - 1)) : 0
                columns: Math.max(1, singleRowWidth < root.width ? buttonCount : Math.ceil(buttonCount / 2))
            }
        }
        Item {
            Layout.fillHeight: true
        }
    }
}

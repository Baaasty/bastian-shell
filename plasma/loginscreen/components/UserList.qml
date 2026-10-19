/*
    SPDX-FileCopyrightText: 2014 David Edmundson <davidedmundson@kde.org>

    SPDX-License-Identifier: LGPL-2.0-or-later

    Desktop: Kopie von org.kde.breeze.components.UserList (plasma-workspace 6.7.5) für den Login-Greeter.
    Geändert: kompakter – bei einem Nutzer nur der Name (ruhig wie der Lockscreen, der gar keinen
    Avatar zeigt), bei mehreren kleine runde Avatare. API (selectedUser, userSelected, constrainText …)
    unverändert, Login.qml im Greeter-Binary braucht sie.
*/
pragma ComponentBehavior: Bound

import QtQuick

import org.kde.kirigami as Kirigami

ListView {
    id: view
    readonly property string selectedUser: currentItem ? (currentItem as UserDelegate).userName : ""
    // Desktop: ein Nutzer = nur eine Namenszeile
    readonly property bool desktopSingle: count <= 1
    readonly property int userItemWidth: desktopSingle ? Kirigami.Units.gridUnit * 16 : Kirigami.Units.gridUnit * 7
    readonly property int userItemHeight: desktopSingle ? Kirigami.Units.gridUnit * 2 : Kirigami.Units.gridUnit * 6
    readonly property bool constrainText: count > 1
    property real fontSize: Kirigami.Theme.defaultFont.pointSize + 2

    implicitHeight: userItemHeight

    activeFocusOnTab: true

    /*
     * Signals that a user was explicitly selected
     */
    signal userSelected()

    orientation: ListView.Horizontal
    highlightRangeMode: ListView.StrictlyEnforceRange

    //centre align selected item (which implicitly centre aligns the rest
    preferredHighlightBegin: width/2 - userItemWidth/2
    preferredHighlightEnd: preferredHighlightBegin

    // Disable flicking if we only have on user (like on the lockscreen)
    interactive: count > 1

    delegate: UserDelegate {
        id: userDelegate
        required property int index
        required property string icon
        required property string realName
        required property var model
        avatarPath: icon || ""
        iconSource: model.iconName || "user-identity"
        fontSize: view.fontSize
        needsPassword: model.needsPassword !== undefined ? model.needsPassword : true
        single: view.desktopSingle

        name: realName || model.name || ""

        userName: model.name || ""

        width: view.userItemWidth
        height: view.userItemHeight

        //if we only have one delegate, we don't need to clip the text as it won't be overlapping with anything
        constrainText: view.constrainText

        isCurrent: ListView.isCurrentItem

        onClicked: {
            view.currentIndex = index;
            view.userSelected();
        }
    }

    Keys.onEscapePressed: view.userSelected()
    Keys.onEnterPressed: view.userSelected()
    Keys.onReturnPressed: view.userSelected()
}

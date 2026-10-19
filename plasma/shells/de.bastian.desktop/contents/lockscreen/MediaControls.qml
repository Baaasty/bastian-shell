/*
    SPDX-FileCopyrightText: 2016 Kai Uwe Broulik <kde@privat.broulik.de>
    Desktop: Glaskarte mit Cover, Titel und Material-Symbolen statt Plasma-Knöpfen.

    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Layouts

import org.kde.plasma.private.mpris as Mpris

Item {
    visible: instantiator.count > 0
    implicitHeight: 64
    implicitWidth: 320

    component Glyph: Text {
        id: glyph
        property alias hovered: area.containsMouse
        signal clicked()
        font.family: "Material Symbols Rounded"
        color: !enabled ? DesktopTheme.textFaint : area.containsMouse ? DesktopTheme.accentText : DesktopTheme.textMuted
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        Behavior on color { ColorAnimation { duration: 120 } }
        MouseArea {
            id: area
            anchors.fill: parent
            anchors.margins: -6
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                fadeoutTimer.running = false;
                glyph.clicked();
            }
        }
    }

    Repeater {
        id: instantiator
        model: Mpris.MultiplexerModel { }

        Rectangle {
            anchors.fill: parent
            radius: 16
            color: DesktopTheme.glassStrong
            border.width: 1
            border.color: DesktopTheme.border
            enabled: model.canControl

            RowLayout {
                anchors.fill: parent
                anchors.margins: 8
                anchors.rightMargin: 14
                spacing: 12

                Rectangle {
                    Layout.preferredWidth: 48
                    Layout.preferredHeight: 48
                    radius: 10
                    color: DesktopTheme.wood
                    clip: true
                    Image {
                        anchors.fill: parent
                        visible: status === Image.Ready
                        asynchronous: true
                        fillMode: Image.PreserveAspectCrop
                        source: model.artUrl
                        sourceSize.height: 96
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2
                    Text {
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                        text: model.track.length > 0 ? model.track : "Nothing playing"
                        textFormat: Text.PlainText
                        color: DesktopTheme.text
                        font.family: DesktopTheme.fontUi
                        font.pixelSize: 14
                        font.weight: Font.Medium
                    }
                    Text {
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                        text: model.artist || model.identity
                        textFormat: Text.PlainText
                        color: DesktopTheme.textMuted
                        font.family: DesktopTheme.fontUi
                        font.pixelSize: 12
                    }
                }

                Glyph {
                    visible: model.canGoBack || model.canGoNext
                    enabled: model.canGoPrevious
                    text: "skip_previous"
                    font.pixelSize: 22
                    onClicked: model.container.Previous()
                }
                Glyph {
                    text: model.playbackStatus === Mpris.PlaybackStatus.Playing ? "pause" : "play_arrow"
                    font.pixelSize: 28
                    color: hovered ? DesktopTheme.accentText : DesktopTheme.text
                    onClicked: model.container.PlayPause()
                }
                Glyph {
                    visible: model.canGoBack || model.canGoNext
                    enabled: model.canGoNext
                    text: "skip_next"
                    font.pixelSize: 22
                    onClicked: model.container.Next()
                }
            }
        }
    }
}

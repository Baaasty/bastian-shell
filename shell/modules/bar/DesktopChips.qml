import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.services
import qs.components

// Desktops: Klick wechselt, Doppelklick benennt um, Rechtsklick = Menü (Umbenennen / Entfernen), "+" = neuer leerer Desktop
Row {
    id: root

    property var barWindow
    property string menuFor: ""

    spacing: 2

    function rename(id, index) {
        Prompt.ask("edit", "Name this workspace", Desktops.names[index] ?? "", text => {
            if (text.trim() !== "")
                Desktops.rename(id, text.trim());
        });
    }

    Repeater {
        model: Desktops.ids

        Chip {
            id: chip

            required property var modelData
            required property int index
            readonly property bool isCurrent: modelData === Desktops.current

            active: isCurrent
            onClicked: mouse => {
                if (mouse.button === Qt.RightButton) {
                    root.menuFor = modelData;
                    menu.anchor.item = chip;
                    menu.visible = true;
                } else
                    Desktops.switchTo(modelData);
            }
            onDoubleClicked: mouse => {
                if (mouse.button === Qt.LeftButton)
                    root.rename(modelData, index);
            }

            Txt {
                anchors.verticalCenter: parent.verticalCenter
                text: Desktops.names[chip.index] ?? ""
                color: chip.isCurrent ? Theme.text : Theme.textMuted
            }
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                visible: chip.isCurrent
                width: 6
                height: 6
                radius: 3
                color: Theme.accent
            }
        }
    }

    Chip {
        padding: 7
        onClicked: Desktops.add("", null)

        Icon {
            anchors.verticalCenter: parent.verticalCenter
            name: "add"
            size: 17
        }
    }

    // ---------- Rechtsklick-Menü ----------
    PopupWindow {
        id: menu

        anchor.window: root.barWindow
        anchor.edges: Edges.Bottom
        anchor.gravity: Edges.Bottom
        anchor.margins.top: 8
        grabFocus: true
        implicitWidth: 200
        implicitHeight: col.implicitHeight + 12
        color: "transparent"
        onVisibleChanged: if (root.barWindow) root.barWindow.openMenus += visible ? 1 : -1

        BackgroundEffect.blurRegion: Region {
            Region { x: 0; y: 0; width: 1; height: 1 }
            Region { item: card; radius: Theme.radiusMd }
        }

        Glass {
            id: card
            anchors.fill: parent
            strong: true
            radius: Theme.radiusMd

            Column {
                id: col
                x: 6
                y: 6
                width: parent.width - 12

                Repeater {
                    model: [
                        { icon: "edit", text: "Rename", danger: false },
                        { icon: "delete", text: "Remove", danger: true }
                    ]
                    Chip {
                        required property var modelData
                        width: col.width
                        alignLeft: true
                        height: 34
                        visible: !modelData.danger || Desktops.count > 1
                        onClicked: {
                            const id = root.menuFor;
                            menu.visible = false;
                            if (modelData.danger)
                                Desktops.remove(id);
                            else
                                root.rename(id, Desktops.ids.indexOf(id));
                        }
                        Icon {
                            anchors.verticalCenter: parent.verticalCenter
                            name: modelData.icon
                            size: 17
                            color: modelData.danger ? Theme.error : Theme.textMuted
                        }
                        Txt {
                            anchors.verticalCenter: parent.verticalCenter
                            text: modelData.text
                            color: modelData.danger ? Theme.error : Theme.text
                        }
                    }
                }
            }
        }
    }
}

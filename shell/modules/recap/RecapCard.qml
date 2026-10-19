import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.config
import qs.services
import qs.components
import qs.modules.morning

// Tagesrückblick (Doku docs/PROJECTTIME.md): „das hast du heute geschafft“ – im Look der Morgen-Übersicht.
// Commits, Projektzeit, Fokus, abgehakte To-dos, fertige Claude-Aufgaben; Bereiche ohne Inhalt fehlen.
// Kommt mit der Feierabend-Szene (Super+Alt+B) oder per Super+Alt+R / IPC recap open.
// Schließt per Klick, Esc/Enter/Leertaste oder nach Recap.closeSec (Überfahren hält sie offen).
Scope {
    id: root

    property string screenName: Config.mainScreen
    property real remaining: 1

    readonly property string who: {
        const u = Quickshell.env("USER") || "";
        return u ? u.charAt(0).toUpperCase() + u.slice(1) : "";
    }

    // ---------- Inhalte ----------
    readonly property var c: Recap.commits
    readonly property int commitCount: c ? c.total : 0
    readonly property var commitLines: c ? c.projects.slice(0, 4).map(p => ({ left: String(p.count), text: p.name + "  ·  " + (p.commits[0] ? p.commits[0].subject : "") })) : []

    readonly property var timeList: ProjectTime.todayList
    readonly property var timeLines: timeList.slice(0, 4).map(p => ({ left: ProjectTime.hm(p.sec), text: p.name }))

    readonly property var todos: Recap.todosDone
    readonly property var todoLines: todos.slice(-3).reverse().map(t => ({ left: "", text: t.text + (t.list !== Todos.general ? "  ·  " + t.list : "") }))

    readonly property var claude: Recap.claudeDone
    readonly property var claudeLines: claude.slice(0, 3).map(t => ({ left: "", text: (t.title || "Task") + (t.project ? "  ·  " + t.project : "") }))

    readonly property bool empty: commitCount === 0 && timeList.length === 0 && todos.length === 0 && claude.length === 0 && Focus.focusMin < 1

    function plural(n: int, one: string, many: string): string {
        return n + " " + (n === 1 ? one : many);
    }
    function projectsIn(n: int): string {
        return n > 1 ? " in " + n + " projects" : "";
    }

    Connections {
        target: Recap
        function onOpenChanged() {
            if (Recap.open) {
                root.screenName = Hyprland.focusedMonitor?.name ?? Config.mainScreen;
                root.remaining = 1;
            }
        }
    }
    Timer {
        interval: 100
        repeat: true
        running: Recap.open
        onTriggered: {
            if (hoverState.hovered)
                return;
            root.remaining = Math.max(0, root.remaining - 0.1 / Recap.closeSec);
            if (root.remaining <= 0)
                Recap.hide();
        }
    }
    QtObject {
        id: hoverState
        property bool hovered: false
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: win

            required property var modelData

            screen: modelData
            visible: Recap.open && modelData.name === root.screenName
            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }
            exclusionMode: ExclusionMode.Ignore
            color: "transparent"
            WlrLayershell.namespace: "dock"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

            onVisibleChanged: if (visible) keys.forceActiveFocus()

            Rectangle {
                anchors.fill: parent
                color: Qt.alpha(Theme.dim, 0.45)
                opacity: win.visible ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: Theme.fade; easing.type: Easing.OutCubic } }
                MouseArea {
                    anchors.fill: parent
                    onClicked: Recap.hide()
                }
            }

            FocusScope {
                id: keys
                anchors.fill: parent
                focus: true
                Keys.onPressed: event => {
                    if (event.key === Qt.Key_Escape || event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
                        Recap.hide();
                        event.accepted = true;
                    }
                }
            }

            Glass {
                id: card
                strong: true
                radius: Theme.radiusXl
                width: 540
                height: col.implicitHeight + 64
                x: (parent.width - width) / 2
                y: Math.round(Math.max(40, (parent.height - height) * 0.3))
                opacity: win.visible ? 1 : 0
                scale: win.visible ? 1 : 0.97
                Behavior on opacity { NumberAnimation { duration: Theme.slide; easing.type: Easing.OutCubic } }
                Behavior on scale { NumberAnimation { duration: Theme.slide; easing.type: Easing.OutCubic } }

                HoverHandler {
                    onHoveredChanged: hoverState.hovered = hovered
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Recap.hide()
                }

                Column {
                    id: col
                    x: 32
                    y: 30
                    width: parent.width - 64
                    spacing: 22

                    Column {
                        width: parent.width
                        spacing: 4
                        SystemClock {
                            id: clock
                            precision: SystemClock.Minutes
                            enabled: win.visible
                        }
                        Txt {
                            width: parent.width
                            text: (root.empty ? "A quiet day" : "Nice work today") + (root.who ? ", " + root.who : "")
                            font.pixelSize: 26
                            font.weight: Font.DemiBold
                        }
                        Txt {
                            width: parent.width
                            text: Qt.formatDate(clock.date, "dddd, d MMMM") + "  ·  here's what you got done"
                            color: Theme.textMuted
                            font.weight: Font.Normal
                        }
                    }

                    MorningRow {
                        visible: root.commitCount > 0 || Recap.commitsLoading
                        icon: "commit"
                        title: root.commitCount > 0 ? root.plural(root.commitCount, "commit", "commits") + root.projectsIn(root.c.projects.length) : "Counting commits…"
                        lines: root.commitLines
                        more: root.c && root.c.projects.length > 4 ? "+ " + (root.c.projects.length - 4) + " more projects" : ""
                    }
                    MorningRow {
                        visible: root.timeList.length > 0
                        icon: "schedule"
                        title: ProjectTime.fmt(ProjectTime.todaySec) + " on projects"
                        lines: root.timeLines
                        more: root.timeList.length > 4 ? "+ " + (root.timeList.length - 4) + " more" : ""
                    }
                    MorningRow {
                        visible: Focus.focusMin >= 1 || Focus.screenMin >= 1
                        icon: "timer"
                        title: Focus.focusMin >= 1 ? ProjectTime.fmt(Focus.focusMin * 60) + " in focus" : "No focus blocks today"
                        lines: [{ left: "", text: "Screen time " + ProjectTime.fmt(Focus.screenMin * 60) + (Focus.focusMin >= Focus.goalMin ? "  ·  daily goal reached" : "") }]
                    }
                    MorningRow {
                        visible: root.todos.length > 0
                        icon: "task_alt"
                        title: root.plural(root.todos.length, "to-do", "to-dos") + " ticked off"
                        lines: root.todoLines
                        more: root.todos.length > 3 ? "+ " + (root.todos.length - 3) + " more" : ""
                    }
                    MorningRow {
                        visible: root.claude.length > 0
                        icon: "smart_toy"
                        title: root.plural(root.claude.length, "Claude task", "Claude tasks") + " finished"
                        lines: root.claudeLines
                        more: root.claude.length > 3 ? "+ " + (root.claude.length - 3) + " more" : ""
                    }
                    MorningRow {
                        visible: root.empty && !Recap.commitsLoading
                        icon: "local_cafe"
                        title: "Nothing tracked today, and that's fine"
                        lines: [{ left: "", text: "Rest counts too." }]
                    }

                    Column {
                        width: parent.width
                        spacing: 8
                        Rectangle {
                            width: parent.width
                            height: 3
                            radius: 1.5
                            color: Theme.raise
                            Rectangle {
                                width: parent.width * root.remaining
                                height: parent.height
                                radius: parent.radius
                                color: Qt.alpha(Theme.accent, 0.55)
                            }
                        }
                        Row {
                            width: parent.width
                            Txt {
                                width: parent.width / 2
                                text: "Time to wind down. See you tomorrow."
                                color: Theme.textFaint
                                font.pixelSize: 12
                                font.weight: Font.Normal
                            }
                            Txt {
                                width: parent.width / 2
                                text: "Click, Esc or Enter to close"
                                color: Theme.textFaint
                                font.pixelSize: 12
                                font.weight: Font.Normal
                                horizontalAlignment: Text.AlignRight
                            }
                        }
                    }
                }
            }
        }
    }
}

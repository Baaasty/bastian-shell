import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.config
import qs.services
import qs.components

// Morgen-Übersicht (Doku docs/MORNING.md): eine ruhige Karte mit Begrüßung, Terminen, Mails, Wetter, To-dos, Inbox.
// Schließt per Klick, Esc, Enter/Leertaste oder nach Morning.closeSec Sekunden (Überfahren hält sie offen).
// Auslöser und Zeitfenster: services/Morning.qml. Von Hand zeigen: qs ipc … call morning open.
// Tastatur: Esc/Enter gehen, sobald die Karte den Fokus hat (Layer-Shell „OnDemand“ – nach Überfahren/Klick); Klick geht immer.
Scope {
    id: root

    property string screenName: Config.mainScreen
    property real remaining: 1      // 1 → 0 über closeSec

    readonly property string who: {
        const u = Quickshell.env("USER") || "";
        return u ? u.charAt(0).toUpperCase() + u.slice(1) : "";
    }

    // ---------- Inhalte (alles aus den vorhandenen Diensten, nichts wird geladen oder gelogged) ----------
    readonly property var events: Agenda.todayAllDay.concat(Agenda.todayTimed.slice().sort((a, b) => a.start - b.start))
    readonly property bool calendarOk: Agenda.configured
    readonly property var eventLines: events.slice(0, 4).map(e => ({ left: e.allDay ? "All day" : Qt.formatTime(new Date(e.start), "HH:mm"), text: e.title || "(no title)" }))

    readonly property bool mailOk: Mail.configured
    readonly property var mailLines: Mail.latest.slice(0, 2).map(m => ({ left: "", text: (m.from || "?") + " – " + (m.subject || "(no subject)") }))

    readonly property var openTodos: {
        const names = Object.keys(Todos.lists).sort((a, b) => a === Todos.general ? -1 : b === Todos.general ? 1 : a.localeCompare(b));
        const out = [];
        for (const n of names)
            for (const t of Todos.openItems(n))
                out.push({ list: n, text: t.text });
        return out;
    }
    readonly property var todoLines: openTodos.slice(0, 3).map(t => ({ left: "", text: t.text + (t.list !== Todos.general ? "  ·  " + t.list : "") }))
    readonly property int dueCal: Agenda.dueTodos.length

    function plural(n: int, one: string, many: string): string {
        return n + " " + (n === 1 ? one : many);
    }

    Connections {
        target: Morning
        function onOpenChanged() {
            if (Morning.open) {
                root.screenName = Hyprland.focusedMonitor?.name ?? Config.mainScreen;
                root.remaining = 1;
            }
        }
    }
    // Restzeit: läuft nur, solange die Maus nicht auf der Karte liegt
    Timer {
        interval: 100
        repeat: true
        running: Morning.open
        onTriggered: {
            if (hoverState.hovered)
                return;
            root.remaining = Math.max(0, root.remaining - 0.1 / Morning.closeSec);
            if (root.remaining <= 0)
                Morning.hide();
        }
    }
    // Hover-Zustand liegt in der Karte des sichtbaren Fensters; hier nur der Spiegel
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
            visible: Morning.open && modelData.name === root.screenName
            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }
            exclusionMode: ExclusionMode.Ignore
            color: "transparent"
            WlrLayershell.namespace: "dock"   // ohne Öffnen-Animation des Compositors, die Karte blendet selbst ein
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

            onVisibleChanged: if (visible) keys.forceActiveFocus()

            // sanft abgedunkelt; Klick irgendwo schließt
            Rectangle {
                anchors.fill: parent
                color: Qt.alpha(Theme.dim, 0.45)
                opacity: win.visible ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: Theme.fade; easing.type: Easing.OutCubic } }
                MouseArea {
                    anchors.fill: parent
                    onClicked: Morning.hide()
                }
            }

            FocusScope {
                id: keys
                anchors.fill: parent
                focus: true
                Keys.onPressed: event => {
                    if (event.key === Qt.Key_Escape || event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
                        Morning.hide();
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
                // Klick auf die Karte schließt ebenfalls
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Morning.hide()
                }

                Column {
                    id: col
                    x: 32
                    y: 30
                    width: parent.width - 64
                    spacing: 22

                    // Begrüßung
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
                            text: Morning.greeting(clock.date) + (root.who ? ", " + root.who : "")
                            font.pixelSize: 26
                            font.weight: Font.DemiBold
                        }
                        Txt {
                            width: parent.width
                            text: Qt.formatDate(clock.date, "dddd, d MMMM")
                            color: Theme.textMuted
                            font.weight: Font.Normal
                        }
                    }

                    MorningRow {
                        visible: root.calendarOk
                        icon: "event"
                        title: root.events.length === 0 ? "Nothing in your calendar today" : root.plural(root.events.length, "appointment", "appointments") + " today"
                        lines: root.eventLines
                        more: root.events.length > 4 ? "+ " + (root.events.length - 4) + " more" : ""
                    }
                    MorningRow {
                        visible: root.mailOk
                        icon: Mail.total > 0 ? "mark_email_unread" : "drafts"
                        title: Mail.total === 0 ? "No new mail" : Mail.total + " unread"
                        lines: root.mailLines
                    }
                    MorningRow {
                        visible: Weather.ready
                        icon: Weather.icon(Weather.code, Weather.isDay)
                        title: Math.round(Weather.temp) + "°  " + Weather.label(Weather.code)
                        lines: [{ left: "", text: "Feels like " + Math.round(Weather.feels) + "°" }]
                    }
                    MorningRow {
                        visible: root.openTodos.length > 0 || root.dueCal > 0
                        icon: "checklist"
                        title: root.plural(root.openTodos.length + root.dueCal, "open to-do", "open to-dos") + (root.dueCal > 0 ? "  ·  " + root.dueCal + " due today" : "")
                        lines: root.todoLines
                        more: root.openTodos.length > 3 ? "+ " + (root.openTodos.length - 3) + " more" : ""
                    }
                    MorningRow {
                        visible: Notes.openCount > 0
                        icon: "edit_note"
                        title: root.plural(Notes.openCount, "note", "notes") + " waiting in your inbox"
                    }

                    // Fuß: Hinweis + Restzeit
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
                        Txt {
                            width: parent.width
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

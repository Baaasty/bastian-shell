import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services
import qs.components

// Agenda in drei Spalten: links heute + nächste Tage kompakt in einer Liste (Tagesname nur am ersten
// Termin des Tages, heute mit Jetzt-Markierung), Mitte Monatskalender mit KW (Klick auf einen Tag zeigt
// links dessen Termine), rechts offene To-dos (fällig heute/überfällig). Klick auf einen Termin öffnet Thunderbird.
// Daten: Agenda-Service (CalDAV über scripts/agenda-status).
Tile {
    id: tile

    readonly property var okAccounts: Agenda.accounts.filter(a => a.status === "ok")
    readonly property bool ready: Agenda.configured && okAccounts.length > 0
    readonly property int rowH: 28
    readonly property int headH: 26    // Spaltenüberschrift + Abstand
    readonly property int maxRows: Math.max(1, Math.floor((height - 74 - headH) / rowH))

    // im Kalender gewählter Tag (Mitternacht ms), 0 = heute + nächste Tage
    property real selected: 0
    readonly property bool picking: selected > 0
    // Spaltenbreiten der Agenda-Liste
    readonly property int dayW: picking ? 0 : 72
    readonly property int timeW: 48

    title: "Agenda"
    note: ready && Agenda.problems.length ? Agenda.problems[0].label + " · " + (Agenda.problems[0].error || Agenda.problems[0].status) : ""

    // Dashboard zu → beim nächsten Öffnen wieder heute
    readonly property bool shown: Window.window ? Window.window.visible : false
    onShownChanged: if (!shown) {
        selected = 0;
        cal.reset();
    }

    function hm(t: real): string {
        return Qt.formatTime(new Date(t), "HH:mm");
    }
    function dayLabel(t: real): string {
        if (t === Agenda.dayStart)
            return "Today";
        if (t === Agenda.dayEnd)
            return "Tomorrow";
        const d = new Date(t);
        return Mail.dayNames[d.getDay()] + " " + d.getDate();
    }
    function longDay(t: real): string {
        const d = new Date(t);
        const y = d.getFullYear() !== new Date(Agenda.now).getFullYear() ? " " + d.getFullYear() : "";
        return Mail.dayNames[d.getDay()] + " " + d.getDate() + " " + Mail.monthNames[d.getMonth()] + y;
    }
    function dueLabel(t: real): string {
        const days = Math.round((Agenda.dayOf(Agenda.now) - Agenda.dayOf(t)) / 86400000);
        return days <= 0 ? "today" : days + "d late";
    }
    // Termin -> Listenzeile mit vergangen/läuft relativ zu jetzt
    function makeRow(e: var, day: real): var {
        const past = e.end > e.start ? e.end <= Agenda.now : e.start < Agenda.now;
        const live = !e.allDay && e.start <= Agenda.now && e.end > Agenda.now;
        return Object.assign({ kind: "event", day: day, past: past, live: live }, e);
    }
    // Tagesname nur an der ersten sichtbaren Zeile eines Tages
    function labelRows(rows: var): var {
        let last = -1;
        for (const r of rows) {
            r.label = r.kind !== "now" && r.kind !== "more" && r.day >= 0 && r.day !== last ? tile.dayLabel(r.day) : "";
            if (r.kind !== "now" && r.kind !== "more")
                last = r.day;
        }
        return rows;
    }
    // zu viele Zeilen? erst Vergangenes von heute weg, dann hinten "+n more"
    function fit(rows: var, cap: int): var {
        const weight = rs => rs.reduce((n, r) => n + (r.kind === "now" ? 0.5 : 1), 0);
        while (weight(rows) > cap) {
            const i = rows.findIndex(r => r.kind === "event" && r.past);
            if (i < 0)
                break;
            rows.splice(i, 1);
        }
        // Jetzt-Marke ganz vorne sagt nichts
        while (rows.length && rows[0].kind === "now")
            rows.shift();
        if (weight(rows) > cap) {
            let keep = rows.slice();
            while (keep.length && weight(keep) > cap - 1)
                keep.pop();
            while (keep.length && keep[keep.length - 1].kind === "now")
                keep.pop();
            const hidden = rows.slice(keep.length).filter(r => r.kind === "event").length;
            rows = keep.concat([{ kind: "more", more: hidden }]);
        }
        return rows;
    }

    // Standard: heute (ganztägig zuerst, Jetzt-Marke zwischen Vergangenem und Kommendem), dann die nächsten Tage
    readonly property var agendaRows: {
        if (picking)
            return [];
        const rows = [];
        const day = Agenda.dayStart;
        for (const e of Agenda.todayAllDay)
            rows.push(makeRow(e, day));
        let marked = false;
        for (const e of Agenda.todayTimed) {
            if (!marked && e.start > Agenda.now) {
                rows.push({ kind: "now", day: day });
                marked = true;
            }
            rows.push(makeRow(e, day));
        }
        if (!marked && Agenda.todayTimed.length)
            rows.push({ kind: "now", day: day });
        if (Agenda.today.length === 0)
            rows.push({ kind: "note", day: day, text: "Nothing today." });
        for (const g of Agenda.upcoming)
            for (const e of g.events)
                rows.push(makeRow(e, g.day));
        if (Agenda.upcoming.length === 0)
            rows.push({ kind: "note", day: -2, text: "Free week ahead." });
        return labelRows(fit(rows, maxRows));
    }

    // gewählter Tag: alle Termine dieses Tages
    readonly property var dayRows: {
        if (!picking)
            return [];
        const evs = Agenda.eventsOn(selected).slice().sort((a, b) => (b.allDay - a.allDay) || (a.start - b.start));
        const rows = evs.map(e => makeRow(e, selected));
        if (!rows.length)
            rows.push({ kind: "note", day: selected, text: Agenda.synced(selected) ? "Nothing planned." : "Not synced this far." });
        return labelRows(fit(rows, maxRows));
    }
    readonly property var listRows: picking ? dayRows : agendaRows

    readonly property var dueRows: Agenda.dueTodos.length > maxRows
        ? Agenda.dueTodos.slice(0, maxRows - 1).concat([{ more: Agenda.dueTodos.length - (maxRows - 1) }])
        : Agenda.dueTodos

    // ---------- Bausteine ----------

    // leiser Platzhalter mitten in der Spalte
    component Empty: Column {
        property string icon
        property string text
        property string sub
        anchors.centerIn: parent
        spacing: 6
        Icon {
            anchors.horizontalCenter: parent.horizontalCenter
            name: parent.icon
            size: 22
            color: Theme.textFaint
        }
        Txt {
            anchors.horizontalCenter: parent.horizontalCenter
            text: parent.text
            color: Theme.textFaint
            font.weight: Font.Normal
        }
        MonoTxt {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: parent.sub !== ""
            text: parent.sub
            color: Theme.textFaint
            font.pixelSize: 12
        }
    }

    // Zeile mit Hover, Klick = Thunderbird
    component ClickRow: Rectangle {
        id: cr
        default property alias content: inner.data
        property bool clickable: Mail.clientInstalled
        width: parent ? parent.width : 0
        height: tile.rowH
        radius: Theme.radiusSm
        color: ma.containsMouse && clickable ? Theme.raise : "transparent"
        Behavior on color { ColorAnimation { duration: Theme.fade } }
        Item {
            id: inner
            anchors.fill: parent
            anchors.leftMargin: 6
            anchors.rightMargin: 6
        }
        MouseArea {
            id: ma
            anchors.fill: parent
            hoverEnabled: true
            enabled: cr.clickable
            cursorShape: Qt.PointingHandCursor
            onClicked: Agenda.openClient()
        }
    }

    // ---------- ohne Konto: leiser Hinweis ----------
    AccountHint {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        visible: !tile.ready
        status: Agenda.status
        problems: Agenda.problems
    }

    RowLayout {
        anchors.fill: parent
        visible: tile.ready
        spacing: 20

        // ================= Agenda (heute + nächste Tage / gewählter Tag) =================
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.preferredWidth: 5

            Label {
                id: listHead
                text: tile.picking ? tile.longDay(tile.selected) : "Coming up"
                color: tile.picking ? Theme.textMuted : Theme.textFaint
            }
            // Weg zurück aus der Tagesansicht
            Rectangle {
                anchors.right: parent.right
                anchors.verticalCenter: listHead.verticalCenter
                visible: tile.picking
                width: backRow.implicitWidth + 14
                height: 22
                radius: Theme.radiusSm
                color: backMa.containsMouse ? Theme.raise : "transparent"
                Behavior on color { ColorAnimation { duration: Theme.fade } }
                Row {
                    id: backRow
                    anchors.centerIn: parent
                    spacing: 4
                    Icon {
                        anchors.verticalCenter: parent.verticalCenter
                        name: "arrow_back"
                        size: 14
                        color: backMa.containsMouse ? Theme.text : Theme.textFaint
                    }
                    Txt {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Today"
                        color: backMa.containsMouse ? Theme.text : Theme.textFaint
                        font.pixelSize: 12
                    }
                }
                MouseArea {
                    id: backMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        tile.selected = 0;
                        cal.reset();
                    }
                }
            }

            Item {
                anchors.fill: parent
                anchors.topMargin: tile.headH

                Column {
                    id: listCol
                    width: parent.width

                    Repeater {
                        model: tile.listRows

                        Loader {
                            required property var modelData
                            width: listCol.width
                            sourceComponent: modelData.kind === "now" ? nowRow
                                : modelData.kind === "event" ? eventRow : noteRow
                            property var entry: modelData
                        }
                    }
                }

                // Jetzt-Marke: Uhrzeit, Glutpunkt, feine Linie
                Component {
                    id: nowRow
                    Item {
                        height: tile.rowH / 2
                        MonoTxt {
                            x: 6 + tile.dayW
                            width: tile.timeW
                            anchors.verticalCenter: parent.verticalCenter
                            text: tile.hm(Agenda.now)
                            color: Theme.accentText
                            font.pixelSize: 11
                        }
                        Rectangle {
                            x: 6 + tile.dayW + tile.timeW
                            anchors.verticalCenter: parent.verticalCenter
                            width: 6
                            height: 6
                            radius: 3
                            color: Theme.accent
                        }
                        Rectangle {
                            x: 6 + tile.dayW + tile.timeW + 10
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - x - 6
                            height: 1
                            color: Qt.alpha(Theme.accent, 0.5)
                        }
                    }
                }

                // leise Zeile: "Nothing today.", "+3 more" …
                Component {
                    id: noteRow
                    Item {
                        id: nr
                        readonly property var e: parent ? parent.entry : ({})
                        height: tile.rowH
                        Txt {
                            x: 6
                            width: tile.dayW
                            anchors.verticalCenter: parent.verticalCenter
                            visible: tile.dayW > 0
                            text: nr.e.label || ""
                            color: nr.e.day === Agenda.dayStart ? Theme.accentText : Theme.textMuted
                            font.pixelSize: 12
                            font.weight: nr.e.day === Agenda.dayStart ? Font.DemiBold : Font.Medium
                        }
                        Txt {
                            x: 6 + (nr.e.kind === "more" ? 0 : tile.dayW)
                            width: parent.width - x - 6
                            anchors.verticalCenter: parent.verticalCenter
                            text: nr.e.kind === "more" ? "+" + nr.e.more + " more" : nr.e.text || ""
                            color: Theme.textFaint
                            font.pixelSize: 12
                            font.weight: Font.Normal
                        }
                    }
                }

                Component {
                    id: eventRow
                    ClickRow {
                        id: er
                        readonly property var e: parent ? parent.entry : ({})
                        readonly property bool isToday: er.e.day === Agenda.dayStart

                        Txt {
                            width: tile.dayW - 6
                            anchors.verticalCenter: parent.verticalCenter
                            visible: tile.dayW > 0
                            text: er.e.label || ""
                            color: er.isToday ? Theme.accentText : Theme.textMuted
                            font.pixelSize: 12
                            font.weight: er.isToday ? Font.DemiBold : Font.Medium
                        }
                        MonoTxt {
                            x: tile.dayW
                            width: tile.timeW
                            anchors.verticalCenter: parent.verticalCenter
                            text: er.e.allDay ? "all day" : tile.hm(er.e.start || 0)
                            color: er.e.live ? Theme.accentText : er.e.past ? Theme.textFaint : Theme.textMuted
                            font.pixelSize: er.e.allDay ? 11 : 12
                        }
                        // Kalenderfarbe als kleiner Punkt (wie im Kalender)
                        Rectangle {
                            x: tile.dayW + tile.timeW
                            anchors.verticalCenter: parent.verticalCenter
                            width: 6
                            height: 6
                            radius: 3
                            color: er.e.live ? Theme.accent : er.e.color || Theme.accent
                            opacity: er.e.past ? 0.4 : 0.9
                        }
                        Txt {
                            id: titleTxt
                            x: tile.dayW + tile.timeW + 16
                            width: Math.min(implicitWidth, parent.width - x - (locTxt.text !== "" ? 60 : 0))
                            anchors.verticalCenter: parent.verticalCenter
                            text: er.e.title || ""
                            color: er.e.past ? Theme.textFaint : Theme.text
                            font.weight: er.e.live ? Font.DemiBold : Font.Medium
                        }
                        // Ort leise dahinter, wenn Platz ist
                        Txt {
                            id: locTxt
                            anchors.left: titleTxt.right
                            anchors.leftMargin: 8
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            visible: text !== "" && width > 30
                            text: er.e.location || ""
                            color: Theme.textFaint
                            font.pixelSize: 12
                            font.weight: Font.Normal
                        }
                    }
                }
            }
        }

        Rectangle {
            Layout.fillHeight: true
            implicitWidth: 1
            color: Theme.border
        }

        // ================= Monatskalender =================
        MonthCalendar {
            id: cal
            Layout.fillHeight: true
            Layout.preferredWidth: 300
            headH: tile.headH
            selected: tile.selected
            onPicked: day => tile.selected = day
        }

        Rectangle {
            Layout.fillHeight: true
            implicitWidth: 1
            color: Theme.border
        }

        // ================= To-dos =================
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.preferredWidth: 3.5

            Label {
                text: "To-dos"
            }
            MonoTxt {
                anchors.right: parent.right
                y: 0
                height: listHead.height
                visible: Agenda.otherTodos > 0 && tile.dueRows.length > 0
                text: Agenda.otherTodos + " later"
                color: Theme.textFaint
                font.pixelSize: 12
            }
            Item {
                anchors.fill: parent
                anchors.topMargin: tile.headH

                Empty {
                    visible: tile.dueRows.length === 0
                    icon: "task_alt"
                    text: "Nothing due."
                    sub: Agenda.otherTodos > 0 ? Agenda.otherTodos + " open later" : ""
                }

                Column {
                    width: parent.width
                    Repeater {
                        model: tile.dueRows
                        ClickRow {
                            id: tr
                            required property var modelData
                            readonly property bool more: tr.modelData.more !== undefined
                            readonly property bool overdue: !more && tr.modelData.due < Agenda.dayStart
                            clickable: Mail.clientInstalled && !more

                            Icon {
                                id: box
                                anchors.verticalCenter: parent.verticalCenter
                                visible: !tr.more
                                name: "radio_button_unchecked"
                                size: 16
                                color: tr.overdue ? Theme.accentText : Theme.textMuted
                            }
                            Txt {
                                id: todoTxt
                                x: tr.more ? 0 : box.width + 8
                                width: parent.width - x - (dueTxt.visible ? dueTxt.width + 8 : 0)
                                anchors.verticalCenter: parent.verticalCenter
                                text: tr.more ? "+" + tr.modelData.more + " more" : tr.modelData.title
                                color: tr.more ? Theme.textFaint : Theme.text
                                font.pixelSize: tr.more ? 12 : 13
                                font.weight: tr.more ? Font.Normal : Font.Medium
                            }
                            MonoTxt {
                                id: dueTxt
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                visible: !tr.more
                                text: tr.more ? "" : tile.dueLabel(tr.modelData.due)
                                color: tr.overdue ? Theme.accentText : Theme.textFaint
                                font.pixelSize: 12
                            }
                        }
                    }
                }
            }
        }
    }
}

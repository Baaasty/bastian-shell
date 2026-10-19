import QtQuick
import qs.config
import qs.services
import qs.components

// Monatskalender für die Agenda-Kachel: Woche ab Montag, links ISO-Kalenderwoche,
// heute mit Glut-Akzent, Termin-Tage mit kleinen Punkten (Kalenderfarbe, sonst Akzent).
// Blättern: Pfeile oder Mausrad, Klick auf den Monatsnamen = zurück zu heute.
// Klick auf einen Tag meldet picked(tag); die Kachel zeigt dann dessen Termine.
Item {
    id: cal

    property real selected: 0          // gewählter Tag (Mitternacht ms), 0 = keiner
    property int headH: 26
    signal picked(real day)

    property int viewYear: new Date(Agenda.now).getFullYear()
    property int viewMonth: new Date(Agenda.now).getMonth()
    readonly property bool atToday: {
        const n = new Date(Agenda.now);
        return viewYear === n.getFullYear() && viewMonth === n.getMonth();
    }

    readonly property int wkW: 26
    readonly property int dowH: 18
    readonly property real cellW: (width - wkW) / 7
    readonly property real cellH: Math.max(20, Math.floor((height - headH - dowH) / 6))

    readonly property var monthNames: ["January", "February", "March", "April", "May", "June", "July",
        "August", "September", "October", "November", "December"]

    function reset(): void {
        const n = new Date(Agenda.now);
        viewYear = n.getFullYear();
        viewMonth = n.getMonth();
    }
    function shift(n: int): void {
        const d = new Date(viewYear, viewMonth + n, 1);
        viewYear = d.getFullYear();
        viewMonth = d.getMonth();
    }
    function show(day: real): void {
        const d = new Date(day);
        viewYear = d.getFullYear();
        viewMonth = d.getMonth();
    }

    // ISO-8601-Woche: Donnerstag der Woche entscheidet über das Jahr
    function isoWeek(t: real): int {
        const d = new Date(t);
        d.setHours(12, 0, 0, 0);
        d.setDate(d.getDate() + 3 - (d.getDay() + 6) % 7);
        const jan4 = new Date(d.getFullYear(), 0, 4, 12);
        return 1 + Math.round(((d - jan4) / 86400000 - 3 + (jan4.getDay() + 6) % 7) / 7);
    }

    // 6 Wochen ab dem Montag vor (oder am) Monatsersten: [{ t, date, inMonth, weekend }]
    readonly property var cells: {
        const first = new Date(viewYear, viewMonth, 1);
        const d = new Date(viewYear, viewMonth, 1 - (first.getDay() + 6) % 7);
        const out = [];
        for (let i = 0; i < 42; i++) {
            out.push({ t: d.getTime(), date: d.getDate(), inMonth: d.getMonth() === viewMonth, weekend: i % 7 >= 5 });
            d.setDate(d.getDate() + 1);
        }
        return out;
    }

    // Mausrad: eine Raste = ein Monat (Touchpad sammelt erst)
    WheelHandler {
        property real acc: 0
        target: null
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: event => {
            acc += event.angleDelta.y;
            while (Math.abs(acc) >= 120) {
                cal.shift(acc > 0 ? -1 : 1);
                acc -= acc > 0 ? 120 : -120;
            }
        }
    }

    // kleiner runder Pfeil-Knopf
    component Nav: Rectangle {
        id: nav
        property string icon
        signal clicked()
        width: 24
        height: 24
        radius: Theme.radiusSm
        color: navMa.containsMouse ? Theme.raise : "transparent"
        Behavior on color { ColorAnimation { duration: Theme.fade } }
        Icon {
            anchors.centerIn: parent
            name: nav.icon
            size: 18
            color: navMa.containsMouse ? Theme.text : Theme.textFaint
        }
        MouseArea {
            id: navMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: nav.clicked()
        }
    }

    // ---------- Kopf: Monat + Pfeile ----------
    Label {
        id: monthLabel
        text: cal.monthNames[cal.viewMonth] + (cal.viewYear !== new Date(Agenda.now).getFullYear() ? " " + cal.viewYear : "")
        color: !cal.atToday && monthMa.containsMouse ? Theme.text : cal.atToday ? Theme.textFaint : Theme.textMuted
        Behavior on color { ColorAnimation { duration: Theme.fade } }
        MouseArea {
            id: monthMa
            anchors.fill: parent
            anchors.margins: -4
            hoverEnabled: true
            cursorShape: cal.atToday ? Qt.ArrowCursor : Qt.PointingHandCursor
            onClicked: {
                cal.reset();
                cal.picked(0);
            }
        }
    }
    Row {
        anchors.right: parent.right
        anchors.verticalCenter: monthLabel.verticalCenter
        spacing: 2
        Nav {
            icon: "chevron_left"
            onClicked: cal.shift(-1)
        }
        Nav {
            icon: "chevron_right"
            onClicked: cal.shift(1)
        }
    }

    // ---------- Wochentage ----------
    Item {
        id: dow
        y: cal.headH
        width: parent.width
        height: cal.dowH
        MonoTxt {
            width: cal.wkW
            height: parent.height
            horizontalAlignment: Text.AlignHCenter
            text: "wk"
            color: Theme.textFaint
            opacity: 0.7
            font.pixelSize: 10
        }
        Repeater {
            model: ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"]
            MonoTxt {
                required property string modelData
                required property int index
                x: cal.wkW + index * cal.cellW
                width: cal.cellW
                height: parent.height
                horizontalAlignment: Text.AlignHCenter
                text: modelData
                color: Theme.textFaint
                opacity: index >= 5 ? 0.7 : 1
                font.pixelSize: 11
            }
        }
    }

    // ---------- Wochen ----------
    Repeater {
        model: 6
        Item {
            id: week
            required property int index
            y: cal.headH + cal.dowH + index * cal.cellH
            width: cal.width
            height: cal.cellH

            // Kalenderwoche
            MonoTxt {
                width: cal.wkW
                height: parent.height
                horizontalAlignment: Text.AlignHCenter
                text: cal.cells.length ? cal.isoWeek(cal.cells[week.index * 7].t) : ""
                color: Theme.textFaint
                opacity: 0.7
                font.pixelSize: 11
            }

            Repeater {
                model: 7
                Item {
                    id: cell
                    required property int index
                    readonly property var c: cal.cells[week.index * 7 + index]
                    readonly property bool isToday: c.t === Agenda.dayStart
                    readonly property bool isSel: cal.selected > 0 && c.t === cal.selected
                    readonly property var evs: Agenda.byDay[c.t] || []
                    // bis zu drei Punkte, je Kalenderfarbe einer
                    readonly property var dots: {
                        const out = [];
                        for (const e of evs) {
                            const col = e.color || "";
                            if (!out.includes(col))
                                out.push(col);
                            if (out.length >= 3)
                                break;
                        }
                        return out;
                    }

                    x: cal.wkW + index * cal.cellW
                    width: cal.cellW
                    height: cal.cellH

                    Rectangle {
                        anchors.centerIn: parent
                        width: Math.min(parent.width - 4, 34)
                        height: parent.height - 2
                        radius: Theme.radiusSm
                        color: cell.isToday ? Theme.accentSoft
                            : cell.isSel ? Qt.alpha(Theme.text, 0.1)
                            : dayMa.containsMouse ? Theme.raise : "transparent"
                        border.width: cell.isToday || cell.isSel ? 1 : 0
                        border.color: cell.isToday ? Qt.alpha(Theme.accent, 0.55) : Theme.borderStrong
                        Behavior on color { ColorAnimation { duration: Theme.fade } }
                    }
                    MonoTxt {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.verticalCenterOffset: cell.dots.length ? -2 : 0
                        text: cell.c.date
                        color: cell.isToday ? Theme.accentText
                            : !cell.c.inMonth ? Theme.textFaint
                            : cell.c.weekend ? Theme.textMuted : Theme.text
                        opacity: cell.c.inMonth || cell.isToday ? 1 : 0.55
                        font.pixelSize: 12
                        font.weight: cell.isToday ? Font.DemiBold : Font.Normal
                    }
                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 4
                        spacing: 3
                        opacity: cell.c.inMonth ? (cell.c.t < Agenda.dayStart ? 0.55 : 0.9) : 0.35
                        Repeater {
                            model: cell.dots
                            Rectangle {
                                required property string modelData
                                width: 4
                                height: 4
                                radius: 2
                                color: modelData !== "" ? modelData : Theme.accent
                            }
                        }
                    }
                    MouseArea {
                        id: dayMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (!cell.c.inMonth)
                                cal.show(cell.c.t);
                            // heute oder schon gewählt = zurück zur normalen Agenda
                            cal.picked(cell.isToday || cell.isSel ? 0 : cell.c.t);
                        }
                    }
                }
            }
        }
    }
}

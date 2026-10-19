import QtQuick
import qs.config
import qs.services

// Zwei kleine Punkte im Kopf einer Projekt-Kachel (Idee o): links amber = ungespeicherte Änderungen,
// rechts CI des letzten Laufs: grün = ok, rot = fehlgeschlagen, Ring = läuft, grau = keine/abgebrochen.
// Ohne Daten (gh nicht angemeldet, kein GitHub-Remote) bleibt der Platz leer. Feste Breite, damit nichts springt.
Item {
    id: dots

    property var proj: null
    readonly property var g: proj ? GitInfo.git[proj.id] : undefined
    readonly property var c: proj ? GitInfo.ci[proj.id] : undefined
    readonly property bool dirty: !!g && g.changes > 0
    // „keine Läufe“ (Repo ohne CI) bleibt leer: kein Punkt
    readonly property bool hasCi: !!c && !(c.state === "none" && c.status === "")
    readonly property color ciColor: !c ? "transparent" : c.state === "ok" ? Theme.success : c.state === "fail" ? Theme.error : Theme.textFaint

    visible: dirty || hasCi
    implicitWidth: 26
    implicitHeight: 24

    Row {
        anchors.centerIn: parent
        spacing: 4
        // Rand in dunklem Ton: bleibt auf der Akzent-Kachel und auf der ruhigen Kachel gleich gut lesbar
        Rectangle {
            width: 11
            height: 11
            radius: 6
            visible: true
            opacity: dots.dirty ? 1 : 0
            color: Theme.warning
            border.width: 1.5
            border.color: Theme.surfaceSunken
        }
        Rectangle {
            width: 11
            height: 11
            radius: 6
            opacity: dots.hasCi ? 1 : 0
            color: dots.c && dots.c.state === "running" ? "transparent" : dots.ciColor
            border.width: dots.c && dots.c.state === "running" ? 2 : 1.5
            border.color: dots.c && dots.c.state === "running" ? Theme.textFaint : Theme.surfaceSunken
        }
    }
}

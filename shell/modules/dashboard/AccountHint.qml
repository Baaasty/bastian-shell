import QtQuick
import qs.config
import qs.services
import qs.components

// Leiser Hinweis für Mail/Agenda, solange kein Konto läuft: was fehlt + Verweis auf die Anleitung
Column {
    id: hint

    property string status: "no-config"   // Gesamtzustand der Datei
    property var problems: []              // Konten mit Status != ok

    spacing: 10

    Row {
        width: parent.width
        spacing: 10
        Icon {
            id: ico
            readonly property string why: hint.problems.length ? hint.problems[0].status : ""
            name: hint.status === "loading" ? "hourglass_empty"
                : why === "no-password" || why === "auth" ? "key"
                : why === "error" ? "cloud_off" : "person_add"
            size: 18
            color: Theme.textFaint
        }
        Txt {
            width: parent.width - ico.width - 10
            wrapMode: Text.WordWrap
            color: Theme.textMuted
            font.weight: Font.Normal
            text: hint.status === "loading" ? "Waiting for the first sync…"
                : hint.status === "config-error" ? "Can’t read " + Mail.configPath + " (JSON broken?)"
                : hint.problems.length ? Mail.problemText(hint.problems[0])
                : "Add your iCloud account in " + Mail.configPath + " (accounts)"
        }
    }
    MonoTxt {
        // Anleitung nur, solange Benutzer/Passwort/Konto fehlen (nicht bei Offline o. Ä.)
        readonly property string why: hint.problems.length ? hint.problems[0].status : ""
        visible: hint.status !== "loading" && (hint.status !== "ok" || why === "no-user" || why === "no-password" || why === "auth")
        width: parent.width
        leftPadding: 28
        wrapMode: Text.Wrap
        text: "Guide: " + Mail.guidePath
        color: Theme.textFaint
        font.pixelSize: 12
    }
}

import QtQuick
import qs.config
import qs.components

// Listenzeile im Datei-Wähler (34 px wie die Menüs): Icon nach Typ · Name · Größe · Datum.
// Klick = markieren (Speichern: Name übernehmen), Doppelklick = Ordner öffnen bzw. Datei wählen.
// Mehrfachauswahl (fp.multi): Haken rechts (Klick schaltet um, auch für Ordner), Klick auf eine Datei schaltet ebenfalls um.
Item {
    id: row

    required property var fp
    required property var modelData
    required property int index
    readonly property bool selected: fp.sel === index
    readonly property bool marked: fp.multi && fp.isMarked(modelData.path)
    readonly property var project: modelData.isDir ? fp.projectByPath[modelData.path] : undefined

    signal picked()
    signal opened()
    signal markToggled()

    function icon(e: var): string {
        if (e.isDir)
            return row.project ? "folder_code" : "folder";
        const s = e.suffix;
        if (["png", "jpg", "jpeg", "webp", "gif", "svg", "bmp", "avif", "heic", "tif", "tiff", "ico"].includes(s))
            return "image";
        if (["mp4", "mkv", "webm", "mov", "avi"].includes(s))
            return "movie";
        if (["mp3", "flac", "ogg", "opus", "wav", "m4a"].includes(s))
            return "music_note";
        if (s === "pdf")
            return "picture_as_pdf";
        if (["zip", "tar", "gz", "xz", "zst", "7z", "rar", "bz2", "tgz", "rpm"].includes(s))
            return "folder_zip";
        if (["js", "ts", "tsx", "jsx", "qml", "py", "sh", "rs", "go", "c", "cpp", "h", "json", "toml", "yaml", "yml", "css", "html", "lua", "conf"].includes(s))
            return "code";
        if (["txt", "md", "log", "csv", "odt", "doc", "docx"].includes(s))
            return "description";
        return "draft";
    }
    function size(b: real): string {
        if (b < 1024)
            return b + " B";
        const u = ["KB", "MB", "GB", "TB"];
        let v = b / 1024, i = 0;
        while (v >= 1024 && i < u.length - 1) {
            v /= 1024;
            i++;
        }
        return (v < 10 ? v.toFixed(1) : Math.round(v)) + " " + u[i];
    }
    // heute: Uhrzeit · dieses Jahr: „18 Oct“ · sonst mit Jahr (englisch, unabhängig von der Systemsprache)
    function when(d: var): string {
        if (!d || isNaN(d.getTime()))
            return "";
        const m = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"][d.getMonth()];
        const now = new Date();
        if (d.toDateString() === now.toDateString())
            return ("0" + d.getHours()).slice(-2) + ":" + ("0" + d.getMinutes()).slice(-2);
        return d.getDate() + " " + m + (d.getFullYear() === now.getFullYear() ? "" : " " + d.getFullYear());
    }

    opacity: modelData.hidden ? 0.62 : 1

    Chip {
        id: chip
        anchors.fill: parent
        alignLeft: true
        active: row.selected
        // gewählte Zeile = deckende Akzentfläche (wie jede Listenauswahl)
        color: row.selected ? Theme.accentFill : hovered ? Theme.raise : "transparent"
        onClicked: mouse => {
            if (mouse.button === Qt.LeftButton)
                row.picked();
        }
        onDoubleClicked: mouse => {
            if (mouse.button === Qt.LeftButton)
                row.opened();
        }

        Icon {
            anchors.verticalCenter: parent.verticalCenter
            width: 18
            name: row.icon(row.modelData)
            size: 18
            fill: row.modelData.isDir
            color: row.project ? row.project.color : row.modelData.isDir ? Theme.woodLight : row.selected ? Theme.textMuted : Theme.textFaint
        }
        Txt {
            anchors.verticalCenter: parent.verticalCenter
            width: Math.max(0, row.width - (chip.padding + 4) * 2 - 28 - meta.width - 16)
            text: row.modelData.name
            color: row.marked ? Theme.accentText : Theme.text
            font.weight: Font.Normal
        }
    }

    Row {
        id: meta
        anchors.right: parent.right
        anchors.rightMargin: 14
        anchors.verticalCenter: parent.verticalCenter
        spacing: 14
        // Haken (nur Mehrfachauswahl)
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            visible: row.fp.multi
            width: 20
            height: 20
            radius: 6
            color: row.marked ? Theme.accent : markArea.containsMouse ? Theme.surfaceRaised : "transparent"
            border.width: row.marked ? 0 : 1
            border.color: markArea.containsMouse ? Theme.borderStrong : Theme.border
            Icon {
                anchors.centerIn: parent
                visible: row.marked
                name: "check"
                size: 15
                color: Theme.onAccent
            }
            MouseArea {
                id: markArea
                anchors.fill: parent
                anchors.margins: -6
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: row.markToggled()
            }
        }
        MonoTxt {
            anchors.verticalCenter: parent.verticalCenter
            visible: !row.modelData.isDir || row.fp.multi      // Mehrfachauswahl: Platz bleibt, damit die Haken fluchten
            width: 64
            horizontalAlignment: Text.AlignRight
            text: row.modelData.isDir ? "" : row.size(row.modelData.size)
            color: Theme.textFaint
            font.pixelSize: Theme.fontSm
        }
        MonoTxt {
            anchors.verticalCenter: parent.verticalCenter
            width: 84
            horizontalAlignment: Text.AlignRight
            text: row.when(row.modelData.modified)
            color: Theme.textFaint
            font.pixelSize: Theme.fontSm
        }
    }
}

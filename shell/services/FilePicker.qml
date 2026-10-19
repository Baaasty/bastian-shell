pragma Singleton
import QtQuick
import Quickshell

// Eigener Datei-/Ordner-Wähler der Shell (statt kdialog): Anfragen + Antwort. Die Oberfläche ist
// shell/modules/filepicker/FilePickerPanel.qml (liest den Zustand hier und ruft finish()).
// Callback bekommt den Pfad oder "" (abgebrochen); jeder Aufruf gibt zusätzlich ein Promise mit demselben Wert zurück.
//   FilePicker.pickFolder("~/Workspace", path => …, { title: "Choose project folder" })
//   FilePicker.openFile("~/Pictures", ["png", "jpg"], path => …)
//   FilePicker.saveFile("~/Pictures/Screenshots", "Snip.png", ["png", "jpg", "webp"], path => …, { title: "Save Snip" })
//   FilePicker.openFiles("~", [], paths => …, { title: "Upload", action: "Upload" })   // mehrere (Tab markiert), [] = abgebrochen
// Nur eine Anfrage gleichzeitig: eine neue bricht die alte ab (deren Callback bekommt "").
// App-Dialoge (Dolphin, Helium …) laufen weiter über das KDE-Portal und haben hiermit nichts zu tun.
Singleton {
    id: root

    property bool active: false
    property string mode: "folder"      // folder | open | save
    property string title: ""
    property string startDir: ""
    property string fileName: ""        // Vorschlag beim Speichern
    property var filters: []            // Endungen ohne Punkt, z. B. ["png", "jpg"]; leer = alle
    property bool multi: false          // openFiles: mehrere Dateien/Ordner markieren, Antwort ist eine Liste
    property string action: ""          // Text des Haupt-Knopfs (openFiles), z. B. "Upload"
    property int serial: 0              // zählt jede neue Anfrage (die Oberfläche setzt sich dann zurück)

    property var _cb: null
    property var _resolve: null

    readonly property string home: Quickshell.env("HOME")

    function expand(p) {
        const s = String(p || "");
        if (s === "~")
            return home;
        return s.startsWith("~/") ? home + s.slice(1) : s;
    }

    function pickFolder(start, cb, opts) {
        return _request("folder", start, "", [], cb, opts, "Choose folder");
    }
    function openFile(start, filters, cb, opts) {
        return _request("open", start, "", filters, cb, opts, "Open file");
    }
    function saveFile(dir, name, filters, cb, opts) {
        return _request("save", dir, name, filters, cb, opts, "Save file");
    }
    // mehrere Dateien (und Ordner) wählen: Callback bekommt eine Liste absoluter Pfade, [] = abgebrochen
    function openFiles(start, filters, cb, opts) {
        return _request("open", start, "", filters, cb, opts, "Choose files", true);
    }

    // von der Oberfläche: Pfad wählen ("" = abbrechen); bei openFiles eine Liste (oder ein Pfad, wird zur Liste)
    function finish(path: var): void {
        if (!active)
            return;
        if (multi)
            path = Array.isArray(path) ? path.filter(p => p) : (path ? [String(path)] : []);
        else if (Array.isArray(path))
            path = path.length ? String(path[0]) : "";
        const cb = _cb, res = _resolve;
        _cb = null;
        _resolve = null;
        active = false;
        try {
            if (typeof cb === "function")
                cb(path);
        } catch (e) {
            console.warn("FilePicker callback: " + e);
        }
        if (res)
            res(path);
    }
    function cancel(): void {
        finish("");
    }

    function _request(mode, start, name, filters, cb, opts, fallbackTitle, many) {
        if (active)
            cancel();
        root.multi = many === true;
        root.action = (opts && opts.action) || "";
        let res = null;
        const p = new Promise(r => res = r);
        root.mode = mode;
        root.title = (opts && opts.title) || fallbackTitle;
        root.startDir = expand(start) || home;
        root.fileName = name || "";
        root.filters = (filters || []).map(f => String(f).replace(/^\*?\./, "").toLowerCase()).filter(f => f);
        _cb = cb;
        _resolve = res;
        serial++;
        active = true;
        return p;
    }
}

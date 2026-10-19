pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Offene Chrome-Tabs aus ~/.cache/desktop/chrome-tabs.json. Die schreibt der Native-Messaging-Host
// scripts/chrome-ext, gefüttert von der Chrome-Erweiterung „Desktop“ (theme/out/chrome-desktop-ext).
// activate() holt einen Tab in seinem Fenster nach vorne; das Fenster selbst hebt der Launcher über Hyprland
// (Chrome darf unter Wayland nicht selbst den Fokus nehmen).
// Andersherum: ~/.cache/desktop/chrome-shell.json mit dem Wetter für die neue Tab-Seite (Termine liest der Host selbst).
// Fehlt die Erweiterung, bleibt tabs einfach leer.
Singleton {
    id: root

    readonly property string script: Quickshell.shellDir + "/../scripts/chrome-ext"
    readonly property string cache: Quickshell.env("HOME") + "/.cache/desktop"

    property var tabs: []              // [{ id, windowId, title, url, active, pinned, audible, lastAccessed }]
    property var activeTitles: ({})    // windowId -> Titel des aktiven Tabs (= Anfang des Fenstertitels)
    property bool running: false       // Host läuft (Chrome offen, Erweiterung geladen)

    // "https://www.github.com/x" -> "github.com"
    function host(url: string): string {
        return (url || "").replace(/^[a-z][a-z0-9+.-]*:\/\//i, "").split(/[\/?#]/)[0].replace(/^www\./, "");
    }

    function activate(tab: var): void {
        Quickshell.execDetached([script, "activate", String(tab.id)]);
    }

    FileView {
        path: root.cache + "/chrome-tabs.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            try {
                const d = JSON.parse(text());
                root.running = !!d.running;
                root.activeTitles = d.activeTitles || {};
                root.tabs = d.running ? (d.tabs || []) : [];
            } catch (e) {}
        }
    }

    // Wetter für die neue Tab-Seite: bei jeder neuen Messung (Weather lädt alle 15 min)
    function writeWeather(): void {
        if (!Weather.ready)
            return;
        weatherFile.setText(JSON.stringify({
            weather: {
                temp: Weather.temp,
                code: Weather.code,
                label: Weather.label(Weather.code),
                icon: Weather.icon(Weather.code, Weather.isDay),
                updated: Date.now()
            }
        }));
    }

    Connections {
        target: Weather
        function onReadyChanged() { root.writeWeather(); }
        function onTempChanged() { root.writeWeather(); }
        function onCodeChanged() { root.writeWeather(); }
    }
    // auch ohne Änderung ab und zu frisch stempeln (die Seite zeigt nur Wetter jünger als 3 h)
    Timer {
        interval: 900000
        repeat: true
        running: true
        onTriggered: root.writeWeather()
    }

    FileView {
        id: weatherFile
        path: root.cache + "/chrome-shell.json"
        printErrors: false
    }
}

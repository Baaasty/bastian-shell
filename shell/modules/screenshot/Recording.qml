import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.config
import qs.components

// Bildschirmaufnahme (Super+R): Start/Stopp über scripts/screenrec, das in einem eigenen
// systemd-Scope läuft und Shell-Neustarts übersteht. Der Zustand kommt aus dessen Zustandsdatei;
// solange aufgenommen wird, zeigt eine kleine Pille (roter Punkt + Laufzeit) neben dem Bereich an,
// dass aufgenommen wird. Klick darauf stoppt.
Scope {
    id: root

    readonly property string script: Quickshell.shellDir + "/../scripts/screenrec"
    readonly property string stateFile: Quickshell.env("XDG_RUNTIME_DIR") + "/desktop-screenrec/state.json"

    property var st: ({})
    property bool alive: false          // Prozess aus der Zustandsdatei lebt noch
    property bool starting: false       // Start angefordert, Zustand noch nicht da
    property bool stopping: false       // Stopp angefordert, Datei wird fertig geschrieben
    property real now: Date.now()

    readonly property bool recording: st.recording === true && alive
    readonly property bool busy: recording || starting
    readonly property int secs: recording && st.start ? Math.max(0, Math.floor((now - st.start) / 1000)) : 0
    readonly property string clock: Math.floor(secs / 60) + ":" + String(secs % 60).padStart(2, "0")

    // x, y, w, h in globalen logischen Koordinaten
    function start(x: int, y: int, w: int, h: int, scale: real): void {
        if (busy)
            return;
        starting = true;
        startTimeout.restart();
        Quickshell.execDetached([script, "start", String(x), String(y), String(w), String(h), String(scale)]);
    }
    function stop(): void {
        if (!recording || stopping)
            return;
        stopping = true;
        Quickshell.execDetached([script, "stop"]);
    }

    // Zustand einmal pro Sekunde lesen (billig, keine Prozesse) – treibt auch die Uhr
    Timer {
        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            root.now = Date.now();
            stateView.reload();
        }
    }
    Timer {
        id: startTimeout
        interval: 8000
        onTriggered: root.starting = false
    }

    FileView {
        id: stateView
        path: root.stateFile
        printErrors: false
        onLoaded: {
            try {
                root.st = JSON.parse(text());
            } catch (e) {
                root.st = {};
            }
            if (root.st.pid)
                procView.reload();
        }
        onLoadFailed: {
            root.st = {};
            root.alive = false;
            root.stopping = false;
        }
    }
    // lebt der Aufnahmeprozess? (verwaiste Zustandsdatei nach hartem Abbruch ignorieren)
    FileView {
        id: procView
        path: root.st.pid ? "/proc/" + root.st.pid + "/cmdline" : ""
        printErrors: false
        onLoaded: {
            root.alive = text().indexOf("screenrec") >= 0;
            if (root.alive && root.st.start)
                root.starting = false;
        }
        onLoadFailed: root.alive = false
    }

    // ---- Hinweis-Pille ----
    readonly property int pillW: 104
    readonly property int pillH: 34
    readonly property int gap: 10

    // Platz neben dem Bereich (nicht darin, sonst wäre sie im Video), sonst auf einem anderen Monitor
    readonly property var place: {
        const screens = Quickshell.screens;
        if (!recording || !st.w || screens.length === 0)
            return null;
        const cx = st.x + st.w / 2, cy = st.y + st.h / 2;
        const s = screens.find(s => cx >= s.x && cx < s.x + s.width && cy >= s.y && cy < s.y + s.height) || screens[0];
        const lx = st.x - s.x, ly = st.y - s.y, W = s.width, H = s.height, m = 8, pw = pillW, ph = pillH;
        const cl = (v, lo, hi) => Math.max(lo, Math.min(hi, v));
        // nie in den Streifen der Top-Bar (Hauptmonitor): die Pille ist eine eigene Overlay-Fläche und
        // würde dort die Klicks der Chips schlucken (Klick hätte stattdessen die Aufnahme gestoppt)
        const top = topFree(s);
        if (ly - gap - ph >= top)
            return { screen: s.name, x: cl(lx + st.w - pw, m, W - pw - m), y: ly - gap - ph };
        if (ly + st.h + gap + ph <= H - m)
            return { screen: s.name, x: cl(lx + st.w - pw, m, W - pw - m), y: ly + st.h + gap };
        if (lx + st.w + gap + pw <= W - m)
            return { screen: s.name, x: lx + st.w + gap, y: cl(ly, top, H - ph - m) };
        if (lx - gap - pw >= m)
            return { screen: s.name, x: lx - gap - pw, y: cl(ly, top, H - ph - m) };
        // Bereich füllt den Monitor: Pille auf den Hauptmonitor (bzw. irgendeinen anderen), dort unter die Bar
        const other = screens.find(o => o.name !== s.name && o.name === Config.mainScreen) || screens.find(o => o.name !== s.name);
        if (!other)
            return { screen: s.name, x: W - pw - 16, y: H - ph - 16 };
        return { screen: other.name, x: other.width - pw - 16, y: Math.max(16, topFree(other)) };
    }
    // oberste freie Zeile eines Monitors: auf dem Hauptmonitor unterhalb der Bar (+ Luft)
    function topFree(s): int {
        return s.name === Config.mainScreen ? Theme.barMargin + Theme.barHeight + gap : 8;
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: win

            required property var modelData

            screen: modelData
            visible: root.place !== null && root.place.screen === modelData.name
            anchors {
                top: true
                left: true
            }
            margins.left: root.place ? root.place.x : 0
            margins.top: root.place ? root.place.y : 0
            implicitWidth: root.pillW
            implicitHeight: root.pillH
            exclusionMode: ExclusionMode.Ignore
            color: "transparent"
            WlrLayershell.namespace: "dock" // "dock": ohne Öffnen-Animation (Hyprland: layerrule noanim)
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

            BackgroundEffect.blurRegion: Region {
                Region { x: 0; y: 0; width: 1; height: 1 }
                Region { item: pill; radius: pill.radius }
            }

            Glass {
                id: pill

                anchors.fill: parent
                strong: true
                radius: height / 2
                border.color: area.containsMouse ? Theme.borderStrong : Theme.border

                Row {
                    anchors.left: parent.left
                    anchors.leftMargin: 14
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 9

                    // ruhig pulsierender Punkt
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 9
                        height: 9
                        radius: 4.5
                        color: root.stopping ? Theme.textFaint : Theme.accent
                        // Breathe (~12 Bilder/s) statt Dauer-Animation mit Bildschirmrate
                        opacity: recBreathe.value
                        Breathe {
                            id: recBreathe
                            running: win.visible && !root.stopping
                            halfMs: 1100
                        }
                    }
                    MonoTxt {
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.stopping ? "saving" : root.clock
                        color: root.stopping ? Theme.textFaint : Theme.text
                        font.pixelSize: 12
                    }
                }

                Icon {
                    anchors.right: parent.right
                    anchors.rightMargin: 11
                    anchors.verticalCenter: parent.verticalCenter
                    visible: !root.stopping
                    name: "stop"
                    fill: true
                    size: 16
                    color: area.containsMouse ? Theme.accentText : Theme.textMuted
                }

                MouseArea {
                    id: area
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.stop()
                }
            }
        }
    }
}

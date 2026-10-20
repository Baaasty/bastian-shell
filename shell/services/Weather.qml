pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Wetter über Open-Meteo (ohne Key), alle 15 min. Ort aus secrets.json: location.name/latitude/longitude
// (Vorlage secrets.example.json); fehlt er, gilt Berlin.
// "Morgen früh": 7–9 Uhr am nächsten Tag -> fertiges Urteil für Motorrad/Rad.
Singleton {
    id: root

    property string place: "Berlin"
    property real lat: 52.52
    property real lon: 13.405
    property bool located: false  // secrets.json gelesen (oder fehlt) -> erst dann abfragen

    property bool ready: false
    property real temp: 0
    property real feels: 0
    property int code: 0
    property bool isDay: true
    property var days: []        // [{ name, code, max, min }]
    property var morning: null   // { tMin, tMax, rain, wind, verdict, ok, sunrise }

    // WMO-Code -> Material-Symbol + Text
    function icon(code: int, day: bool): string {
        if (code === 0) return day ? "sunny" : "clear_night";
        if (code <= 2) return day ? "partly_cloudy_day" : "partly_cloudy_night";
        if (code === 3) return "cloud";
        if (code <= 48) return "foggy";
        if (code <= 67 || (code >= 80 && code <= 82)) return "rainy";
        if (code <= 77 || code === 85 || code === 86) return "weather_snowy";
        return "thunderstorm";
    }
    function label(code: int): string {
        if (code === 0) return "Clear";
        if (code <= 2) return "Partly cloudy";
        if (code === 3) return "Cloudy";
        if (code <= 48) return "Fog";
        if (code <= 57) return "Drizzle";
        if (code <= 67) return "Rain";
        if (code <= 77) return "Snow";
        if (code <= 82) return "Showers";
        return "Thunderstorms";
    }

    function refresh(): void {
        const url = "https://api.open-meteo.com/v1/forecast?latitude=" + lat + "&longitude=" + lon
            + "&current=temperature_2m,apparent_temperature,weather_code,is_day"
            + "&hourly=temperature_2m,precipitation_probability,wind_speed_10m"
            + "&daily=weather_code,temperature_2m_max,temperature_2m_min,sunrise"
            + "&timezone=auto&forecast_days=4";
        const xhr = new XMLHttpRequest();
        xhr.onreadystatechange = () => {
            if (xhr.readyState !== XMLHttpRequest.DONE)
                return;
            // Fehler (offline, 429, kaputte Antwort): bald nochmal statt erst in 15 min, aber mit
            // wachsendem Abstand (1, 2, 4 … 15 min), damit ein Ausfall open-meteo nicht im Minutentakt trifft
            if (xhr.status !== 200) {
                root._retryLater();
                return;
            }
            try {
                root._apply(JSON.parse(xhr.responseText));
                root._failures = 0;
            } catch (e) {
                console.warn("Weather: bad response (" + e + "), retrying later");
                root._retryLater();
            }
        };
        xhr.open("GET", url);
        xhr.send();
    }

    property int _failures: 0
    function _retryLater(): void {
        retry.interval = Math.min(60 * 1000 * Math.pow(2, _failures), 15 * 60 * 1000);
        _failures++;
        retry.restart();
    }

    function _apply(d: var): void {
        root.temp = d.current.temperature_2m;
        root.feels = d.current.apparent_temperature;
        root.code = d.current.weather_code;
        root.isDay = d.current.is_day === 1;
        const names = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];
        root.days = d.daily.time.slice(1, 4).map((t, i) => ({
            name: names[new Date(t + "T12:00").getDay()],
            code: d.daily.weather_code[i + 1],
            max: Math.round(d.daily.temperature_2m_max[i + 1]),
            min: Math.round(d.daily.temperature_2m_min[i + 1])
        }));
        // morgen 07:00–09:00
        const day = d.daily.time[1];
        const idx = d.hourly.time.map((t, i) => [t, i]).filter(([t]) => t >= day + "T07:00" && t <= day + "T09:00").map(([, i]) => i);
        if (idx.length) {
            const temps = idx.map(i => d.hourly.temperature_2m[i]);
            const rain = Math.max(...idx.map(i => d.hourly.precipitation_probability[i]));
            const wind = Math.max(...idx.map(i => d.hourly.wind_speed_10m[i]));
            const tMin = Math.round(Math.min(...temps));
            const ok = rain <= 30 && tMin >= 5 && wind < 35;
            root.morning = {
                tMin: tMin, tMax: Math.round(Math.max(...temps)), rain: rain, wind: Math.round(wind),
                ok: ok,
                verdict: ok ? "Good for the bike" : rain > 30 ? "Take the car – rain" : tMin < 5 ? "Take the car – cold" : "Take the car – windy",
                sunrise: d.daily.sunrise[1].slice(11, 16)
            };
        }
        root.ready = true;
    }

    FileView {
        path: Quickshell.shellDir + "/../secrets.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            let l = {};
            try {
                l = JSON.parse(text()).location || {};
            } catch (e) {}
            const valid = l.latitude !== undefined && l.longitude !== undefined
                && isFinite(Number(l.latitude)) && isFinite(Number(l.longitude));
            const lat = valid ? Number(l.latitude) : 52.52, lon = valid ? Number(l.longitude) : 13.405;
            const changed = root.located && (lat !== root.lat || lon !== root.lon);
            root.place = valid ? (l.name || "") : "Berlin";
            root.lat = lat;
            root.lon = lon;
            root.located = true;
            if (changed)
                root.refresh();
        }
        onLoadFailed: root.located = true
    }

    Timer {
        id: retry
        interval: 60 * 1000
        onTriggered: root.refresh()
    }

    Timer {
        interval: 15 * 60 * 1000
        repeat: true
        running: root.located
        triggeredOnStart: true
        onTriggered: root.refresh()
    }
}

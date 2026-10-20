.pragma library

// Key Light mit der Kamera (CamLight.qml) – reine Zustandslogik, damit sie ohne Shell, Licht und Kamera testbar ist:
// scripts/tests/camlight-test.js (node). Keine Uhr, keine Timer, kein Netz: die Entprellung macht CamLight.qml.
//
// Zustand { session, owned, ref }:
//   session  Kamera läuft (entprellt)
//   owned    die Automatik hat das Licht eingeschaltet und darf es wieder ausschalten
//   ref      Helligkeit/Kelvin beim Einschalten – weicht das Licht am Ende davon ab, hat Bastian es selbst
//            verstellt (auch per Elgato-App oder Taste am Licht), dann bleibt es an
// Ereignisse: start {allowed} · stop · light {phase: "start"|"stop", ok, on, brightness, kelvin} · manual
// Aktionen:   "" · "query-start" / "query-stop" (Licht lesen, Antwort als Ereignis light) · "on" · "off" · "unreachable"

function initial() {
    return { session: false, owned: false, ref: null };
}

function restore(raw) {
    const s = initial();
    if (raw && typeof raw === "object") {
        s.session = raw.session === true;
        s.owned = raw.owned === true;
        if (s.owned && raw.ref && typeof raw.ref.brightness === "number" && typeof raw.ref.kelvin === "number")
            s.ref = { brightness: raw.ref.brightness, kelvin: raw.ref.kelvin };
        else
            s.owned = false;
    }
    return s;
}

function step(s, ev) {
    const n = { session: s.session, owned: s.owned, ref: s.ref };
    const out = a => ({ state: n, action: a });
    switch (ev && ev.type) {
    case "start":
        if (s.session)
            return out("");
        n.session = true;
        // schon von der Automatik an (Kamera kurz aus und wieder an, Aus-Abfrage noch unterwegs): nichts tun
        if (s.owned || !ev.allowed)
            return out("");
        return out("query-start");
    case "stop":
        if (!s.session)
            return out("");
        n.session = false;
        return out(s.owned ? "query-stop" : "");
    case "light":
        if (ev.phase === "start") {
            // veraltete Antwort: Kamera schon wieder aus, oder schon eingeschaltet
            if (!s.session || s.owned)
                return out("");
            if (!ev.ok)
                return out("unreachable");
            // war schon an: gehört Bastian, am Ende nicht ausschalten
            if (ev.on)
                return out("");
            n.owned = true;
            n.ref = { brightness: ev.brightness, kelvin: ev.kelvin };
            return out("on");
        }
        if (ev.phase === "stop") {
            // Kamera wieder an, bevor die Antwort kam: Licht bleibt, Automatik behält es
            if (s.session || !s.owned)
                return out("");
            const ref = s.ref;
            n.owned = false;
            n.ref = null;
            if (!ev.ok)
                return out("unreachable");
            if (ev.on && ref && ev.brightness === ref.brightness && ev.kelvin === ref.kelvin)
                return out("off");
            return out("");
        }
        return out("");
    case "manual":
        // Bastian hat selbst geschaltet/verstellt (oder die Automatik abgeschaltet): Licht gehört wieder ihm
        n.owned = false;
        n.ref = null;
        return out("");
    }
    return out("");
}

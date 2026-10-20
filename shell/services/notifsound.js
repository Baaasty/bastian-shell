.pragma library
.import "timewin.js" as TW

// Klingt eine Meldung? Reine Logik (Test: node scripts/tests/notifsound-test.js), abgespielt wird in Sounds.qml.
// cfg = Schlüssel „sound“ aus config/notifications.json
// n   = { app, desktop, summary, urgent, low, suppress }   (low = Dringlichkeit niedrig, suppress = Hint suppress-sound)
// ctx = { shown, now, last }   shown = Popup erscheint wirklich, last = Zeitpunkt des letzten Klangs (ms)
// -> { name: "" | "notify" | "notify-urgent", why }
function soundFor(cfg, n, ctx) {
    const c = cfg && typeof cfg === "object" ? cfg : {};
    if (c.enabled === false)
        return { name: "", why: "off" };
    // kein Popup = kein Ton: Ruhezeit, Fokus/Nicht stören, App-Regel panel/hide liegen alle schon davor
    if (!ctx.shown)
        return { name: "", why: "no popup" };
    if (n.suppress)
        return { name: "", why: "app asked for silence" };
    if (n.low && !n.urgent)
        return { name: "", why: "low urgency" };
    // Apps mit eigenem Ton (Discord, Spotify …): sonst klingt es doppelt
    const skip = Array.isArray(c.skip) ? c.skip : [];
    if (skip.some(r => TW.ruleMatches(r, n)))
        return { name: "", why: "app has its own sound" };
    // Meldungsschwall (z. B. 5 Mails auf einmal): ein Klick reicht
    const cool = typeof c.cooldownMs === "number" && c.cooldownMs >= 0 ? c.cooldownMs : 1500;
    if (ctx.last > 0 && ctx.now - ctx.last < cool)
        return { name: "", why: "cooldown" };
    return { name: n.urgent && c.urgent !== false ? "notify-urgent" : "notify", why: "" };
}

// Lautstärke 0…1 für pw-play (Standard 0.7 – der Ton ist tief und gedämpft, darunter geht er am GoXLR „System“ unter)
function volumeOf(cfg) {
    const v = cfg && typeof cfg.volume === "number" ? cfg.volume : 0.7;
    return Math.max(0, Math.min(1, v));
}

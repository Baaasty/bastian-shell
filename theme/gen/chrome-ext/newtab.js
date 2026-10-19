// Desktop – neue Tab-Seite: Uhr, Datum, Suche, Häppchen/Tipp/Spruch, Termin + Wetter von der Shell
// (kommen über background.js aus chrome.storage.local; fehlen sie, bleibt die Zeile einfach leer).
const $ = id => document.getElementById(id);
const cfg = globalThis.DESKTOP || { quotes: [] };
const pad = n => String(n).padStart(2, "0");
const hm = d => pad(d.getHours()) + ":" + pad(d.getMinutes());

let shell = null;

// ---------- Uhr ----------
function tick() {
  const now = new Date();
  $("hm").textContent = hm(now);
  $("sec").textContent = pad(now.getSeconds());
  $("date").textContent = now.toLocaleDateString("en-GB", { weekday: "long", day: "numeric", month: "long" });
  if (now.getSeconds() % 15 === 0)
    renderInfo();
  // genau zur nächsten vollen Sekunde
  setTimeout(tick, 1000 - (Date.now() % 1000) + 5);
}

// ---------- Suche ----------
function looksLikeUrl(s) {
  if (/^[a-z][a-z0-9+.-]*:\/\//i.test(s) || /^localhost(:\d+)?(\/|$)/.test(s))
    return true;
  return !/\s/.test(s) && /^[^\/]+\.[a-z]{2,}(:\d+)?(\/.*)?$/i.test(s);
}

$("search").addEventListener("submit", e => {
  e.preventDefault();
  const q = $("q").value.trim();
  if (!q)
    return;
  if (looksLikeUrl(q))
    location.href = /^[a-z][a-z0-9+.-]*:\/\//i.test(q) ? q : "https://" + q;
  else
    location.href = "https://www.google.com/search?q=" + encodeURIComponent(q);
});

// "/" springt ins Suchfeld (Chrome setzt den Fokus sonst in die Adressleiste)
document.addEventListener("keydown", e => {
  if (e.key === "/" && document.activeElement !== $("q")) {
    e.preventDefault();
    $("q").focus();
  } else if (e.key === "Escape") {
    $("q").blur();
  }
});

// ---------- Unter der Suche: Wissenshäppchen, Tipp oder Spruch ----------
// Wikipedia + KI-Nudges kommen über den Host (scripts/newtab-feed), eingebettete Nudges + Sprüche sind der Rückfall.
// Einmal pro Tab gewählt (springt nicht beim Nachladen), Klick = nächstes, nie zweimal dasselbe hintereinander.
const quotes = cfg.quotes || [];
const WIKI = {
  tfa: ["auto_stories", "Article of the day"],
  dyk: ["lightbulb", "Did you know?"],
  otd: ["history_edu", "On this day"],
};
let lastKey = "";
try {
  lastKey = localStorage.getItem("bite") || "";
} catch (e) {}

function candidates() {
  const feed = (shell && shell.feed) || {};
  const ai = feed.nudges || [];
  const wiki = (feed.wiki || []).map(w => ({ key: "w:" + w.kind + ":" + w.title + ":" + w.text.slice(0, 30), type: "wiki", ...w }));
  // KI-Nudges bevorzugt, eingebettete gelegentlich dazwischen
  const nudges = ai.map(n => ({ key: "a:" + n.title, type: "nudge", ai: true, ...n }));
  const local = (cfg.nudges || []).map(n => ({ key: "n:" + n.title, type: "nudge", ...n }));
  const q = quotes.map(x => ({ key: "q:" + x, type: "quote", text: x }));
  return [
    [wiki, 0.4],
    [nudges.length && Math.random() < 0.75 ? nudges : local, 0.35],
    [q, 0.25],
  ].filter(([list]) => list.length);
}

function pick() {
  const groups = candidates();
  if (!groups.length)
    return null;
  const total = groups.reduce((s, [, w]) => s + w, 0);
  let r = Math.random() * total;
  let list = groups[groups.length - 1][0];
  for (const [l, w] of groups) {
    if ((r -= w) < 0) {
      list = l;
      break;
    }
  }
  let item = list[Math.floor(Math.random() * list.length)];
  for (let i = 0; i < 6 && item.key === lastKey && list.length > 1; i++)
    item = list[Math.floor(Math.random() * list.length)];
  lastKey = item.key;
  try {
    localStorage.setItem("bite", item.key);
  } catch (e) {}
  return item;
}

// `Code` in Tipps als <code>, ohne innerHTML
function setRich(el, text) {
  el.replaceChildren();
  String(text).split("`").forEach((part, i) => {
    if (!part)
      return;
    if (i % 2) {
      const c = document.createElement("code");
      c.textContent = part;
      el.append(c);
    } else {
      el.append(part);
    }
  });
}

function showBite() {
  const item = pick();
  const bite = $("bite"), quote = $("quote");
  bite.hidden = quote.hidden = true;
  if (!item)
    return;
  if (item.type === "quote") {
    quote.textContent = item.text;
    quote.hidden = false;
    return;
  }
  if (item.type === "wiki") {
    const [icon, label] = WIKI[item.kind] || ["menu_book", "Wikipedia"];
    $("biteIcon").textContent = icon;
    $("biteKind").textContent = item.kind === "otd" ? label + " · " + item.title : label;
    $("biteTitle").textContent = item.kind === "otd" ? "" : item.title;
    $("biteText").textContent = item.text;
    // Link kommt aus der Wikipedia-API (über den Feed): nur https zulassen, kein chrome:/file:/javascript:
    const url = typeof item.url === "string" && /^https:\/\//i.test(item.url) ? item.url : "";
    $("biteMore").hidden = !url;
    if (url)
      $("biteMore").href = url;
  } else {
    $("biteIcon").textContent = item.ai ? "auto_awesome" : "tips_and_updates";
    $("biteKind").textContent = "Tip · " + item.tag;
    $("biteTitle").textContent = item.title;
    setRich($("biteText"), item.text);
    $("biteMore").hidden = true;
  }
  bite.hidden = false;
}

function next(e) {
  if (e.target.closest("a"))
    return;
  const el = e.currentTarget;
  el.classList.add("swap");
  setTimeout(() => {
    showBite();
    el.classList.remove("swap");
  }, 150);
}
$("bite").addEventListener("click", next);
$("quote").addEventListener("click", next);

// ---------- Termin + Wetter ----------
// wie der Termin-Chip der Bar: nächster Termin heute oder morgen, ganztägige zählen nicht
function nextEvent(events, now) {
  const day = new Date(now);
  day.setHours(0, 0, 0, 0);
  const tomorrowStart = day.getTime() + 86400000;
  const limit = tomorrowStart + 86400000;
  let best = null;
  for (const e of events || []) {
    if (e.allDay || e.end <= now || e.start >= limit)
      continue;
    if (!best || e.start < best.start)
      best = e;
  }
  return best ? { e: best, tomorrow: best.start >= tomorrowStart } : null;
}

function renderInfo() {
  const now = Date.now();
  const ev = shell ? nextEvent(shell.events, now) : null;
  const chip = $("event");
  if (ev) {
    const running = ev.e.start <= now;
    const min = Math.ceil((ev.e.start - now) / 60000);
    const when = running ? "now" : min <= 60 ? "in " + min + " min" : (ev.tomorrow ? "tomorrow " : "") + hm(new Date(ev.e.start));
    $("eventText").textContent = when + " · " + (ev.e.title || "Event");
    chip.title = ev.e.location || "";
    chip.classList.toggle("soon", running || min <= 60);
    chip.hidden = false;
  } else {
    chip.hidden = true;
  }

  const w = shell && shell.weather;
  // Wetter nur, wenn die Shell es in den letzten 3 h geschrieben hat
  if (w && typeof w.temp === "number" && now - (w.updated || 0) < 3 * 3600000) {
    $("weatherIcon").textContent = w.icon || "cloud";
    $("weatherText").textContent = Math.round(w.temp) + "° · " + (w.label || "");
    $("weather").hidden = false;
  } else {
    $("weather").hidden = true;
  }
}

chrome.storage.local.get("shell").then(r => {
  shell = r.shell || null;
  renderInfo();
  showBite();
}).catch(() => showBite());
chrome.storage.onChanged.addListener((changes, area) => {
  if (area === "local" && changes.shell) {
    shell = changes.shell.newValue || null;
    renderInfo();
  }
});
chrome.runtime.sendMessage({ type: "refresh" }).catch(() => {});

tick();

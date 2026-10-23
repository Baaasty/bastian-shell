// Desktop – Hintergrund (Service Worker).
// Meldet offene Tabs an den Native-Messaging-Host (scripts/chrome-ext -> ~/.cache/desktop/chrome-tabs.json),
// führt Befehle der Shell aus (Tab aktivieren) und legt Shell-Daten (Termine, Wetter)
// für die neue Tab-Seite in chrome.storage.local ab. Ohne installierten Host läuft die Seite trotzdem.
// Dazu Passwörter (iCloud über scripts/passwords, siehe unten „Passwörter“): Vermittler zwischen
// autofill.js / popup.js und dem Host, prüft Herkunft und gibt Geheimnisse nur auf Klick heraus;
// nach dem Abschicken eines Login-Formulars Speichern anbieten (siehe „Speichern anbieten“).
const HOST = "de.bastian.desktop";
const NEWTAB = chrome.runtime.getURL("newtab.html");

let port = null;
let retries = 0;
let pending = 0;
let hostFeatures = null;   // aus der "hello"-Nachricht des Hosts; alte Hosts schicken keine
let connectedAt = 0;

function connect() {
  if (port)
    return;
  try {
    port = chrome.runtime.connectNative(HOST);
  } catch (e) {
    port = null;
    return;
  }
  connectedAt = Date.now();
  hostFeatures = null;
  port.onMessage.addListener(onHost);
  port.onDisconnect.addListener(() => {
    void chrome.runtime.lastError; // lesen, sonst meckert Chrome
    port = null;
    failAll("Desktop host disconnected");
    // Host fehlt oder ist abgestürzt: mit wachsendem Abstand neu versuchen (max. ~2 min).
    // Schläft der Worker vorher ein, verbindet ihn das nächste Tab-Ereignis neu.
    retries = Math.min(retries + 1, 6);
    setTimeout(connect, 2000 * 2 ** retries);
  });
  report();
}

function onHost(msg) {
  if (!msg || typeof msg !== "object")
    return;
  retries = 0;
  if (msg.type === "pw") {
    const done = waiting.get(msg.id);
    if (done) {
      waiting.delete(msg.id);
      done(msg);
    }
  } else if (msg.type === "offer-bar") {
    showBar(msg);
  } else if (msg.type === "hello") {
    hostFeatures = Array.isArray(msg.features) ? msg.features : [];
  } else if (msg.type === "activate" && Number.isInteger(msg.tabId)) {
    chrome.tabs.update(msg.tabId, { active: true })
      .then(tab => chrome.windows.update(tab.windowId, { focused: true }))
      .catch(() => {});
  } else if (msg.type === "shell" && msg.data) {
    chrome.storage.local.set({ shell: msg.data });
  } else if (msg.type === "report") {
    report();
  }
}

// Tabs gesammelt melden (viele Ereignisse kurz hintereinander -> eine Nachricht)
function report() {
  clearTimeout(pending);
  pending = setTimeout(send, 250);
}

async function send() {
  if (!port)
    return;
  try {
    const [tabs, focused] = await Promise.all([
      chrome.tabs.query({}),
      chrome.windows.getLastFocused().catch(() => null),
    ]);
    const list = tabs
      .filter(t => !t.incognito && t.url && !t.url.startsWith(NEWTAB) && t.url !== "chrome://newtab/")
      .map(t => ({
        id: t.id,
        windowId: t.windowId,
        index: t.index,
        title: t.title || t.url,
        url: t.url,
        active: t.active,
        pinned: t.pinned,
        audible: !!t.audible,
        lastAccessed: t.lastAccessed || 0,
      }));
    // aktiver Tab je Fenster (auch neue Tab-Seiten): daran erkennt die Shell das Fenster am Titel
    const activeTitles = {};
    // Inkognito-Titel nicht melden (wie in der Tab-Liste oben; landen sonst in chrome-tabs.json)
    for (const t of tabs)
      if (t.active && !t.incognito)
        activeTitles[t.windowId] = t.title || "";
    port.postMessage({ type: "tabs", focusedWindow: focused ? focused.id : -1, activeTitles, tabs: list });
  } catch (e) {}
}

chrome.tabs.onCreated.addListener(report);
chrome.tabs.onRemoved.addListener(report);
chrome.tabs.onActivated.addListener(report);
chrome.tabs.onMoved.addListener(report);
chrome.tabs.onAttached.addListener(report);
chrome.tabs.onDetached.addListener(report);
chrome.tabs.onUpdated.addListener((id, change) => {
  if ("title" in change || "url" in change || "pinned" in change || "audible" in change)
    report();
});
chrome.windows.onFocusChanged.addListener(report);
chrome.windows.onRemoved.addListener(report);

// neue Tab-Seite fragt beim Öffnen nach frischen Daten
chrome.runtime.onMessage.addListener((msg) => {
  if (msg && msg.type === "refresh") {
    connect();
    if (port)
      port.postMessage({ type: "refresh" });
  }
});

// ---------- Passwörter ----------
// Regeln:
//  - Seiten (autofill.js) bekommen ohne Klick nur Metadaten (Titel, Benutzer, Website, hat 2FA).
//  - Passwort/Code nur auf ausdrücklichen Klick, nur an den anfragenden Frame (sendResponse), nur bei https
//    oder http://localhost und nur im obersten Frame oder einem Frame mit derselben Origin wie der Tab.
//  - Ob der Eintrag zur Seite passt, entscheidet der Host (scripts/passwords match) – nicht die Nachricht.
//  - Nichts davon wird geloggt oder in chrome.storage abgelegt; nur Variablen bis zur Antwort.
let seq = 0;
const waiting = new Map();
const lastPicked = new Map();   // tabId -> zuletzt gewählter Eintrag (nur ID, nur im Speicher), für E-Mail-zuerst-Logins

function failAll(error) {
  for (const done of waiting.values())
    done({ ok: false, error });
  waiting.clear();
}

async function hostReady() {
  connect();
  if (!port)
    return "Desktop host not reachable – run scripts/chrome-ext install";
  // frisch verbunden: kurz auf "hello" warten; kommt keins, ist es ein alter Host ohne Passwörter
  while (!hostFeatures && port && Date.now() - connectedAt < 3000)
    await new Promise(r => setTimeout(r, 100));
  if (!port)
    return "Desktop host not reachable – run scripts/chrome-ext install";
  if (!hostFeatures || !hostFeatures.includes("pw"))
    return "Desktop host is outdated – run scripts/chrome-ext install, then reload the extension";
  return "";
}

async function hostPw(op, args = {}) {
  const problem = await hostReady();
  if (problem)
    return { ok: false, error: problem };
  const id = ++seq;
  return new Promise(resolve => {
    const timer = setTimeout(() => {
      waiting.delete(id);
      resolve({ ok: false, error: "Desktop host timed out" });
    }, 30000);
    waiting.set(id, msg => {
      clearTimeout(timer);
      resolve(msg);
    });
    try {
      port.postMessage({ type: "pw", id, op, ...args });
    } catch (e) {
      waiting.delete(id);
      clearTimeout(timer);
      resolve({ ok: false, error: "Desktop host not reachable" });
    }
  });
}

function isLocal(host) {
  return host === "localhost" || host === "127.0.0.1" || host === "[::1]" || host.endsWith(".localhost");
}

// URL einer Seite, die Geheimnisse bekommen darf (secure) bzw. nur gelistet wird
function pageUrl(raw, secure) {
  let u;
  try {
    u = new URL(raw);
  } catch (e) {
    return null;
  }
  if (u.protocol === "https:" || (u.protocol === "http:" && (!secure || isLocal(u.hostname))))
    return u.origin + u.pathname;
  return null;
}

// Frame eines Content-Scripts prüfen: eigene Erweiterung, Tab vorhanden, oberster Frame oder gleiche Origin wie der Tab
function senderPage(sender, secure) {
  if (!sender || sender.id !== chrome.runtime.id || !sender.tab || !sender.url)
    return null;
  let origin, top;
  try {
    origin = sender.origin && sender.origin !== "null" ? sender.origin : new URL(sender.url).origin;
    top = new URL(sender.tab.url || "").origin;
  } catch (e) {
    return null;
  }
  if (sender.frameId !== 0 && origin !== top)
    return null;
  const url = pageUrl(sender.url, secure);
  return url && new URL(url).origin === origin ? url : null;
}

// Popup (auch als Tab geöffnet): Absender-URL ist eine Seite dieser Erweiterung – Content-Scripts haben dort die Seiten-URL
function fromExtensionPage(sender) {
  return sender && sender.id === chrome.runtime.id
    && typeof sender.url === "string" && sender.url.startsWith(chrome.runtime.getURL(""));
}

async function activeTab() {
  const [tab] = await chrome.tabs.query({ active: true, lastFocusedWindow: true });
  return tab || null;
}

function rankPicked(tabId, res) {
  const pick = lastPicked.get(tabId);
  if (res.ok && pick && Array.isArray(res.entries)) {
    const i = res.entries.findIndex(e => e.id === pick);
    if (i > 0)
      res.entries.unshift(...res.entries.splice(i, 1));
  }
  return res;
}

const fail = error => ({ ok: false, error });

// Nachrichten von autofill.js (Seiten-Frames)
async function fromPage(msg, sender) {
  const tabId = sender.tab && sender.tab.id;
  switch (msg.cmd) {
  case "match": {
    const url = senderPage(sender, false);
    if (!url)
      return fail("not allowed here");
    const res = await hostPw("match", { url });
    return { ...rankPicked(tabId, res), secure: !!senderPage(sender, true) };
  }
  case "aliases": {
    if (!senderPage(sender, true))
      return fail("not allowed here");
    return hostPw("aliases");
  }
  case "alias-new": {
    const page = senderPage(sender, true);
    if (!page)
      return fail("not allowed here");
    return hostPw("alias-new", { url: page });
  }
  case "emails": {
    if (!senderPage(sender, true))
      return fail("not allowed here");
    return hostPw("emails");
  }
  case "offer-user":
  case "offer-save":
  case "offer-commit":
  case "offer-cancel":
  case "offer-answer":
    return fromPageOffer(msg, sender);
  case "fill":
  case "totp": {
    // Geheimnis: nur sichere Seite, nur dieser Frame, nur ein Eintrag, der laut Host zur Seite passt
    const url = senderPage(sender, true);
    if (!url || typeof msg.entry !== "string")
      return fail("not allowed here");
    const res = await hostPw(msg.cmd, { url, entry: msg.entry });
    if (res.ok && msg.cmd === "fill")
      lastPicked.set(tabId, msg.entry);
    return res;
  }
  }
  return fail("unknown request");
}

// Nachrichten vom Popup (Erweiterungsseite) – immer bezogen auf den aktiven Tab
async function fromPopup(msg) {
  const tab = await activeTab();
  if (!tab)
    return fail("no active tab");
  switch (msg.cmd) {
  case "popup-status": {
    const url = tab.url ? pageUrl(tab.url, false) : null;
    const status = await hostPw("status");
    if (!status.ok)
      return status;
    if (!url)
      return { ok: true, count: status.count, entries: [], page: null };
    const res = rankPicked(tab.id, await hostPw("match", { url }));
    if (!res.ok)
      return res;
    return { ok: true, count: status.count, entries: res.entries, page: new URL(url).hostname,
             secure: !!pageUrl(tab.url, true) };
  }
  case "popup-copy": {
    const url = tab.url ? pageUrl(tab.url, false) : null;
    if (!url || typeof msg.entry !== "string")
      return fail("no page");
    // Wert bleibt im Host: scripts/passwords copy (wl-copy --sensitive, nach 30 s leer)
    return hostPw("copy", { url, entry: msg.entry, field: msg.field });
  }
  case "popup-fill": {
    const url = tab.url ? pageUrl(tab.url, true) : null;
    if (!url || typeof msg.entry !== "string")
      return fail("Autofill only works on https pages (and http://localhost)");
    const res = await hostPw("fill", { url, entry: msg.entry });
    if (!res.ok)
      return res;
    lastPicked.set(tab.id, msg.entry);
    try {
      // nur oberster Frame; autofill.js prüft dort noch einmal, dass die Origin stimmt (Tab inzwischen woanders?)
      const r = await chrome.tabs.sendMessage(tab.id,
        { cmd: "fill-in", origin: new URL(url).origin, user: res.user, password: res.password },
        { frameId: 0 });
      return r && r.ok ? { ok: true } : fail(r && r.error || "no login form found");
    } catch (e) {
      return fail("Page not ready – reload it once after installing the extension");
    }
  }
  }
  return fail("unknown request");
}

chrome.runtime.onMessage.addListener((msg, sender, sendResponse) => {
  if (!msg || typeof msg.cmd !== "string")
    return false;
  let work;
  if (msg.cmd.startsWith("popup-")) {
    if (!fromExtensionPage(sender))
      return false;
    work = fromPopup(msg);
  } else {
    if (!sender.tab)
      return false;
    work = fromPage(msg, sender);
  }
  work.then(sendResponse, () => sendResponse(fail("internal error")));
  return true;
});

chrome.tabs.onRemoved.addListener(tabId => lastPicked.delete(tabId));

// ---------- Speichern anbieten ----------
// autofill.js meldet ein abgeschicktes Formular („offer-save“). Gefragt wird erst, wenn der Login wohl geklappt hat:
// Seite navigiert weg und die neue zeigt kein Login-Formular mehr, oder (SPA) das Passwortfeld ist verschwunden
// („offer-commit“ vom Content-Script). Bis dahin liegt das Passwort nur hier in einer Variablen (nie in
// chrome.storage), danach nur noch im Host. Die Leiste in der Seite bekommt es nie zurück.
const OFFER_HOLD_MS = 60000;
const USER_STEP_MS = 5 * 60000;
const heldOffers = new Map();   // tabId -> {doc, url, user, password, signup, timer}
const userSteps = new Map();    // tabId -> {site, user, at}: Benutzer aus Schritt 1 eines E-Mail-zuerst-Logins
const barOffers = new Map();    // offer-id -> tabId (Leiste gezeigt, Antwort nur aus diesem Tab)

function siteOf(url) {
  try {
    return new URL(url).hostname.toLowerCase().replace(/^www\./, "").split(".").slice(-2).join(".");
  } catch (e) {
    return "";
  }
}

function dropHeld(tabId) {
  const h = heldOffers.get(tabId);
  if (h) {
    clearTimeout(h.timer);
    heldOffers.delete(tabId);
  }
}

async function commitHeld(tabId) {
  const h = heldOffers.get(tabId);
  if (!h)
    return;
  dropHeld(tabId);
  let user = h.user;
  const step = userSteps.get(tabId);
  if (!user && step && step.site === siteOf(h.url) && Date.now() - step.at < USER_STEP_MS)
    user = step.user;
  userSteps.delete(tabId);
  if (!user)
    return;   // iCloud braucht einen Benutzer
  // Antwort egal: fragt der Host, meldet er sich bei Bedarf selbst („offer-bar“)
  await hostPw("offer", { url: h.url, user, password: h.password, signup: h.signup, tab: tabId });
}

// Seite fertig geladen, während ein Angebot wartet: neue Seite fragen, ob da wieder ein Login-Formular ist
// (dann war das Passwort wohl falsch). Kein Content-Script (z. B. Weiterleitung auf http) -> trotzdem fragen.
chrome.tabs.onUpdated.addListener(async (tabId, change) => {
  if (change.status !== "complete" || !heldOffers.has(tabId))
    return;
  const h = heldOffers.get(tabId);
  // document_idle: das Content-Script kann kurz nach „complete“ erst ankommen -> ein paar Versuche
  let probe = null;
  for (let i = 0; i < 4 && !probe; i++) {
    if (i)
      await new Promise(r => setTimeout(r, 400));
    try {
      probe = await chrome.tabs.sendMessage(tabId, { cmd: "offer-probe" }, { frameId: 0 });
    } catch (e) {}
  }
  if (heldOffers.get(tabId) !== h)
    return;
  if (probe && probe.doc === h.doc)
    return;   // dasselbe Dokument (SPA): entscheidet autofill.js selbst
  if (probe && (h.signup ? probe.signup : probe.login))
    dropHeld(tabId);
  else
    commitHeld(tabId);
});

chrome.tabs.onRemoved.addListener(tabId => {
  dropHeld(tabId);
  userSteps.delete(tabId);
});

async function fromPageOffer(msg, sender) {
  // nur oberster Frame einer https-/localhost-Seite
  const url = sender.frameId === 0 ? senderPage(sender, true) : null;
  const tabId = sender.tab.id;
  if (!url)
    return fail("not allowed here");
  switch (msg.cmd) {
  case "offer-user":
    if (typeof msg.user !== "string" || !msg.user.trim() || msg.user.length > 256)
      return fail("bad request");
    userSteps.set(tabId, { site: siteOf(url), user: msg.user.trim(), at: Date.now() });
    return { ok: true };
  case "offer-save": {
    if (typeof msg.password !== "string" || !msg.password || msg.password.length > 1024
        || typeof msg.user !== "string" || msg.user.length > 256 || typeof msg.doc !== "string")
      return fail("bad request");
    dropHeld(tabId);
    const h = { doc: msg.doc, url, user: msg.user.trim(), password: msg.password, signup: !!msg.signup };
    h.timer = setTimeout(() => {
      if (heldOffers.get(tabId) === h)
        heldOffers.delete(tabId);
    }, OFFER_HOLD_MS);
    heldOffers.set(tabId, h);
    return { ok: true };
  }
  case "offer-commit":
  case "offer-cancel": {
    const h = heldOffers.get(tabId);
    if (!h || h.doc !== msg.doc)
      return fail("nothing held");
    if (msg.cmd === "offer-cancel")
      dropHeld(tabId);
    else
      commitHeld(tabId);
    return { ok: true };
  }
  case "offer-answer": {
    if (typeof msg.offer !== "string" || barOffers.get(msg.offer) !== tabId)
      return fail("unknown offer");
    barOffers.delete(msg.offer);
    return hostPw("offer-answer", { offer: msg.offer, answer: msg.answer, tab: tabId });
  }
  }
  return fail("unknown request");
}

// Host: Benachrichtigung wurde nicht gezeigt (Fokus-Modus, Ruhezeit) -> Leiste im obersten Frame des Tabs.
// Kommt nur Website + Benutzer mit, nie das Passwort. Seite lädt evtl. noch: ein paar Mal versuchen.
async function showBar(msg) {
  if (typeof msg.offer !== "string" || !Number.isInteger(msg.tab))
    return;
  barOffers.set(msg.offer, msg.tab);
  setTimeout(() => barOffers.delete(msg.offer), 125000);   // Host vergisst das Angebot nach OFFER_TTL
  const bar = { cmd: "offer-bar", offer: msg.offer, kind: msg.kind, site: msg.site, user: msg.user };
  for (let i = 0; i < 4; i++) {
    try {
      const r = await chrome.tabs.sendMessage(msg.tab, bar, { frameId: 0 });
      if (r && r.ok)
        return;
    } catch (e) {}
    await new Promise(r => setTimeout(r, 1500));
  }
  barOffers.delete(msg.offer);
  hostPw("offer-answer", { offer: msg.offer, answer: "dismiss", tab: msg.tab });
}

chrome.runtime.onStartup.addListener(connect);
chrome.runtime.onInstalled.addListener(connect);
connect();

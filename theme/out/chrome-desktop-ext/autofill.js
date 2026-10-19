// Desktop – Autofill (Content-Script auf https-Seiten und http://localhost).
// Dropdown an Login-Feldern (iCloud-Passwörter), an 2FA-Feldern (Code wird erst beim Klick geholt) und
// Hide-My-Email-Vorschläge an E-Mail-Feldern bei Registrierungen. Daten: background.js -> Native Host
// (scripts/chrome-ext) -> scripts/passwords.
//
// Herkunft: Feld-Erkennung (Benutzer/Passwort, Passwort als type=text, 2FA-Stichwörter, 4–10 Einzelfelder,
// Shadow DOM) angepasst aus icp „Apple Passwords“ extension/content.js,
// https://github.com/Sank6/iCloud-Keychain-for-Linux – MIT License, Copyright (c) 2026 Sankarsh Makam.
// Geändert: Geheimnisse erst auf Klick (nicht schon beim Öffnen), nur sichtbare Felder, Menü in
// geschlossenem Shadow Root (Seite kann es nicht lesen), nur vertrauenswürdige Ereignisse, Desktop-Look.
(function () {
  "use strict";

  if (globalThis.__desktopAutofill)
    return;
  globalThis.__desktopAutofill = true;

  const isLocal = h => h === "localhost" || h === "127.0.0.1" || h === "[::1]" || h.endsWith(".localhost");
  const SECURE = location.protocol === "https:" || (location.protocol === "http:" && isLocal(location.hostname));
  if (!SECURE)
    return;
  // Iframes: nur, wenn alle Vorfahren dieselbe Origin haben (fremde Iframes bekommen nichts)
  if (window !== window.top) {
    const anc = location.ancestorOrigins;
    if (!anc || !anc.length || Array.from(anc).some(o => o !== location.origin))
      return;
  }

  // ---------- Feld-Erkennung (nach icp) ----------
  const PASSWORD_SEL = 'input[type="password"]';
  const USERNAME_SEL =
    'input[type="text"], input[type="email"], input[type="tel"], input[type="username"], input:not([type])';
  const OTP_SEL = 'input[type="text"], input[type="tel"], input[type="number"], input:not([type])';
  const SEGMENT_SEL = 'input[maxlength="1"]';
  const FIELD_SEL = `${PASSWORD_SEL}, ${USERNAME_SEL}, input[type="number"]`;
  const OTP_TYPES = new Set(["text", "tel", "number"]);

  function visible(el) {
    if (!el || !el.isConnected || el.disabled || el.readOnly)
      return false;
    if (el.checkVisibility && !el.checkVisibility({ checkOpacity: true, checkVisibilityCSS: true }))
      return false;
    const r = el.getBoundingClientRect();
    return r.width > 4 && r.height > 4;
  }

  function deepQueryAll(selector, root) {
    const out = [];
    const walk = node => {
      node.querySelectorAll(selector).forEach(el => out.push(el));
      node.querySelectorAll("*").forEach(el => {
        if (el.shadowRoot)
          walk(el.shadowRoot);
      });
    };
    walk(root || document);
    return out;
  }

  function words(el) {
    return `${el.name} ${el.id} ${el.autocomplete} ${el.placeholder || ""} ${el.getAttribute("aria-label") || ""} ${
      typeof el.className === "string" ? el.className : ""}`.toLowerCase();
  }

  const squash = el => words(el).replace(/[\s_-]/g, "");

  function looksLikeUsername(el) {
    return /user|email|e-mail|login|account|identif|phone|tel\b|benutzer|anmelde|konto/.test(words(el))
      || el.type === "email" || el.type === "username";
  }

  function looksLikeEmail(el) {
    if (el.type === "email" || /(^|\s)email(\s|$)/.test(el.autocomplete || ""))
      return true;
    return OTP_TYPES.has(el.type || "text") && /e-?mail/.test(words(el)) && !/confirm|repeat|wiederhol|bestätig/.test(words(el));
  }

  const OTP_KEYWORDS = [
    "2facode", "approvalscode", "authcode", "authentication", "mfacode", "onetimecode",
    "onetimepassword", "otccode", "otcconfirmation", "otpcode", "secondfactor", "securitycode",
    "smscode", "totp", "totpcode", "twofa", "twofactor", "twofactorcode", "verificationcode",
    "verifycode", "bestätigungscode", "sicherheitscode", "einmalcode",
  ];
  const OTP_NEVER = ["recovery", "backup", "wiederherstell"];
  const OTP_AMBIGUOUS = ["code", "otc", "otp", "2fa", "mfa", "pin", "token", "challenge"];
  const OTP_EXCLUDE = [
    "zip", "postal", "postcode", "plz", "coupon", "promo", "discount", "gutschein", "referral",
    "invite", "area", "country", "currency", "barcode", "encode", "decode", "search", "captcha",
    "user", "email", "phone", "address",
  ];

  function namedLikeOtp(el) {
    const w = squash(el);
    if (OTP_NEVER.some(x => w.includes(x)))
      return false;
    if ((el.autocomplete || "").toLowerCase().includes("one-time-code"))
      return true;
    if (!OTP_TYPES.has(el.type))
      return false;
    if (OTP_EXCLUDE.some(x => w.includes(x)))
      return false;
    if (OTP_KEYWORDS.some(x => w.includes(x)))
      return true;
    if (!OTP_AMBIGUOUS.some(x => w.includes(x)))
      return false;
    return (el.maxLength >= 4 && el.maxLength <= 10) || el.inputMode === "numeric" || /0-9|\\d/.test(el.pattern || "");
  }

  // 4–10 Einzelfelder mit maxlength=1 (z. B. 6 Kästchen für den Code)
  function segmentGroup(el) {
    if (el.maxLength !== 1)
      return null;
    const group = deepQueryAll(SEGMENT_SEL, el.form || el.getRootNode())
      .filter(f => visible(f) && f.maxLength === 1 && OTP_TYPES.has(f.type));
    return group.length >= 4 && group.length <= 10 && group.includes(el) ? group : null;
  }

  const isOtpField = el => namedLikeOtp(el) || !!segmentGroup(el);

  // Manche Seiten zeigen das Passwortfeld als type="text" (LinkedIn)
  function looksLikePassword(el) {
    if (el.type === "password")
      return true;
    if (!OTP_TYPES.has(el.type))
      return false;
    const w = squash(el);
    return (w.includes("password") || w.includes("passwort"))
      && !/passwordless|passwordhint|forgotpassword|resetpassword|passwortvergessen/.test(w);
  }

  // Eine Seite kann dasselbe Formular mehrfach enthalten -> erst im eigenen Formular suchen. Nur sichtbare Felder.
  function within(el, selector) {
    const scoped = el && el.form ? deepQueryAll(selector, el.form).filter(visible) : [];
    return scoped.length ? scoped : deepQueryAll(selector).filter(visible);
  }

  const passwordFields = anchor => within(anchor, FIELD_SEL).filter(looksLikePassword);

  function findUsernameField(pw) {
    const all = within(pw, USERNAME_SEL).filter(el => !looksLikePassword(el) && !isOtpField(el));
    const before = all.filter(el => pw.compareDocumentPosition(el) & Node.DOCUMENT_POSITION_PRECEDING).reverse();
    return before.find(looksLikeUsername) || before[0] || all.find(looksLikeUsername) || null;
  }

  // Registrierung? (neues Passwort, Passwort + Wiederholung, Wörter in Formular/URL/Knöpfen)
  function signupContext(field) {
    const form = field.form || field.closest("form");
    const pws = deepQueryAll(PASSWORD_SEL, form || document).filter(visible);
    if (pws.some(p => /new-password/.test(p.autocomplete || "")) || pws.length >= 2)
      return true;
    if (pws.some(p => /current-password/.test(p.autocomplete || "")))
      return false;
    const buttons = form ? Array.from(form.querySelectorAll('button, input[type="submit"]'))
      .map(b => b.textContent || b.value || "").join(" ") : "";
    const hay = [location.pathname, location.hash, form && form.getAttribute("action"), form && form.id,
                 form && typeof form.className === "string" ? form.className : "", form && form.name,
                 buttons, document.title].join(" ").toLowerCase();
    return /sign[\s_-]?up|register|registr|create[\s_-]?(an?[\s_-]?)?account|new[\s_-]?account|join|enroll|konto[\s_-]?(erstellen|anlegen|eröffnen)|neues[\s_-]?konto/.test(hay);
  }

  function setValue(el, value) {
    const proto = el.tagName === "TEXTAREA" ? HTMLTextAreaElement.prototype : HTMLInputElement.prototype;
    Object.getOwnPropertyDescriptor(proto, "value").set.call(el, value);
    el.dispatchEvent(new Event("input", { bubbles: true, composed: true }));
    el.dispatchEvent(new Event("change", { bubbles: true }));
  }

  // ---------- Daten (über background.js) ----------
  function send(msg) {
    return new Promise(resolve => {
      try {
        if (!chrome.runtime || !chrome.runtime.id)
          return resolve({ ok: false, error: "extension reloaded – reload this page" });
        chrome.runtime.sendMessage(msg, r => resolve(chrome.runtime.lastError ? { ok: false, error: "no answer" }
                                                                               : (r || { ok: false })));
      } catch (e) {
        resolve({ ok: false, error: "extension reloaded – reload this page" });
      }
    });
  }

  let matches = null;   // Promise der Metadaten (ohne Geheimnisse), pro Dokument, 2 min gültig
  let matchesAt = 0;
  let aliases = null;

  function getMatches() {
    if (!matches || Date.now() - matchesAt > 120000) {
      matchesAt = Date.now();
      matches = send({ cmd: "match" }).then(r => (r.ok && Array.isArray(r.entries) ? r.entries : []));
    }
    return matches;
  }

  function getAliases() {
    if (!aliases)
      aliases = send({ cmd: "aliases" }).then(r => (r.ok && Array.isArray(r.aliases) ? r.aliases : []));
    return aliases;
  }

  // ---------- Ausfüllen ----------
  function fillLogin(anchor, user, password) {
    const pws = passwordFields(anchor);
    const pw = anchor && looksLikePassword(anchor) && visible(anchor) ? anchor : pws[0] || null;
    let userField = null;
    if (anchor && !looksLikePassword(anchor) && !isOtpField(anchor) && visible(anchor))
      userField = anchor;
    else if (pw)
      userField = findUsernameField(pw);
    let filled = false;
    if (userField && user) {
      setValue(userField, user);
      filled = true;
    }
    if (pw && password) {
      setValue(pw, password);
      filled = true;
    }
    return { filled, otp: within(anchor || pw, OTP_SEL).find(isOtpField) || null };
  }

  function fillCode(anchor, code) {
    const group = segmentGroup(anchor);
    if (group && code.length >= group.length) {
      group.forEach((el, i) => setValue(el, code[i]));
      group[group.length - 1].focus();
    } else {
      setValue(anchor, code);
    }
  }

  async function act(item, anchor) {
    if (item.kind === "alias") {
      setValue(anchor, item.alias.address);
      close();
      return;
    }
    busy(true);
    const entry = item.entry;
    if (item.kind === "otp") {
      const r = await send({ cmd: "totp", entry: entry.id });
      if (!r.ok || !r.code)
        return problem(r.error || "No code");
      fillCode(anchor, String(r.code));
      close();
      return;
    }
    const r = await send({ cmd: "fill", entry: entry.id });
    if (!r.ok)
      return problem(r.error || "Could not fill");
    const res = fillLogin(anchor, r.user, r.password);
    close();
    // 2FA-Feld im selben Formular? Code gleich mit eintragen (frisch geholt)
    if (entry.hasTotp && res.otp) {
      const t = await send({ cmd: "totp", entry: entry.id });
      if (t.ok && t.code)
        fillCode(res.otp, String(t.code));
    }
  }

  // Popup -> „Fill“: nur oberster Frame, nur wenn die Seite noch dieselbe Origin hat
  chrome.runtime.onMessage.addListener((msg, sender, respond) => {
    if (!msg || msg.cmd !== "fill-in" || sender.id !== chrome.runtime.id || window !== window.top)
      return false;
    if (msg.origin !== location.origin) {
      respond({ ok: false, error: "page changed" });
      return false;
    }
    const focused = deepActive();
    let anchor = focused && focused.tagName === "INPUT" && visible(focused) ? focused : null;
    if (!anchor || isOtpField(anchor)) {
      const pw = passwordFields(null)[0];
      anchor = pw ? (findUsernameField(pw) || pw)
                  : deepQueryAll(USERNAME_SEL).filter(visible).find(looksLikeUsername) || null;
    }
    if (!anchor) {
      respond({ ok: false, error: "No login form found on this page" });
      return false;
    }
    const res = fillLogin(anchor, msg.user, msg.password);
    close();
    respond(res.filled ? { ok: true } : { ok: false, error: "No login form found on this page" });
    return false;
  });

  // ---------- Menü (geschlossener Shadow Root, Top Layer) ----------
  const host = document.createElement("desktop-autofill");
  host.style.cssText = "all:initial;position:fixed;inset:auto;top:0;left:0;width:0;height:0;margin:0;padding:0;"
    + "border:0;background:transparent;overflow:visible;z-index:2147483647;pointer-events:none";
  const root = host.attachShadow({ mode: "closed" });
  try {
    const sheet = new CSSStyleSheet();
    sheet.replaceSync(globalThis.DESKTOP_AUTOFILL_CSS || "");
    root.adoptedStyleSheets = [sheet];   // CSSOM: nicht von der CSP der Seite betroffen
  } catch (e) {}

  let menu = null;
  let anchorEl = null;
  let items = [];
  let active = -1;
  let openSeq = 0;

  const ICONS = {
    key: "M7 14a2 2 0 1 1 0-4 2 2 0 0 1 0 4Zm5.65-4A6 6 0 1 0 12.65 14H17v4h4v-4h2v-4H12.65Z",
    shield: "M12 2 4 5v6c0 5.25 3.4 10.15 8 11.5 4.6-1.35 8-6.25 8-11.5V5l-8-3Zm-1 14-3.5-3.5 1.4-1.4L11 13.2l4.6-4.6 1.4 1.4L11 16Z",
    mail: "M4 5h16a2 2 0 0 1 2 2v10a2 2 0 0 1-2 2H4a2 2 0 0 1-2-2V7a2 2 0 0 1 2-2Zm8 7 8-5H4l8 5Zm0 2L4 9v8h16V9l-8 5Z",
  };

  function el(tag, cls, text) {
    const e = document.createElement(tag);
    if (cls)
      e.className = cls;
    if (text != null)
      e.textContent = text;
    return e;
  }

  function icon(name) {
    const ns = "http://www.w3.org/2000/svg";
    const svg = document.createElementNS(ns, "svg");
    svg.setAttribute("viewBox", "0 0 24 24");
    svg.setAttribute("class", "ico");
    const path = document.createElementNS(ns, "path");
    path.setAttribute("d", ICONS[name]);
    svg.appendChild(path);
    return svg;
  }

  function deepActive() {
    let a = document.activeElement;
    while (a && a.shadowRoot && a.shadowRoot.activeElement)
      a = a.shadowRoot.activeElement;
    return a;
  }

  function close() {
    openSeq++;
    if (menu) {
      menu.remove();
      menu = null;
    }
    items = [];
    active = -1;
    anchorEl = null;
    if (host.isConnected) {
      try {
        host.hidePopover();
      } catch (e) {}
      host.remove();
    }
  }

  function place() {
    if (!menu || !anchorEl)
      return;
    if (!visible(anchorEl))
      return close();
    const r = anchorEl.getBoundingClientRect();
    const w = Math.min(Math.max(r.width, 280), 380);
    const left = Math.max(8, Math.min(r.left, innerWidth - w - 8));
    menu.style.width = w + "px";
    menu.style.left = left + "px";
    const below = innerHeight - r.bottom - 12;
    const h = menu.offsetHeight;
    if (h > below && r.top - 12 > below) {
      menu.style.top = "";
      menu.style.bottom = (innerHeight - r.top + 6) + "px";
      menu.style.maxHeight = Math.max(120, r.top - 18) + "px";
    } else {
      menu.style.bottom = "";
      menu.style.top = (r.bottom + 6) + "px";
      menu.style.maxHeight = Math.max(120, below - 6) + "px";
    }
  }

  function initial(s) {
    return ((s || "?").trim().replace(/^[^a-z0-9]+/i, "").charAt(0) || "?").toUpperCase();
  }

  function row(item, i) {
    const r = el("div", "row");
    r.setAttribute("role", "option");
    if (item.kind === "alias") {
      r.appendChild(el("div", "avatar alias")).appendChild(icon("mail"));
      const meta = r.appendChild(el("div", "meta"));
      meta.appendChild(el("div", "main", item.alias.address));
      meta.appendChild(el("div", "sub", item.alias.label || item.alias.domain || "Hide My Email"));
    } else {
      const e = item.entry;
      r.appendChild(el("div", "avatar", initial(e.title || e.site || e.user)));
      const meta = r.appendChild(el("div", "meta"));
      meta.appendChild(el("div", "main", e.user || e.title || "(no username)"));
      const sub = [e.title, e.site && e.site !== (e.title || "").toLowerCase() ? e.site : ""].filter(Boolean).join(" · ");
      meta.appendChild(el("div", "sub", sub));
      r.appendChild(el("div", "tail", item.kind === "otp" ? "Fill code" : (e.hasPassword ? "Fill" : "Fill user")));
    }
    r.addEventListener("pointerdown", ev => ev.preventDefault());   // Fokus bleibt im Feld
    r.addEventListener("mouseenter", () => highlight(i));
    r.addEventListener("click", ev => {
      ev.preventDefault();
      ev.stopPropagation();
      if (ev.isTrusted && anchorEl)
        act(item, anchorEl);
    });
    return r;
  }

  function highlight(i) {
    active = i;
    if (!menu)
      return;
    menu.querySelectorAll(".row").forEach((r, j) => r.classList.toggle("active", j === i));
  }

  function busy(on) {
    if (menu)
      menu.classList.toggle("busy", on);
  }

  function problem(text) {
    if (!menu)
      return;
    busy(false);
    let p = menu.querySelector(".problem");
    if (!p)
      p = menu.appendChild(el("div", "problem"));
    p.textContent = text;
    place();
  }

  function render(anchor, sections) {
    if (!sections.some(s => s.items.length))
      return close();
    if (menu)
      menu.remove();
    items = [];
    menu = el("div", "menu");
    menu.setAttribute("role", "listbox");
    for (const s of sections) {
      if (!s.items.length)
        continue;
      const head = menu.appendChild(el("div", "head"));
      head.appendChild(icon(s.icon));
      head.appendChild(el("span", "", s.title));
      for (const it of s.items) {
        menu.appendChild(row(it, items.length));
        items.push(it);
      }
    }
    root.appendChild(menu);
    anchorEl = anchor;
    const parent = anchor.closest("dialog[open]") || document.documentElement;
    if (host.parentNode !== parent)
      parent.appendChild(host);
    try {
      host.popover = "manual";
      if (!host.matches(":popover-open"))
        host.showPopover();
    } catch (e) {}
    place();
  }

  function siteKey(h) {
    return (h || "").toLowerCase().replace(/^www\./, "").split(".").slice(-2).join(".");
  }

  async function open(field) {
    const seq = ++openSeq;
    const otp = isOtpField(field);
    const isPw = !otp && looksLikePassword(field);
    const email = !otp && !isPw && looksLikeEmail(field);
    const loginish = isPw || (!otp && (looksLikeUsername(field) || passwordFields(field).length > 0));
    if (!otp && !loginish && !email)
      return close();
    const signup = email && signupContext(field);
    const [entries, aliasList] = await Promise.all([getMatches(), signup ? getAliases() : Promise.resolve([])]);
    if (seq !== openSeq || deepActive() !== field)
      return;
    const q = !isPw && !otp ? (field.value || "").trim().toLowerCase() : "";
    const sections = [];
    if (otp) {
      sections.push({ title: "Verification code", icon: "shield",
                      items: entries.filter(e => e.hasTotp).map(e => ({ kind: "otp", entry: e })) });
    } else {
      const logins = entries
        .filter(e => !q || (e.user || "").toLowerCase().includes(q) || (e.title || "").toLowerCase().includes(q))
        .slice(0, 8)
        .map(e => ({ kind: "login", entry: e }));
      const site = siteKey(location.hostname);
      const al = aliasList
        .filter(a => !q || a.address.toLowerCase().includes(q) || (a.label || "").toLowerCase().includes(q))
        .sort((a, b) => (siteKey(b.domain) === site) - (siteKey(a.domain) === site))
        .slice(0, 6)
        .map(a => ({ kind: "alias", alias: a }));
      const loginSection = { title: "iCloud Passwords", icon: "key", items: logins };
      const aliasSection = { title: "Hide My Email", icon: "mail", items: al };
      // Registrierung: Hide My Email zuerst
      sections.push(...(signup ? [aliasSection, loginSection] : [loginSection, aliasSection]));
    }
    render(field, sections);
  }

  function inputFrom(ev) {
    const t = ev.composedPath ? ev.composedPath()[0] : ev.target;
    return t && t.tagName === "INPUT" && t.type !== "hidden" && visible(t) ? t : null;
  }

  // Ein Satz Listener fürs ganze Dokument statt Felder zu scannen (focusin/click/input gehen durch Shadow DOM)
  document.addEventListener("focusin", ev => {
    if (!ev.isTrusted)
      return;
    const f = inputFrom(ev);
    if (f)
      open(f);
    else if (menu)
      close();
  }, true);

  document.addEventListener("click", ev => {
    if (!ev.isTrusted)
      return;
    const path = ev.composedPath ? ev.composedPath() : [ev.target];
    if (path.includes(host))
      return;
    const f = inputFrom(ev);
    if (f && f === anchorEl)
      return;
    if (f)
      open(f);
    else
      close();
  }, true);

  document.addEventListener("input", ev => {
    // unsere eigenen input-Ereignisse (setValue) sind nicht isTrusted -> öffnen das Menü nicht wieder
    if (!ev.isTrusted)
      return;
    const f = inputFrom(ev);
    if (f && !looksLikePassword(f) && !segmentGroup(f))
      open(f);
  }, true);

  document.addEventListener("focusout", ev => {
    if (!ev.isTrusted || !menu)
      return;
    const t = ev.composedPath ? ev.composedPath()[0] : ev.target;
    if (t === anchorEl)
      setTimeout(() => {
        if (deepActive() !== anchorEl)
          close();
      }, 0);
  }, true);

  document.addEventListener("keydown", ev => {
    if (!menu || !ev.isTrusted)
      return;
    const t = ev.composedPath ? ev.composedPath()[0] : ev.target;
    if (t !== anchorEl)
      return;
    if (ev.key === "Escape") {
      close();
    } else if (ev.key === "ArrowDown" || ev.key === "ArrowUp") {
      ev.preventDefault();
      const n = items.length;
      highlight(ev.key === "ArrowDown" ? (active + 1) % n : (active - 1 + n) % n);
      const r = menu.querySelectorAll(".row")[active];
      if (r)
        r.scrollIntoView({ block: "nearest" });
    } else if (ev.key === "Enter" && active >= 0 && items[active]) {
      ev.preventDefault();
      ev.stopPropagation();
      act(items[active], anchorEl);
    }
  }, true);

  addEventListener("scroll", () => place(), { capture: true, passive: true });
  addEventListener("resize", () => place(), { passive: true });
  addEventListener("pagehide", close);

  // Feld hatte schon beim Laden den Fokus (autofocus)
  const first = deepActive();
  if (first && first.tagName === "INPUT" && visible(first))
    open(first);
})();

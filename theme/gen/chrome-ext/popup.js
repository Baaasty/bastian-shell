// Desktop – Popup: Logins der aktuellen Seite (iCloud über background.js -> Native Host -> scripts/passwords).
// Kopieren läuft komplett im Host (passwords copy: wl-copy --sensitive, nach 30 s leer) – das Popup sieht keine Werte.
// Ausfüllen: background.js holt die Daten und gibt sie nur an den obersten Frame der Seite (https/localhost).
// Aufbau angelehnt an icp „Apple Passwords“ extension/popup.js (https://github.com/Sank6/iCloud-Keychain-for-Linux,
// MIT License, Copyright (c) 2026 Sankarsh Makam).
const $ = id => document.getElementById(id);

function send(msg) {
  return chrome.runtime.sendMessage(msg).then(r => r || { ok: false, error: "no answer" },
                                              () => ({ ok: false, error: "extension not ready" }));
}

let toastTimer = 0;
function toast(text, error) {
  const t = $("toast");
  t.textContent = text;
  t.classList.toggle("error", !!error);
  t.hidden = false;
  clearTimeout(toastTimer);
  toastTimer = setTimeout(() => (t.hidden = true), 3500);
}

function button(icon, title, onClick) {
  const b = document.createElement("button");
  b.title = title;
  b.setAttribute("aria-label", title);
  const s = document.createElement("span");
  s.className = "sym";
  s.textContent = icon;
  b.appendChild(s);
  b.addEventListener("click", async e => {
    e.stopPropagation();
    b.disabled = true;
    await onClick();
    b.disabled = false;
  });
  return b;
}

const LABEL = { user: "Username", password: "Password", totp: "Code" };

async function copy(entry, field) {
  const r = await send({ cmd: "popup-copy", entry: entry.id, field });
  if (r.ok)
    toast(`${LABEL[field]} copied – clipboard clears in ${r.clearAfter || 30} s`);
  else
    toast(r.error || "Copy failed", true);
}

async function fill(entry) {
  const r = await send({ cmd: "popup-fill", entry: entry.id });
  if (r.ok)
    window.close();
  else
    toast(r.error || "Fill failed", true);
}

function initial(s) {
  return ((s || "?").trim().replace(/^[^a-z0-9]+/i, "").charAt(0) || "?").toUpperCase();
}

function row(e, secure) {
  const div = document.createElement("div");
  div.className = "cred";
  const av = div.appendChild(document.createElement("div"));
  av.className = "avatar";
  av.textContent = initial(e.title || e.site || e.user);
  const meta = div.appendChild(document.createElement("div"));
  meta.className = "meta";
  const u = meta.appendChild(document.createElement("div"));
  u.className = "u";
  u.textContent = e.user || "(no username)";
  const d = meta.appendChild(document.createElement("div"));
  d.className = "d";
  d.textContent = [e.title, e.site && e.site !== (e.title || "").toLowerCase() ? e.site : ""].filter(Boolean).join(" · ");
  const acts = div.appendChild(document.createElement("div"));
  acts.className = "actions";
  if (e.user)
    acts.appendChild(button("person", "Copy username", () => copy(e, "user")));
  if (e.hasPassword)
    acts.appendChild(button("key", "Copy password", () => copy(e, "password")));
  if (e.hasTotp)
    acts.appendChild(button("pin", "Copy 2FA code", () => copy(e, "totp")));
  const f = button("", secure ? "Fill on this page" : "Autofill needs https (or localhost)", () => fill(e));
  f.className = "fill";
  f.textContent = "Fill";
  f.disabled = !secure;
  acts.appendChild(f);
  return div;
}

async function main() {
  const r = await send({ cmd: "popup-status" });
  const status = $("status");
  if (!r.ok) {
    status.textContent = r.error || "Not connected";
    status.classList.add("error");
    $("count").textContent = "not connected";
    return;
  }
  $("count").textContent = `${r.count.toLocaleString("en")} saved`;
  if (!r.page) {
    status.textContent = "Open a website to see its logins.";
    return;
  }
  const n = r.entries.length;
  status.textContent = n ? `${n} ${n === 1 ? "login" : "logins"} for ${r.page}` : `No saved logins for ${r.page}`;
  if (n && !r.secure)
    status.textContent += " · not secure (http): copy only";
  const list = $("list");
  for (const e of r.entries)
    list.appendChild(row(e, r.secure));
}

main();

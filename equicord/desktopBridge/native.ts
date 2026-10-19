/*
 * Vencord, a Discord client mod
 * Copyright (c) 2026 Bastian and contributors
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

// Hauptprozess (Node): lokaler Unix-Socket zur Desktop-Shell. Nur Verbindung, keine Logik.
// Protokoll (eine Zeile pro Nachricht, Bilder als Rohbytes danach):
//   Plugin -> Shell:  "S <json>\n"  Zustand (wird für neue Verbindungen zwischengespeichert)
//                     "E <json>\n"  Ereignis (Antwort auf guilds/channels/peek)
//                     "F <id> <länge>\n<jpeg-bytes>"  Kamerabild einer gepinnten Kachel
//   Shell -> Plugin:  "pin <id>" · "unpin <id>" · sonst Befehl (mute 1, deaf 0, leave, join <id>, uvol <id> <0-200>, …)
// Socket: $XDG_RUNTIME_DIR/desktop/cams.sock, Ordner 0700, Socket 0600 – nur der eigene Benutzer, nichts im Netz.

import type { IpcMainInvokeEvent } from "electron";
import { chmodSync, mkdirSync, unlinkSync } from "fs";
import { createServer, type Server, type Socket } from "net";
import { dirname, join } from "path";

const MAX_PINS = 6;   // gleich wie Cams.maxPins in der Shell
const MAX_CMDS = 64;
const MAX_BACKLOG = 512 * 1024;   // langsamer Leser: Bilder auslassen statt Speicher zu füllen (~20 Bilder Rückstau)

let server: Server | null = null;
let socketPath = "";
let lastState = "";
const clients = new Set<Socket>();
const pins = new Set<string>();
let cmds: string[] = [];

// Test: DESKTOP_CAMS_SOCK=/pfad/cams.sock verlegt den Socket (eine zweite, isolierte Equibop-Instanz stört den echten nicht)
function socketFile() {
    if (process.env.DESKTOP_CAMS_SOCK) return process.env.DESKTOP_CAMS_SOCK;
    const base = process.env.XDG_RUNTIME_DIR;
    return base ? join(base, "desktop", "cams.sock") : "";
}

function onLine(line: string) {
    const [op, arg] = line.split(" ", 2);
    if (op === "pin") {
        if (/^[\w:.-]{1,64}$/.test(arg ?? "") && pins.size < MAX_PINS) pins.add(arg);
    } else if (op === "unpin") {
        pins.delete(arg ?? "");
    } else if (cmds.length < MAX_CMDS && line.length < 512) {
        cmds.push(line);
    }
}

function accept(s: Socket) {
    clients.add(s);
    let buf = "";
    s.setEncoding("utf8");
    s.on("data", (d: string) => {
        buf += d;
        if (buf.length > 65536) buf = "";
        for (let i = buf.indexOf("\n"); i >= 0; i = buf.indexOf("\n")) {
            onLine(buf.slice(0, i).trim());
            buf = buf.slice(i + 1);
        }
    });
    const gone = () => {
        clients.delete(s);
        if (!clients.size) pins.clear();   // ohne Shell wird nichts mehr abgegriffen
    };
    s.on("close", gone);
    s.on("error", gone);
    if (lastState) s.write("S " + lastState + "\n");
}

export function start(_: IpcMainInvokeEvent): string {
    if (server) return socketPath;
    socketPath = socketFile();
    if (!socketPath) return "";
    mkdirSync(dirname(socketPath), { recursive: true, mode: 0o700 });
    try { unlinkSync(socketPath); } catch { /* war nicht da */ }
    const srv = createServer(accept);
    srv.on("error", () => { /* Fehler schlucken: ein kaputter Socket darf Equibop nicht stören */ });
    srv.listen(socketPath, () => {
        try { chmodSync(socketPath, 0o600); } catch { /* egal */ }
    });
    server = srv;
    return socketPath;
}

// Discord-Fenster nicht drosseln, wenn es minimiert/verdeckt ist: die Kameras sollen weiterlaufen
export function keepAwake(e: IpcMainInvokeEvent) {
    try {
        e.sender.setBackgroundThrottling(false);
    } catch { /* älteres Electron */ }
}

export function stop(_: IpcMainInvokeEvent) {
    for (const c of clients) c.destroy();
    clients.clear();
    pins.clear();
    cmds = [];
    lastState = "";
    server?.close();
    server = null;
    try { if (socketPath) unlinkSync(socketPath); } catch { /* egal */ }
}

// Renderer fragt regelmäßig: Befehle der Shell, gepinnte Kacheln, Zahl der Verbindungen
export function poll(_: IpcMainInvokeEvent) {
    const out = cmds;
    cmds = [];
    return { cmds: out, pins: [...pins], clients: clients.size };
}

export function push(_: IpcMainInvokeEvent, kind: "S" | "E", json: string) {
    if (kind === "S") lastState = json;
    const line = `${kind} ${json}\n`;
    for (const c of clients) c.write(line);
}

export function frame(_: IpcMainInvokeEvent, id: string, jpeg: Uint8Array) {
    const buf = Buffer.concat([Buffer.from(`F ${id} ${jpeg.length}\n`), Buffer.from(jpeg)]);
    for (const c of clients) {
        if (c.writableLength > MAX_BACKLOG) continue;
        c.write(buf);
    }
}

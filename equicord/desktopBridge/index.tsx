/*
 * Vencord, a Discord client mod
 * Copyright (c) 2026 Bastian and contributors
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

// DesktopBridge: Call-Zustand + gepinnte Kameras an die lokale Desktop-Shell (Quickshell) – nur über einen
// 0600-Unix-Socket (native.ts), nichts geht ins Netz. Doku: docs/DISCORD-CAMS.md im Desktop-Repo.
//
// Renderer-Seite:
//  - liest Stores (VoiceStateStore, MediaEngineStore, …) und schickt bei jeder Änderung einen Zustand ("S"),
//  - führt Befehle der Shell aus (Mic/Taub/Verlassen/Beitreten/Lautstärke),
//  - greift NUR die von der Shell gepinnten Kameras/Streams ab und schickt sie als JPEG ("F"). Quelle: direkt Discords
//    Video-Engine (wie Discords eigene Kacheln: VideoStreamStore -> streamId -> createDiscordStream + DirectVideoOutputSink,
//    Discords Referenzzählung), gelesen per MediaStreamTrackProcessor -> geht auch ohne sichtbare Call-Ansicht und bei
//    minimiertem Fenster. Rückfall: die <video>-Kacheln im Fenster.

import { definePluginSettings } from "@api/Settings";
import definePlugin, { OptionType, PluginNative } from "@utils/types";
import { findByCodeLazy, findStoreLazy } from "@webpack";
import { ChannelActions, ChannelStore, FluxDispatcher, GuildChannelStore, GuildMemberStore, GuildStore, MediaEngineStore, NavigationRouter, SelectedChannelStore, UserStore, VoiceActions, VoiceStateStore } from "@webpack/common";

const Native = VencordNative.pluginHelpers.DesktopBridge as PluginNative<typeof import("./native")>;

// Discord (web.js, 2026-10): VideoStreamStore.getStreamId(userId, guildId|null, "default"|"stream") und das Modul mit
// „Direct video streams are unavailable outside the native client“: function(streamId) -> { stream: MediaStream, release() }
const VideoStreamStore = findStoreLazy("VideoStreamStore");
// wer im Call Video hat, mit streamId (so findet auch Discords eigenes Pop-out die Kameras; Ansatz aus dem Plugin
// „CallCameraOverlay“ eines Kollegen von Bastian)
const ChannelRTCStore = findStoreLazy("ChannelRTCStore");
const acquireDirect: (streamId: string) => { stream: MediaStream; release(): void; } = findByCodeLazy("addDirectVideoOutputSink(", "addref()");

const settings = definePluginSettings({
    fps: {
        type: OptionType.SLIDER,
        description: "Frames per second for pinned cameras.",
        markers: [2, 5, 10, 15, 24],
        default: 10,
        stickToMarkers: false
    },
    height: {
        type: OptionType.SLIDER,
        description: "Height in pixels of pinned camera frames (width follows the video).",
        markers: [180, 270, 360, 480, 720],
        default: 270,      // Kacheln sind höchstens 420 × 236 px groß – mehr kostet nur Kodierzeit
        stickToMarkers: false
    },
    quality: {
        type: OptionType.SLIDER,
        description: "JPEG quality for pinned camera frames (percent).",
        markers: [40, 50, 60, 70, 85],
        default: 60,
        stickToMarkers: false
    }
});

interface Frame {
    draw: CanvasImageSource;
    w: number;
    h: number;
    stamp: number;     // ändert sich nur bei neuem Bild
}

interface Tile {
    key: string;       // "<userId>" für Kamera, "<userId>:stream" für Bildschirmübertragung
    userId: string;
    stream: boolean;
    w: number;
    h: number;
    get(): Frame | null;
}

// eine Hintergrund-Quelle je gepinntem Schlüssel
interface Source {
    key: string;
    streamId: string;
    handle: { stream: MediaStream; release(): void; };
    reader: ReadableStreamDefaultReader<VideoFrame> | null;
    clone: MediaStreamTrack | null;     // eigener Track-Klon (muss beim Schließen gestoppt werden, sonst Leck)
    video: HTMLVideoElement | null;
    frame: VideoFrame | null;
    n: number;
    dead: boolean;
    opened: number;    // performance.now() beim Öffnen (stirbt eine Quelle sofort wieder: Pause vor dem nächsten Versuch)
}

const speaking = new Set<string>();
let started = false;
let callChannel = "";
let callSince = 0;
let lastJson = "";
let publishTimer = 0;
let pollTimer = 0;
let resyncTimer = 0;
let busy = false;
let hasClients = false;
let pins: string[] = [];
const lastTime = new Map<string, number>();
const canvases = new Map<string, OffscreenCanvas>();   // je Schlüssel eine, damit alle Kameras parallel kodieren
const sources = new Map<string, Source>();
// Neu-Öffnen bremsen: eine Quelle, die gleich wieder stirbt, nicht zehnmal pro Sekunde neu holen (jedes acquire hängt
// in Discords Video-Engine einen Ausgang an/ab)
const retryAt = new Map<string, number>();
const retryWait = new Map<string, number>();
let hiddenBox: HTMLDivElement | null = null;

// ---------------------------------------------------------------- Zustand lesen

function absolute(url: string | undefined): string {
    if (!url) return "";
    if (url.startsWith("//")) return "https:" + url;
    if (url.startsWith("/")) return "https://discord.com" + url;
    return url;
}

function avatarOf(id: string, guildId: string | null | undefined): string {
    const u = UserStore.getUser(id);
    if (!u) return "";
    try {
        return absolute(u.getAvatarURL(guildId ?? undefined, 64, false));
    } catch {
        return "";
    }
}

function nameOf(id: string, guildId: string | null | undefined): string {
    const u = UserStore.getUser(id);
    const nick = guildId ? GuildMemberStore.getNick(guildId, id) : null;
    return nick || u?.globalName || u?.username || "?";
}

function snapshot() {
    const me = UserStore.getCurrentUser()?.id ?? "";
    const cid = SelectedChannelStore.getVoiceChannelId() ?? "";
    if (cid !== callChannel) {
        callChannel = cid;
        callSince = cid ? Date.now() : 0;
    }
    const base = { state: "ok", configured: true, plugin: true, canControl: true, connection: "" };
    if (!cid) {
        return { ...base, inVoice: false, channelId: "", guildId: "", channelName: "", guildName: "", since: 0, self: { mute: MediaEngineStore.isSelfMute(), deaf: MediaEngineStore.isSelfDeaf(), video: null, stream: null }, members: [], tiles: [] };
    }

    const channel = ChannelStore.getChannel(cid);
    const guildId = channel?.guild_id ?? "";
    const states = Object.values(VoiceStateStore.getVoiceStatesForChannel(cid) ?? {});
    const members = states.map(s => {
        const isSelf = s.userId === me;
        const u = UserStore.getUser(s.userId);
        return {
            id: s.userId,
            name: nameOf(s.userId, guildId),
            avatarUrl: avatarOf(s.userId, guildId),
            mute: isSelf ? (MediaEngineStore.isSelfMute() || s.mute) : (s.mute || s.selfMute || s.suppress),
            deaf: isSelf ? (MediaEngineStore.isSelfDeaf() || s.deaf) : (s.deaf || s.selfDeaf),
            video: !!s.selfVideo,
            stream: !!s.selfStream,
            bot: !!u?.bot,
            volume: isSelf ? 100 : Math.round(MediaEngineStore.getLocalVolume(s.userId) ?? 100),
            localMute: isSelf ? false : MediaEngineStore.isLocalMute(s.userId),
            speaking: speaking.has(s.userId),
            isSelf
        };
    });
    members.sort((a, b) => Number(a.isSelf) - Number(b.isSelf) || a.name.localeCompare(b.name));

    let name = channel?.name ?? "";
    if (!name) {
        name = members.filter(m => !m.isSelf).slice(0, 3).map(m => m.name).join(", ") || "Private call";
    }
    const mine = members.find(m => m.isSelf);
    return {
        ...base,
        inVoice: true,
        channelId: cid,
        guildId,
        channelName: name,
        guildName: guildId ? (GuildStore.getGuild(guildId)?.name ?? "") : "Private",
        since: callSince,
        self: { mute: mine?.mute ?? MediaEngineStore.isSelfMute(), deaf: mine?.deaf ?? MediaEngineStore.isSelfDeaf(), video: mine?.video ?? false, stream: mine?.stream ?? false },
        members,
        // welche Kacheln gerade als <video> im Fenster stehen (nur dann sind Bilder möglich)
        tiles: findTiles().map(t => ({ key: t.key, userId: t.userId, stream: t.stream, w: t.w, h: t.h }))
    };
}

function publish(force = false) {
    const json = JSON.stringify(snapshot());
    if (!force && json === lastJson) return;
    lastJson = json;
    Native.push("S", json);
}

function schedulePublish() {
    if (publishTimer) return;
    publishTimer = window.setTimeout(() => {
        publishTimer = 0;
        publish();
    }, 60);
}

// ---------------------------------------------------------------- Kacheln finden

// Discords Kachel ist <div data-selenium-video-tile="<userId>"> (geprüft am Web-Client, 2026-10); das <video>
// darin wird von Discord per createElement angehängt (kein React-Element) -> nur über das DOM zu finden.
// Kamera und Bildschirmübertragung derselben Person sind zwei Kacheln mit gleicher ID: hat die Person nur eines
// von beidem, ist die Art klar (mehrere Kacheln derselben Art: die größte); hat sie beides, gilt die größere Kachel
// als Übertragung (Annahme, im echten Call prüfen).
function domTile(key: string, userId: string, stream: boolean, v: HTMLVideoElement): Tile {
    return {
        key, userId, stream, w: v.videoWidth, h: v.videoHeight,
        get() {
            if (v.readyState < 2 || v.videoWidth < 2) return null;
            // die eigene Vorschau (lokaler Stream) zählt currentTime nicht hoch (bleibt 0) -> dann immer greifen
            const frames = v.getVideoPlaybackQuality?.().totalVideoFrames ?? 0;
            const stamp = v.currentTime > 0 || frames > 0 ? v.currentTime * 1e6 + frames : performance.now();
            return { draw: v, w: v.videoWidth, h: v.videoHeight, stamp };
        }
    };
}

function sourceTile(src: Source): Tile | null {
    const userId = src.key.split(":")[0], stream = src.key.endsWith(":stream");
    const size = () => src.frame ? { w: src.frame.displayWidth, h: src.frame.displayHeight }
        : src.video && src.video.videoWidth >= 2 ? { w: src.video.videoWidth, h: src.video.videoHeight } : null;
    const s0 = size();
    if (src.dead || !s0) return null;
    return {
        key: src.key, userId, stream, w: s0.w, h: s0.h,
        get() {
            if (src.dead) return null;
            if (src.frame) return { draw: src.frame, w: src.frame.displayWidth, h: src.frame.displayHeight, stamp: src.n };
            const v = src.video;
            if (!v || v.readyState < 2 || v.videoWidth < 2) return null;
            return { draw: v, w: v.videoWidth, h: v.videoHeight, stamp: v.currentTime * 1e6 + (v.getVideoPlaybackQuality?.().totalVideoFrames ?? 0) };
        }
    };
}

// alle greifbaren Kacheln: Hintergrund-Quellen zuerst, dann was im Fenster als <video> steht
function findTiles(): Tile[] {
    const out: Tile[] = [];
    for (const src of sources.values()) {
        const t = sourceTile(src);
        if (t) out.push(t);
    }
    const have = new Set(out.map(t => t.key));
    for (const t of findDomTiles()) if (!have.has(t.key)) out.push(t);
    return out;
}

function findDomTiles(): Tile[] {
    const byUser = new Map<string, HTMLVideoElement[]>();
    for (const v of document.querySelectorAll<HTMLVideoElement>("[data-selenium-video-tile] video")) {
        if (!v.srcObject || v.videoWidth < 2) continue;
        const id = v.closest("[data-selenium-video-tile]")?.getAttribute("data-selenium-video-tile") ?? "";
        if (!/^\d+$/.test(id)) continue;
        byUser.set(id, [...(byUser.get(id) ?? []), v]);
    }
    const out: Tile[] = [];
    for (const [userId, list] of byUser) {
        list.sort((a, b) => b.videoWidth * b.videoHeight - a.videoWidth * a.videoHeight);
        const vs = VoiceStateStore.getVoiceStateForUser(userId);
        const cam = !!vs?.selfVideo, str = !!vs?.selfStream;
        if (cam && str && list.length >= 2) {
            out.push(domTile(`${userId}:stream`, userId, true, list[0]));
            out.push(domTile(userId, userId, false, list[1]));
        } else {
            const stream = str && !cam;
            out.push(domTile(stream ? `${userId}:stream` : userId, userId, stream, list[0]));
        }
    }
    return out;
}

// ---------------------------------------------------------------- Bilder

async function grab(tile: Tile) {
    const f = tile.get();
    if (!f) return;
    if (lastTime.get(tile.key) === f.stamp) return;            // kein neues Bild seit dem letzten Mal
    lastTime.set(tile.key, f.stamp);

    const maxH = Math.max(90, settings.store.height);
    const scale = Math.min(1, maxH / f.h, 1280 / f.w);
    const w = Math.max(2, Math.round(f.w * scale));
    const h = Math.max(2, Math.round(f.h * scale));
    let canvas = canvases.get(tile.key);
    if (!canvas) canvases.set(tile.key, canvas = new OffscreenCanvas(w, h));
    if (canvas.width !== w) canvas.width = w;
    if (canvas.height !== h) canvas.height = h;
    const ctx = canvas.getContext("2d");
    if (!ctx) return;
    ctx.drawImage(f.draw, 0, 0, w, h);
    const blob = await canvas.convertToBlob({ type: "image/jpeg", quality: settings.store.quality / 100 });
    await Native.frame(tile.key, new Uint8Array(await blob.arrayBuffer()));
}

// ---------------------------------------------------------------- Hintergrund-Quellen

function closeSource(src: Source) {
    src.dead = true;
    sources.delete(src.key);
    try { src.reader?.cancel(); } catch { /* schon zu */ }
    try { src.clone?.stop(); } catch { /* schon zu */ }
    canvases.delete(src.key);
    src.clone = null;
    try { src.frame?.close(); } catch { /* schon zu */ }
    src.frame = null;
    if (src.video) {
        src.video.srcObject = null;
        src.video.remove();
    }
    try { src.handle.release(); } catch { /* Discord hat schon aufgeräumt */ }
}

function closeAllSources() {
    for (const src of [...sources.values()]) closeSource(src);
}

async function readFrames(src: Source) {
    try {
        while (!src.dead && src.reader) {
            const { value, done } = await src.reader.read();
            if (done || !value) break;
            if (src.dead) { value.close(); break; }
            src.frame?.close();          // nur das neueste Bild behalten, sonst staut sich Discords Bildpuffer
            src.frame = value;
            src.n++;
        }
    } catch { /* Track beendet */ }
    if (!src.dead) src.dead = true;      // nächste Runde holt die Quelle neu
}

function openSource(key: string, streamId: string): Source | null {
    if (typeof (window as any).createDiscordStream !== "function") return null;   // nur im nativen Client
    let handle: Source["handle"];
    try {
        handle = acquireDirect(streamId);
    } catch (e) {
        console.warn("[DesktopBridge] no direct stream", e);
        return null;
    }
    if (!handle?.stream) {
        try { handle?.release(); } catch { /* egal */ }
        return null;
    }
    const src: Source = { key, streamId, handle, reader: null, clone: null, video: null, frame: null, n: 0, dead: false, opened: performance.now() };
    const track = handle.stream.getVideoTracks()[0];
    const Processor = (window as any).MediaStreamTrackProcessor;
    if (track && Processor) {
        try {
            // eigener Klon: Discords Kacheln bekommen den Track weiter unverändert
            src.clone = track.clone();
            // nur so viele Bilder wie gebraucht in JS holen (sonst 30 VideoFrames/s je Kamera, von denen 20 verworfen werden)
            src.clone.applyConstraints({ frameRate: { max: Math.max(2, settings.store.fps) } }).catch(() => { /* egal */ });
            // maxBufferSize 1: liest die Schleife mal nicht rechtzeitig, verwirft der Processor alte Bilder statt zu stauen
            src.reader = new Processor({ track: src.clone, maxBufferSize: 1 }).readable.getReader();
        } catch (e) {
            // ohne Aufräumen bliebe Discords Ausgang (acquire) und der Klon für immer offen
            console.warn("[DesktopBridge] track processor failed", e);
            closeSource(src);
            return null;
        }
        sources.set(key, src);
        readFrames(src);
        return src;
    } else {
        // Rückfall: verstecktes <video> (läuft weiter, weil Hintergrund-Drosselung aus ist)
        if (!hiddenBox) {
            hiddenBox = document.createElement("div");
            hiddenBox.style.cssText = "position:fixed;left:-10000px;top:0;width:320px;height:180px;opacity:0;pointer-events:none";
            document.body.appendChild(hiddenBox);
        }
        const v = document.createElement("video");
        v.muted = true;
        v.autoplay = true;
        v.playsInline = true;
        v.width = 320;
        v.height = 180;
        v.srcObject = handle.stream;
        hiddenBox.appendChild(v);
        v.play().catch(() => { /* kommt mit dem ersten Bild */ });
        src.video = v;
    }
    sources.set(key, src);
    return src;
}

// gepinnte Schlüssel -> Quellen (neu, ersetzt, geschlossen)
function syncSources() {
    const vc = SelectedChannelStore.getVoiceChannelId();
    const gid = vc ? (ChannelStore.getChannel(vc)?.guild_id ?? null) : null;
    const me = UserStore.getCurrentUser()?.id ?? "";
    // nie die eigene Kamera/Übertragung abgreifen: daran hängt Discords Aufnahme (/dev/video*) und der Encoder
    const want = new Set(vc ? pins.filter(k => /^\d+(:stream)?$/.test(k) && k.split(":")[0] !== me) : []);
    // Kameras laut Discord (type 2 = Nutzer; Go-Live-Streams haben eigene Einträge)
    const rtcStreamIds = new Map<string, string>();
    try {
        for (const p of (vc ? ChannelRTCStore.getVideoParticipants(vc) : []) ?? [])
            if (p?.type === 2 && p.user?.id && p.streamId) rtcStreamIds.set(p.user.id, String(p.streamId));
    } catch { /* Store fehlt -> VideoStreamStore reicht */ }
    for (const src of [...sources.values()])
        if (!want.has(src.key)) closeSource(src);
    for (const k of [...retryAt.keys()])
        if (!want.has(k)) { retryAt.delete(k); retryWait.delete(k); }
    const now = performance.now();
    for (const key of want) {
        const userId = key.split(":")[0];
        let streamId: string | undefined;
        try {
            if (!key.endsWith(":stream"))
                streamId = rtcStreamIds.get(userId);
            streamId ??= VideoStreamStore.getStreamId(userId, gid, key.endsWith(":stream") ? "stream" : "default");
        } catch { streamId = undefined; }
        const sid = streamId != null && streamId !== "" ? String(streamId) : "";   // Store liefert mal Zahl, mal Text
        const cur = sources.get(key);
        if (cur && !cur.dead && cur.streamId === sid) continue;
        if (cur) {
            // schnell gestorben (< 5 s): Wartezeit verdoppeln (1 s … 30 s), sonst zurücksetzen
            const quick = cur.dead && now - cur.opened < 5000;
            const wait = quick ? Math.min(30000, (retryWait.get(key) ?? 500) * 2) : 0;
            closeSource(cur);
            if (wait) {
                retryWait.set(key, wait);
                retryAt.set(key, now + wait);
            } else {
                retryWait.delete(key);
                retryAt.delete(key);
            }
        }
        if (!sid || now < (retryAt.get(key) ?? 0)) continue;
        openSource(key, sid);
    }
}

// ---------------------------------------------------------------- Befehle

function setMute(want: boolean) {
    if (MediaEngineStore.isSelfMute() !== want) VoiceActions.toggleSelfMute();
}
function setDeaf(want: boolean) {
    if (MediaEngineStore.isSelfDeaf() !== want) VoiceActions.toggleSelfDeaf();
}

function channelPeople(id: string) {
    const ch = ChannelStore.getChannel(id);
    if (!ch) return { id, missing: true, members: [] };
    const gid = ch.guild_id ?? "";
    return {
        id,
        name: ch.name ?? "",
        type: ch.type,
        guildId: gid,
        members: Object.values(VoiceStateStore.getVoiceStatesForChannel(id) ?? {}).map(s => ({
            id: s.userId, name: nameOf(s.userId, gid), avatarUrl: avatarOf(s.userId, gid)
        }))
    };
}

function event(obj: object) {
    Native.push("E", JSON.stringify(obj));
}

function runCommand(line: string) {
    const [op, a, b] = line.split(" ");
    const num = (x: string | undefined) => (x && /^\d+$/.test(x) ? x : "");
    switch (op) {
        case "mute": setMute(a === "1"); break;
        case "deaf": setDeaf(a === "1"); break;
        case "leave": ChannelActions.selectVoiceChannel(null); break;
        case "join": if (num(a)) ChannelActions.selectVoiceChannel(a); break;
        case "umute": {
            if (!num(a)) break;
            if (MediaEngineStore.isLocalMute(a) !== (b === "1")) VoiceActions.toggleLocalMute(a);
            break;
        }
        case "uvol": {
            const v = Math.max(0, Math.min(200, Number(b)));
            if (!num(a) || Number.isNaN(v)) break;
            if (typeof VoiceActions.setLocalVolume === "function") VoiceActions.setLocalVolume(a, v);
            else FluxDispatcher.dispatch({ type: "AUDIO_SET_LOCAL_VOLUME", userId: a, volume: v, context: "default" });
            break;
        }
        case "open": {
            if (!num(a)) break;
            NavigationRouter.transitionTo(`/channels/@me/${a}`);
            event({ event: "opened", id: a });
            break;
        }
        case "guilds": {
            const list = GuildStore.getGuildsArray().map(g => ({
                id: g.id, name: g.name || "?",
                iconUrl: g.icon ? `https://cdn.discordapp.com/icons/${g.id}/${g.icon}.png?size=64` : ""
            }));
            event({ event: "guilds", guilds: list });
            break;
        }
        case "channels": {
            if (!num(a)) break;
            const vocal = (GuildChannelStore.getChannels(a)?.VOCAL ?? []).slice(0, 25);
            const channels = vocal.map(({ channel }) => ({
                id: channel.id, name: channel.name || "?", type: channel.type,
                members: channelPeople(channel.id).members
            }));
            event({ event: "channels", guildId: a, partial: false, channels });
            break;
        }
        case "peek": {
            const ids = line.split(" ").slice(1).filter(x => num(x)).slice(0, 8);
            event({ event: "peek", channels: ids.map(channelPeople) });
            break;
        }
        // Fehler sichtbar machen statt zu raten: unbekannter Befehl
        default:
            if (op) event({ event: "actionFailed", action: op, message: "Unknown command" });
    }
}

// ---------------------------------------------------------------- Schleife

async function tick() {
    if (!started || busy) return;
    busy = true;
    let delay = 1000;
    try {
        const r = await Native.poll();
        pins = r.pins;
        const wasConnected = hasClients;
        hasClients = r.clients > 0;
        for (const c of r.cmds) {
            try {
                runCommand(c);
            } catch (e) {
                event({ event: "actionFailed", action: c.split(" ")[0], message: "That didn’t work" });
                console.warn("[DesktopBridge] command failed", e);
            }
        }
        if (r.cmds.length) schedulePublish();
        if (hasClients && !wasConnected) publish(true);

        if (hasClients && pins.length) {
            syncSources();
            const me = UserStore.getCurrentUser()?.id ?? "";
            const wanted = new Set(pins.filter(k => k.split(":")[0] !== me));
            // alle Kameras parallel (vorher nacheinander + danach noch die volle Pause = nur ~7 statt 10 Bilder/s)
            const t0 = performance.now();
            await Promise.all(findTiles().filter(t => wanted.has(t.key)).map(t => grab(t).catch(() => { /* nächstes Bild */ })));
            const took = performance.now() - t0, budget = 1000 / Math.max(1, settings.store.fps);
            // Kodieren dauert länger als ein Bild Zeit hat (Discord ausgelastet): mindestens genauso lange Pause,
            // also lieber weniger Bilder/s als Dauerlast
            delay = took > budget * 0.8 ? Math.min(1000, Math.max(took, budget)) : Math.max(20, budget - took);
        } else {
            lastTime.clear();
            canvases.clear();
            retryAt.clear();
            retryWait.clear();
            if (sources.size) closeAllSources();
            delay = hasClients ? 150 : 1000;
        }
    } catch (e) {
        console.warn("[DesktopBridge] tick failed", e);
        delay = 2000;
    } finally {
        busy = false;
        if (started) pollTimer = window.setTimeout(tick, delay);
    }
}

function onSpeaking({ userId, speakingFlags }: { userId: string; speakingFlags: number; }) {
    if (speakingFlags & 1) speaking.add(userId);
    else speaking.delete(userId);
    schedulePublish();
}

export default definePlugin({
    name: "DesktopBridge",
    description: "Shows call state, controls and pinned cameras in the local desktop shell (local unix socket only).",
    authors: [{ name: "Bastian", id: 0n }],
    tags: ["Voice", "Utility"],
    settings,

    flux: {
        VOICE_STATE_UPDATES: schedulePublish,
        VOICE_CHANNEL_SELECT: schedulePublish,
        SPEAKING: onSpeaking,
        AUDIO_TOGGLE_SELF_MUTE: schedulePublish,
        AUDIO_TOGGLE_SELF_DEAF: schedulePublish,
        AUDIO_SET_LOCAL_VOLUME: schedulePublish,
        AUDIO_TOGGLE_LOCAL_MUTE: schedulePublish,
        RTC_CONNECTION_STATE: schedulePublish
    },

    async start() {
        started = true;
        const sock = await Native.start();
        // minimiert/weggeräumt: Timer und Bilder nicht drosseln (sonst 1 Bild/s oder weniger)
        Native.keepAwake().catch(() => { /* egal */ });
        console.log("[DesktopBridge] started, socket:", sock || "(none)");
        tick();
        // Kacheln erscheinen/verschwinden ohne Store-Ereignis -> ab und zu neu lesen
        resyncTimer = window.setInterval(() => { if (hasClients) publish(); }, 3000);
    },

    stop() {
        started = false;
        clearTimeout(pollTimer);
        clearTimeout(publishTimer);
        clearInterval(resyncTimer);
        publishTimer = 0;
        speaking.clear();
        lastTime.clear();
        canvases.clear();
        closeAllSources();
        Native.stop();
    }
});

// nvencblock – LD_PRELOAD-Bibliothek: Discord darf libnvidia-encode und libnvcuvid nicht laden.
//
// Warum: Der Renderer stürzt im Call mit Kamera/Go Live immer an derselben Stelle ab (libnvcuvid + 0x1b021,
// SIGSEGV). Geladen wird die Bibliothek vom Voice-Modul für NVENC (Encoder „nvidia: cuda“). Ohne die beiden
// Bibliotheken nimmt das Voice-Modul den Software-Encoder (OpenH264). Im Test lief Discord damit 25 h ohne
// Absturz, vorher kamen mehrere pro Abend. Chromiums eigene Videodekodierung ist ohnehin aus (scripts/app-run).
//
// Alles andere geht unverändert an das echte dlopen.
// Bauen/Einbinden: scripts/nvenc-block · Doku: docs/knowledge/discord.md → Renderer-Absturz
#define _GNU_SOURCE
#include <dlfcn.h>
#include <stdio.h>
#include <string.h>

typedef void *(*dlopen_fn)(const char *, int);

static int blocked(const char *f) {
    return f && (strstr(f, "libnvidia-encode") || strstr(f, "libnvcuvid"));
}

void *dlopen(const char *file, int flags) {
    static dlopen_fn real;
    if (!real)
        real = (dlopen_fn)dlsym(RTLD_NEXT, "dlopen");
    if (blocked(file)) {
        // eine Zeile ins Discord-stderr-Log (scripts/app-run): zeigt, dass die Sperre gegriffen hat
        fprintf(stderr, "nvencblock: dlopen(%s) gesperrt\n", file);
        return NULL;
    }
    return real(file, flags);
}

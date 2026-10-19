// desktop-screencast – hält einen KWin-Screencast eines festen Bereichs offen.
//
// Spricht direkt das Wayland-Protokoll zkde_screencast_unstable_v1 (stream_region, Mauszeiger
// eingebettet), ohne libwayland. Gibt "node <id> serial <serial>" aus, sobald KWin den
// PipeWire-Knoten angelegt hat, und hält den Stream offen, bis SIGINT/SIGTERM kommt oder KWin
// ihn schließt. Aufnehmen tut gst-launch (siehe scripts/screenrec).
//
// KWin gibt das Protokoll nur frei, wenn eine .desktop-Datei mit Exec=<dieser Pfad> und
// X-KDE-Wayland-Interfaces=zkde_screencast_unstable_v1 existiert (scripts/screenrec install).
//
// Bauen: gcc -O2 -o ~/.local/libexec/desktop-screencast scripts/screencast.c
// Aufruf: desktop-screencast X Y W H [SCALE]   (globale logische Koordinaten)

#include <errno.h>
#include <poll.h>
#include <signal.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/socket.h>
#include <sys/un.h>
#include <unistd.h>

// Objekt-IDs (Client vergibt fortlaufend)
enum { ID_DISPLAY = 1, ID_REGISTRY = 2, ID_SYNC = 3, ID_CAST = 4, ID_STREAM = 5 };
// Mauszeiger: 1 = versteckt, 2 = eingebettet, 4 = Metadaten
enum { POINTER_EMBEDDED = 2 };

static int fd = -1;
static volatile sig_atomic_t quit = 0;

static void on_signal(int sig) { (void)sig; quit = 1; }

// ---- Nachricht zusammenbauen ----
static uint32_t msg[256];
static int len;

static void begin(uint32_t obj) { msg[0] = obj; len = 2; }
static void put_u(uint32_t v) { msg[len++] = v; }
static void put_s(const char *s) {
    uint32_t n = strlen(s) + 1;
    put_u(n);
    memset(&msg[len], 0, (n + 3) & ~3u);
    memcpy(&msg[len], s, n);
    len += (n + 3) / 4;
}
static int send_msg(uint16_t opcode) {
    msg[1] = ((uint32_t)(len * 4) << 16) | opcode;
    ssize_t w = send(fd, msg, len * 4, MSG_NOSIGNAL);
    return w == len * 4 ? 0 : -1;
}

// ---- Events lesen ----
static uint8_t rbuf[65536];
static size_t rlen;

// liest, was da ist; -1 bei Verbindungsende
static int fill(void) {
    if (rlen == sizeof rbuf)
        return -1;
    ssize_t r = recv(fd, rbuf + rlen, sizeof rbuf - rlen, 0);
    if (r <= 0)
        return r < 0 && (errno == EINTR || errno == EAGAIN) ? 0 : -1;
    rlen += r;
    return 0;
}

static uint32_t cast_name = 0, cast_version = 0;
static int synced = 0;
static int64_t node = -1;
static uint64_t serial = 0;
static int stream_done = 0;   // closed/failed

static const char *arg_s(const uint32_t *a, int *i) {
    uint32_t n = a[(*i)++];
    const char *s = (const char *)&a[*i];
    *i += (n + 3) / 4;
    return n ? s : "";
}

static void dispatch(uint32_t obj, uint16_t op, const uint32_t *a) {
    int i = 0;
    if (obj == ID_DISPLAY && op == 0) {             // wl_display.error
        uint32_t o = a[i++], code = a[i++];
        fprintf(stderr, "wayland error on object %u (code %u): %s\n", o, code, arg_s(a, &i));
        exit(3);
    } else if (obj == ID_REGISTRY && op == 0) {     // wl_registry.global
        uint32_t name = a[i++];
        const char *iface = arg_s(a, &i);
        uint32_t version = a[i++];
        if (strcmp(iface, "zkde_screencast_unstable_v1") == 0) {
            cast_name = name;
            cast_version = version;
        }
    } else if (obj == ID_SYNC && op == 0) {         // wl_callback.done
        synced = 1;
    } else if (obj == ID_STREAM) {
        if (op == 0) {                              // closed
            stream_done = 1;
        } else if (op == 1) {                       // created(node)
            node = a[0];
        } else if (op == 2) {                       // failed(error)
            fprintf(stderr, "screencast failed: %s\n", arg_s(a, &i));
            stream_done = 1;
        } else if (op == 3) {                       // serial(hi, lo)
            serial = ((uint64_t)a[0] << 32) | a[1];
        }
    }
}

static void drain(void) {
    size_t off = 0;
    while (rlen - off >= 8) {
        uint32_t h[2];
        memcpy(h, rbuf + off, 8);
        uint16_t size = h[1] >> 16, op = h[1] & 0xffff;
        if (size < 8 || rlen - off < size)
            break;
        uint32_t args[16384];
        memcpy(args, rbuf + off + 8, size - 8);
        dispatch(h[0], op, args);
        off += size;
    }
    memmove(rbuf, rbuf + off, rlen - off);
    rlen -= off;
}

static int wait_for(int *flag) {
    while (!*flag && !quit) {
        if (fill() < 0)
            return -1;
        drain();
    }
    return quit ? -1 : 0;
}

int main(int argc, char **argv) {
    if (argc < 5) {
        fprintf(stderr, "usage: %s X Y W H [SCALE]\n", argv[0]);
        return 1;
    }
    int x = atoi(argv[1]), y = atoi(argv[2]), w = atoi(argv[3]), h = atoi(argv[4]);
    double scale = argc > 5 ? atof(argv[5]) : 1.0;
    if (w <= 0 || h <= 0 || scale <= 0) {
        fprintf(stderr, "invalid region\n");
        return 1;
    }

    struct sigaction sa = { .sa_handler = on_signal };
    sigaction(SIGINT, &sa, NULL);
    sigaction(SIGTERM, &sa, NULL);
    sigaction(SIGHUP, &sa, NULL);

    // Socket: $WAYLAND_DISPLAY (absolut oder relativ zu $XDG_RUNTIME_DIR)
    const char *disp = getenv("WAYLAND_DISPLAY");
    const char *rt = getenv("XDG_RUNTIME_DIR");
    if (!disp)
        disp = "wayland-0";
    struct sockaddr_un addr = { .sun_family = AF_UNIX };
    if (disp[0] == '/')
        snprintf(addr.sun_path, sizeof addr.sun_path, "%s", disp);
    else if (rt)
        snprintf(addr.sun_path, sizeof addr.sun_path, "%s/%s", rt, disp);
    else {
        fprintf(stderr, "XDG_RUNTIME_DIR not set\n");
        return 1;
    }
    fd = socket(AF_UNIX, SOCK_STREAM | SOCK_CLOEXEC, 0);
    if (fd < 0 || connect(fd, (struct sockaddr *)&addr, sizeof addr) < 0) {
        perror("connect");
        return 1;
    }

    // Registry holen + Rundlauf
    begin(ID_DISPLAY); put_u(ID_REGISTRY); send_msg(1);   // get_registry
    begin(ID_DISPLAY); put_u(ID_SYNC); send_msg(0);       // sync
    if (wait_for(&synced) < 0)
        return 1;
    if (!cast_name) {
        fprintf(stderr, "zkde_screencast_unstable_v1 not offered (missing KWin permission, run: screenrec install)\n");
        return 2;
    }
    if (cast_version < 3) {
        fprintf(stderr, "KWin screencast too old for regions (v%u)\n", cast_version);
        return 2;
    }

    // binden + Bereich anfordern
    uint32_t ver = cast_version < 6 ? cast_version : 6;
    begin(ID_REGISTRY); put_u(cast_name); put_s("zkde_screencast_unstable_v1"); put_u(ver); put_u(ID_CAST);
    send_msg(0);
    begin(ID_CAST); put_u(ID_STREAM); put_u((uint32_t)x); put_u((uint32_t)y); put_u(w); put_u(h);
    put_u((uint32_t)(int32_t)(scale * 256.0)); put_u(POINTER_EMBEDDED);
    send_msg(4);                                          // stream_region

    while (node < 0 && !stream_done && !quit) {
        if (fill() < 0)
            return 1;
        drain();
    }
    if (node < 0)
        return 4;
    printf("node %lld serial %llu\n", (long long)node, (unsigned long long)serial);
    fflush(stdout);

    // offen halten, bis Signal oder KWin schließt
    struct pollfd p = { .fd = fd, .events = POLLIN };
    while (!quit && !stream_done) {
        int r = poll(&p, 1, -1);
        if (r < 0 && errno == EINTR)
            continue;
        if (r < 0 || (p.revents & (POLLHUP | POLLERR)))
            break;
        if (fill() < 0)
            break;
        drain();
    }

    // sauber schließen
    begin(ID_STREAM); send_msg(0);   // close
    begin(ID_CAST); send_msg(2);     // destroy
    close(fd);
    return 0;
}

// fastprobe – LD_PRELOAD-Bibliothek: beantwortet VIDIOC_TRY_FMT für die Elgato Facecam aus einem Zwischenspeicher.
//
// Warum: Discords Voice-Modul (libwebrtc, DeviceInfoV4l2::FillCapabilities) probiert vor jedem Kamerastart
// 15 Formate x 13 Größen per VIDIOC_TRY_FMT. uvcvideo schickt für jeden Versuch einen USB-Probe an die Kamera,
// die Facecam braucht dafür ~32 ms -> ~6,5 s bis zum Bild. Der Treiber bildet aber jede Anfrage auf eines von
// wenigen echten Formaten ab (bei der Facecam 2 Formate x 3 Größen). Wir wählen dieses Ziel genau wie uvcvideo
// (Format per fourcc, sonst Standardformat; nächstgelegene Größe), fragen das echte ioctl je Ziel nur einmal
// und geben danach die gemerkte Antwort zurück: höchstens ~7 echte Probes statt 195.
//
// Alles andere (S_FMT, STREAMON, Controls, andere Geräte, andere ioctls) geht unverändert an das echte ioctl.
// Bei jedem Zweifel (unbekannte Struktur, stufenlose Größen, Fehler) ebenso.
//   DESKTOP_FASTPROBE=0           ausgeschaltet (alles durchreichen)
//   DESKTOP_FASTPROBE_MATCH=...   Teil des Kartennamens (VIDIOC_QUERYCAP card), Standard "Elgato Facecam"
//   DESKTOP_FASTPROBE_DEBUG=1     eine Zeile je TRY_FMT auf stderr
// Bauen/Einbinden: scripts/fastprobe · Doku: docs/knowledge/hardware.md
#define _GNU_SOURCE
#include <dlfcn.h>
#include <errno.h>
#include <linux/videodev2.h>
#include <pthread.h>
#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <sys/sysmacros.h>

#define MAX_FDS 32       // gleichzeitig offene Kamera-Knoten, mehr braucht kein Programm
#define MAX_FMTS 8
#define MAX_SIZES 16
#define V4L_MAJOR 81

typedef int (*ioctl_fn)(int, unsigned long, ...);

struct size { __u32 w, h; };
struct fmt {
    __u32 fourcc;
    int nsizes;
    struct size sizes[MAX_SIZES];
    int have[MAX_SIZES];                 // Antwort für sizes[i] gemerkt?
    struct v4l2_format answer[MAX_SIZES];
};
struct slot {
    int fd;                              // -1 = frei
    dev_t rdev;
    int match;                           // 1 Facecam, 0 anderes Gerät (durchreichen)
    int nfmts;
    __u32 fallback;                      // fourcc, das der Treiber bei unbekanntem Format nimmt (0 = noch unbekannt)
    struct fmt fmts[MAX_FMTS];
};

static pthread_mutex_t lock = PTHREAD_MUTEX_INITIALIZER;
static pthread_once_t once = PTHREAD_ONCE_INIT;
static ioctl_fn real_ioctl;
static int enabled, debug;
static const char *match_name = "Elgato Facecam";
static struct slot slots[MAX_FDS];
static int next_slot;

static void init(void) {
    real_ioctl = (ioctl_fn)dlsym(RTLD_NEXT, "ioctl");
    const char *e = getenv("DESKTOP_FASTPROBE");
    enabled = real_ioctl && !(e && strcmp(e, "0") == 0);
    const char *d = getenv("DESKTOP_FASTPROBE_DEBUG");
    debug = d && *d && strcmp(d, "0") != 0;
    const char *m = getenv("DESKTOP_FASTPROBE_MATCH");
    if (m && *m)
        match_name = m;
    for (int i = 0; i < MAX_FDS; i++)
        slots[i].fd = -1;
}

static void dbg(const char *f, ...) {
    if (!debug)
        return;
    va_list ap;
    va_start(ap, f);
    fputs("fastprobe: ", stderr);
    vfprintf(stderr, f, ap);
    fputc('\n', stderr);
    va_end(ap);
}

// Formate und Größen einlesen; diese ioctls beantwortet uvcvideo aus den USB-Deskriptoren, ohne die Kamera zu fragen.
static int load(int fd, struct slot *s) {
    struct v4l2_capability cap;
    memset(&cap, 0, sizeof cap);
    if (real_ioctl(fd, VIDIOC_QUERYCAP, &cap) < 0)
        return 0;
    cap.card[sizeof cap.card - 1] = 0;
    if (!strstr((const char *)cap.card, match_name) || strcmp((const char *)cap.driver, "uvcvideo") != 0)
        return 0;
    s->nfmts = 0;
    for (__u32 i = 0; i < MAX_FMTS; i++) {
        struct v4l2_fmtdesc fd_;
        memset(&fd_, 0, sizeof fd_);
        fd_.index = i;
        fd_.type = V4L2_BUF_TYPE_VIDEO_CAPTURE;
        if (real_ioctl(fd, VIDIOC_ENUM_FMT, &fd_) < 0)
            break;
        struct fmt *f = &s->fmts[s->nfmts];
        memset(f, 0, sizeof *f);
        f->fourcc = fd_.pixelformat;
        for (__u32 j = 0; j < MAX_SIZES; j++) {
            struct v4l2_frmsizeenum fs;
            memset(&fs, 0, sizeof fs);
            fs.index = j;
            fs.pixel_format = f->fourcc;
            if (real_ioctl(fd, VIDIOC_ENUM_FRAMESIZES, &fs) < 0)
                break;
            if (fs.type != V4L2_FRMSIZE_TYPE_DISCRETE)
                return 0;                // stufenlos: nicht nachbilden, durchreichen
            f->sizes[f->nsizes].w = fs.discrete.width;
            f->sizes[f->nsizes].h = fs.discrete.height;
            f->nsizes++;
        }
        if (f->nsizes == 0)
            return 0;
        s->nfmts++;
    }
    return s->nfmts > 0;
}

static struct slot *slot_for(int fd, dev_t rdev) {
    for (int i = 0; i < MAX_FDS; i++)
        if (slots[i].fd == fd && slots[i].rdev == rdev)
            return &slots[i];
    struct slot *s = NULL;
    for (int i = 0; i < MAX_FDS && !s; i++)
        if (slots[i].fd == fd || slots[i].fd == -1)
            s = &slots[i];
    if (!s) {                            // voll: reihum überschreiben
        s = &slots[next_slot];
        next_slot = (next_slot + 1) % MAX_FDS;
    }
    memset(s, 0, sizeof *s);
    s->fd = fd;
    s->rdev = rdev;
    s->match = load(fd, s);
    dbg("fd %d (%u:%u) %s, %d Formate", fd, major(rdev), minor(rdev), s->match ? "Facecam" : "anderes Gerät", s->nfmts);
    return s;
}

static struct fmt *find_fmt(struct slot *s, __u32 fourcc) {
    for (int i = 0; i < s->nfmts; i++)
        if (s->fmts[i].fourcc == fourcc)
            return &s->fmts[i];
    return NULL;
}

// wie uvc_v4l2_try_format: Abstand = Pixel der nicht überlappenden Flächen, erste kleinste gewinnt
static int nearest(const struct fmt *f, __u32 rw, __u32 rh) {
    unsigned long long best = (unsigned long long)-1;
    int bi = 0;
    for (int i = 0; i < f->nsizes; i++) {
        unsigned long long w = f->sizes[i].w, h = f->sizes[i].h;
        unsigned long long ow = w < rw ? w : rw, oh = h < rh ? h : rh;
        unsigned long long d = w * h + (unsigned long long)rw * rh - 2 * ow * oh;
        if (d < best) {
            best = d;
            bi = i;
        }
        if (best == 0)
            break;
    }
    return bi;
}

// 1 = beantwortet (Ergebnis in *ret), 0 = durchreichen
static int try_fmt(int fd, struct v4l2_format *req, int *ret) {
    if (!req || req->type != V4L2_BUF_TYPE_VIDEO_CAPTURE)
        return 0;
    struct stat st;
    if (fstat(fd, &st) < 0 || !S_ISCHR(st.st_mode) || major(st.st_rdev) != V4L_MAJOR)
        return 0;
    pthread_mutex_lock(&lock);
    struct slot *s = slot_for(fd, st.st_rdev);
    if (!s->match) {
        pthread_mutex_unlock(&lock);
        return 0;
    }
    __u32 want = req->fmt.pix.pixelformat;
    struct fmt *f = find_fmt(s, want);
    if (!f && s->fallback)
        f = find_fmt(s, s->fallback);
    if (!f) {
        // Standardformat des Treibers noch unbekannt: einmal echt fragen und merken
        int r = real_ioctl(fd, VIDIOC_TRY_FMT, req);
        if (r == 0 && find_fmt(s, req->fmt.pix.pixelformat))
            s->fallback = req->fmt.pix.pixelformat;
        dbg("TRY_FMT %.4s %ux%u -> echt (Standardformat %.4s)", (char *)&want, req->fmt.pix.width,
            req->fmt.pix.height, (char *)&s->fallback);
        pthread_mutex_unlock(&lock);
        *ret = r;
        return 1;
    }
    int i = nearest(f, req->fmt.pix.width, req->fmt.pix.height);
    if (!f->have[i]) {
        // einmal echt fragen, mit genau dieser Größe – die Antwort ist dann die des Treibers
        struct v4l2_format q;
        memset(&q, 0, sizeof q);
        q.type = V4L2_BUF_TYPE_VIDEO_CAPTURE;
        q.fmt.pix.pixelformat = f->fourcc;
        q.fmt.pix.width = f->sizes[i].w;
        q.fmt.pix.height = f->sizes[i].h;
        q.fmt.pix.field = V4L2_FIELD_ANY;
        if (real_ioctl(fd, VIDIOC_TRY_FMT, &q) < 0 || q.fmt.pix.pixelformat != f->fourcc ||
            q.fmt.pix.width != f->sizes[i].w || q.fmt.pix.height != f->sizes[i].h) {
            int e = errno;
            pthread_mutex_unlock(&lock);
            dbg("TRY_FMT %.4s %ux%u -> Ziel passt nicht, durchreichen", (char *)&want, req->fmt.pix.width,
                req->fmt.pix.height);
            errno = e;
            return 0;
        }
        f->answer[i] = q;
        f->have[i] = 1;
    }
    dbg("TRY_FMT %.4s %ux%u -> %.4s %ux%u (gemerkt)", (char *)&want, req->fmt.pix.width, req->fmt.pix.height,
        (char *)&f->fourcc, f->sizes[i].w, f->sizes[i].h);
    *req = f->answer[i];
    pthread_mutex_unlock(&lock);
    *ret = 0;
    return 1;
}

int ioctl(int fd, unsigned long request, ...) {
    va_list ap;
    va_start(ap, request);
    void *arg = va_arg(ap, void *);
    va_end(ap);
    pthread_once(&once, init);
    if (!real_ioctl) {
        errno = ENOSYS;
        return -1;
    }
    if (enabled && request == VIDIOC_TRY_FMT) {
        int r;
        if (try_fmt(fd, (struct v4l2_format *)arg, &r))
            return r;
    }
    return real_ioctl(fd, request, arg);
}

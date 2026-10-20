#!/usr/bin/python3 -I
"""Misst die Format-Abfrage wie Discord/WebRTC (DeviceInfoV4l2::FillCapabilities: 15 Formate x 13 Größen VIDIOC_TRY_FMT)
und gibt Zeit + alle Antworten als JSON aus. Aufruf über `scripts/fastprobe bench` (einmal ohne, einmal mit Shim).

  bench.py [/dev/videoN]
"""
import fcntl
import json
import os
import struct
import sys
import time

VIDIOC_TRY_FMT = 0xC0D05640
FMTS = ["MJPG", "JPEG", "YU12", "YV12", "YUYV", "UYVY", "NV12", "BGR3", "RGB3", "RGBP", "AR24", "BA24", "AB24", "BX24", "XB24"]
SIZES = [(128, 96), (160, 120), (176, 144), (320, 240), (352, 288), (640, 480), (704, 576), (800, 600),
         (960, 720), (1280, 720), (1024, 768), (1440, 1080), (1920, 1080)]


def fourcc(s):
    return struct.unpack("<I", s.encode())[0]


def main():
    dev = sys.argv[1] if len(sys.argv) > 1 else "/dev/video0"
    fd = os.open(dev, os.O_RDWR | os.O_NONBLOCK)
    answers = []
    t0 = time.monotonic()
    for f in FMTS:
        for w, h in SIZES:
            buf = bytearray(208)
            struct.pack_into("<I", buf, 0, 1)                    # V4L2_BUF_TYPE_VIDEO_CAPTURE
            struct.pack_into("<III", buf, 8, w, h, fourcc(f))
            try:
                fcntl.ioctl(fd, VIDIOC_TRY_FMT, buf)
                # v4l2_pix_format: width height pixelformat field bytesperline sizeimage colorspace
                ww, hh, pf, _field, bpl, size, cs = struct.unpack_from("<7I", buf, 8)
                answers.append([f, w, h, struct.pack("<I", pf).decode(errors="replace"), ww, hh, bpl, size, cs])
            except OSError as e:
                answers.append([f, w, h, "err", e.errno])
    total = time.monotonic() - t0
    os.close(fd)
    print(json.dumps({"seconds": round(total, 3), "n": len(answers), "answers": answers}))


if __name__ == "__main__":
    main()

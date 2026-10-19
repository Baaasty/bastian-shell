#!/usr/bin/env python3
"""Test für scripts/netinfo mit gespielten Befehlsausgaben (kein Netz, kein Eingriff): python3 scripts/tests/netinfo-test.py"""
import importlib.machinery
import importlib.util
import json
import os
import sys

path = os.path.join(os.path.dirname(__file__), "..", "netinfo")
loader = importlib.machinery.SourceFileLoader("netinfo", path)
spec = importlib.util.spec_from_loader("netinfo", loader)
ni = importlib.util.module_from_spec(spec)
loader.exec_module(ni)

fails = 0


def check(name, got, want):
    global fails
    ok = got == want
    fails += not ok
    print(("ok   " if ok else "FAIL ") + name + ("" if ok else f"  got={got!r} want={want!r}"))


def fake(table):
    def run(cmd, timeout=5):
        for key, val in table.items():
            if cmd[: len(key)] == list(key):
                return val
        return 127, "", "not found"
    return run


# Wi-Fi (iw link)
iw = "Connected to aa:bb:cc:dd:ee:ff (on wlan0)\n\tSSID: Hütte WLAN\n\tsignal: -52 dBm\n\ttx bitrate: 866.7 MBit/s\n"
ni.default_route = lambda: {"dev": "wlan0", "gateway": "10.0.0.1"}
ni.iface_kind = lambda d: "wifi"
ni.run = fake({("ip", "-j", "-4"): (0, json.dumps([{"addr_info": [{"family": "inet", "local": "10.0.0.5"}]}]), ""), ("iw", "dev", "wlan0", "link"): (0, iw, "")})
li = ni.link()
check("wifi link", (li["name"], li["speed"], li["signal"], li["ip"]), ("Hütte WLAN", 867, -52, "10.0.0.5"))

# Ping-Ausgabe + Host-Prüfung
ni.run = fake({("ping",): (0, "rtt min/avg/max/mdev = 1.0/2.5/4.0/0.5 ms\n2 packets transmitted, 2 received, 0% packet loss\n", "")})
check("ping parse", ni.ping_one({"name": "x", "host": "1.1.1.1"}, "", 2)["ms"], 2.5)
check("host ok", bool(ni.HOST_OK.match("1.1.1.1")) and bool(ni.HOST_OK.match("example.com")), True)
check("host rejects option", bool(ni.HOST_OK.match("-f")) or bool(ni.HOST_OK.match("a b")), False)

sys.exit(1 if fails else 0)

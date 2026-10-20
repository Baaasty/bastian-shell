#!/usr/bin/env python3
"""Test für scripts/share-pick: Ausgabeformat für xdph und Merken je App (ohne Shell, ohne Portal, Speicher im Temp-Ordner):
python3 -I scripts/tests/share-pick-test.py"""
import importlib.machinery
import importlib.util
import os
import sys
import tempfile

path = os.path.join(os.path.dirname(__file__), "..", "share-pick")
loader = importlib.machinery.SourceFileLoader("share_pick", path)
spec = importlib.util.spec_from_loader("share_pick", loader)
sp = importlib.util.module_from_spec(spec)
loader.exec_module(sp)

tmp = tempfile.mkdtemp()
sp.STATE = tmp
sp.LOG = os.path.join(tmp, "share-pick.log")
sp.MEMORY = os.path.join(tmp, "share-picker.json")
sp.log = lambda msg: None   # Log nicht in den Check-Ausgaben

fails = 0


def check(name, got, want):
    global fails
    ok = got == want
    fails += not ok
    print(("ok   " if ok else "FAIL ") + name + ("" if ok else f"  got={got!r} want={want!r}"))


wins = sp.parse_list("11[HC>]helium[HT>]Meet[HE>]1234[HA>]12[HC>]discord[HT>]Discord[HE>]5678[HA>]")
check("parse", [(w["id"], w["cls"]) for w in wins], [(11, "helium"), (12, "discord")])
check("format screen", sp.format_result("ok r/screen:DP-2", wins), "[SELECTION]r/screen:DP-2\n")
check("format fremdes Fenster", sp.format_result("ok /window:99", wins), None)
check("format Abbruch", sp.format_result("cancel", wins), None)

# Ohne Flag r wird nichts gemerkt
sp.remember("discord", "[SELECTION]/screen:DP-2\n", wins)
check("ohne r nichts gemerkt", sp.load_memory(), {})

# Mit r: Bildschirm merken und wiedergeben, solange der Monitor da ist
sp.remember("discord", "[SELECTION]r/screen:DP-2\n", wins)
e = sp.load_memory().get("discord")
check("screen gemerkt", e and e["sel"], "screen:DP-2")
check("recall screen", sp.recall_line(e, wins, {"DP-2", "DP-1"}), "[SELECTION]r/screen:DP-2\n")
check("recall Monitor weg", sp.recall_line(e, wins, {"DP-1"}), None)

# Fenster: über die Klasse, nur wenn eindeutig
sp.remember("helium", "[SELECTION]r/window:11\n", wins)
e = sp.load_memory().get("helium")
check("fenster gemerkt", (e["sel"], e["cls"]), ("window", "helium"))
wins2 = sp.parse_list("40[HC>]helium[HT>]Meet[HE>]1[HA>]")
check("recall fenster neue id", sp.recall_line(e, wins2, set()), "[SELECTION]r/window:40\n")
wins3 = sp.parse_list("40[HC>]helium[HT>]A[HE>]1[HA>]41[HC>]helium[HT>]B[HE>]2[HA>]")
check("recall fenster mehrdeutig", sp.recall_line(e, wins3, set()), None)

# Region: nie merken, alte Merkungen nie wiedergeben, für Call-Apps gar nicht anbieten
sp.remember("obs", "[SELECTION]r/region:DP-2@10,20,300,200\n", wins)
check("region nicht gemerkt", "obs" in sp.load_memory(), False)
check("alte region nie wiedergeben", sp.recall_line({"sel": "region:DP-2@10,20,300,200"}, wins, {"DP-2"}), None)
check("region für discord aus", sp.region_ok("discord"), False)
check("region für helium an", sp.region_ok("helium"), True)

# Ohne App (aktives Fenster unbekannt) nichts merken; Kaputtes nie wiedergeben
sp.remember("", "[SELECTION]r/screen:DP-1\n", wins)
check("ohne app", sorted(sp.load_memory()), ["discord", "helium"])
check("recall kaputt", sp.recall_line({"sel": "screen:DP-2; rm -rf"}, wins, {"DP-2"}), None)
check("recall leer", sp.recall_line(None, wins, {"DP-2"}), None)

# Ansage der Shell: gilt einmal, nur gültige App-Namen, läuft ab
sp.DIR = tmp
sp.EXPECT = os.path.join(tmp, "expect.json")
check("expect gültig", sp.expect("discord"), True)
check("take expect", sp.take_expect(), {"app": "discord"})
check("expect verbraucht", sp.take_expect(), None)
check("expect kaputter name", sp.expect("../x; rm"), False)
sp.expect("Discord")
check("expect klein", sp.take_expect(), {"app": "discord"})
sp.expect("discord")
check("expect abgelaufen", sp.take_expect(now=10 ** 12), None)

sp.expect("discord")
check("expect andere app bleibt", sp.take_expect("xwaylandvideobridge"), None)
check("expect passende app", sp.take_expect("discord"), {"app": "discord"})

# Wer fragt: offene Portal-Anfrage → Absender → Programmname (Versionsordner egal)
st = "PID=1\nComm=Discord\nExe=/home/x/.config/discord/app-1.0.164/Discord\nUserUnit=app-discord-1.scope\n"
check("app_key discord", sp.app_key(st), "discord")
check("app_key electron → comm", sp.app_key("Exe=/usr/lib/electron/electron\nComm=Signal\n"), "signal")
check("app_key leer", sp.app_key(""), "")
tree = "/org/freedesktop/portal/desktop/session/1_9/x\n/org/freedesktop/portal/desktop/request/1_1083/ashpd_9D9q9MUPjc\n"
check("requester einer", sp.portal_requester(tree, lambda s: st if s == ":1.1083" else ""), "discord")
tree2 = tree + "/org/freedesktop/portal/desktop/request/1_33/xwaylandvideobridge1\n"
check("requester mehrdeutig", sp.portal_requester(tree2, lambda s: st), "")
check("requester keiner", sp.portal_requester("/org\n", lambda s: st), "")

sys.exit(1 if fails else 0)

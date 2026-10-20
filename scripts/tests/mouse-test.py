#!/usr/bin/env python3
"""Test für scripts/mouse mit eingefrorenen Solaar-Ausgaben (keine Maus, kein Schreiben): python3 -I scripts/tests/mouse-test.py
Beispielausgaben gekürzt und ohne Seriennummer/Unit-ID."""
import importlib.machinery
import importlib.util
import os
import sys

path = os.path.join(os.path.dirname(__file__), "..", "mouse")
loader = importlib.machinery.SourceFileLoader("mouse", path)
spec = importlib.util.spec_from_loader("mouse", loader)
mo = importlib.util.module_from_spec(spec)
loader.exec_module(mo)

fails = 0


def check(name, got, want):
    global fails
    ok = got == want
    fails += not ok
    print(("ok   " if ok else "FAIL ") + name + ("" if ok else f"  got={got!r} want={want!r}"))


SHOW = """solaar version 1.1.20

G502 X PLUS
     Device path  : /dev/hidraw5
     USB id       : 046d:C095
     Codename     : G502 X PLUS
     Kind         : mouse
     Protocol     : HID++ 4.2
         6: UNIFIED BATTERY        {1004} V3
            Battery: 45%, BatteryStatus.RECHARGING.
         7: ADJUSTABLE DPI         {2201} V2
            Sensitivity (DPI) (saved): 1200
            Sensitivity (DPI)        : 1600
        11: ONBOARD PROFILES       {8100} V0
            Device Mode: On-Board
            Onboard Profiles (saved): Profile 1
            Onboard Profiles        : Profile 2
     Battery: 45%, BatteryStatus.RECHARGING.
"""
SHOW_SLEEP = """G502 X PLUS
     Codename     : G502 X PLUS
     Kind         : mouse
     Protocol     : unknown (device is offline)
     Battery: unknown (device is offline).
"""
SHOW_HOST = SHOW.replace("Profile 2\n", "Disabled\n").replace("RECHARGING", "DISCHARGING").replace("45%", "12%")

s = mo.parse_show(SHOW)
check("show ok", (s["state"], s["battery"], s["charging"], s["profile"], s["mode"], s["dpi"]), ("ok", 45, True, 2, "On-Board", 1600))
check("show ohne Seriennummer", "serial" in str(s).lower(), False)
s = mo.parse_show(SHOW_SLEEP)
check("show schläft", (s["state"], s["battery"]), ("asleep", None))
s = mo.parse_show(SHOW_HOST)
check("show Host-Modus", (s["profile"], s["battery"], s["charging"]), (0, 12, False))
check("fehler: kein Gerät", mo.classify_error(1, "", "solaar: error: no device found matching 'g502 x plus'"), "absent")
check("fehler: kein Empfänger", mo.classify_error(1, "", "solaar: error: Logitech receiver not found"), "absent")
check("fehler: offline", mo.classify_error(1, "Device G502 X PLUS is offline.", ""), "asleep")
check("fehler: solaar fehlt", mo.classify_error(127, "", ""), "nosolaar")

DUMP = """#Dumping profiles from G502 X PLUS
!OnboardProfiles
buttons: 11
count: 5
gbuttons: 11
name: G502 X PLUS
profiles:
  1: !OnboardProfile
    angle_snap: 0
    buttons:
    - !Button {behavior: 8, type: 1, value: 1}
    - !Button {behavior: 9, data: 0, value: 0}
    enabled: 1
    lighting:
    - !LEDEffectSetting {ID: 0}
    - !LEDEffectSetting {ID: 1, color: 0xff3700, ramp: 2}
    - !LEDEffectSetting {ID: 0}
    - !LEDEffectSetting {ID: 1, color: 0x000000, ramp: 2}
    name: PROFILE_NAME_DEFAULT
    reserved: !!binary |
      //////////8=
    resolution_default_index: 0
    resolution_shift_index: 1
    resolutions:
    - 1200
    - 1600
    - 2000
    - 0
    - 0
    sector: 1
  2: !OnboardProfile
    angle_snap: 0
    enabled: 0
    lighting:
    - !LEDEffectSetting {ID: 15, intensity: 100, period: 0}
    - !LEDEffectSetting {ID: 15, intensity: 100, period: 0}
    - !LEDEffectSetting {ID: 16, intensity: 100, period: 0}
    - !LEDEffectSetting {ID: 16, intensity: 100, period: 0}
    name: ''
    resolution_default_index: 2
    resolution_shift_index: 0
    resolutions:
    - 800
    - 1200
    - 1600
    - 2400
    - 3200
    sector: 2
sectors: 16
size: 255
version: 3
"""
data = mo.yaml_load(DUMP)
i1 = mo.profile_info(data, 1)
check("profil 1", (i1["resolutions"], i1["slots"], i1["defaultIndex"], i1["color"]), ([1200, 1600, 2000], 5, 0, "#FF3700"))
i2 = mo.profile_info(data, 2)
check("profil 2 ohne Farbe", (i2["resolutions"], i2["defaultIndex"], i2["color"]), ([800, 1200, 1600, 2400, 3200], 2, ""))

# Patch: nur gewollte Felder, Rest Byte für Byte
new = mo.patch_profile(DUMP, 1, [800, 1600], 1, "#FFA300")
d2 = mo.yaml_load(new)
check("patch Werte", (d2["profiles"][1]["resolutions"], d2["profiles"][1]["resolution_default_index"], d2["profiles"][1]["lighting"][1]["color"]),
      ([800, 1600, 0, 0, 0], 1, 0xFFA300))
check("patch Profil 2 unberührt", d2["profiles"][2], data["profiles"][2])
diff = sorted(mo.changed_paths(data, d2))
check("patch nur erlaubte Pfade", diff, ["/profiles/1/lighting/1/color", "/profiles/1/resolution_default_index",
                                         "/profiles/1/resolutions/0", "/profiles/1/resolutions/2"])
check("patch Zeilenzahl gleich", len(new.splitlines()), len(DUMP.splitlines()))
check("patch ohne Änderung = gleich", mo.patch_profile(DUMP, 1), DUMP)
# Farbe in ein Profil ohne statische Farbe: Eintrag wird Static
d3 = mo.yaml_load(mo.patch_profile(DUMP, 2, color="#FF3700"))
check("patch Farbe neu", d3["profiles"][2]["lighting"][1], {"ID": 1, "color": 0xFF3700, "ramp": 2})

# Prüfen der Anfrage
check("validate nur Geändertes", mo.validate({"resolutions": [1200, 1600, 2000], "defaultIndex": 1, "color": "#ff3700"}, i1),
      (None, 1, None))
for bad, why in (({"resolutions": [50]}, "dpi zu klein"), ({"resolutions": [1] * 6}, "zu viele Stufen"),
                 ({"defaultIndex": 3}, "index"), ({"color": "rot"}, "farbe")):
    try:
        mo.validate(bad, i1)
        check("validate " + why, "kein Fehler", "Fehler")
    except ValueError:
        check("validate " + why, True, True)
try:
    mo.patch_profile(DUMP, 3)
    check("patch fehlendes Profil", "kein Fehler", "Fehler")
except ValueError:
    check("patch fehlendes Profil", True, True)

# Nach dem Licht-Fix hängt logitech_receiver eigene Tags global an SafeLoader – yaml_load muss trotzdem dicts liefern
import yaml  # noqa: E402

yaml.SafeLoader.add_constructor("!OnboardProfiles", lambda loader, node: object())
yaml.SafeLoader.add_constructor("!OnboardProfile", lambda loader, node: object())
check("yaml_load trotz fremder Tags", mo.profile_info(mo.yaml_load(DUMP), 1)["resolutions"], [1200, 1600, 2000])

sys.exit(1 if fails else 0)

#!/usr/bin/env python3
"""theme/palette.json -> Equibop/Equicord-Theme (nur Farben, Flächen, Text, Schrift – Discord bleibt Discord).

Erzeugt theme/out/equibop/desktop.theme.css. Das Theme überschreibt NUR Discords Farb-Variablen
(Hintergründe, Text, Ränder, Eingabefelder, Scrollbars) und die Schrift. Layout, Server-Leiste, Icons, Emojis,
Rollenfarben, Avatare, Statusfarben (grün/gelb/rot) bleiben unverändert. Discords Marken-Akzent (Blurple)
bleibt als gedämpfte Variante für Buttons, Links, Erwähnungen und Auswahl – damit man es sofort als Discord erkennt.

Aufruf aus dem Repo-Root:
  python3 -I theme/gen/equibop.py [variante] [--nur-out] [--ohne-schrift]
Installieren/Einschalten: scripts/equibop-theme install (Equibop vorher beenden).

Discord-Variablen geprüft gegen die Web-App (discord.com/login, 2026-10-18): Block .theme-dark, Primitive in :root.
Discord hängt die Klasse theme-dark/-darker/-midnight an <html>; wir verdoppeln den Selektor, damit unser Theme
unabhängig von der Ladereihenfolge gewinnt.
"""
import colorsys
import pathlib
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import _pal  # noqa: E402

DISCORD_BLURPLE = "#5865F2"  # Discords Marken-Akzent (hier nur als Ausgangsfarbe für die gedämpfte Variante)
MIN_CONTRAST = 4.5
NAME = "desktop.theme.css"


def hsl(color: str):
    r, g, b, _ = _pal.rgba(color)
    h, l, s = colorsys.rgb_to_hls(r / 255, g / 255, b / 255)
    return h, s, l


def from_hsl(h, s, l) -> str:
    r, g, b = colorsys.hls_to_rgb(h % 1.0, max(0.0, min(1.0, l)), max(0.0, min(1.0, s)))
    return _pal.hexc(r * 255, g * 255, b * 255)


def rgba(color: str, a: float) -> str:
    r, g, b, _ = _pal.rgba(color)
    return f"rgba({r}, {g}, {b}, {a:g})"


def build(p: dict, font: bool = True) -> tuple[str, list[str]]:
    """-> (css, Kontrast-Meldungen). p = Variante aus der Palette."""
    flat = lambda k: _pal.over(p[k], p["bg"])  # noqa: E731  (Alpha auf Grund legen, falls Variante durchsichtig)
    lowest, lower, low = flat("bgBottom"), flat("bg"), flat("surfaceSunken")
    chat, raised = flat("surface"), flat("surfaceRaised")
    highest = _pal.mix(raised, flat("woodLight"), 0.16)
    foot = _pal.mix(low, lower, 0.5)              # Modal-Fuß, Vertiefungen
    text, muted, faint = flat("text"), flat("textMuted"), flat("textFaint")
    channel = _pal.mix(muted, faint, 0.45)        # inaktive Kanalnamen
    hairline = p["border"]                         # 1-px-Rand (Creme mit Alpha)
    cream = text

    # Marken-Akzent: Discords Blurple, gedämpft und etwas dunkler, damit Creme-Text darauf ≥ 4,5 : 1 hat
    bh, _, _ = hsl(DISCORD_BLURPLE)
    brand = from_hsl(bh, 0.34, 0.50)
    brand_hover = from_hsl(bh, 0.34, 0.45)
    brand_press = from_hsl(bh, 0.34, 0.40)
    brand_text = from_hsl(bh, 0.62, 0.80)         # Akzent als Text/Icon auf Dunkel
    link = from_hsl(bh - 0.015, 0.62, 0.76)       # Links: ruhiges Periwinkle
    mention_fg = from_hsl(bh, 0.70, 0.88)

    checks = [
        ("Text auf Chat", text, chat), ("Text auf Kanalliste", text, lower), ("Text auf Server-Leiste", text, lowest),
        ("Text auf Popout", text, raised), ("gedämpft auf Chat", muted, chat), ("gedämpft auf Kanalliste", muted, lower),
        ("schwach auf Chat", faint, chat), ("schwach auf Kanalliste", faint, lower), ("schwach auf Popout", faint, raised),
        ("Kanalname auf Kanalliste", channel, lower), ("Text auf Marken-Button", cream, brand),
        ("Text auf Marken-Button (Hover)", cream, brand_hover), ("Marken-Text auf Chat", brand_text, chat),
        ("Link auf Chat", link, chat), ("Erwähnung auf Chat", mention_fg, _pal.over(rgba(brand, 0.28), chat)),
    ]
    notes = []
    for label, fg, bg in checks:
        c = _pal.contrast(fg, bg)
        if c < MIN_CONTRAST:
            notes.append(f"Kontrast zu niedrig: {label} {c:.2f}")

    V = {}  # Variablenname -> Wert (Reihenfolge bleibt)

    def put(group: str, **kw):
        V.setdefault(group, {}).update({k.replace("_", "-"): v for k, v in kw.items()})

    put("Flächen (Discord: base-lowest = Server-Leiste/Titel, lower = Kanalliste, low = Seitenfelder, surface = Chat/Karten/Popouts)",
        background_base_lowest=lowest, background_base_lower=lower, background_base_low=low,
        background_surface_high=chat, background_surface_higher=raised, background_surface_highest=highest,
        app_frame_background=lowest, app_frame_border=hairline,
        chat_background_default=chat, chat_background=chat, chat_border=hairline,
        channel_background_default=lower, home_background=chat, guild_profile_banner_background_default=lowest,
        channeltextarea_background=raised, card_background_default=raised, card_border_default=hairline,
        card_secondary_bg=rgba(cream, 0.07), card_primary_pressed_bg=low, card_secondary_pressed_bg=low,
        embed_background=raised, embed_background_alternate=raised, modal_background=chat, modal_footer_background=foot,
        bg_surface_raised=raised, background_secondary_alt=lower, background_accent=highest,
        background_scrim=rgba("#18110D", 0.72), background_scrim_lightbox=rgba("#18110D", 0.9),
        spoiler_hidden_background=flat("wood"), spoiler_hidden_background_hover=_pal.mix(flat("wood"), flat("woodLight"), 0.4),
        spoiler_revealed_background=low)
    put("Schleier (Hover, Auswahl, Kacheln)",
        background_mod_muted=rgba(cream, 0.05), background_mod_subtle=rgba(cream, 0.08),
        background_mod_normal=rgba(cream, 0.12), background_mod_strong=rgba(cream, 0.17),
        interactive_background_default=rgba(cream, 0.05), interactive_background_hover=rgba(cream, 0.09),
        interactive_background_active=rgba(cream, 0.13), interactive_background_selected=rgba(cream, 0.16),
        message_background_hover=rgba(cream, 0.045),
        control_secondary_background_default=rgba(cream, 0.09), control_secondary_background_hover=rgba(cream, 0.13),
        control_secondary_background_active=rgba(cream, 0.17),
        control_icon_only_background_hover=rgba(cream, 0.10), control_icon_only_background_active=rgba(cream, 0.15),
        redesign_button_tertiary_pressed_background=rgba(cream, 0.15))
    put("Text",
        text_strong=cream, text_default=text, text_subtle=muted, text_muted=faint,
        text_invert=lowest, chat_text_muted=faint, channels_default=channel, channel_icon=faint,
        interactive_text_default=muted, interactive_text_hover=cream, interactive_text_active=cream,
        interactive_icon_default=muted, interactive_icon_hover=cream, interactive_icon_active=cream,
        interactive_muted=flat("wood"), textbox_markdown_syntax=faint,
        control_icon_only_icon_default=muted, control_secondary_text_default=cream,
        redesign_button_tertiary_text=text, redesign_button_tertiary_pressed_text=cream)
    put("Ränder und Eingabefelder",
        border_muted=rgba(cream, 0.05), border_subtle=hairline, border_normal=p["borderStrong"], border_strong=rgba(cream, 0.34),
        input_background_default=rgba("#000000", 0.20), input_border_default=p["borderStrong"], input_border_hover=rgba(cream, 0.30),
        input_text_default=text, input_placeholder_text_default=faint, input_icon_default=muted,
        channel_text_area_placeholder=faint)
    put("Marken-Akzent: Discord-Blurple, gedämpft (Buttons, Links, Erwähnungen, Auswahl)",
        brand_500=brand, brand_360=brand_text, brand_400=brand_text, brand_530=brand_hover, brand_560=brand_press,
        brand_600=brand_press, brand_experiment=brand, background_brand=brand,
        control_primary_background_default=brand, control_primary_background_hover=brand_hover,
        control_primary_background_active=brand_press,
        control_primary_text_default=cream, control_primary_text_hover=cream, control_primary_text_active=cream,
        control_primary_icon_default=cream, control_primary_icon_hover=cream, control_primary_icon_active=cream,
        control_brand_foreground=brand_text, control_brand_foreground_new=brand_text, text_brand=brand_text, text_link=link,
        interactive_accent_background_default=rgba(cream, 0.09), interactive_accent_background_hover=brand,
        interactive_accent_background_active=brand_press, interactive_accent_background_selected=brand,
        input_border_active=brand_text, border_focus=brand_text,
        mention_background=rgba(brand, 0.30), mention_foreground=mention_fg,
        message_highlight_background_default=rgba(brand, 0.14), message_highlight_background_hover=rgba(brand, 0.19))
    put("Scrollbars",
        scrollbar_thin_thumb=flat("woodLight"), scrollbar_thin_track="transparent",
        scrollbar_auto_thumb=flat("woodLight"), scrollbar_auto_track="transparent",
        scrollbar_auto_scrollbar_color_thumb=flat("woodLight"), scrollbar_auto_scrollbar_color_track=low)
    put("Alte Namen (Plugins/Themes anderer greifen darauf zu)",
        background_primary=chat, background_secondary=lower, background_tertiary=lowest, background_floating=raised,
        background_modifier_hover=rgba(cream, 0.07), background_modifier_selected=rgba(cream, 0.14),
        background_modifier_accent=hairline, text_normal=text, header_primary=cream, header_secondary=muted,
        interactive_normal=muted, interactive_hover=cream, interactive_active=cream)

    sel = ",\n".join(f".{c}.{c}" for c in ("theme-dark", "theme-darker", "theme-midnight"))
    out = [
        "/**",
        " * @name Desktop (Equibop)",
        " * @description Bastians PC-Look (hearth): warme Braunflächen, Creme-Text – Discord bleibt erkennbar (Blurple gedämpft, Layout unverändert)",
        " * @author desktop",
        " * @version 1",
        " */",
        f"/* {_pal.MARK} (Variante {p.get('_name', 'hearth')}) – nicht von Hand ändern. Neu: python3 -I theme/gen/equibop.py */",
        "/* Nur Farb-Variablen + Schrift. Layout, Icons, Emojis, Rollenfarben, Avatare, Status (grün/gelb/rot) bleiben Discord. */",
        "",
        sel + " {",
    ]
    for group, vars_ in V.items():
        out.append(f"    /* {group} */")
        for k, v in vars_.items():
            out.append(f"    --{k}: {v};")
        out.append("")
    out[-1] = "}"
    if font:
        out += [
            "",
            "/* Schrift: Inter für den Fließtext (Discords gg sans bleibt als Rückfall, Überschriften/Code unverändert) */",
            'html:root { --font-primary: "Inter", "gg sans", "Noto Sans", "Helvetica Neue", Helvetica, Arial, sans-serif; }',
        ]
    return "\n".join(out) + "\n", notes


def main():
    src, variant, p = _pal.load()
    p = dict(p, _name=variant)
    css, notes = build(p, font="--ohne-schrift" not in sys.argv)
    print(f"Equibop-Theme ({variant}):")
    _pal.write(_pal.OUT / "equibop" / NAME, css)
    for n in notes:
        print("  WARNUNG:", n)
    if notes:
        sys.exit(1)
    print("  Kontraste ok (>= 4,5 : 1). Installieren: scripts/equibop-theme install")


if __name__ == "__main__":
    main()

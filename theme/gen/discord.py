#!/usr/bin/env python3
"""theme/palette.json -> Discord-Theme für Equicord im normalen Discord-Client (RPM).

Erzeugt theme/out/discord/desktop-discord.theme.css.
Flächen und Text = Shell-Palette (aktive Variante, hearth): dieselben Braun-/Cremetöne wie die Shell.
Erkennungsmerkmal = Discord-Blurple, deutlich sichtbar (nur leicht ruhiger als das Original): Home-Knopf,
aktiver Server-Strich, ausgewählter Kanal, Buttons, Schalter, Links, @-Erwähnungen. Ember-Terrakotta nur sparsam:
Nachrichten, in denen man erwähnt wird, Zähler für ungelesene Erwähnungen, Ungelesen-Strich in der Server-Leiste.
Layout, Icons, Emojis, Rollenfarben, Avatare und Statusfarben (grün/gelb/rot) bleiben Discord.

Aufruf aus dem Repo-Root:
  python3 -I theme/gen/discord.py [variante] [--nur-out] [--ohne-schrift]
Ist das Theme schon installiert (~/.config/Equicord/themes/, von hier), wird nur die Datei erneuert
(Equicord lädt sie beim Ändern neu). Einschalten: scripts/discord-theme install.

Discord-Variablen geprüft gegen den Desktop-Client 1.0.162 (Block .theme-dark aus Discords CSS, 2026-10-18).
Zwei Ebenen: semantische Variablen (--background-base-*, --text-*, --interactive-* …) und die Grund-Töne,
aus denen Discord den Rest baut (--opacity-N-hsl = Schleier, --opacity-blurple-N-hsl / --blurple-N-hsl = Marke).
Selektor doppelt (.theme-dark.theme-dark), damit das Theme unabhängig von der Ladereihenfolge gewinnt.
"""
import colorsys
import os
import pathlib
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import _pal  # noqa: E402

# Einzige Farbe außerhalb der Palette: Discords Marken-Blurple, nur als Ausgangs-Farbton für die Ableitung.
DISCORD_BLURPLE = "#5865F2"
MIN_CONTRAST = 4.5
NAME = "desktop-discord.theme.css"
INSTALLED = pathlib.Path(os.environ.get("EQUICORD_CONFIG") or (_pal.HOME / ".config/Equicord")).expanduser() / "themes" / NAME
OPACITY_STEPS = (1, 4, 8, 12, 16, 20, 24, 28, 32, 36, 40, 44, 48, 52, 56, 60, 64, 68, 72, 76, 80, 84, 88, 92, 96)


def hsl(color: str):
    r, g, b, _ = _pal.rgba(color)
    h, l, s = colorsys.rgb_to_hls(r / 255, g / 255, b / 255)
    return h, s, l


def from_hsl(h, s, l) -> str:
    r, g, b = colorsys.hls_to_rgb(h % 1.0, max(0.0, min(1.0, l)), max(0.0, min(1.0, s)))
    return _pal.hexc(r * 255, g * 255, b * 255)


def triplet(color: str) -> str:
    """'#RRGGBB' -> 'H S% L%' (Discords *-hsl-Variablen, benutzt als hsl(var(--x-hsl)/alpha))."""
    h, s, l = hsl(color)
    return f"{h * 360:.1f} {s * 100:.1f}% {l * 100:.1f}%"


def rgba(color: str, a: float) -> str:
    r, g, b, _ = _pal.rgba(color)
    return f"rgba({r}, {g}, {b}, {a:g})"


def build(p: dict, radius: dict, font_ui: str, font_mono: str, font: bool = True) -> tuple[str, list[str]]:
    """-> (css, Kontrast-Meldungen). p = Variante aus der Palette."""
    flat = lambda k: _pal.over(p[k], p["bg"])  # noqa: E731  (Alpha auf Grund legen, falls Variante durchsichtig)
    # Flächen = Shell-Palette, Discords Schichtung: Server-Leiste am tiefsten, Chat = Kachel-Ton
    lowest, lower, low = flat("bgBottom"), flat("bg"), flat("surfaceSunken")
    chat, raised = flat("surface"), flat("surfaceRaised")
    highest = _pal.mix(raised, flat("woodLight"), 0.16)
    foot = _pal.mix(low, lower, 0.5)
    text, muted, faint = flat("text"), flat("textMuted"), flat("textFaint")
    channel = _pal.mix(muted, faint, 0.45)          # inaktive Kanalnamen
    cream = text
    hairline, line = p["border"], p["borderStrong"]
    shade = _pal.hexc(*_pal.rgba(p["shadow"])[:3])  # Schatten-Ton der Palette, deckend (Schleier hinter Dialogen)
    wood, wood_light = flat("wood"), flat("woodLight")
    thumb = _pal.mix(wood, wood_light, 0.5)

    # Marke: Discord-Blurple, kräftig genug zum Wiedererkennen, Creme-Text darauf >= 4,5 : 1
    bh, _, _ = hsl(DISCORD_BLURPLE)
    brand = from_hsl(bh, 0.60, 0.58)
    brand_hover = from_hsl(bh, 0.60, 0.54)
    brand_press = from_hsl(bh, 0.60, 0.50)
    brand_text = from_hsl(bh, 0.80, 0.80)           # Marke als Text/Icon auf Braun
    link = from_hsl(bh - 0.015, 0.75, 0.78)         # Links: helles Periwinkle
    mention_fg = from_hsl(bh, 0.85, 0.90)

    # Ember sparsam: erwähnt werden, ungelesene Erwähnungen
    ember, ember_text = flat("accent"), flat("accentText")
    ember_badge = _pal.mix(flat("accentPressed"), shade, 0.12)  # Zähler-Kreis, weiße Zahl darauf lesbar

    checks = [
        ("Text auf Chat", text, chat), ("Text auf Kanalliste", text, lower), ("Text auf Server-Leiste", text, lowest),
        ("Text auf Popout", text, raised), ("gedämpft auf Chat", muted, chat), ("gedämpft auf Kanalliste", muted, lower),
        ("schwach auf Chat", faint, chat), ("schwach auf Kanalliste", faint, lower), ("schwach auf Popout", faint, raised),
        ("Kanalname auf Kanalliste", channel, lower), ("Text auf Blurple-Button", cream, brand),
        ("Text auf Blurple-Button (Hover)", cream, brand_hover), ("Blurple-Text auf Chat", brand_text, chat),
        ("Link auf Chat", link, chat), ("Link auf Popout", link, raised),
        ("Erwähnung auf Chat", mention_fg, _pal.over(rgba(brand, 0.30), chat)),
        ("Text in Erwähnt-Nachricht", text, _pal.over(rgba(ember, 0.12), chat)),
        ("Text auf ausgewähltem Kanal", cream, _pal.over(rgba(brand, 0.28), lower)),
        ("Zahl auf Erwähnungs-Zähler", "#FFFFFF", ember_badge),
    ]
    notes = [f"Kontrast zu niedrig: {label} {c:.2f}" for label, fg, bg in checks
             if (c := _pal.contrast(fg, bg)) < MIN_CONTRAST]

    V = {}  # Gruppe -> {Variablenname: Wert}

    def put(group: str, **kw):
        V.setdefault(group, {}).update({k.replace("_", "-"): v for k, v in kw.items()})

    put("Grund-Töne: Schleier (Discord baut Hover/Ränder/Kacheln daraus) = warmes Grau statt Blaugrau",
        **{f"opacity_{n}_hsl": triplet(faint) for n in OPACITY_STEPS})
    put("Grund-Töne: Marke (alles, was Discord in Blurple tönt)",
        **{f"opacity_blurple_{n}_hsl": triplet(brand) for n in OPACITY_STEPS},
        blurple_50_hsl=triplet(brand), blurple_59_hsl=triplet(brand_hover), blurple_60_hsl=triplet(brand_hover),
        blurple_65_hsl=triplet(brand_press), blurple_26_hsl=triplet(brand_text), blurple_29_hsl=triplet(brand_text),
        brand_500_hsl=triplet(brand), brand_530_hsl=triplet(brand_hover), brand_560_hsl=triplet(brand_press),
        brand_600_hsl=triplet(brand_press), brand_360_hsl=triplet(brand_text), brand_400_hsl=triplet(brand_text))
    put("Flächen (base-lowest = Server-Leiste, lower = Kanalliste, low = Seitenfelder, surface = Chat/Karten/Popouts)",
        background_base_lowest=lowest, background_base_lower=lower, background_base_low=low,
        background_surface_high=chat, background_surface_higher=raised, background_surface_highest=highest,
        app_frame_background=lowest, app_frame_border=hairline, panel_bg=lower,
        chat_background_default=chat, chat_background=chat, chat_border=hairline,
        channel_background_default=lower, home_background=chat, guild_profile_banner_background_default=lowest,
        channeltextarea_background=raised, card_background_default=raised, card_border_default=hairline,
        card_secondary_bg=rgba(cream, 0.07), card_primary_pressed_bg=low, card_secondary_pressed_bg=low,
        embed_background=raised, embed_background_alternate=raised, modal_background=chat, modal_footer_background=foot,
        bg_surface_raised=raised, background_secondary_alt=lower, background_accent=highest,
        user_profile_overlay_background=raised, user_profile_toolbar_background=raised,
        user_profile_activity_toolbar_background=raised, user_profile_note_background_focus=lowest,
        user_profile_border=hairline, mobile_expression_picker_background_default=chat,
        background_scrim=rgba(shade, 0.72), background_scrim_lightbox=rgba(shade, 0.9),
        context_menu_backdrop_background=rgba(shade, 0.72), overlay_backdrop_lightbox=rgba(shade, 0.9),
        spoiler_hidden_background=wood, spoiler_hidden_background_hover=_pal.mix(wood, wood_light, 0.4),
        spoiler_revealed_background=low, background_code=rgba(brand, 0.08))
    put("Schleier (Hover, Kacheln); Auswahl = Blurple-Tönung (ausgewählter Kanal, DM, Einstellungs-Seite)",
        background_mod_muted=rgba(cream, 0.05), background_mod_subtle=rgba(cream, 0.08),
        background_mod_normal=rgba(cream, 0.12), background_mod_strong=rgba(cream, 0.17),
        interactive_background_default=rgba(cream, 0.05), interactive_background_hover=rgba(cream, 0.09),
        interactive_background_active=rgba(cream, 0.13), interactive_background_selected=rgba(brand, 0.28),
        message_background_hover=rgba(cream, 0.045), user_profile_background_hover=rgba(cream, 0.08),
        control_secondary_background_default=rgba(cream, 0.09), control_secondary_background_hover=rgba(cream, 0.13),
        control_secondary_background_active=rgba(cream, 0.17),
        control_icon_only_background_hover=rgba(cream, 0.10), control_icon_only_background_active=rgba(cream, 0.15),
        redesign_button_tertiary_pressed_background=rgba(cream, 0.15),
        reaction_background_default=rgba(cream, 0.07), reaction_background_hover=rgba(cream, 0.11),
        reaction_background_active=rgba(cream, 0.15), reaction_border_default=hairline,
        keyword_highlight_background=rgba(cream, 0.16))
    put("Text und Icons",
        text_strong=cream, text_default=text, text_subtle=muted, text_muted=faint, text_invert=lowest,
        chat_text_muted=faint, channels_default=channel, channel_icon=faint,
        icon_strong=cream, icon_default=text, icon_subtle=muted, icon_muted=faint, icon_invert=lowest,
        interactive_text_default=muted, interactive_text_hover=cream, interactive_text_active=cream,
        interactive_icon_default=muted, interactive_icon_hover=cream, interactive_icon_active=cream,
        interactive_muted=wood, textbox_markdown_syntax=faint,
        control_icon_only_icon_default=muted, control_secondary_text_default=cream,
        redesign_button_tertiary_text=text, redesign_button_tertiary_pressed_text=cream,
        reaction_text_default=muted, reaction_text_hover=cream, reaction_text_active=cream)
    put("Ränder und Eingabefelder",
        border_muted=rgba(cream, 0.05), border_subtle=hairline, border_normal=line, border_strong=rgba(cream, 0.34),
        input_background_default=rgba(shade, 0.30), input_border_default=line, input_border_hover=rgba(cream, 0.30),
        input_text_default=text, input_placeholder_text_default=faint, input_icon_default=muted,
        channel_text_area_placeholder=faint)
    put("Marke: Discord-Blurple (Home-Knopf, Buttons, Schalter, Links, Erwähnungen, Fokus)",
        brand_500=brand, brand_360=brand_text, brand_400=brand_text, brand_530=brand_hover, brand_560=brand_press,
        brand_600=brand_press, brand_experiment=brand, background_brand=brand,
        control_primary_background_default=brand, control_primary_background_hover=brand_hover,
        control_primary_background_active=brand_press,
        control_primary_text_default=cream, control_primary_text_hover=cream, control_primary_text_active=cream,
        control_primary_icon_default=cream, control_primary_icon_hover=cream, control_primary_icon_active=cream,
        control_brand_foreground=brand_text, control_brand_foreground_new=brand_text,
        text_brand=brand_text, icon_brand=brand_text, text_link=link, icon_link=link, tabs_indicator_default=brand_text,
        interactive_accent_background_default=rgba(cream, 0.09), interactive_accent_background_hover=brand,
        interactive_accent_background_active=brand_press, interactive_accent_background_selected=brand,
        input_border_active=brand_text, border_focus=brand_text,
        switch_background_selected_default=brand, switch_background_selected_hover=brand_hover,
        switch_background_active=brand_press, switch_thumb_icon_active=brand,
        checkbox_background_selected_default=brand, checkbox_background_selected_hover=brand_hover,
        checkbox_background_active=brand_press,
        radio_background_selected_default=brand, radio_background_selected_hover=brand_hover,
        radio_background_active=brand_press, radio_foreground_active=brand,
        progressbar_indicator_background=brand, progressbar_track_background=rgba(cream, 0.14),
        slider_track_background=wood,
        badge_primary_background=brand, togglebutton_border_selected=brand,
        togglebutton_background_selected=rgba(brand, 0.18), togglebutton_background_selected_hover=rgba(brand, 0.26),
        reaction_background_reacted_default=rgba(brand, 0.26), reaction_background_reacted_hover=rgba(brand, 0.32),
        reaction_border_reacted_default=brand, reaction_text_reacted_default=mention_fg,
        mention_background=rgba(brand, 0.30), mention_foreground=mention_fg,
        message_highlight_background_default=rgba(brand, 0.14), message_highlight_background_hover=rgba(brand, 0.19))
    put("Ember sparsam: Nachrichten mit Erwähnung, Zähler ungelesener Erwähnungen",
        message_mentioned_background_default=rgba(ember, 0.12), message_mentioned_background_hover=rgba(ember, 0.16),
        badge_notification_background=ember_badge, background_feedback_notification=ember_badge,
        icon_feedback_notification=ember_text)
    put("Scrollbars",
        scrollbar_thin_thumb=thumb, scrollbar_thin_track="transparent",
        scrollbar_auto_thumb=thumb, scrollbar_auto_track="transparent",
        scrollbar_auto_scrollbar_color_thumb=thumb, scrollbar_auto_scrollbar_color_track=low)
    put("Weiche Ecken (Palette radius)",
        radius_xs=f"{radius['xs']}px", radius_sm=f"{radius['sm']}px", radius_md=f"{radius['md']}px",
        radius_lg=f"{radius['lg']}px")
    put("Alte Namen (Plugins/Themes anderer greifen darauf zu)",
        background_primary=chat, background_secondary=lower, background_tertiary=lowest, background_floating=raised,
        background_modifier_hover=rgba(cream, 0.07), background_modifier_selected=rgba(brand, 0.28),
        background_modifier_accent=hairline, text_normal=text, header_primary=cream, header_secondary=muted,
        interactive_normal=muted, interactive_hover=cream, interactive_active=cream)

    sel = ",\n".join(f".{c}.{c}" for c in ("theme-dark", "theme-darker", "theme-midnight"))
    dark = ", ".join(f".{c}" for c in ("theme-dark", "theme-darker", "theme-midnight"))
    guilds = '[data-list-id="guildsnav"] [class^="wrapper_"] > [class^="item_"]'
    out = [
        "/**",
        " * @name Desktop (Discord)",
        " * @description Bastians PC-Look: Flächen und Text wie die Shell (warmes Braun, Creme), Discord-Blurple als Erkennungszeichen, Ember nur für Erwähnungen",
        " * @author desktop",
        " * @version 1",
        " */",
        f"/* {_pal.MARK} (Variante {p.get('_name', 'hearth')}) – nicht von Hand ändern. Neu: python3 -I theme/gen/discord.py */",
        "/* Farb-Variablen, Ecken, Schrift. Layout, Icons, Emojis, Rollenfarben, Avatare, Status (grün/gelb/rot) bleiben Discord. */",
        "",
        sel + " {",
    ]
    for group, vars_ in V.items():
        out.append(f"    /* {group} */")
        out += [f"    --{k}: {v};" for k, v in vars_.items()]
        out.append("")
    out[-1] = "}"
    out += [
        "",
        "/* Server-Leiste: aktiver Server-Strich in Blurple, Ungelesen-Punkt in Ember (Discord nimmt für beide --text-strong) */",
        f":is({dark}) {guilds}[class*=\" selected_\"] {{ background-color: {brand_text}; }}",
        f":is({dark}) {guilds}[class*=\" visible_\"]:not([class*=\" selected_\"]):not([class*=\" hovered_\"]) {{ background-color: {ember}; }}",
        "/* Nachricht mit Erwähnung: Randstrich in Ember statt Gelb */",
        f":is({dark}) [class^=\"mentioned_\"]::before, :is({dark}) [class*=\" mentioned_\"]::before {{ background: {ember}; }}",
    ]
    if font:
        out += [
            "",
            "/* Schrift: Inter (Shell), Code in JetBrains Mono Nerd Font; Discords gg sans bleibt Rückfall */",
            "html:root {",
            f'    --font-primary: "{font_ui}", "gg sans", "Noto Sans", "Helvetica Neue", Helvetica, Arial, sans-serif;',
            f'    --font-display: "{font_ui}", "gg sans", "Noto Sans", "Helvetica Neue", Helvetica, Arial, sans-serif;',
            f'    --font-code: "{font_mono}", "JetBrains Mono", Consolas, "Andale Mono WT", "Andale Mono", monospace;',
            "}",
        ]
    return "\n".join(out) + "\n", notes


def balanced(css: str) -> bool:
    depth = 0
    for ch in css:
        depth += {"{": 1, "}": -1}.get(ch, 0)
        if depth < 0:
            return False
    return depth == 0 and css.count("/*") == css.count("*/")


def main():
    src, variant, p = _pal.load()
    p = dict(p, _name=variant)
    t = src["type"]
    css, notes = build(p, src["radius"], t["ui"]["family"], t["mono"]["family"], font="--ohne-schrift" not in sys.argv)
    if not balanced(css):
        sys.exit("Fehler: CSS unausgeglichen (Klammern/Kommentare) – Generator prüfen")
    print(f"Discord-Theme ({variant}):")
    out = _pal.OUT / "discord" / NAME
    _pal.write(out, css)
    for n in notes:
        print("  WARNUNG:", n)
    if notes:
        sys.exit(1)
    # Schon installiert (von hier)? Dann nur die Datei erneuern – Einstellungen fasst nur scripts/discord-theme an
    if _pal.install_wanted() and INSTALLED.exists():
        _pal.install(out, INSTALLED)
    print("  Kontraste ok (>= 4,5 : 1). Einschalten: scripts/discord-theme install")


if __name__ == "__main__":
    main()

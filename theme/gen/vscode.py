#!/usr/bin/env python3
"""theme/palette.json -> VS-Code-Farbschema "Desktop" (theme/out/vscode-desktop/).

Editor = editorSyntax, Rahmen (Sidebar, Activity Bar, Statusleiste, Tabs) = Ember-Töne,
integriertes Terminal = ansi. Dazu theme/out/vscode-desktop-projects/ (Projektpunkt in der Statusleiste,
siehe vscode_projects.py). Installiert als desktop.desktop-theme / desktop.desktop-projects in beide VS Codes,
soweit eingerichtet: natives RPM (~/.vscode/extensions) und Flatpak (~/.var/app/…). Jeweils über
die CLI (damit extensions.json stimmt), sonst Ordner kopieren + in extensions.json eintragen.
Setzt das Theme NICHT aktiv (das macht `scripts/vscode-colors theme on`). Aufruf aus dem Repo-Root:
  python3 -I theme/gen/vscode.py [variante] [--nur-out]
"""
import json
import pathlib
import shutil
import subprocess
import sys
import tempfile
import zipfile

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
from _pal import HOME, MARK, OUT, alpha, contrast, hex8, install, install_wanted, load, mix, write  # noqa: E402

src, variant, t = load()
ansi = src["ansi"]
ed = src["editorSyntax"]

PUBLISHER, NAME, VERSION = "desktop", "desktop-theme", "0.2.0"
FLATPAK = "com.visualstudio.code"
FLATPAK_EXT = HOME / f".var/app/{FLATPAK}/data/vscode/extensions"
NATIVE_BIN = pathlib.Path("/usr/bin/code")
NATIVE_EXT = HOME / ".vscode/extensions"

solid = not t.get("blur", True)   # hearth & Co.: deckend, mittelbraun statt Fast-Schwarz
raised = t.get("surfaceRaised", t["surface"])
if solid:
    # Ebenen wie in der Shell: Rahmen (Titel, Activity Bar, Statusleiste) = raised, Seitenleiste = surface,
    # Editor + Panel = bg. Editor-Farben aus editorSyntax werden auf den helleren Grund angehoben (Kontrast).
    frame = raised
    side = t["surface"]
    bg_edit = t["bg"]
    panel_bg = t["bg"]
    widget = raised            # Menüs, Suche, Vorschläge, Quick Open
    field = t.get("surfaceSunken", t["bg"])   # Eingabefelder
    soft = t.get("accentFill", hex8(t["accentSoft"]))   # Auswahl: deckender Terrakotta-Ton
else:
    bg_edit = ed["background"]
    side = ed["sidebar"]
    frame = t["bgBottom"]      # Activity Bar, Titel, Statusleiste
    panel_bg = ansi["background"]
    widget = t["surface"]
    field = t["bg"]
    soft = hex8(t["accentSoft"])


def lift(c: str, minc: float) -> str:
    """Farbe Richtung Text-Creme schieben, bis sie auf dem Editor-Grund mindestens Kontrast minc hat."""
    if not solid:
        return c
    for i in range(21):
        v = mix(c, t["text"], i / 20)
        if contrast(v, bg_edit) >= minc:
            return v
    return t["text"]


if solid:
    ed = {**ed, "text": lift(ed["text"], 9), "keyword": lift(ed["keyword"], 6), "type": lift(ed["type"], 7),
          "string": lift(ed["string"], 6), "number": lift(ed["number"], 6), "comment": lift(ed["comment"], 4.5),
          "punctuation": lift(ed["punctuation"], 5), "lineNumber": lift(ed["lineNumber"], 3.2),
          "error": lift(ed["error"], 4.5)}
    ansi = {**ansi, **{k: lift(ansi[k], 4.5) for k in ansi
                       if k.startswith("bright") or k in ("red", "green", "yellow", "blue", "magenta", "cyan", "white")},
            "black": lift(ansi["black"], 1.8), "brightBlack": lift(ansi["brightBlack"], 3.2), "background": panel_bg,
            "foreground": t["text"], "cursor": t["accent"],
            "selectionBackground": t["accentSoft"]}
border = hex8(t["border"])
hover = alpha(t["text"], 0.05)
fn = t["text"]                 # Funktionen: Creme, heller als Grundtext
err = ed["error"]              # Fehler: Ziegel statt Karmin (kein Pink, heller/oranger als der Akzent)
calm = t["woodLight"]          # Fokus-/Eingabe-Rahmen: Holz statt Akzentrot (Claude-Panel, Suche, Listen)

colors = {
    # Allgemein
    "foreground": t["textMuted"],
    "descriptionForeground": t["textFaint"],
    "disabledForeground": alpha(t["textFaint"], 0.6),
    "errorForeground": err,
    "focusBorder": alpha(calm, 0.6),
    "contrastBorder": "#00000000",
    "selection.background": alpha(t["accent"], 0.4),
    "widget.shadow": "#00000073",
    "widget.border": border,
    "icon.foreground": t["textMuted"],
    "textLink.foreground": t["accentText"],
    "textLink.activeForeground": t["accent"],
    "textPreformat.foreground": ed["string"],
    "textBlockQuote.background": t["surface"],
    "textBlockQuote.border": t["wood"],
    "textCodeBlock.background": t["surface"],
    "textSeparator.foreground": border,
    "sash.hoverBorder": alpha(calm, 0.6),
    "progressBar.background": t["accent"],
    "badge.background": t["wood"],
    "badge.foreground": t["text"],
    "scrollbar.shadow": "#00000000",
    "scrollbarSlider.background": alpha(t["text"], 0.08),
    "scrollbarSlider.hoverBackground": alpha(t["text"], 0.14),
    "scrollbarSlider.activeBackground": alpha(t["text"], 0.2),
    # Titel + Menü
    "titleBar.activeBackground": frame,
    "titleBar.activeForeground": t["textMuted"],
    "titleBar.inactiveBackground": frame,
    "titleBar.inactiveForeground": t["textFaint"],
    "titleBar.border": border,
    "menubar.selectionBackground": hover,
    "menu.background": widget,
    "menu.foreground": t["text"],
    "menu.selectionBackground": soft,
    "menu.selectionForeground": t["text"],
    "menu.separatorBackground": border,
    "menu.border": border,
    "commandCenter.background": widget,
    "commandCenter.foreground": t["textMuted"],
    "commandCenter.border": border,
    "commandCenter.activeBackground": hover,
    # Activity Bar
    "activityBar.background": frame,
    "activityBar.foreground": t["text"],
    "activityBar.inactiveForeground": t["textFaint"],
    "activityBar.border": border,
    "activityBar.activeBorder": t["accent"],
    "activityBar.activeBackground": "#00000000",
    "activityBarBadge.background": t["accent"],
    "activityBarBadge.foreground": t.get("onAccent", t["text"]) if solid else t["text"],
    # Sidebar
    "sideBar.background": side,
    "sideBar.foreground": t["textMuted"],
    "sideBar.border": border,
    "sideBarTitle.foreground": t["textFaint"],
    "sideBarSectionHeader.background": side,
    "sideBarSectionHeader.foreground": t["textFaint"],
    "sideBarSectionHeader.border": border,
    # Listen
    "list.activeSelectionBackground": soft,
    "list.activeSelectionForeground": t["text"],
    "list.activeSelectionIconForeground": t["accentText"],
    "list.inactiveSelectionBackground": alpha(t["text"], 0.06),
    "list.inactiveSelectionForeground": t["text"],
    "list.hoverBackground": hover,
    "list.hoverForeground": t["text"],
    "list.focusOutline": alpha(calm, 0.6),
    "list.focusBackground": soft,
    "list.highlightForeground": t["accentText"],
    "list.errorForeground": err,
    "list.warningForeground": t["warning"],
    "list.dropBackground": soft,
    "tree.indentGuidesStroke": alpha(t["text"], 0.12),
    # Tabs
    "editorGroupHeader.tabsBackground": side,
    "editorGroupHeader.tabsBorder": border,
    "editorGroupHeader.noTabsBackground": bg_edit,
    "editorGroup.border": border,
    "editorGroup.dropBackground": soft,
    "tab.activeBackground": bg_edit,
    "tab.activeForeground": t["text"],
    "tab.activeBorderTop": t["accent"],
    "tab.activeBorder": bg_edit,
    "tab.inactiveBackground": side,
    "tab.inactiveForeground": t["textFaint"],
    "tab.hoverBackground": hover,
    "tab.hoverForeground": t["textMuted"],
    "tab.border": side,
    "tab.unfocusedActiveForeground": t["textMuted"],
    "tab.unfocusedActiveBorderTop": t["wood"],
    "tab.unfocusedInactiveForeground": t["textFaint"],
    "tab.activeModifiedBorder": t["warning"],
    "tab.inactiveModifiedBorder": alpha(t["warning"], 0.5),
    "breadcrumb.background": bg_edit,
    "breadcrumb.foreground": t["textFaint"],
    "breadcrumb.focusForeground": t["text"],
    "breadcrumb.activeSelectionForeground": t["text"],
    "breadcrumbPicker.background": widget,
    # Editor
    "editor.background": bg_edit,
    "editor.foreground": ed["text"],
    "editorLineNumber.foreground": ed["lineNumber"],
    "editorLineNumber.activeForeground": t["textMuted"],
    "editorCursor.foreground": t["accent"],
    "editor.lineHighlightBackground": hex8(ed["activeLine"]),
    "editor.lineHighlightBorder": "#00000000",
    "editor.selectionBackground": alpha(t["accent"], 0.28),
    "editor.inactiveSelectionBackground": alpha(t["accent"], 0.14),
    "editor.selectionHighlightBackground": alpha(t["text"], 0.08),
    "editor.wordHighlightBackground": alpha(t["text"], 0.08),
    "editor.wordHighlightStrongBackground": alpha(t["text"], 0.12),
    "editor.findMatchBackground": alpha(t["warning"], 0.35),
    "editor.findMatchHighlightBackground": alpha(t["warning"], 0.16),
    "editor.findMatchBorder": t["warning"],
    "editor.rangeHighlightBackground": alpha(t["text"], 0.04),
    "editor.foldBackground": alpha(t["wood"], 0.25),
    "editorIndentGuide.background1": alpha(t["text"], 0.06),
    "editorIndentGuide.activeBackground1": alpha(t["text"], 0.18),
    "editorWhitespace.foreground": alpha(t["text"], 0.12),
    "editorRuler.foreground": alpha(t["text"], 0.06),
    "editorBracketMatch.background": alpha(t["accent"], 0.12),
    "editorBracketMatch.border": alpha(t["accent"], 0.5),
    "editorBracketHighlight.foreground1": ed["punctuation"],
    "editorBracketHighlight.foreground2": ed["keyword"],
    "editorBracketHighlight.foreground3": ed["type"],
    "editorBracketHighlight.foreground4": ansi["cyan"],
    "editorBracketHighlight.foreground5": ansi["magenta"],
    "editorBracketHighlight.foreground6": ansi["blue"],
    "editorBracketHighlight.unexpectedBracket.foreground": err,
    "editorCodeLens.foreground": ed["comment"],
    "editorInlayHint.background": alpha(t["text"], 0.05),
    "editorInlayHint.foreground": ed["comment"],
    "editorLink.activeForeground": t["accentText"],
    "editorError.foreground": err,
    "editorWarning.foreground": t["warning"],
    "editorInfo.foreground": ansi["blue"],
    "editorHint.foreground": t["success"],
    "editorGutter.background": bg_edit,
    "editorGutter.addedBackground": t["success"],
    "editorGutter.modifiedBackground": t["warning"],
    "editorGutter.deletedBackground": err,
    "editorOverviewRuler.border": "#00000000",
    "editorOverviewRuler.addedForeground": alpha(t["success"], 0.6),
    "editorOverviewRuler.modifiedForeground": alpha(t["warning"], 0.6),
    "editorOverviewRuler.deletedForeground": alpha(err, 0.6),
    "editorOverviewRuler.errorForeground": err,
    "editorOverviewRuler.warningForeground": t["warning"],
    "editorOverviewRuler.findMatchForeground": alpha(t["warning"], 0.6),
    "minimap.background": bg_edit,
    "minimap.selectionHighlight": alpha(t["accent"], 0.4),
    "minimap.findMatchHighlight": alpha(t["warning"], 0.6),
    "minimapGutter.addedBackground": t["success"],
    "minimapGutter.modifiedBackground": t["warning"],
    "minimapGutter.deletedBackground": err,
    "editorStickyScroll.background": bg_edit,
    "editorStickyScroll.shadow": "#00000059",
    # Widgets (Suche, Vorschläge, Hover, Quick Open)
    "editorWidget.background": widget,
    "editorWidget.foreground": t["text"],
    "editorWidget.border": border,
    "editorSuggestWidget.background": widget,
    "editorSuggestWidget.border": border,
    "editorSuggestWidget.foreground": ed["text"],
    "editorSuggestWidget.selectedBackground": soft,
    "editorSuggestWidget.selectedForeground": t["text"],
    "editorSuggestWidget.highlightForeground": t["accentText"],
    "editorSuggestWidget.focusHighlightForeground": t["accentText"],
    "editorHoverWidget.background": widget,
    "editorHoverWidget.border": border,
    "quickInput.background": widget,
    "quickInput.foreground": t["text"],
    "quickInputList.focusBackground": soft,
    "quickInputList.focusForeground": t["text"],
    "quickInputTitle.background": widget,
    "pickerGroup.foreground": t["textFaint"],
    "pickerGroup.border": border,
    "notifications.background": widget,
    "notifications.foreground": t["text"],
    "notifications.border": border,
    "notificationCenterHeader.background": widget,
    "notificationToast.border": border,
    "notificationsErrorIcon.foreground": err,
    "notificationsWarningIcon.foreground": t["warning"],
    "notificationsInfoIcon.foreground": ansi["blue"],
    "peekView.border": t["wood"],
    "peekViewEditor.background": side,
    "peekViewEditor.matchHighlightBackground": alpha(t["warning"], 0.25),
    "peekViewResult.background": widget,
    "peekViewResult.selectionBackground": soft,
    "peekViewResult.matchHighlightBackground": alpha(t["warning"], 0.25),
    "peekViewTitle.background": widget,
    "peekViewTitleLabel.foreground": t["text"],
    "peekViewTitleDescription.foreground": t["textFaint"],
    # Eingaben + Knöpfe ("pri" wie in der Shell: Glut-Text auf accentSoft)
    "input.background": field,
    "input.foreground": t["text"],
    "input.border": border,
    "input.placeholderForeground": t["textFaint"],
    "inputOption.activeBorder": calm,
    "inputOption.activeBackground": soft,
    "inputOption.activeForeground": t["text"],
    "inputValidation.errorBackground": t["surface"],
    "inputValidation.errorBorder": err,
    "inputValidation.warningBackground": t["surface"],
    "inputValidation.warningBorder": t["warning"],
    "inputValidation.infoBackground": t["surface"],
    "inputValidation.infoBorder": ansi["blue"],
    "dropdown.background": widget,
    "dropdown.foreground": t["text"],
    "dropdown.border": border,
    "dropdown.listBackground": widget,
    "button.background": t["accent"] if solid else soft,
    "button.foreground": t.get("onAccent", t["text"]) if solid else t["accentText"],
    "button.hoverBackground": t.get("accentHover", t["accent"]) if solid else alpha(t["accent"], 0.26),
    "button.border": "#00000000" if solid else alpha(t["accent"], 0.3),
    "button.secondaryBackground": alpha(t["text"], 0.08),
    "button.secondaryForeground": t["text"],
    "button.secondaryHoverBackground": alpha(t["text"], 0.12),
    "checkbox.background": field,
    "checkbox.border": border,
    "checkbox.foreground": t["text"],
    "keybindingLabel.background": alpha(t["text"], 0.06),
    "keybindingLabel.foreground": t["textMuted"],
    "keybindingLabel.border": hex8(t["borderStrong"]),
    "keybindingLabel.bottomBorder": hex8(t["borderStrong"]),
    "settings.headerForeground": t["text"],
    "settings.modifiedItemIndicator": t["accent"],
    # Panel + Terminal (= Konsole-Farben)
    "panel.background": panel_bg,
    "panel.border": border,
    "panelTitle.activeForeground": t["text"],
    "panelTitle.inactiveForeground": t["textFaint"],
    "panelTitle.activeBorder": t["accent"],
    "panelSectionHeader.background": panel_bg,
    "terminal.background": panel_bg,
    "terminal.foreground": ansi["foreground"],
    "terminalCursor.foreground": ansi["cursor"],
    "terminalCursor.background": panel_bg,
    "terminal.selectionBackground": hex8(ansi["selectionBackground"]),
    "terminal.border": border,
    "terminal.tab.activeBorder": t["accent"],
    # Statusleiste
    "statusBar.background": frame,
    "statusBar.foreground": t["textFaint"],
    "statusBar.border": border,
    "statusBar.focusBorder": alpha(calm, 0.6),
    "statusBar.noFolderBackground": frame,
    "statusBar.noFolderForeground": t["textFaint"],
    "statusBar.debuggingBackground": t["wood"],
    "statusBar.debuggingForeground": t["text"],
    "statusBarItem.hoverBackground": hover,
    "statusBarItem.activeBackground": alpha(t["text"], 0.08),
    "statusBarItem.remoteBackground": soft,
    "statusBarItem.remoteForeground": t["accentText"],
    "statusBarItem.prominentBackground": alpha(t["text"], 0.08),
    "statusBarItem.errorBackground": frame,
    "statusBarItem.errorForeground": err,
    "statusBarItem.warningBackground": frame,
    "statusBarItem.warningForeground": t["warning"],
    # Git + Diff
    "gitDecoration.modifiedResourceForeground": t["warning"],
    "gitDecoration.untrackedResourceForeground": t["success"],
    "gitDecoration.addedResourceForeground": t["success"],
    "gitDecoration.deletedResourceForeground": err,
    "gitDecoration.renamedResourceForeground": ansi["cyan"],
    "gitDecoration.ignoredResourceForeground": ed["comment"],
    "gitDecoration.conflictingResourceForeground": ansi["magenta"],
    "gitDecoration.stageModifiedResourceForeground": t["warning"],
    "gitDecoration.stageDeletedResourceForeground": err,
    "gitDecoration.submoduleResourceForeground": ansi["blue"],
    "diffEditor.insertedTextBackground": alpha(t["success"], 0.14),
    "diffEditor.removedTextBackground": alpha(err, 0.14),
    "diffEditor.insertedLineBackground": alpha(t["success"], 0.07),
    "diffEditor.removedLineBackground": alpha(err, 0.07),
    "diffEditor.diagonalFill": alpha(t["text"], 0.06),
    "merge.currentHeaderBackground": alpha(t["success"], 0.3),
    "merge.incomingHeaderBackground": alpha(ansi["blue"], 0.3),
    # Sonstiges
    "welcomePage.tileBackground": t["surface"],
    "walkThrough.embeddedEditorBackground": side,
    "debugToolBar.background": widget,
    "extensionButton.prominentBackground": t["accent"] if solid else soft,
    "extensionButton.prominentForeground": t.get("onAccent", t["text"]) if solid else t["accentText"],
    "extensionButton.prominentHoverBackground": t.get("accentHover", t["accent"]) if solid else alpha(t["accent"], 0.26),
    "charts.foreground": t["textMuted"],
    "charts.red": err,
    "charts.orange": t["accentText"],
    "charts.yellow": t["warning"],
    "charts.green": t["success"],
    "charts.blue": ansi["blue"],
    "charts.purple": ansi["magenta"],
}
for i, n in enumerate(["black", "red", "green", "yellow", "blue", "magenta", "cyan", "white"]):
    colors[f"terminal.ansi{n.capitalize()}"] = ansi[n]
    colors[f"terminal.ansiBright{n.capitalize()}"] = ansi["bright" + n.capitalize()]


def rule(name, scope, fg=None, style=None):
    s = {}
    if fg:
        s["foreground"] = fg
    if style is not None:
        s["fontStyle"] = style
    return {"name": name, "scope": scope, "settings": s}


token_colors = [
    rule("Kommentar", ["comment", "punctuation.definition.comment", "string.comment"], ed["comment"], "italic"),
    rule("Schlüsselwort", ["keyword", "storage", "storage.type", "storage.modifier", "keyword.control",
                           "keyword.operator.new", "keyword.operator.expression", "keyword.operator.logical.python",
                           "variable.language.this", "variable.language.self", "variable.language.super"], ed["keyword"]),
    rule("Operator", ["keyword.operator", "punctuation.accessor", "punctuation.separator.key-value"], ed["punctuation"]),
    rule("Satzzeichen", ["punctuation", "meta.brace", "meta.delimiter"], ed["punctuation"]),
    rule("Text", ["source", "variable", "meta.definition.variable", "variable.other.readwrite",
                  "support.variable.property", "variable.other.property", "meta.object-literal.key"], ed["text"]),
    rule("Funktion", ["entity.name.function", "support.function", "meta.function-call entity.name.function",
                      "variable.function", "meta.method-call", "entity.name.method"], fn),
    rule("Typ", ["entity.name.type", "entity.name.class", "entity.name.namespace", "entity.other.inherited-class",
                 "support.type", "support.class", "storage.type.primitive", "entity.name.type.module",
                 "meta.type.annotation entity.name.type"], ed["type"]),
    rule("String", ["string", "string.quoted", "string.template", "punctuation.definition.string",
                    "markup.inline.raw", "markup.fenced_code"], ed["string"]),
    rule("Zahl + Konstante", ["constant.numeric", "constant.language", "constant.character", "constant.other",
                              "support.constant", "variable.other.constant", "variable.other.enummember",
                              "constant.character.escape", "keyword.other.unit"], ed["number"]),
    rule("Regex", ["string.regexp"], ansi["cyan"]),
    rule("Interpolation", ["punctuation.definition.template-expression", "punctuation.section.embedded"], ed["keyword"]),
    rule("Parameter", ["variable.parameter", "meta.parameter"], ed["text"], "italic"),
    rule("Dekorator", ["meta.decorator", "entity.name.function.decorator", "punctuation.decorator",
                       "storage.type.annotation"], ed["type"], "italic"),
    rule("Tag", ["entity.name.tag", "punctuation.definition.tag"], ed["keyword"]),
    rule("Tag-Komponente", ["support.class.component", "entity.name.tag.component"], ed["type"]),
    rule("Attribut", ["entity.other.attribute-name"], ed["type"], "italic"),
    rule("CSS-Eigenschaft", ["support.type.property-name", "meta.property-name"], ed["text"]),
    rule("CSS-Wert", ["support.constant.property-value", "meta.property-value"], ed["string"]),
    rule("JSON-Schlüssel", ["support.type.property-name.json", "meta.mapping.key string"], ed["keyword"]),
    rule("Markdown Überschrift", ["markup.heading", "entity.name.section"], ed["keyword"], "bold"),
    rule("Markdown fett", ["markup.bold"], ed["type"], "bold"),
    rule("Markdown kursiv", ["markup.italic"], ed["text"], "italic"),
    rule("Markdown Link", ["markup.underline.link", "string.other.link"], t["accentText"]),
    rule("Markdown Zitat", ["markup.quote"], ed["comment"], "italic"),
    rule("Markdown Liste", ["punctuation.definition.list", "beginning.punctuation.definition.list"], ed["keyword"]),
    rule("Diff +", ["markup.inserted"], t["success"]),
    rule("Diff -", ["markup.deleted"], err),
    rule("Diff ~", ["markup.changed"], t["warning"]),
    rule("Ungültig", ["invalid", "invalid.illegal"], err),
    rule("Veraltet", ["invalid.deprecated"], ed["comment"], "strikethrough"),
]

semantic = {
    "keyword": ed["keyword"],
    "type": ed["type"],
    "class": ed["type"],
    "interface": ed["type"],
    "enum": ed["type"],
    "struct": ed["type"],
    "typeParameter": ed["type"],
    "namespace": ed["type"],
    "function": fn,
    "method": fn,
    "macro": ed["number"],
    "parameter": {"foreground": ed["text"], "italic": True},
    "variable": ed["text"],
    "property": ed["text"],
    "enumMember": ed["number"],
    "variable.readonly.defaultLibrary": ed["number"],
    "string": ed["string"],
    "number": ed["number"],
    "regexp": ansi["cyan"],
    "comment": {"foreground": ed["comment"], "italic": True},
    "decorator": {"foreground": ed["type"], "italic": True},
    "*.deprecated": {"strikethrough": True},
}

theme = {
    "$schema": "vscode://schemas/color-theme",
    "name": "Desktop",
    "type": "dark",
    "semanticHighlighting": True,
    "colors": colors,
    "tokenColors": token_colors,
    "semanticTokenColors": semantic,
}

package = {
    "name": NAME,
    "displayName": "Desktop",
    "description": f"Warmes Braun, Creme und Terrakotta-Akzent. {MARK} ({variant}).",
    "version": VERSION,
    "publisher": PUBLISHER,
    "license": "UNLICENSED",
    "engines": {"vscode": "^1.70.0"},
    "categories": ["Themes"],
    "contributes": {
        "themes": [
            {"label": "Desktop", "uiTheme": "vs-dark", "path": "./themes/desktop-color-theme.json"}
        ]
    },
}

# Zweite Erweiterung: Projektpunkt in der Statusleiste (liest theme/projects.json live, siehe vscode_projects.py)
PROJ_NAME = "desktop-projects"
PROJ_VERSION = "0.2.0"  # eigene Version: Wrapper-Erkennung (0.1.1), Dev-Terminal aus Marken (0.2.0)
proj_package = {
    "name": PROJ_NAME,
    "displayName": "Desktop Projekte",
    "description": f"Projektfarbe als Punkt + Name links in der Statusleiste, Dev-Terminal beim Projekt-Öffnen. {MARK}.",
    "version": PROJ_VERSION,
    "publisher": PUBLISHER,
    "license": "UNLICENSED",
    "engines": {"vscode": "^1.70.0"},
    "categories": ["Other"],
    "main": "./extension.js",
    "activationEvents": ["onStartupFinished"],
    "capabilities": {"untrustedWorkspaces": {"supported": True}, "virtualWorkspaces": False},
}
def _root_js() -> str:
    """Repo-Pfad für die Erweiterung: DESKTOP aus ~/.config/desktop/hyprland.env (eine Stelle, scripts/hypr install),
    sonst ~/Workspace/bastian-shell. Kein fester Checkout-Pfad in der Datei (gleiche Ausgabe in jedem Checkout)."""
    return """(() => {
  try {
    const m = /^DESKTOP=(.+)$/m.exec(fs.readFileSync(path.join(os.homedir(), ".config/desktop/hyprland.env"), "utf8"));
    if (m) return m[1].trim();
  } catch (e) {}
  return path.join(os.homedir(), "Workspace/bastian-shell");
})()"""


proj_js = """// %(mark)s – theme/gen/vscode.py. Farben: palette.json -> projectAccents, Zuordnung: theme/projects.json
"use strict";
const vscode = require("vscode");
const fs = require("fs");
const os = require("os");
const path = require("path");
const ROOT = %(root)s;
const PROJECTS = path.join(ROOT, "theme/projects.json");
const PALETTE = path.join(ROOT, "theme/palette.json");
const abs = (p) => (p.startsWith("~/") ? path.join(os.homedir(), p.slice(2)) : p);

// Kandidaten: Arbeitsbereich-Datei (z. B. ~/Workspace/x.code-workspace), dann erster Ordner –
// so wird auch ein Wrapper (~/.config/desktop/workspaces/<name>.code-workspace, scripts/vscode-colors)
// über seinen Repo-Ordner erkannt.
function candidates() {
  const out = [];
  const ws = vscode.workspace.workspaceFile;
  if (ws && ws.scheme === "file") out.push(ws.fsPath);
  const f = vscode.workspace.workspaceFolders;
  if (f && f.length && f[0].uri.scheme === "file") out.push(f[0].uri.fsPath);
  return out;
}

function lookup(p) {
  try {
    const list = JSON.parse(fs.readFileSync(PROJECTS, "utf8")).projects || [];
    const accents = JSON.parse(fs.readFileSync(PALETTE, "utf8")).projectAccents || {};
    let hit = null;
    for (const e of list) {
      const a = abs(e.path);
      if ((p === a || p.startsWith(a + path.sep)) && (!hit || a.length > abs(hit.path).length)) hit = e;
    }
    // Farbname aus projectAccents oder eigene Farbe als #RRGGBB
    return hit ? { name: hit.name, color: hit.color, hex: /^#[0-9a-f]{6}$/i.test(hit.color) ? hit.color : accents[hit.color] } : null;
  } catch (e) {
    return null;
  }
}

function activate(ctx) {
  const item = vscode.window.createStatusBarItem("desktop.project", vscode.StatusBarAlignment.Left, 100000);
  item.name = "Desktop: Projekt";
  ctx.subscriptions.push(item);
  const update = () => {
    const ps = candidates();
    if (!ps.length) return item.hide();
    let e = null;
    for (const p of ps) if ((e = lookup(p))) break;
    item.text = "$(circle-large-filled) " + (e ? e.name : path.basename(ps[0]).replace(/\\.code-workspace$/, ""));
    item.color = e && e.hex ? e.hex : undefined;
    item.tooltip = e ? "Projektfarbe: " + e.color + " (scripts/vscode-colors)" : "Noch keine Projektfarbe: scripts/vscode-colors apply";
    item.show();
  };
  update();
  ctx.subscriptions.push(vscode.workspace.onDidChangeWorkspaceFolders(update));
  for (const dir of [path.dirname(PROJECTS)]) {
    try {
      const w = fs.watch(dir, (_ev, f) => { if (!f || f === "projects.json" || f === "palette.json") update(); });
      ctx.subscriptions.push({ dispose: () => w.close() });
    } catch (e) { /* ohne Watch: beim nächsten Fenster */ }
  }
  openTerminals(ctx);
}

// Dev-Terminal beim Projekt-Öffnen (shell/services/Templates.qml -> openProject): Einmal-Marke
// ~/.cache/desktop/open-terminal/<id>.json = { dir, target, command|null, name: "dev"|"shell", created }.
// Das Fenster, dessen Ordner (oder Arbeitsbereich-Datei) passt, öffnet unten im Panel ein Terminal in dir,
// schickt command und löscht die Marke. Marken älter als 2 min zählen nicht mehr (nach 10 min weg).
const MARKS = path.join(os.homedir(), ".cache/desktop/open-terminal");
const MAX_AGE = 2 * 60 * 1000;
const DROP_AGE = 10 * 60 * 1000;

function norm(p) {
  if (!p) return null;
  const a = path.resolve(abs(String(p)));
  try { return fs.realpathSync(a); } catch (e) { return a; }
}

// Eigene Pfade: alle Ordner + Arbeitsbereich-Datei (Wrapper ~/.config/desktop/workspaces/<name>.code-workspace
// hat das Repo als Ordner, *.code-workspace mit mehreren Repos hat dir als einen davon)
function ownPaths() {
  const out = new Set();
  const ws = vscode.workspace.workspaceFile;
  if (ws && ws.scheme === "file") out.add(norm(ws.fsPath));
  for (const f of vscode.workspace.workspaceFolders || []) if (f.uri.scheme === "file") out.add(norm(f.uri.fsPath));
  return out;
}

function matches(m, own) {
  return !!m && typeof m.dir === "string" && (own.has(norm(m.dir)) || (!!m.target && own.has(norm(m.target))));
}

function cwdOf(t) {
  const c = t.creationOptions && t.creationOptions.cwd;
  return c ? norm(typeof c === "string" ? c : c.fsPath) : null;
}

function startTerminal(m) {
  const name = m.name === "shell" ? "shell" : "dev";
  const dir = norm(m.dir);
  // Läuft das Terminal hier schon (Projekt erneut geöffnet): nur zeigen, nicht den Dev-Server doppelt starten
  const old = vscode.window.terminals.find((t) => t.name === name && t.exitStatus === undefined && (cwdOf(t) === null || cwdOf(t) === dir));
  if (old) return old.show(true);
  const opts = { name, cwd: dir };
  if (vscode.TerminalLocation) opts.location = vscode.TerminalLocation.Panel;
  if (vscode.ThemeIcon) opts.iconPath = new vscode.ThemeIcon(m.command ? "server-process" : "terminal");
  const t = vscode.window.createTerminal(opts);
  if (typeof m.command === "string" && m.command) t.sendText(m.command, true);
  t.show(true);
}

// Marke nehmen: erst lesen + prüfen, dann atomar umbenennen (nur ein Fenster gewinnt), dann löschen
function claim(file, own, now) {
  let st, m;
  try { st = fs.statSync(file); } catch (e) { return null; }
  try { m = JSON.parse(fs.readFileSync(file, "utf8")); } catch (e) { m = null; }
  const age = now - (m && typeof m.created === "number" ? m.created : st.mtimeMs);
  if (!m || age > DROP_AGE) {
    if (now - st.mtimeMs > DROP_AGE) try { fs.unlinkSync(file); } catch (e) { /* schon weg */ }
    return null;
  }
  if (!matches(m, own)) return null;
  const taken = file + ".taken-" + process.pid;
  try { fs.renameSync(file, taken); } catch (e) { return null; }
  try { fs.unlinkSync(taken); } catch (e) { /* egal */ }
  return age <= MAX_AGE && age >= -MAX_AGE ? m : null;
}

function checkMarks() {
  const own = ownPaths();
  if (!own.size) return;
  let names;
  try { names = fs.readdirSync(MARKS); } catch (e) { return; }
  const now = Date.now();
  for (const n of names) {
    if (n.startsWith(".") || !n.endsWith(".json")) continue;
    const m = claim(path.join(MARKS, n), own, now);
    if (m) {
      try { startTerminal(m); } catch (e) { console.error("desktop-projects: Terminal", e); }
    }
  }
}

function openTerminals(ctx) {
  let timer = null;
  const soon = () => { clearTimeout(timer); timer = setTimeout(checkMarks, 150); };
  ctx.subscriptions.push({ dispose: () => clearTimeout(timer) });
  try { fs.mkdirSync(MARKS, { recursive: true, mode: 0o700 }); } catch (e) { /* ohne Ordner: kein Watch */ }
  try {
    const w = fs.watch(MARKS, (_ev, f) => { if (!f || (f.endsWith(".json") && !f.startsWith("."))) soon(); });
    ctx.subscriptions.push({ dispose: () => w.close() });
  } catch (e) { /* ohne Watch: beim Fokus */ }
  ctx.subscriptions.push(vscode.window.onDidChangeWindowState((s) => { if (s.focused) soon(); }));
  ctx.subscriptions.push(vscode.workspace.onDidChangeWorkspaceFolders(soon));
  checkMarks();
}

exports.activate = activate;
exports.deactivate = () => {};
exports._test = { checkMarks, startTerminal, matches, ownPaths, MARKS };
""" % {"mark": MARK, "root": _root_js()}

print(f"VS Code ({variant}):")
out = OUT / "vscode-desktop"
write(out / "package.json", json.dumps(package, indent=2, ensure_ascii=False) + "\n")
write(out / "themes/desktop-color-theme.json", json.dumps(theme, indent=2, ensure_ascii=False) + "\n")
proj_out = OUT / "vscode-desktop-projects"
write(proj_out / "package.json", json.dumps(proj_package, indent=2, ensure_ascii=False) + "\n")
write(proj_out / "extension.js", proj_js)

if not install_wanted():
    sys.exit(0)

TYPES = """<?xml version="1.0" encoding="utf-8"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension=".json" ContentType="application/json"/>
  <Default Extension=".js" ContentType="application/javascript"/>
  <Default Extension=".vsixmanifest" ContentType="text/xml"/>
</Types>
"""


def manifest(pkg: dict) -> str:
    return f"""<?xml version="1.0" encoding="utf-8"?>
<PackageManifest Version="2.0.0" xmlns="http://schemas.microsoft.com/developer/vsx-schema/2011">
  <Metadata>
    <Identity Language="en-US" Id="{pkg["name"]}" Version="{pkg["version"]}" Publisher="{pkg["publisher"]}"/>
    <DisplayName>{pkg["displayName"]}</DisplayName>
    <Description xml:space="preserve">{pkg["description"]}</Description>
    <Categories>{",".join(pkg["categories"])}</Categories>
    <Properties><Property Id="Microsoft.VisualStudio.Code.Engine" Value="{pkg["engines"]["vscode"]}"/></Properties>
  </Metadata>
  <Installation><InstallationTarget Id="Microsoft.VisualStudio.Code"/></Installation>
  <Dependencies/>
  <Assets><Asset Type="Microsoft.VisualStudio.Code.Manifest" Path="extension/package.json" Addressable="true"/></Assets>
</PackageManifest>
"""


def build_vsix(where: pathlib.Path, src: pathlib.Path, pkg: dict) -> pathlib.Path:
    folder = f"{pkg['publisher']}.{pkg['name']}-{pkg['version']}"
    with zipfile.ZipFile(vsix := where / f"{folder}.vsix", "w", zipfile.ZIP_DEFLATED) as z:
        z.writestr("[Content_Types].xml", TYPES)
        z.writestr("extension.vsixmanifest", manifest(pkg))
        for f in sorted(src.rglob("*")):
            if f.is_file():
                z.write(f, "extension/" + f.relative_to(src).as_posix())
    return vsix


def register(ext_dir: pathlib.Path, pkg: dict) -> None:
    """Rückfall ohne CLI: Eintrag in extensions.json (ab VS Code 1.7x maßgeblich, sonst unsichtbar)."""
    manifest_file = ext_dir / "extensions.json"
    if not manifest_file.exists():
        return  # ohne Liste liest VS Code den Ordner beim Start selbst ein
    ident = f"{pkg['publisher']}.{pkg['name']}"
    folder = f"{ident}-{pkg['version']}"
    entries = json.loads(manifest_file.read_text() or "[]")
    entries = [e for e in entries if e.get("identifier", {}).get("id") != ident]
    entries.append({
        "identifier": {"id": ident},
        "version": pkg["version"],
        "location": {"$mid": 1, "path": str(ext_dir / folder), "scheme": "file"},
        "relativeLocation": folder,
        "metadata": {"installedTimestamp": 0, "source": "vsix"},
    })
    manifest_file.write_text(json.dumps(entries, separators=(",", ":")))


def install_into(label: str, ext_dir: pathlib.Path, cli: list | None, cache: pathlib.Path | None,
                 src: pathlib.Path, pkg: dict) -> None:
    target = ext_dir / f"{pkg['publisher']}.{pkg['name']}-{pkg['version']}"
    print(f"  {label} · {pkg['displayName']}:")
    if target.exists() and MARK not in (target / "package.json").read_text(errors="ignore"):
        print(f"  Übersprungen: {target} existiert und stammt nicht von hier.")
        return
    # VSIX bauen (Flatpak: im eigenen Cache, dort sieht die Sandbox die Datei), per CLI installieren
    if cli and cache:
        cache.mkdir(parents=True, exist_ok=True)
        tmp = pathlib.Path(tempfile.mkdtemp(prefix="desktop-vsix-", dir=cache))
        try:
            r = subprocess.run(cli + ["--install-extension", str(build_vsix(tmp, src, pkg)), "--force"],
                               capture_output=True, text=True, timeout=120)
            print("  " + (r.stdout.strip() or r.stderr.strip()).replace("\n", "\n  "))
            ok = r.returncode == 0
        finally:
            shutil.rmtree(tmp)
        if ok and target.is_dir():
            print(f"  -> {target}")
            return
        print("  CLI-Installation fehlgeschlagen, kopiere Ordner direkt.")
    # Rückfall: Ordner kopieren (VS Code nimmt ihn beim nächsten Start auf)
    install(src, target)
    register(ext_dir, pkg)


done = 0
for src_dir, pkg in ((out, package), (proj_out, proj_package)):
    # Natives VS Code: wenn installiert oder sein Extensions-Ordner schon da ist (z. B. vom Flatpak übernommen)
    if NATIVE_BIN.exists() or NATIVE_EXT.is_dir():
        install_into("nativ", NATIVE_EXT, [str(NATIVE_BIN)] if NATIVE_BIN.exists() else None,
                     pathlib.Path(tempfile.gettempdir()), src_dir, pkg)
        done += 1
    # Flatpak nur, wenn es wirklich installiert ist (nach dem Umzug aufs RPM bleibt ~/.var/app/… liegen)
    if FLATPAK_EXT.is_dir() and shutil.which("flatpak") and subprocess.run(
            ["flatpak", "info", FLATPAK], capture_output=True).returncode == 0:
        cache = HOME / f".var/app/{FLATPAK}/cache"
        install_into("Flatpak", FLATPAK_EXT, ["flatpak", "run", FLATPAK] if shutil.which("flatpak") else None,
                     cache if cache.is_dir() else None, src_dir, pkg)
        done += 1
if not done:
    sys.exit("Abbruch: weder natives VS Code (~/.vscode/extensions) noch das Flatpak eingerichtet.")
# Projekt-Tönungen an die (evtl. neue) Variante anpassen – nur wo sie schon an sind
subprocess.run([sys.executable, "-I", str(pathlib.Path(__file__).resolve().parent / "vscode_projects.py"), "refresh"])

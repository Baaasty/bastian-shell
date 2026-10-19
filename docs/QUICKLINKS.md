# Quicklinks an den Workspaces (Idee n)

Jeder **Projekt-Workspace** hat in der Workspace-Leiste seine Quicklinks: die localhost-Ports des Projekts und seine
Links (Repo, Board, Doku …). Klick öffnet in Helium. Workspaces ohne Projekt zeigen nichts.

## Was ist ein „Projekt-Workspace“?

Ein Workspace, dessen **eigener Name** der Projekt-ID (oder dem Anzeigenamen) in `projects/projects.json` entspricht
(Groß-/Kleinschreibung egal). Der Projekt-Desktop aus dem Launcher (`#` + Name) heißt automatisch so.
Ohne eigenen Namen („Workspace 2“) gibt es kein Projekt. Umbenennen: Doppelklick auf die Kachel oder Workspace-Modus `R`.

## Bedienung

- Rechts oben im Kopf jeder Projekt-Kachel sitzt immer ein kleiner **Link-Knopf** (Git/CI-Punkte links daneben). Klick öffnet das Popup.
- Alternativ: Rechtsklick auf die Kachel → **Quick links**.
- Popup, immer gleich sortiert: **Local** (Ports aus `dev.ports` nach Nummer, Punkt grün = läuft, Ring = läuft nicht; geprüft per `ss -ltn`, nur solange
  das Popup offen ist), **Containers**, **Repos** (Links auf GitHub/GitLab oder mit Icon `code`, dazu die Seite aus `git remote`), **Links** (der Rest), ganz unten **Add link**. Ein Icon je Kategorie (das `icon` aus `projects.json` zählt
  im Popup nicht); lange Namen haben Vorrang, Host/Pfad dahinter wird gekürzt. Klick auf eine Zeile öffnet die Adresse in Helium (`http://localhost:<port>`).
- **Mehrere Repos in einem Workspace:** Hat das Projekt eine `.code-workspace` (`workspace` in `projects.json`) und
  gehört einer ihrer Ordner zu einem anderen Projekt (z. B. soulwick → soulwick-platform), stehen dessen Ports,
  Container und Repo-Links mit im Popup (Ports mit „· <Projekt>“, Repo-Link unter dem Projektnamen). Entfernen geht
  nur bei Links des eigenen Projekts.
- Unter **Containers** die Container des Projekts (Punkt grün = läuft), mit ihren Ports. Zuordnung kommt aus
  `DevServices` (dieselbe wie im Dev-Popout, keine zweite Erkennung). Klick: Port mit Weboberfläche (Rolle in
  `dev.infra` mit console/web/ui/admin/dashboard, z. B. `minio-console`) öffnet in Helium, sonst (postgres …) wird
  `localhost:<port>` kopiert.
- **Add link**: Eingabefeld unter dem Popup, Format `Name https://…` (nur `https://…` geht auch, dann ist der Host der Name).
- **X** rechts an einem Link (nur bei Hover): erster Klick „Remove?“, zweiter entfernt.
- **Tastatur**: Workspace-Modus (Alt antippen oder Alt+Esc), Kachel mit ←/→ markieren – bei Projekt-Workspaces steht
  Branch/Änderungen/CI über der Leiste und der Hinweis `Q links`. **Q** öffnet das Popup: ↑/↓ (oder J/K) wählen,
  Enter öffnet, 1–9 öffnet die Zeile direkt, A = Link ergänzen, Entf zweimal = Link entfernen, Esc = zurück in den Modus.
  Im Popup steht auch **Repository** (aus `git remote`, falls nicht schon als Link eingetragen).
- Per Befehl: `qs ipc -p ~/Workspace/bastian-shell/shell call workbar quickLinks <n>` (n = Platz in der Leiste, 0 = aktueller);
  im Modus `workbar modeLinks` (wie Q).

## Wo liegen die Daten?

`projects/projects.json` (lokal, gitignored; Vorlage `projects/projects.example.json`), Eintrag des Projekts (Schema: `projects/README.md`):

```jsonc
"habit-tracker": {
  "dev":   { "ports": { "web": 3000, "api": 3001 } },          // -> Local: localhost:<port>
  "links": [ { "name": "Repo", "url": "https://github.com/example-org/habit-tracker", "icon": "code" } ]   // -> Links
}
```

`icon` ist ein Material-Symbol-Name (optional, Standard `link`), z. B. `code`, `view_kanban`, `description`, `bug_report`.

## Ändern (ohne KI)

**Nie die Datei von Hand ändern** – nur über `scripts/project` (prüft das Schema, schreibt atomar):

```
scripts/project link <projekt> add "Board" https://github.com/example-org/my-app/issues view_kanban   # Icon optional
scripts/project link <projekt> rm  "Board"
scripts/project set  <projekt> dev.ports web=3000,api=3001        # Ports (oder: dev.ports.web 3100 · dev.ports none)
scripts/project show <projekt>                                     # Eintrag ansehen
```

Dasselbe geht im Popup (Add link / X) und mit `/project` → Desktop in Claude Code. Die Shell lädt die Datei live neu.
Links für **alle** Projekte (z. B. Buchhaltung): `scripts/project link global add …` – die erscheinen hier nicht, nur
die des Projekts.

## Technik

`shell/modules/workbar/QuickLinksPopup.qml` (Popup) + `QuickLinksRow.qml` (Zeile) · Zuordnung Workspace → Projekt in
`shell/services/GitInfo.qml` (`projectFor`) · Knopf und Rechtsklick-Eintrag in `WorkBar.qml` (Kachel, Desktop-Menü) ·
Öffnen über `Launch.cmd(["helium", url])` (uwsm, überlebt Shell-Neustarts) · Speichern über `scripts/project link …`.

---

# Git- und CI-Status pro Projekt-Workspace (Idee o)

Projekt-Workspaces zeigen kleine Zustandspunkte im Kopf der Kachel und mehr im Tooltip (Maus kurz auf der Kachel
lassen) und im Quicklinks-Popup. Gleiche Zuordnung wie oben (Workspace-Name = Projekt).

| Wo | Was |
|---|---|
| Kachel, rechts im Kopf | **amber** = ungespeicherte Änderungen (geänderte + neue Dateien) · rechts **grün** = letzter CI-Lauf ok, **rot** = fehlgeschlagen, **Ring** = läuft, **grau** = abgebrochen/übersprungen. Repo ohne CI oder ohne `gh`: kein CI-Punkt. Die Punkte sitzen links neben dem Link-Knopf |
| Tooltip + Popup | `Branch · 3 changes · ↑1 ↓2 · CI passing` (↑ = noch nicht gepusht, ↓ = noch nicht geholt) |

## Woher kommen die Daten?

`scripts/gitinfo <ordner>…` (nur lesen) gibt JSON aus; probieren: `scripts/gitinfo ~/Workspace/bastian-shell`.
- **Git:** `git status --porcelain=v2 --branch` im Haupt-Repo des Projekts (`paths[0]`), mit `--no-optional-locks`
  (schreibt nichts, hält keinen Index-Lock).
- **CI:** `scripts/gitinfo --ci-only <ordner>` → `gh run list --limit 1` (nur github.com-Remotes, 5 s Timeout).
  Braucht installiertes und angemeldetes `gh` (`gh auth status`). Fehler (nicht angemeldet, kein Netz, kein Zugriff aufs
  Repo) bleiben still: dann gibt es nur keinen CI-Punkt. Es werden nie Tokens gelesen oder gespeichert.

## Sparsam

Nur für Projekte, die gerade einen Workspace haben, und **nur solange die Leiste sichtbar ist** (`GitInfo.active`,
gesetzt von `WorkBar.qml`). Git alle 30 s (ein Aufruf für alle Projekte), CI je Projekt höchstens alle 5 min
(Cache im Speicher, auch nach einem Fehler). Die Leiste wird dadurch nicht breiter (feste Punkt-Breite, nur der Name
kürzt ggf. um ~30 px) und blockiert nichts: alles läuft in Hintergrundprozessen.

## Technik

`scripts/gitinfo` · `shell/services/GitInfo.qml` (Zuordnung, Polling, `git`/`ci` je Projekt-ID) ·
`QuickLinksDots.qml` (Punkte in der Kachel) · `QuickLinksTip.qml` (Zeile für Tooltip/Popup).
Ändern: Intervalle in `GitInfo.qml` (`gitEvery`, `ciEvery`), Farben kommen aus den Theme-Tokens (`warning`, `success`, `error`).

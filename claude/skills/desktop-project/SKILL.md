---
name: desktop-project
description: Register or change how a project appears on the desktop shell (the shell's project registry, projects/projects.json) – project color (#RRGGBB) and VS Code tint, dev command and ports / port block, what the project workspace opens (VS Code, browser, terminal), and links. Only touches the shell's registry via scripts/project; the project's own repo stays unchanged. Use with /desktop-project or when the user wants to add a project to the desktop, change its color, ports, dev command, what opens, or its links.
argument-hint: "[path | color | ports | open | links]"
---

# /desktop-project

Shell feature "project workspaces": every project in the registry gets a color, a port block, a dev command,
links and a rule for what its workspace opens (launcher `#`, workbar, project desktop). This skill edits that
registry. **It never changes the project's repo**: no commits, no files written there.

Answer in the user's language, keep answers short, ask as multiple choice (AskUserQuestion; "Other" = free text
for hex values, ports, URLs, commands), recommended option first.

Tool: `P=~/.claude/skills/desktop-project/project` – wrapper around the shell's `scripts/project`
(registry `projects/projects.json`, schema in `projects/README.md` of the shell repo). Write **only** through it,
never edit the JSON by hand. `$P hilfe` prints the full help. Field values are German (`an`/`aus`, `ja`/`nein`).

## Flow

1. **Find the project**: target = `$ARGUMENTS` (path) or the current directory. `$P show <dir>` (also finds the
   project from a subfolder; JSON with `_info`: id, VS Code tint state, what opens). Otherwise `$P list` and take
   the id from there. Not registered → `$P add <path>` (picks the least used color, detects ports and links).
2. **Collect suggestions** (read only, change nothing in the project, **never open `.env`** – only `.env.example`):
   - ports/command: `$P detect <id>` (package.json, `apps/*/package.json`, `.env.example`, compose).
   - color: brand color from logo, Tailwind/CSS variables (`--primary`), brand file – with where it was found.
   - links: production domain (`SITE_URL` in `.env.example`, README), repo (git remote).
3. **Ask** – **one** AskUserQuestion round (max. 4 questions), only about what the user mentioned. Without a hint,
   first ask "What to change?" (multiSelect): color · tint · dev/ports · open · links. Put the current value first,
   marked "(current)".
   - **Color**: own `#RRGGBB` or none. Options: current · brand color (hex + source) · "No color".
   - **Tint** of VS Code title and status bar: on / off. Without a checked-in `.vscode/settings.json` a small local
     one is written and hidden via `.git/info/exclude` (never committed). With a **checked-in** one, a central
     workspace file `~/.config/desktop/workspaces/<name>.code-workspace` wraps the repo; launcher and project
     desktops open through it (a window opened as plain folder stays untinted). "Off" = only the color dot.
   - **Dev/ports**: first `$P ports show <id>` (block, collisions). Options: current (⚠ on collision) ·
     own port block (`$P ports allocate <id> --dry-run`, e.g. "block 2: web 3200 · api 3201 · postgres 5632") ·
     suggestion from `detect` · no ports. The **first** app port is what the browser opens.
     Schema: apps `3000 + 100·n + offset` (web 00, api 01, admin 02), infra `default port + 100·n`.
     A new block only changes the desktop setting – tell the user that the repo config (`.env.example`, compose,
     `--port` flags) has to follow in the repo (separate step, not part of this skill).
   - **Open** (project workspace): VS Code + browser on the first port *(default)* · VS Code only ·
     VS Code + browser + terminal · VS Code + dev server in terminal. The dev server never starts on its own.
     Terminal = the integrated VS Code terminal, needs `open.code an` and the "Desktop Projekte" extension ≥ 0.2.0.
   - **Links**: suggestions (production, repo, dashboards) as multiSelect; "Other" = "Name URL".
4. **Apply** (quote values containing `#`, spaces or `&` in single quotes):
   | What | Command |
   |---|---|
   | Color | `$P set <id> color '#RRGGBB'` · none: `$P set <id> color none` (also turns tint off) |
   | Tint | `$P set <id> tint an` / `aus` |
   | Port block | `$P ports allocate <id>` (next free one, keeps an existing block) · fixed: `--block 3` · overview: `$P ports list` |
   | Single port | `$P ports set <id> web 3100` · container: `$P ports set <id> postgres 5532 --infra` · remove: `… none` |
   | Ports | `$P set <id> dev.ports web=3000,api=3001` · single `dev.ports.<name> 3001` / `none` · re-detect: `$P set <id> dev detect` |
   | Dev command | `$P set <id> dev.command 'bun run dev'` · before it (containers): `$P set <id> dev.services 'bun run services:up'` |
   | Browser | `$P set <id> open.browser web` (port names and/or URLs, comma separated) · none: `none` |
   | VS Code | `$P set <id> open.code an` / `aus` |
   | Terminal | `$P set <id> open.terminal shell` (empty) · `dev` (services + dev.command) · `none` |
   | Link | `$P link <id> add Prod https://… public` (icon = Material Symbol name, optional) · `$P link <id> rm Prod` |
   | Other | `$P set <id> name '…'` · `kind kunde\|labs\|intern\|privat` · `workspace <file>\|none` · `paths <p>[,<p>…]` |
   | Remove | `$P rm <id>` (tint off first; folder goes on the ignore list) |
   Global links (all projects): `$P link global add …`. The script validates everything and saves **nothing** on
   an error – pass the message on briefly.
5. **Check**: `git -C <project> status --short` must look the same as before. `$P show <id>` → report
   `_info.opens` briefly (e.g. "Opens: VS Code, http://localhost:3000"). VS Code picks up color/tint immediately;
   the shell reads the registry live.

## Rules

- Never commit in the project, never change its files, never open `.env`.
- Do not commit `projects/projects.json` / `theme/projects.json` in the shell repo yourself – the user does that.
- No secrets in links or commands.

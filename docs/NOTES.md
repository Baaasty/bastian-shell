# Gedanken parken (Super+N)

Idee loswerden, ohne den Fokus zu verlieren: **Super+N** öffnet ein kleines Feld (Fokus sofort drin), **Enter** speichert und schließt.
Kein Netz, keine KI, kein Sync – nur eine Textdatei.

## Bedienung

| Taste | Wirkung |
|---|---|
| Enter | speichern (hängt an die Inbox an), Fenster zu, kurz „Saved“ unten |
| Shift+Enter | neue Zeile |
| Esc oder Klick daneben | schließen – der **Entwurf bleibt** bis zum nächsten Öffnen (auch nach Shell-Neustart: `~/.local/state/desktop/notes-draft.txt`) |
| Super+N nochmal | schließt ebenfalls |

- Erscheint auf dem Monitor mit Fokus.
- **To-do:** beginnt die Notiz mit `t ` oder `!`, landet sie zusätzlich in der To-do-Liste des aktuellen Desktops (Bar oben links). Das Feld zeigt dann „also becomes a task“.
- **Tags:** einfach `#projekt` in den Text schreiben (zum Suchen mit `grep`).
- Oben links im To-do-Popout steht unten „Inbox · N open notes“ (zählt die offenen Zeilen der Datei).

## Dateiformat (`~/Notes/inbox.md`, von Hand pflegbar)

```
- [ ] 2026-10-18 20:15 Idee für die Startseite #website
- [ ] 2026-10-18 20:16 Zahnarzt anrufen #todo
- [ ] 2026-10-18 20:20 Erste Zeile
    weitere Zeilen sind eingerückt
- [x] 2026-10-17 09:02 Erledigtes: einfach [ ] zu [x] machen oder die Zeile löschen
```

Eine Notiz = ein Block, neue Einträge kommen unten an. Gezählt werden nur Zeilen mit `- [ ] ` am Anfang.
Datei und Ordner werden beim ersten Speichern angelegt. Klappt das Schreiben nicht, bleibt das Fenster offen (Hinweis „Could not save“, Entwurf bleibt).

## Konfiguration (`~/.config/desktop/notes.json`, Änderungen gelten sofort)

```json
{
  "path": "~/Notes/inbox.md",
  "todoPrefixes": ["t ", "!"],
  "todoList": "current",
  "savedMs": 1000
}
```

| Schlüssel | Bedeutung |
|---|---|
| `path` | Inbox-Datei (`~` = Home) |
| `todoPrefixes` | Anfänge, die zusätzlich ein To-do machen; `[]` = nie |
| `todoList` | `"current"` = Liste des aktuellen Desktops, sonst ein Listenname (z. B. `"General"`) |
| `savedMs` | wie lange „Saved“ zu sehen ist |

Fehlt die Datei oder einzelne Schlüssel, gelten diese Standardwerte.

## Technik

- `shell/services/Notes.qml` (Speichern, Zähler, Entwurf, Konfiguration, IPC) · `shell/modules/notes/NotesWindow.qml` (Fenster + Hinweis)
- Kürzel: `hypr/binds.conf` (`SUPER, N` → `qs ipc … call notes toggle`)
- IPC: `notes open|toggle|close|add "<text>"|count` (`add` = wie Enter, ohne Fenster – zum Testen und für Skripte)

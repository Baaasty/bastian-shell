# Downloads-Popout

Kleiner Chip in der Bar (rechts, nach dem Netz-Chip): sonst ein **leises Download-Symbol**.
- lädt gerade etwas → Symbol „downloading“ im Glut-Ton
- eben fertig geworden → Haken-Symbol + kleiner Punkt, **15 min** lang oder bis du das Popout öffnest

Klick öffnet das Popout, Klick daneben oder Esc schließt es.

**Warum ein eigener Chip und kein Abschnitt in einem bestehenden Popout?** Kein vorhandenes Popout passt thematisch (Netz, Sound,
Ressourcen …), und der Hinweis „neuer Download“ braucht einen Platz in der Bar. Der Chip ist nur ein Symbol (~32 px) und im Fokus-Modus
wie die anderen rechten Chips ausgeblendet.

## Was drin ist

| Bereich | Inhalt |
|---|---|
| Kopf | Titel + Suchfeld („Search…“ durchsucht den ganzen Ordner, Enter öffnet den ersten Treffer) |
| Liste | die **12 neuesten** Einträge aus `~/Downloads` (nach Änderungszeit): Typ-Symbol, Name, Größe · Alter |
| Laufende | `.part` (Firefox), `.crdownload` (Chrome/Brave) stehen als „Downloading… 12 MB“ (Größe läuft mit, solange das Popout offen ist) |
| Fuß | **Open folder** · Anzahl · **Clean up** |

- **Zeile klicken** = Datei öffnen (`xdg-open`, gestartet über `Launch.cmd`, also nicht als Kind der Shell)
- **Ordner-Knopf** (beim Drüberfahren rechts) = im Dateimanager zeigen (D-Bus `FileManager1.ShowItems`, z. B. Dolphin markiert die Datei)
- **Ziehen** = Datei als `text/uri-list` in eine App legen (Browser-Upload, Discord, Dateimanager …)
- **Clean up** = Rückfrage mit Wahl **7 / 14 / 30 / 90 Tage**, zeigt Anzahl + Größe; „Move to trash“ legt alles Ältere per
  `gio trash` in den **Papierkorb** (wiederherstellbar, nie endgültig gelöscht). Laufende Downloads werden nie angefasst.

## Konfiguration (optional)

`~/.config/desktop/downloads.json` – fehlt die Datei, gilt:
```json
{ "dir": "~/Downloads", "count": 12, "cleanupDays": 30 }
```
`count` = Einträge ohne Suche, `cleanupDays` = Vorauswahl beim Aufräumen. Wird live neu gelesen.

## Wann wird gelesen?

Nur bei Ereignissen im Ordner (`inotifywait`: anlegen, umbenennen, löschen, fertig schreiben – entprellt 0,4 s), kein Dauer-Polling.
Nur bei offenem Popout **und** laufendem Download alle 1,5 s (für die Größe). Versteckte Dateien (`.…`) werden nicht gezeigt.

## Dateien

- `shell/services/Downloads.qml` – Liste, Ereignisse, Öffnen/Zeigen, Aufräumen
- `shell/modules/bar/DownloadsChip.qml` (+ IPC), `DownloadsPopout.qml`

## Testen ohne Maus

```sh
S=~/Workspace/bastian-shell/shell
qs ipc --any-display -p $S call downloads status            # Ordner, Anzahl, lädt/neu, die neuesten Namen
qs ipc --any-display -p $S call downloads cleanupPreview 30 # nur anzeigen, was „Clean up“ in den Papierkorb legen würde
qs ipc --any-display -p $S call downloads testDir /pfad     # anderen Ordner zeigen ("" = zurück), wird nicht gespeichert
qs ipc --any-display -p $S call downloads fresh             # Chip im Zustand „neu“
qs ipc --any-display -p $S call downloads open|close        # Popout (ohne Klick-Fang)
qs ipc --any-display -p $S call downloads askCleanup        # Rückfrage zeigen (Bestätigen nur per Klick)
```
Hinweis: `gio trash` geht nicht auf tmpfs (`/tmp`) – zum Testen einen Ordner unter `~` nehmen.

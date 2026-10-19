# Sperrbildschirm unter Hyprland

Unter Plasma sperrt weiter kscreenlocker mit dem Shell-Paket (`plasma/`). Unter Hyprland sperrt die Shell selbst
(`shell/modules/lock`, Wayland ext-session-lock), sieht aus wie das Plasma-Paket. Einstieg für alles: `scripts/lock`.

## Ablauf

- **Sperren:** Super+L, Power-Menü, `loginctl lock-session` und hypridle rufen `scripts/lock now` → IPC `lock lock`.
  Antwortet die Shell nicht, übernimmt sofort **hyprlock** (Notfall, Farben aus `theme/palette.json`).
- **Entsperren:** nur per Passwort über PAM (`shell/assets/pam.d/desktop-lock`: pam_unix, 2 s Wartezeit nach
  Fehlversuch, kein leeres Passwort). Es gibt bewusst kein IPC-„unlock“.
- **Leerlauf** (`hypr/hypridle.conf`): 5:00 dimmen (Bewegung = weiter ohne Passwort), 5:05 sperren,
  +1 min Monitore aus. Läuft ein Fokus-Block: erst nach 15 min. Videos/Spiele halten alles an.
- Zustand: `$XDG_RUNTIME_DIR/desktop-lock` (`locked`/`unlocked`).

## Absturz

Hyprland bleibt gesperrt, wenn das Sperrprogramm stirbt (`misc:allow_session_lock_restore` erlaubt die Übernahme).
Der Wächter (`scripts/lock guard`, eigener systemd-Scope) prüft alle paar Sekunden: hält die Shell die Sperre
~12 s lang nicht, startet er hyprlock. Die neu gestartete Shell sperrt dank Zustandsdatei auch selbst wieder.

## Notfall aus dem TTY

Strg+Alt+F3, einloggen, dann (Hyprland startet hyprlock mit seiner eigenen Umgebung):

```sh
hyprctl --instance 0 dispatch exec ~/Workspace/bastian-shell/scripts/lock rescue
```

Zurück mit Strg+Alt+F2 (bzw. der Konsole, auf der die Sitzung läuft). Geht gar nichts: `loginctl terminate-user $USER`.

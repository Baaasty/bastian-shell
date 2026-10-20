// >>> desktop-theme (ERZEUGT aus theme/palette.json) – verwaltet von theme/gen/thunderbird.py, nicht von Hand ändern
// userChrome.css/userContent.css im Profil/chrome laden (desktop-Look für Listen, Kalender, Mailtext)
user_pref("toolkit.legacyUserProfileCustomizations.stylesheets", true);
// Kalender: Woche beginnt am Montag (Oberfläche bleibt Englisch)
user_pref("calendar.week.start", 1);
// Neue Mail meldet die Shell (scripts/mail-watch) – Thunderbirds eigene Meldung + Ton wären doppelt
user_pref("mail.biff.show_alert", false);
user_pref("mail.biff.play_sound", false);
// <<< desktop-theme

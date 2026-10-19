# ~/.bashrc.d/desktop-fetch.sh – Fastfetch (kleine Katze) beim Öffnen von Kitty.
# Symlink aus dem Repo, gesetzt/entfernt von scripts/kitty-theme install|off. Konfiguration: theme/out/fastfetch/config.jsonc.
# Nur im ersten Fenster eines Kitty-Prozesses (nicht in neuen Tabs/Splits), nicht im Drop-down (DESKTOP_NOFETCH)
# und nicht in verschachtelten Shells (DESKTOP_FETCHED).
if [[ $- == *i* && "${KITTY_WINDOW_ID:-}" == 1 && -z "${DESKTOP_NOFETCH:-}${DESKTOP_FETCHED:-}" ]] \
    && command -v fastfetch >/dev/null; then
    export DESKTOP_FETCHED=1
    fastfetch
fi

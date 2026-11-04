-- desktop – Hyprland-Einstieg (Lua; hyprlang gibt es ab Hyprland 0.57 nicht mehr, Rückweg: Git-Tag hyprlang-final).
-- Wird nicht direkt geladen, sondern von ~/.config/hypr/hyprland.lua, die scripts/hypr install anlegt:
--
--   DESKTOP = "/home/<user>/Workspace/bastian-shell"     (Repo-Pfad, nie hart in diesen Dateien)
--   require(DESKTOP .. "/hypr/hyprland.lua")
--
-- Ein Modul pro Datei: ein Laufzeitfehler bricht nur sein Modul ab, der Rest lädt weiter (hyprctl configerrors).
-- Alle geladenen Dateien beobachtet Hyprland selbst – Speichern lädt neu.
-- Prüfen ohne Start: scripts/hypr check

for _, part in ipairs({ "env", "monitors", "general", "look", "rules", "pins", "binds", "autostart" }) do
    require(DESKTOP .. "/hypr/" .. part .. ".lua")
end

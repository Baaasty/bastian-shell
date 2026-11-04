-- Gemeinsame Helfer für alle Teile der Hyprland-Konfiguration (require liefert überall dieselbe Tabelle).
-- DESKTOP (Repo-Pfad) setzt ~/.config/hypr/hyprland.lua (scripts/hypr install) als globale Variable.
local M = {}

-- qs-Instanz: derselbe absolute Pfad wie beim Start (systemd-Unit), sonst findet IPC sie nicht
M.IPC = "qs ipc --any-display -p " .. DESKTOP .. "/shell call"
-- Apps nie direkt starten (stürben mit der Shell/Hyprland): eigene systemd-Unit über uwsm
M.APP = "uwsm app --"

function M.exec(cmd)
    return hl.dsp.exec_cmd(cmd)
end

-- Shell-IPC: ipc("launcher toggle") = qs ipc … call launcher toggle
function M.ipc(call)
    return hl.dsp.exec_cmd(M.IPC .. " " .. call)
end

-- Kürzel mit Titel (Super+K und scripts/hotkeys-md lesen ihn aus binds.lua, Hyprland zeigt ihn in hyprctl binds).
-- Titel zuerst, damit die Leser ihn ohne Lua-Parser finden; nil = technischer Bind ohne Eintrag im Viewer.
function M.bind(keys, title, action, opts)
    opts = opts or {}
    if title then
        opts.description = title
    end
    return hl.bind(keys, action, opts)
end

return M

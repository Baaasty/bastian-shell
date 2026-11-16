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

-- Shell-Kürzel (opts.shell = true): gelten auch hinter offenen Panels, siehe M.modal_submap
M.shell_binds = {}

-- Kürzel mit Titel (Super+K und scripts/hotkeys-md lesen ihn aus binds.lua, Hyprland zeigt ihn in hyprctl binds).
-- Titel zuerst, damit die Leser ihn ohne Lua-Parser finden; nil = technischer Bind ohne Eintrag im Viewer.
function M.bind(keys, title, action, opts)
    local o = {}
    for k, v in pairs(opts or {}) do
        if k ~= "shell" then
            o[k] = v
        end
    end
    if opts and opts.shell then
        local plain = {}
        for k, v in pairs(o) do
            plain[k] = v
        end
        table.insert(M.shell_binds, { keys, action, plain })
    end
    if title then
        o.description = title
    end
    return hl.bind(keys, action, o)
end

-- Kürzel-Sperre (Hypr.setModal): Submap „modal“ mit allen Shell-Kürzeln (ohne Titel → nicht im Viewer) plus extra().
-- Fenster-Kürzel fehlen dort absichtlich. Liste danach leeren, damit ein Neuladen nichts doppelt bindet.
function M.modal_submap(extra)
    local list = M.shell_binds
    M.shell_binds = {}
    hl.define_submap("modal", function()
        for _, b in ipairs(list) do
            hl.bind(b[1], b[2], b[3])
        end
        extra()
    end)
end

return M

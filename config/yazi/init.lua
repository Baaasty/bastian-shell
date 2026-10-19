-- ~/.config/yazi/init.lua (Symlink aus dem Repo, gesetzt von scripts/sshs install).
-- sshs: yazi meldet seinen Ordner in die Datei $SSHS_CWD_FILE, damit das Terminal beim Umschalten mitwandert
-- (config/sshs/sshs_kitten.py). Ohne die Variable passiert nichts.
local f = os.getenv("SSHS_CWD_FILE")
if f then
	ps.sub("cd", function()
		local h = io.open(f, "w")
		if h then
			h:write(tostring(cx.active.current.cwd))
			h:close()
		end
	end)
end

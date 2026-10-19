-- sshs (auf dem Server): yazi in der su-Shell (bashrc: _sshs_y) meldet seinen Ordner per OSC 7 an Kitty, wie die Shell
-- an der Prompt – so landen Upload und neuer Tab im Ordner, den yazi gerade zeigt.
local function enc(s)
	return (s:gsub("[^%w%-%._~/]", function(c)
		return string.format("%%%02X", c:byte())
	end))
end

ps.sub("cd", function()
	local h = io.open("/dev/tty", "w")
	if h then
		h:write("\27]7;file://" .. enc(tostring(cx.active.current.cwd)) .. "\7")
		h:close()
	end
end)

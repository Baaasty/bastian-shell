-- Umgebungsvariablen stehen in env.conf (Datendatei, die auch uwsm liest – Format und Gründe dort).
for line in io.lines(DESKTOP .. "/hypr/env.conf") do
    local name, value = line:match("^env = ([^,]+),(.*)$")
    if name then
        hl.env(name, value)
    end
end

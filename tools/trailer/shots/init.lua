local Shots = {}

local files = love.filesystem.getDirectoryItems("tools/trailer/shots")

for _, file in ipairs(files) do
    if file:match("^shot_.*%.lua$") then
        local name = file:gsub("%.lua$", "")
		
        Shots[name] = require("tools.trailer.shots." .. name)
    end
end

return Shots
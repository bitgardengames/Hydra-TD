local Sequences = {}

local files = love.filesystem.getDirectoryItems("tools/trailer/sequences")

for _, file in ipairs(files) do
	if file:match("%.lua$") then
		local name = file:gsub("%.lua$", "")
		Sequences[name] = require("tools.trailer.sequences." .. name)
	end
end

return Sequences
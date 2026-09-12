local Camera = require("core.camera")
local Constants = require("core.constants")
local State = require("core.state")
local Towers = require("world.towers")

local SceneExport = {}

local function rounded(value)
	if value >= 0 then return math.floor(value + 0.5) end
	return math.ceil(value - 0.5)
end

local function decimal(value)
	local formatted = string.format("%.2f", value)
	return formatted:gsub("0$", "")
end

function SceneExport.format(duration)
	local tile = Constants.TILE
	local screenW, screenH = love.graphics.getDimensions()
	local centerX = Camera.wx + screenW / (2 * Camera.wscale)
	local centerY = Camera.wy + screenH / (2 * Camera.wscale)
	-- Keep the anchor consistent with the existing backdrop scenes. Camera
	-- offsets then preserve the exact current framing.
	local cameraGX = math.floor(Constants.GRID_W / 2)
	local cameraGY = math.floor(Constants.GRID_H / 2)
	local anchorX = cameraGX * tile + tile * 0.5
	local anchorY = cameraGY * tile + tile * 0.5
	local lines = {
		"\t{",
		string.format("\t\tduration = %d,", duration or 14),
		string.format("\t\tmap = %d,", State.worldMapIndex),
		"\t\ttowers = {",
	}

	for _, tower in ipairs(Towers.towers) do
		lines[#lines + 1] = string.format(
			'\t\t\t{kind = "%s", gx = %d, gy = %d, level = %d},',
			tower.kind, tower.gx, tower.gy, tower.level or 1)
	end

	lines[#lines + 1] = "\t\t},"
	lines[#lines + 1] = string.format("\t\twave = %d,", State.wave)
	lines[#lines + 1] = string.format("\t\twarmup = %.1f,", State.waveTime or 0)
	lines[#lines + 1] = string.format(
		"\t\tcamera = {gx = %d, gy = %d, ox = %d, oy = %d, zoom = %s},",
		cameraGX, cameraGY, rounded(centerX - anchorX), rounded(centerY - anchorY), decimal(Camera.wscale))
	lines[#lines + 1] = "\t},"

	return table.concat(lines, "\n")
end

function SceneExport.copy(duration)
	local scene = SceneExport.format(duration)
	love.system.setClipboardText(scene)
	print("Backdrop scene copied to clipboard:\n" .. scene)
	return scene
end

return SceneExport

local Messages = require("ui.messages")
local BossHP = require("ui.boss_hp")
local Effects = require("world.effects")
local Constants = require("core.constants")

local Presentation = {}

function Presentation.event(kind, payload)
	payload = payload or {}
	Messages.presentationEvent(kind, payload)
	BossHP.presentationEvent(kind, payload)
	Effects.presentationEvent(kind, payload)
end

function Presentation.path(map)
	local result = {}
	for i, point in ipairs((map and map.path) or {}) do
		result[i] = {(point[1] - .5) * Constants.TILE, (point[2] - .5) * Constants.TILE}
	end
	return result
end

function Presentation.waveStarted(wave, map)
	local start = map and map.path and map.path[1]
	Presentation.event("wave_start", {wave=wave, x=start and (start[1]-.5)*Constants.TILE, y=start and (start[2]-.5)*Constants.TILE})
end

function Presentation.waveCleared(wave, map, bonus, bossPosition, wasBoss)
	if wasBoss then Presentation.event("boss_defeated", {wave=wave, x=bossPosition and bossPosition.x, y=bossPosition and bossPosition.y}) end
	local finish = map and map.path and map.path[#map.path]
	Presentation.event("wave_cleared", {wave=wave, perfectWaveBonus=bonus,
		x=finish and (finish[1]-.5)*Constants.TILE, y=finish and (finish[2]-.5)*Constants.TILE})
end

return Presentation

local Scale = {}

-- Authored reference resolution
local REF_W = 1920
local REF_H = 1080

Scale.sw = REF_W
Scale.sh = REF_H
Scale.factor = 1.0

function Scale.update()
	Scale.sw, Scale.sh = love.graphics.getDimensions()

	local sx = Scale.sw / REF_W
	local sy = Scale.sh / REF_H

	-- Limiting axis preserves framing/layout
	Scale.factor = math.min(sx, sy)
end

function Scale.getScale()
	return Scale.factor
end

function Scale.getDimensions()
	return Scale.sw, Scale.sh
end

function Scale.suggestMSAA(w, h)
	local Save = package.loaded["core.save"]
	local quality = Save and Save.data and Save.data.settings and Save.data.settings.msaaQuality or "auto"
	local explicit = {off = 0, low = 2, medium = 4, high = 8}
	if explicit[quality] ~= nil then return explicit[quality] end
	local pixels = (w or Scale.sw) * (h or Scale.sh)
	if pixels <= 1280 * 800 then return 0 end
	if pixels <= 1920 * 1080 then return 2 end
	return 4
end

return Scale

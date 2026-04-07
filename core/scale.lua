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
	--[[if w >= 1920 and h >= 1080 then
		return 8
	elseif w >= 1280 and h >= 720 then
		return 4
	else
		return 2
	end]]

	-- Should just make it an option later
	return 8
end

return Scale
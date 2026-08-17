local Theme = require("core.theme")

local ScatterCommon = {}

-- Resolve sparse biome overrides without allocating a merged table per prop.
function ScatterCommon.getLighting(biome)
	local override = biome and biome.lighting or nil
	local base = Theme.lighting
	return {
		direction = (override and override.direction) or base.direction,
		shadowOffset = (override and override.shadowOffset) or base.shadowOffset,
		shadowSoftness = (override and override.shadowSoftness) or base.shadowSoftness,
		shadowOpacity = (override and override.shadowOpacity) or base.shadowOpacity,
		ambientMultiplier = (override and override.ambientMultiplier) or base.ambientMultiplier,
		highlightTint = (override and override.highlightTint) or base.highlightTint,
	}
end

-- Crisp two-ellipse softness approximation. `height` makes tall props cast away
-- from the light, while height zero remains a tight contact shadow.
function ScatterCommon.drawShadow(graphics, x, y, rx, ry, height, alpha, config)
	config = config or Theme.lighting
	local direction = config.direction or Theme.lighting.direction
	local offset = (config.shadowOffset or Theme.lighting.shadowOffset) * (height or 0)
	local sx, sy = x - direction[1] * offset, y - direction[2] * offset
	local opacity = (alpha or 1) * (config.shadowOpacity or Theme.lighting.shadowOpacity)
	local softness = config.shadowSoftness or Theme.lighting.shadowSoftness

	graphics.setColor(0, 0, 0, opacity * 0.35)
	graphics.ellipse("fill", sx, sy, rx * (1 + softness), ry * (1 + softness))
	graphics.setColor(0, 0, 0, opacity * 0.65)
	graphics.ellipse("fill", sx, sy, rx, ry)
end

function ScatterCommon.setLitColor(graphics, color, highlighted, alpha, config)
	config = config or Theme.lighting
	local ambient = config.ambientMultiplier or Theme.lighting.ambientMultiplier
	local tint = highlighted and (config.highlightTint or Theme.lighting.highlightTint) or {1, 1, 1}
	local shade = highlighted and 1 or Theme.lighting.shadowMul
	graphics.setColor(
		math.min(1, color[1] * ambient * tint[1] * shade),
		math.min(1, color[2] * ambient * tint[2] * shade),
		math.min(1, color[3] * ambient * tint[3] * shade),
		alpha or color[4] or 1
	)
end

-- Fill a decoration list with at most `count` unique grid positions. Keeping
-- this loop here gives every scatter system the same placement rules and, more
-- importantly, prevents an impossible map layout from hanging generation.
function ScatterCommon.populate(list, count, random, gridWidth, gridHeight, canPlace, create)
	local occupied = {}
	local attempts = 0
	local maxAttempts = count * 100

	while #list < count and attempts < maxAttempts do
		attempts = attempts + 1

		local gx = random(2, gridWidth - 1)
		local gy = random(2, gridHeight - 1)
		local column = occupied[gx]

		if not (column and column[gy]) and canPlace(gx, gy) then
			if not column then
				column = {}
				occupied[gx] = column
			end

			column[gy] = true
			list[#list + 1] = create(gx, gy)
		end
	end
end

function ScatterCommon.isNearPath(path, gx, gy)
	for dx = -1, 1 do
		local col = path[gx + dx]

		if col then
			for dy = -1, 1 do
				if col[gy + dy] then
					return true
				end
			end
		end
	end

	return false
end

return ScatterCommon

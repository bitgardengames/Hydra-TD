local ScatterCommon = {}

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

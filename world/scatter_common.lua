local ScatterCommon = {}

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

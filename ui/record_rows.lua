local RecordRows = {}

local definitions = {
	{"bestScore", "Best score (higher is better)"},
	{"fastestClear", "Fastest clear, seconds (lower is better)"},
	{"highestRemainingLives", "Most lives remaining (higher is better)"},
	{"fewestLeaks", "Fewest leaks (lower is better)"},
}

function RecordRows.build(records, newKeys)
	local fresh, rows = {}, {}
	for _, key in ipairs(newKeys or {}) do fresh[key] = true end
	for _, definition in ipairs(definitions) do
		local key, label = definition[1], definition[2]
		if records and records[key] ~= nil then
			rows[#rows + 1] = {label = (fresh[key] and "★ NEW — " or "Record — ") .. label,
				value = records[key], isRecord = fresh[key] == true}
		end
	end
	return rows
end

return RecordRows

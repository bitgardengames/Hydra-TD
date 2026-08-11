-- Cheap fixed-step diagnostics for development builds. Fused distributions do
-- not allocate or mutate counters, so release gameplay pays only the call cost.
local Counters = {
	enabled = love.filesystem and not love.filesystem.isFused(),
	values = {},
}

function Counters.add(name, amount)
	if not Counters.enabled then return end
	Counters.values[name] = (Counters.values[name] or 0) + (amount or 1)
end

function Counters.maximum(name, value)
	if not Counters.enabled then return end
	Counters.values[name] = math.max(Counters.values[name] or 0, value)
end

function Counters.snapshot()
	local result = {}
	for name, value in pairs(Counters.values) do
		result[name] = value
	end
	return result
end

function Counters.reset()
	if Counters.enabled then Counters.values = {} end
end

return Counters

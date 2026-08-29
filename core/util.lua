local Util = {}

local min = math.min
local max = math.max
local sqrt = math.sqrt
local floor = math.floor

-- Targeting / distance math
function Util.clamp(x, a, b)
	return max(a, min(x, b))
end

function Util.dist2(x1, y1, x2, y2)
	local dx = x2 - x1
	local dy = y2 - y1

	return dx * dx + dy * dy
end

function Util.len(x, y)
	return sqrt(x * x + y * y)
end

function Util.norm(x, y)
	local l = sqrt(x * x + y * y)

	if l == 0 then
		return 0, 0
	end

	return x / l, y / l
end

-- Number formatting
local numCache = {}

function Util.formatInt(n)
	local v = floor(n + 0.5)
	local cached = numCache[v]

	if cached then
		return cached
	end

	local s = tostring(v)
	s = s:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
	numCache[v] = s

	return s
end

function Util.clearTable(t)
	for k in pairs(t) do
		t[k] = nil
	end

	return t
end

-- Copies source's entries into destination and returns destination. This is a
-- shallow operation: keys and values (including nested tables) are retained by
-- reference. Neither table's metatable is read or changed.
function Util.shallowCopyInto(destination, source)
	for key, value in pairs(source) do
		destination[key] = value
	end

	return destination
end

-- Like shallowCopyInto, but accepts a nil source and skips nil values. (Normal
-- Lua tables do not expose nil entries through pairs; the explicit check also
-- documents the overlay contract.) Nested tables and table keys remain shared,
-- and metatables are ignored.
function Util.copyNonNilInto(destination, source)
	for key, value in pairs(source or {}) do
		if value ~= nil then
			destination[key] = value
		end
	end

	return destination
end

-- Clones the graph reachable through table values. Cycles terminate, and
-- repeated references to the same source table point to one cloned table.
-- Table-valued keys are deliberately retained (not cloned), metatables are not
-- copied, and non-table values are shared/retained as-is.
function Util.deepCloneGraph(source)
	if type(source) ~= "table" then
		return source
	end

	local seen = {}
	local function clone(value)
		if type(value) ~= "table" then
			return value
	end

		local existing = seen[value]
		if existing then
			return existing
		end

		local copy = {}
		seen[value] = copy
		for key, nestedValue in pairs(value) do
			copy[key] = clone(nestedValue)
		end
		return copy
	end

	return clone(source)
end

return Util

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

function Util.len(x,y)
	return sqrt(x * x + y * y)
end

function Util.norm(x,y)
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

return Util
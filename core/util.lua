local Util = {}

local sqrt = math.sqrt

function Util.clamp(x, a, b)
	if x < a then
		return a
	elseif x > b then
		return b
	else
		return x
	end
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

return Util
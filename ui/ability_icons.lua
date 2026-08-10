local lg = love.graphics
local pi = math.pi

local AbilityIcons = {}

-- Icon glyphs are authored around a 36px box. Keeping state decoration outside
-- these functions lets every presentation use the exact same underlying mark.
local function meteor(cx, cy, scale, alpha)
	lg.setLineWidth(5 * scale)
	lg.setColor(1, 0.48, 0.18, 0.9 * alpha)
	lg.line(cx - 15 * scale, cy - 15 * scale, cx - 5 * scale, cy - 5 * scale)
	lg.setColor(1, 0.76, 0.28, alpha)
	lg.circle("fill", cx + 3 * scale, cy + 3 * scale, 12 * scale)
	lg.setColor(1, 0.92, 0.55, alpha)
	lg.circle("fill", cx, cy, 5 * scale)
end

local function frostNova(cx, cy, scale, alpha)
	lg.setColor(0.55, 0.88, 1, alpha)
	lg.setLineWidth(3 * scale)
	for i = 0, 2 do
		local angle = i * pi / 3
		local dx, dy = math.cos(angle) * 17 * scale, math.sin(angle) * 17 * scale
		lg.line(cx - dx, cy - dy, cx + dx, cy + dy)
	end
	lg.circle("fill", cx, cy, 4 * scale)
end

local function overdrive(cx, cy, scale, alpha)
	lg.setColor(1, 0.75, 0.2, alpha)
	lg.setLineWidth(3 * scale)
	lg.circle("line", cx, cy, 16 * scale)
	lg.line(cx, cy - 15 * scale, cx + 7 * scale, cy - 3 * scale, cx + scale, cy - 3 * scale, cx + 8 * scale, cy + 14 * scale)
end

local function gravityWell(cx, cy, scale, alpha)
	lg.setColor(0.65, 0.35, 1, alpha)
	lg.setLineWidth(3 * scale)
	for radius = 6, 17, 5 do
		lg.arc("line", cx, cy, radius * scale, radius * 0.4, radius * 0.4 + 4.7)
	end
end

local function goldRush(cx, cy, scale, alpha)
	lg.setColor(1, 0.78, 0.16, alpha)
	lg.circle("fill", cx, cy, 17 * scale)
	lg.setColor(1, 0.94, 0.5, alpha)
	lg.setLineWidth(2 * scale)
	lg.circle("line", cx, cy, 13 * scale)
	lg.setColor(0.35, 0.2, 0.03, alpha)
	lg.setLineWidth(2.5 * scale)
	lg.line(cx + 4 * scale, cy - 8 * scale, cx - 4 * scale, cy - 8 * scale, cx - 6 * scale, cy - 4 * scale, cx + 5 * scale, cy + 3 * scale, cx + 3 * scale, cy + 8 * scale, cx - 5 * scale, cy + 8 * scale)
	lg.line(cx, cy - 12 * scale, cx, cy + 12 * scale)
end

local function lastStand(cx, cy, scale, alpha)
	lg.setColor(1, 0.62, 0.2, alpha)
	lg.setLineWidth(3 * scale)
	lg.circle("line", cx, cy, 16 * scale)
	lg.line(cx - 20 * scale, cy, cx + 20 * scale, cy)
	lg.line(cx, cy - 20 * scale, cx, cy + 20 * scale)
end

local drawers = {
	meteor = meteor,
	frost_nova = frostNova,
	overdrive = overdrive,
	gravity_well = gravityWell,
	gold_rush = goldRush,
	last_stand = lastStand,
}

local function unknown(cx, cy, scale, alpha)
	-- A gray broken diamond reads as unavailable data, not as a prize.
	lg.setColor(0.58, 0.61, 0.65, 0.8 * alpha)
	lg.setLineWidth(2.5 * scale)
	lg.polygon("line", cx, cy - 14 * scale, cx + 14 * scale, cy, cx, cy + 14 * scale, cx - 14 * scale, cy)
	lg.line(cx - 5 * scale, cy - 5 * scale, cx + 5 * scale, cy + 5 * scale)
	lg.line(cx + 5 * scale, cy - 5 * scale, cx - 5 * scale, cy + 5 * scale)
end

local function stateName(state)
	if type(state) == "string" then return state end
	if type(state) == "table" then return state.kind or state.status or state.state end
	return nil
end

local function drawAccent(kind, cx, cy, scale, alpha)
	if not kind then return end
	local radius = 22 * scale
	lg.setLineWidth(2.5 * scale)

	if kind == "ready" then
		lg.setColor(0.42, 1, 0.62, 0.72 * alpha)
		lg.arc("line", cx, cy, radius, -pi * 0.72, pi * 0.72)
	elseif kind == "active" then
		lg.setColor(1, 0.78, 0.12, 0.95 * alpha)
		lg.circle("line", cx, cy, radius)
		lg.circle("fill", cx + radius, cy, 2.5 * scale)
	elseif kind == "locked" then
		lg.setColor(0.06, 0.07, 0.09, 0.58 * alpha)
		lg.circle("fill", cx, cy, 20 * scale)
		lg.setColor(0.68, 0.71, 0.76, 0.9 * alpha)
		lg.arc("line", cx, cy - 3 * scale, 7 * scale, pi, pi * 2)
		lg.rectangle("line", cx - 9 * scale, cy - 3 * scale, 18 * scale, 14 * scale, 3 * scale)
	elseif kind == "newly-unlocked" or kind == "newly_unlocked" then
		lg.setColor(1, 0.86, 0.3, alpha)
		lg.circle("line", cx, cy, radius)
		for i = 0, 3 do
			local angle = i * pi / 2 + pi / 4
			local x, y = cx + math.cos(angle) * 27 * scale, cy + math.sin(angle) * 27 * scale
			lg.line(x - 3 * scale, y, x + 3 * scale, y)
			lg.line(x, y - 3 * scale, x, y + 3 * scale)
		end
	end
end

-- Stable public API: ID, center, scale, alpha, and optional visual state.
-- State may be a string or a table with a `kind` field.
function AbilityIcons.draw(abilityId, cx, cy, scale, alpha, state)
	scale = math.max(0.01, tonumber(scale) or 1)
	alpha = math.max(0, math.min(1, tonumber(alpha) or 1))
	cx, cy = tonumber(cx) or 0, tonumber(cy) or 0

	lg.push("all")
	local kind = stateName(state)
	local drawer = type(abilityId) == "string" and drawers[abilityId] or nil
	(drawer or unknown)(cx, cy, scale, (kind == "locked" or kind == "cooldown") and alpha * 0.58 or alpha)
	drawAccent(kind, cx, cy, scale, alpha)
	lg.pop()

	return drawer ~= nil
end

return AbilityIcons

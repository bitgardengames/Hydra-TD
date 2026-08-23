-- Deterministic, side-effect-free map generation for daily and seeded runs.
-- This module deliberately does not use love.math or math.random: generation
-- must not perturb combat/decorative random streams.
local MapDefs = require("world.map_defs")

local Generator = { VERSION = 1, PROFILE_ID = "standard_v1" }
local WIDTH, HEIGHT, ENTRANCE_X, EXIT_X = 32, 14, 5, 30
local MIN_Y, MAX_Y = 3, 11
local MODULUS, MULTIPLIER = 2147483647, 48271
local BIOMES = {"default", "autumn", "drylands", "highlands", "winter"}

local function hash(text)
	-- Keep every intermediate below 2^53 so integer results agree on Lua 5.1
	-- doubles and integer-enabled Lua versions alike.
	local value = 5381
	for i = 1, #text do
		value = (value * 131 + text:byte(i)) % MODULUS
	end
	return math.max(1, value)
end

local function newRng(seed)
	local state = math.max(1, math.floor(tonumber(seed) or hash(tostring(seed)))) % MODULUS
	return {
		nextInt = function(self, low, high)
			state = (state * MULTIPLIER) % MODULUS
			return low + (state % (high - low + 1))
		end,
	}
end

local function expandPath(points)
	local tiles, occupied = {}, {}
	for i = 1, #points - 1 do
		local a, b = points[i], points[i + 1]
		local dx = b[1] == a[1] and 0 or (b[1] > a[1] and 1 or -1)
		local dy = b[2] == a[2] and 0 or (b[2] > a[2] and 1 or -1)
		local x, y = a[1], a[2]
		if i == 1 then
			tiles[#tiles + 1], occupied[x .. "," .. y] = {x, y}, true
		end
		while x ~= b[1] or y ~= b[2] do
			x, y = x + dx, y + dy
			local key = x .. "," .. y
			if occupied[key] then return nil, "repeated_path_tile" end
			tiles[#tiles + 1], occupied[key] = {x, y}, true
		end
	end
	return tiles, occupied
end

local function pathLength(points)
	local n = 0
	for i = 1, #points - 1 do
		n = n + math.abs(points[i + 1][1] - points[i][1])
			+ math.abs(points[i + 1][2] - points[i][2])
	end
	return n
end

local function percentile(values, fraction)
	table.sort(values)
	return values[math.max(1, math.floor((#values - 1) * fraction + 1.5))]
end

-- The envelope follows the shipped content rather than duplicating balance
-- constants. Looped legacy maps are ignored because the MVP forbids repeats.
function Generator.authoredProfile()
	local lengths = {}
	for _, def in ipairs(MapDefs) do
		if expandPath(def.path) then lengths[#lengths + 1] = pathLength(def.path) end
	end
	return {
		id = Generator.PROFILE_ID,
		minLength = percentile(lengths, 0.20),
		maxLength = percentile(lengths, 0.80),
		minPoints = 7, maxPoints = 11,
		minSegment = 2,
	}
end

local function metrics(def)
	local tiles, occupied = expandPath(def.path)
	if not tiles then return nil end
	local adjacent, thirds = {}, {0, 0, 0}
	for i, tile in ipairs(tiles) do
		local third = math.min(3, math.floor((i - 1) * 3 / #tiles) + 1)
		for dx = -1, 1 do for dy = -1, 1 do
			local x, y = tile[1] + dx, tile[2] + dy
			local key = x .. "," .. y
			if x >= 1 and x <= WIDTH and y >= 1 and y <= HEIGHT
				and not occupied[key] and not adjacent[key] then
				adjacent[key] = true
				thirds[third] = thirds[third] + 1
			end
		end end
	end
	local count = 0
	for _ in pairs(adjacent) do count = count + 1 end
	return {pathLength = #tiles - 1, pathTiles = #tiles, usefulSites = count,
		coverageIndex = count / math.max(1, #tiles - 1), usefulSitesByThird = thirds}
end

function Generator.validate(def, profile)
	profile = profile or Generator.authoredProfile()
	if type(def) ~= "table" or type(def.path) ~= "table" then return false, "missing_path" end
	if #def.path < profile.minPoints or #def.path > profile.maxPoints then return false, "control_point_count" end
	if def.path[1][1] ~= ENTRANCE_X or def.path[#def.path][1] ~= EXIT_X then return false, "entrance_or_exit" end
	for i, point in ipairs(def.path) do
		if point[1] % 1 ~= 0 or point[2] % 1 ~= 0 or point[1] < 1 or point[1] > WIDTH
			or point[2] < MIN_Y or point[2] > MAX_Y then return false, "point_bounds" end
		if i < #def.path then
			local nextPoint = def.path[i + 1]
			if (point[1] == nextPoint[1]) == (point[2] == nextPoint[2]) then return false, "non_orthogonal_segment" end
			if math.abs(point[1] - nextPoint[1]) + math.abs(point[2] - nextPoint[2]) < profile.minSegment then
				return false, "short_segment"
			end
		end
	end
	local tiles, occupiedOrReason = expandPath(def.path)
	if not tiles then return false, occupiedOrReason end
	local report = metrics(def)
	if report.pathLength < profile.minLength or report.pathLength > profile.maxLength then return false, "path_length", report end
	if math.min(report.usefulSitesByThird[1], report.usefulSitesByThird[2], report.usefulSitesByThird[3]) < 3 then
		return false, "route_third_without_sites", report
	end
	for _, water in ipairs(def.water or {}) do
		local radius = math.max(1, math.floor(water[3] or 1))
		for x = water[1], water[1] + radius - 1 do for y = water[2], water[2] + radius - 1 do
			if occupiedOrReason[x .. "," .. y] then return false, "water_on_path", report end
		end end
	end
	return true, nil, report
end

local function partitionHorizontal(rng)
	local widths, remaining = {}, EXIT_X - ENTRANCE_X
	for i = 1, 4 do
		local maxWidth = remaining - (5 - i) * 2
		widths[i] = rng:nextInt(2, math.min(7, maxWidth))
		remaining = remaining - widths[i]
	end
	widths[5] = remaining
	if widths[5] < 2 then return nil end
	return widths
end

local function candidate(seed, attempt, profile)
	local rng = newRng((seed + attempt * 104729) % MODULUS)
	local widths = partitionHorizontal(rng)
	if not widths then return nil end
	local x, y = ENTRANCE_X, rng:nextInt(MIN_Y, MAX_Y)
	local points = {{x, y}}
	for i = 1, 5 do
		x = x + widths[i]
		points[#points + 1] = {x, y}
		if i < 5 then
			local choices = {}
			for row = MIN_Y, MAX_Y do
				if math.abs(row - y) >= 2 then choices[#choices + 1] = row end
			end
			y = choices[rng:nextInt(1, #choices)]
			points[#points + 1] = {x, y}
		end
	end
	local def = {path = points, biome = BIOMES[rng:nextInt(1, #BIOMES)]}
	local _, occupied = expandPath(points)
	local water = {}
	for _ = 1, rng:nextInt(1, 3) do
		for _ = 1, 20 do
			local size = rng:nextInt(1, 4) == 1 and 2 or 1
			local wx, wy = rng:nextInt(6, 29 - size), rng:nextInt(1, HEIGHT - size + 1)
			local clear = true
			for xx = wx, wx + size - 1 do for yy = wy, wy + size - 1 do
				if occupied[xx .. "," .. yy] then clear = false end
			end end
			if clear then water[#water + 1] = {wx, wy, size}; break end
		end
	end
	def.water = water
	return def
end

function Generator.generate(runSeed, options)
	options = options or {}
	local readable = tostring(runSeed or "0")
	local tuple = table.concat({Generator.VERSION, options.mode or "seeded", readable,
		options.modifierSet or "none"}, "|")
	local seed, profile = hash(tuple), options.profile or Generator.authoredProfile()
	local best, bestReport, bestAttempt, bestScore
	for attempt = 1, options.attempts or 64 do
		local def = candidate(seed, attempt, profile)
		local valid, _, report = Generator.validate(def, profile)
		if valid then
			local center = (profile.minLength + profile.maxLength) / 2
			local score = report.usefulSites - math.abs(report.pathLength - center) * 2
			if not bestScore or score > bestScore then best, bestReport, bestAttempt, bestScore = def, report, attempt, score end
		end
	end
	-- This authored fallback is structurally prevalidated and remains deterministic.
	if not best then
		local choices = {}
		for _, def in ipairs(MapDefs) do if Generator.validate(def, profile) then choices[#choices + 1] = def end end
		best = choices[(seed % #choices) + 1]
		bestReport, bestAttempt = metrics(best), 0
	end
	local result = {id = options.id or ((options.mode == "daily" and "daily-" or "random-") .. readable),
		nameKey = options.nameKey or "map.random", biome = best.biome, path = {}, water = {}}
	for i, p in ipairs(best.path) do result.path[i] = {p[1], p[2]} end
	for i, w in ipairs(best.water or {}) do result.water[i] = {w[1], w[2], w[3]} end
	result.generation = {version = Generator.VERSION, profile = profile.id, seed = seed,
		attempt = bestAttempt, tuple = tuple, fallback = bestAttempt == 0, metrics = bestReport}
	return result
end

Generator.hashSeed = hash
Generator.newRng = newRng
Generator.metrics = metrics
return Generator

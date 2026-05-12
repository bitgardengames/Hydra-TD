local Theme = require("core.theme")

local lg = love.graphics
local floor = math.floor

local Glyphs = {}

local cache = {}
local registry = {}
-- Base visual parameters
local BASE_H = 24
local RADIUS = 2

-- Colors
local colorFill = Theme.ui.panel

-- Register a glyph renderer
function Glyphs.register(id, def)
	-- Allow shorthand: register(id, function() end)
	if type(def) == "function" then
		registry[id] = {draw = def}
	else
		registry[id] = def
	end
end

local function resolveGlyph(id)
	return id
end

local function buildCanvas(id, scale)
	scale = scale or 1

	-- Ensure sub-cache exists for this id
	local idCache = cache[id]

	if not idCache then
		idCache = {}
		cache[id] = idCache
	end

	-- Return cached scale if present
	if idCache[scale] then
		return idCache[scale]
	end

	local h = floor(BASE_H * scale)
	local def = registry[id]

	local w

	if def and def.getWidth then
		w = floor(def.getWidth(h, scale))
	else
		w = floor((BASE_H * 1.4) * scale)
	end

	local canvas = lg.newCanvas(w, h, {msaa = 8})

	lg.push("all")
	lg.setCanvas(canvas)
	lg.clear(0, 0, 0, 0)

	if def and def.draw then
		def.draw(w, h, scale)
	else
		lg.setColor(colorFill)
		lg.rectangle("fill", 0, 0, w, h, RADIUS * scale, RADIUS * scale)
	end

	lg.setCanvas()
	lg.pop()

	local entry = {canvas = canvas, w = w, h = h}

	idCache[scale] = entry

	return entry
end

function Glyphs.draw(id, x, y, opts)
	local scale = (opts and opts.scale) or 1
	local resolved = resolveGlyph(id)
	local g = buildCanvas(resolved, scale)

	lg.setColor(1, 1, 1, 1)
	lg.draw(g.canvas, floor(x + 0.5), floor(y + 0.5))
end

function Glyphs.getSize(id, scale)
	scale = scale or 1
	local g = buildCanvas(id, scale)
	return g.w, g.h
end

-- Sprite sheet export
function Glyphs.exportSheet(path, opts)
	opts = opts or {}

	local scale = opts.scale or 1
	local cols = opts.cols or 8
	local spacing = opts.spacing or 6

	local ids = {}

	for id in pairs(registry) do
		ids[#ids + 1] = id
	end

	if #ids == 0 then
		print("[Glyphs] exportSheet skipped (no glyphs registered)")

		return
	end

	table.sort(ids)

	-- Measure widest glyph
	local maxW = 0
	local cellH = floor(BASE_H * scale)

	for _, id in ipairs(ids) do
		local g = buildCanvas(id, scale)
		maxW = math.max(maxW, g.w)
	end

	local cellW = maxW
	local cellH = floor(BASE_H * scale)

	local rows = math.ceil(#ids / cols)
	local sheetW = cols * cellW + (cols - 1) * spacing
	local sheetH = rows * cellH + (rows - 1) * spacing

	local canvas = lg.newCanvas(sheetW, sheetH)

	lg.push("all")
	lg.setCanvas(canvas)
	lg.clear(0, 0, 0, 0)

	for i, id in ipairs(ids) do
		local col = (i - 1) % cols
		local row = floor((i - 1) / cols)

		local x = col * (cellW + spacing)
		local y = row * (cellH + spacing)

		Glyphs.draw(id, x, y, { scale = scale })
	end

	lg.setCanvas()
	lg.pop()

	canvas:newImageData():encode("png", path)
end

return Glyphs

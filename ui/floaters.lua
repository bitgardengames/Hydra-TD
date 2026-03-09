local Camera = require("core.camera")
local Text = require("ui.text")

local floaters = {}
local pool = {}

local floor = math.floor
local max = math.max
local min = math.min
local random = love.math.random
local lg = love.graphics

local function add(x, y, text, r, g, b, drift)
	local n = #pool
	local f = pool[n]

	if f then
		pool[n] = nil
	else
		f = {}
	end

	y = floor(y + 0.5)

	-- Base position
	local baseX

	if drift == true then
		f.drift = (random() * 2 - 1) * (14 + random() * 6)
		baseX = floor(x + 0.5 + random(-4, 4))
	else
		f.drift = 0
		baseX = floor(x + 0.5)
	end

	f.baseX = baseX
	f.x = baseX
	f.y = y
	f.startY = y

	-- Motion
	f.rise = 18 + random() * 6

	-- Text
	f.text = text

	-- Timing
	f.t = 0
	f.life = 1.25

	-- Color
	f.r = r or 1
	f.g = g or 1
	f.b = b or 1

	floaters[#floaters + 1] = f
end

local function update(dt)
	for i = #floaters, 1, -1 do
		local f = floaters[i]

		f.t = f.t + dt
		local p = f.t / f.life

		if p >= 1 then
			floaters[i] = floaters[#floaters]
			floaters[#floaters] = nil
			pool[#pool + 1] = f
		else
			local q = 1 - p
			local ease = 1 - q * q * q

			-- Vertical rise
			f.y = f.startY - ease * f.rise

			-- Horizontal drift (eases out)
			f.x = f.baseX + f.drift * (1 - q * q)
		end
	end
end

local function draw()
	local font = lg.getFont()

	for i = 1, #floaters do
		local f = floaters[i]

		local p = f.t / f.life

		-- Fade after 20% life
		local alpha = 1 - max(0, (p - 0.2) / 0.8)

		-- Pop scale (short window only)
		local scale = 1
		if p < 0.12 then
			local pop = 1 - (p / 0.12)
			pop = pop * pop
			scale = 1 + pop * 0.35
		end

		local sx, sy = Camera.worldToScreen(f.x, f.y)

		-- Pixel snap
		sx = floor(sx + 0.5)
		sy = floor(sy + 0.5)

		local textW = font:getWidth(f.text) * scale
		local leftX = floor(sx - textW * 0.5 + 0.5)

		lg.setColor(f.r, f.g, f.b, alpha)

		Text.printShadow(f.text, leftX, sy, {sx = scale, sy = scale})
	end
end

function clear()
	for i = #floaters, 1, -1 do
		pool[#pool + 1] = floaters[i]
		floaters[i] = nil
	end
end

return {
	floaters = floaters,
	add = add,
	update = update,
	draw = draw,
	clear = clear,
}
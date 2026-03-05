local Camera = require("core.camera")
local Text = require("ui.text")

local floaters = {}
local pool = {}

local floor = math.floor
local max = math.max
local min = math.min
local random = love.math.random
local lg = love.graphics

local function add(x, y, text, r, g, b)
	local n = #pool
	local f = pool[n]

	if f then
		pool[n] = nil
	else
		f = {}
	end

	y = floor(y + 0.5)

	f.x = floor(x + 0.5 + random(-4, 4)) -- Small horizontal spawn jitter prevents perfect stacking
	f.y = y
	f.startY = y
	f.rise = 18 + random() * 6

	f.text = text
	f.t = 0
	f.life = 1.25

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

			f.y = f.startY - ease * f.rise
		end
	end
end

local function draw()
	local font = lg.getFont()

	for i = 1, #floaters do
		local f = floaters[i]

		local p = f.t / f.life

		-- Fade after 20% of life
		local alpha = 1 - max(0, (p - 0.2) / 0.8)

		-- Premium "pop scale"
		local pop = 1 - min(p / 0.12, 1)
		local scale = 1 + pop * 0.35

		local sx, sy = Camera.worldToScreen(f.x, f.y)

		local textW = font:getWidth(f.text) * scale
		local leftX = floor(sx - textW * 0.5 + 0.5)

		sy = floor(sy + 0.5)

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
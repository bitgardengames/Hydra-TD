local floaters = {}

local function addFloater(x, y, text, r, g, b)
	table.insert(floaters, {
		x = x,
		y = y,
		startY = y,
		rise = 22 + math.random() * 6,
		text = text,
		t = 0,
		life = 1,
		r = r or 1,
		g = g or 1,
		b = b or 1,
	})
end

local function updateFloaters(dt)
	for i = #floaters, 1, -1 do
		local f = floaters[i]

		f.t = f.t + dt

		local p = f.t / f.life

		if p >= 1 then
			table.remove(floaters, i)
		else
			local ease = 1 - (1 - p) * (1 - p)

			f.y = f.startY - ease * f.rise
		end
	end
end

function clear()
	for i = #floaters, 1, -1 do
		floaters[i] = nil
	end
end

return {
	floaters = floaters,
	addFloater = addFloater,
	updateFloaters = updateFloaters,
	clear = clear,
}
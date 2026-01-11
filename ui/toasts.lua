local toasts = {}

local function addToast(x, y, text, r, g, b)
	table.insert(toasts, {
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

local function updateToasts(dt)
	for i = #toasts, 1, -1 do
		local f = toasts[i]

		f.t = f.t + dt

		local p = f.t / f.life

		if p >= 1 then
			table.remove(toasts, i)
		else
			local ease = 1 - (1 - p) * (1 - p)

			f.y = f.startY - ease * f.rise
		end
	end
end

local function clear()
	for i = #toasts, 1, -1 do
		toasts[i] = nil
	end
end

return {
	toasts = toasts,
	addToast = addToast,
	updateToasts = updateToasts,
	clear = clear,
}
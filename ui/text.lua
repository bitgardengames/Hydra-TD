local Text = {}

local lg = love.graphics

function Text.printShadow(text, x, y, opts)
	opts = opts or {}

	local ox = opts.ox or 1
	local oy = opts.oy or 1
	local alphaMul = opts.alpha or 0.4
	local shadowColor = opts.shadowColor or {0, 0, 0}

	local r, g, b, a = lg.getColor()

	-- Shadow
	lg.setColor(shadowColor[1], shadowColor[2], shadowColor[3], a * alphaMul)
	lg.print(text, x + ox, y + oy)

	-- Main
	lg.setColor(r, g, b, a)
	lg.print(text, x, y)
end

function Text.printfShadow(text, x, y, w, align, opts)
	opts = opts or {}

	local ox = opts.ox or 1
	local oy = opts.oy or 1
	local alphaMul = opts.alpha or 0.4
	local shadowColor = opts.shadowColor or {0, 0, 0}

	local r, g, b, a = lg.getColor()

	-- Shadow
	lg.setColor(shadowColor[1], shadowColor[2], shadowColor[3], a * alphaMul)
	lg.printf(text, x + ox, y + oy, w, align)

	-- Main
	lg.setColor(r, g, b, a)
	lg.printf(text, x, y, w, align)
end

return Text
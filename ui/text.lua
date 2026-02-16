local Theme = require("core.theme")

local Text = {}

local lg = love.graphics
local getColor = lg.getColor

local colorShadow = Theme.ui.shadow

local sr, sg, sb = colorShadow[1], colorShadow[2], colorShadow[3]

function Text.printShadow(text, x, y, opts)
	opts = opts or {}

	local ox = opts.ox or 1
	local oy = opts.oy or 1

	local r, g, b, a = getColor()

	-- Shadow
	lg.setColor(sr, sg, sb, a)
	lg.print(text, x + ox, y + oy)

	-- Main
	lg.setColor(r, g, b, a)
	lg.print(text, x, y)
end

function Text.printfShadow(text, x, y, w, align, opts)
	opts = opts or {}

	local ox = opts.ox or 1
	local oy = opts.oy or 1

	local r, g, b, a = getColor()

	-- Shadow
	lg.setColor(sr, sg, sb, a)
	lg.printf(text, x + ox, y + oy, w, align)

	-- Main
	lg.setColor(r, g, b, a)
	lg.printf(text, x, y, w, align)
end

return Text
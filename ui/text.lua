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

	local r = opts.r or 0
	local sx = opts.sx or 1
	local sy = opts.sy or sx
	local kx = opts.kx or 0
	local ky = opts.ky or 0

	local cr, cg, cb, ca = getColor()

	-- Shadow
	lg.setColor(sr, sg, sb, ca)
	lg.print(text, x + ox, y + oy, r, sx, sy, kx, ky)

	-- Main
	lg.setColor(cr, cg, cb, ca)
	lg.print(text, x, y, r, sx, sy, kx, ky)
end

function Text.printShadowScaled(text, x, y, sx, sy)
	sx = sx or 1
	sy = sy or sx

	local cr, cg, cb, ca = getColor()

	-- Shadow
	lg.setColor(sr, sg, sb, ca)
	lg.print(text, x + 1, y + 1, 0, sx, sy, 0, 0)

	-- Main
	lg.setColor(cr, cg, cb, ca)
	lg.print(text, x, y, 0, sx, sy, 0, 0)
end

function Text.printfShadow(text, x, y, w, align, opts)
	opts = opts or {}

	local ox = opts.ox or 1
	local oy = opts.oy or 1

	local cr, cg, cb, ca = getColor()

	-- Shadow
	lg.setColor(sr, sg, sb, ca)
	lg.printf(text, x + ox, y + oy, w, align)

	-- Main
	lg.setColor(cr, cg, cb, ca)
	lg.printf(text, x, y, w, align)
end

return Text

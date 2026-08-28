local State = require("core.state")
local Enemies = require("world.enemies")

local min, max = math.min, math.max
local EYE_SMOOTH = 0.35
local function lerp(a, b, t) return a + (b - a) * t end

-- Central owner of render-only fields attached to enemies: rx/ry, prevRX/prevRY,
-- eyeDX/eyeDY, and rAnimT. Simulation code must not read these fields.
local function prepare(enemies, alpha)
	enemies = enemies or Enemies.enemies
	local a = max(0, min(1, alpha == nil and (State.renderAlpha or 0) or alpha))
	for i = 1, #enemies do
		local e = enemies[i]
		local ex, ey = e.x, e.y
		local oldRX, oldRY = e.rx or ex, e.ry or ey
		local baseX = lerp(e.prevX or ex, ex, a)
		local baseY = lerp(e.prevY or ey, ey, a)
		local nx, ny = e.nudgeX or 0, e.nudgeY or 0
		local targetX = baseX + lerp(e.prevNudgeX or nx, nx, a)
		local targetY = baseY + lerp(e.prevNudgeY or ny, ny, a)
		e.rx, e.ry, e.prevRX, e.prevRY = targetX, targetY, oldRX, oldRY
		local rawDX, rawDY = targetX - oldRX, targetY - oldRY
		local eyeDX, eyeDY = e.eyeDX or rawDX, e.eyeDY or rawDY
		e.eyeDX = eyeDX + (rawDX - eyeDX) * EYE_SMOOTH
		e.eyeDY = eyeDY + (rawDY - eyeDY) * EYE_SMOOTH
		e.rAnimT = lerp(e.prevAnimT or e.animT, e.animT, a)
	end
end
return { prepare = prepare }

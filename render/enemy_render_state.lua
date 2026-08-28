local State = require("core.state")
local Enemies = require("world.enemies")

local min, max, exp = math.min, math.max, math.exp
-- Matches the old 0.35 response at 60 Hz, without making draw-call count a clock.
local EYE_RESPONSE_RATE = -math.log(1 - 0.35) * 60
local function lerp(a, b, t) return a + (b - a) * t end

-- Kept here rather than on the enemy so presentation bookkeeping cannot leak
-- into simulation state. A timestamp makes multiple world passes in one frame
-- idempotent (for example, a trailer export pass followed by the screen pass).
local preparedAt = setmetatable({}, { __mode = "k" })

-- Central owner of render-only fields attached to enemies: rx/ry, prevRX/prevRY,
-- eyeDX/eyeDY, and rAnimT. Simulation code must not read these fields.
local function prepare(enemies, alpha, dt, timestamp)
	enemies = enemies or Enemies.enemies
	local a = max(0, min(1, alpha == nil and (State.renderAlpha or 0) or alpha))
	local presentationDt = max(0, dt or 0)
	local eyeBlend = 1 - exp(-EYE_RESPONSE_RATE * presentationDt)
	for i = 1, #enemies do
		local e = enemies[i]
		if timestamp == nil or preparedAt[e] ~= timestamp then
			preparedAt[e] = timestamp
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
			e.eyeDX = eyeDX + (rawDX - eyeDX) * eyeBlend
			e.eyeDY = eyeDY + (rawDY - eyeDY) * eyeBlend
			e.rAnimT = lerp(e.prevAnimT or e.animT, e.animT, a)
		end
	end
end
return { prepare = prepare }

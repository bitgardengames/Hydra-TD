local State = require("core.state")
local Enemies = require("world.enemies")

local min, max, exp = math.min, math.max, math.exp
-- Matches the old 0.35 response at 60 Hz, without making draw-call count a clock.
local EYE_RESPONSE_RATE = -math.log(1 - 0.35) * 60
local NUDGE_IDLE_EPS = 1e-3
local INV_SPAWN_FADE_DUR = 1 / 0.12
local INV_EXIT_FADE_DUR = 1 / 0.10
local function lerp(a, b, t) return a + (b - a) * t end

-- Kept here rather than on the enemy so presentation bookkeeping cannot leak
-- into simulation state. A timestamp makes multiple world passes in one frame
-- idempotent (for example, a trailer export pass followed by the screen pass).
local preparedAt = setmetatable({}, { __mode = "k" })

-- Central owner of presentation-only fields attached to enemies: rx/ry,
-- prevRX/prevRY, eyeDX/eyeDY, rAnimT, and nudge positions/targets. Only the
-- simulation-owned prevX/prevY -> x/y transition is sampled with renderAlpha.
-- Simulation code must not read the presentation-only fields.
local function prepare(enemies, alpha, dt, timestamp)
	enemies = enemies or Enemies.enemies
	local a = max(0, min(1, alpha == nil and (State.renderAlpha or 0) or alpha))
	local presentationDt = max(0, dt or 0)
	local eyeBlend = 1 - exp(-EYE_RESPONSE_RATE * presentationDt)
	for i = 1, #enemies do
		local e = enemies[i]
		if timestamp == nil or preparedAt[e] ~= timestamp then
			preparedAt[e] = timestamp
			-- These fields are presentation-only. In particular, nudges never feed
			-- back into e.x/e.y, spatial queries, path progress, or escape checks.
			e.hitSquash = max(0, (e.hitSquash or 0) - presentationDt)
			e.healthBarHitTimer = max(0, (e.healthBarHitTimer or 0) - presentationDt)
			e.hitFlash = max(0, (e.hitFlash or 0) - presentationDt)
			e.regenVisualPulse = max(0, (e.regenVisualPulse or 0) - presentationDt)
			if e.face ~= "normal" then
				e.faceT = (e.faceT or 0) + presentationDt
				if e.faceT >= (e.faceDur or 0) then e.face = "normal" end
			end
			e.spawnFade = max(0, (e.spawnFade or 0) - presentationDt)
			local alphaIn = e.spawnFade > 0 and 1 - e.spawnFade * INV_SPAWN_FADE_DUR or 1
			local alphaOut = e.exitFade and max(0, e.exitFade * INV_EXIT_FADE_DUR) or 1
			e.alpha = min(alphaIn, alphaOut)

			e.prevAnimT = e.animT or 0
			e.animT = (e.animT or 0) + presentationDt * (e.speed or 0) * 0.03
			local tx, ty = e.nudgeTargetX or 0, e.nudgeTargetY or 0
			local nx, ny = e.nudgeX or 0, e.nudgeY or 0
			if math.abs(tx) > NUDGE_IDLE_EPS or math.abs(ty) > NUDGE_IDLE_EPS
				or math.abs(nx) > NUDGE_IDLE_EPS or math.abs(ny) > NUDGE_IDLE_EPS then
				local decay = exp(-(e.nudgeTargetK or 0) * presentationDt)
				local follow = 1 - exp(-(e.nudgeFollowK or 0) * presentationDt)
				tx, ty = tx * decay, ty * decay
				e.nudgeTargetX, e.nudgeTargetY = tx, ty
				e.nudgeX, e.nudgeY = nx + (tx - nx) * follow, ny + (ty - ny) * follow
			else
				e.nudgeTargetX, e.nudgeTargetY, e.nudgeX, e.nudgeY = 0, 0, 0, 0
			end
			local ex, ey = e.x, e.y
			local oldRX, oldRY = e.rx or ex, e.ry or ey
			local baseX = lerp(e.prevX or ex, ex, a)
			local baseY = lerp(e.prevY or ey, ey, a)
			local nx, ny = e.nudgeX or 0, e.nudgeY or 0
			local targetX = baseX + nx
			local targetY = baseY + ny
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

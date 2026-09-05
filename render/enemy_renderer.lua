local Theme = require("core.theme")
local State = require("core.state")
local Enemies = require("world.enemies")
local EnemyHealthVisibility = require("render.enemy_health_visibility")
local lg = love.graphics
local sin, min, max, abs, cos = math.sin, math.min, math.max, math.abs, math.cos
local pi, HALF_PI = math.pi, math.pi / 2
local outlineColor = Theme.outline.color
local enemyShadow, enemyBody, enemyFace = Theme.enemy.shadow, Theme.enemy.body, Theme.enemy.face
local colorSlow = Theme.projectiles.slow
local colorSelected = Theme.ui.selected
local lighting = Theme.lighting
local darkMul, highlightOffset, highlightScale = lighting.shadowMul, lighting.highlightOffset, lighting.highlightScale
local outR, outG, outB = outlineColor[1], outlineColor[2], outlineColor[3]
local eR, eG, eB = enemyBody[1], enemyBody[2], enemyBody[3]
local esR, esG, esB, esA = enemyShadow[1], enemyShadow[2], enemyShadow[3], enemyShadow[4]
local efR, efG, efB = enemyFace[1], enemyFace[2], enemyFace[3]
local sr, sg, sb = colorSlow[1], colorSlow[2], colorSlow[3]
local selR, selG, selB = colorSelected[1], colorSelected[2], colorSelected[3]
local outlineWidth, EYE_DEADZONE, HIT_SQUASH_DUR = Theme.outline.width, 0.03, 0.12

-- A broken circular halo gives Regenerators a compact, readable silhouette
-- without adding detached markers that could be confused with Summoners.
local function drawRegeneratorArcs(ix, iy, radius, rotation)
	for n = 0, 2 do
		local angle = rotation + n * pi * 2 / 3
		lg.arc("line", "open", ix, iy, radius, angle - 0.43, angle + 0.43)
	end
end

local function drawEnemy(e)
	local ix = e.rx
	local iy = e.ry
	local animT = e.rAnimT or 0
	local enemyAlpha = e.alpha
	if e.phaseActive then enemyAlpha = enemyAlpha * 0.28 end

	e.drawX = ix
	e.drawY = iy
	local r = e.radius
	local squash = min(1, (e.hitSquash or 0) / HIT_SQUASH_DUR)
	squash = squash * (e.hitSquashStrength or 1)

	-- Keep the shadow anchored to the ground while the enemy body reacts to a hit.
	-- Drawing it before the squash transform also keeps its footprint unchanged.
	if e.shadow then
		local shadowAlpha = esA * (enemyAlpha * enemyAlpha)

		lg.setColor(esR, esG, esB, shadowAlpha)
		lg.ellipse("fill", ix, iy + e.radius, e.radius * 1.4, e.radius * 0.4)
	end

	-- Briefly compress the whole silhouette on impact, while widening it enough to
	-- preserve roughly the same visual mass. UI such as selection and health bars
	-- remains unscaled and readable.
	lg.push()
	lg.translate(ix, iy)
	lg.scale(1 + squash * 0.12, 1 - squash * 0.16)
	lg.translate(-ix, -iy)

	-- Mechanical silhouettes are deliberately geometric and remain legible without
	-- their colors: armor plates, regeneration halo, and war banner.
	if e.support then
		-- The banner trails opposite the Warcaller's horizontal facing. Mirror the
		-- whole standard so both its pole and cloth keep a consistent silhouette.
		local flagDirection = (e.eyeDX or 0) < 0 and 1 or -1
		local poleX = ix + flagDirection * r * 0.55
		lg.setColor(outR, outG, outB, enemyAlpha)
		lg.rectangle("fill", poleX - (flagDirection < 0 and 3 or 0), iy - r * 2.0, 3, r * 1.7)
		lg.polygon("fill", ix + flagDirection * r * 0.7, iy - r * 1.9,
			ix + flagDirection * r * 1.65, iy - r * 1.55,
			ix + flagDirection * r * 0.7, iy - r * 1.2)
	end
	if e.summon then
		local readiness = 1 - min(1, max(0, (e.summonTimer or 0) / e.summon.period))
		local orbitRadius = r + 7 - readiness * 3
		lg.setColor(0.72, 0.38, 0.95, (0.55 + readiness * 0.35) * enemyAlpha)
		for n = 0, 1 do
			local angle = animT * 1.8 + n * pi
			local sx = ix + cos(angle) * orbitRadius
			local sy = iy + sin(angle) * orbitRadius
			lg.polygon("fill", sx, sy - 4, sx + 4, sy, sx, sy + 4, sx - 4, sy)
		end
	end
	-- Boss archetypes need a readable silhouette of their own. In particular, the
	-- Summoner previously reused the plain round enemy body and could be mistaken
	-- for the first Grunt reinforcement promised by its preview.
	if e.kind == "boss_summoner" then
		local orbit = animT * 1.4
		lg.setColor(0.78, 0.45, 1, 0.85 * enemyAlpha)
		lg.setLineWidth(3)
		lg.circle("line", ix, iy, r + 8)
		for n = 0, 2 do
			local angle = orbit + n * pi * 2 / 3
			local sx = ix + cos(angle) * (r + 8)
			local sy = iy + sin(angle) * (r + 8)
			lg.polygon("fill", sx, sy - 4, sx + 4, sy, sx, sy + 4, sx - 4, sy)
		end
	elseif e.kind == "boss_vanguard" then
		lg.setColor(1, 0.66, 0.22, 0.8 * enemyAlpha)
		lg.setLineWidth(3)
		lg.line(ix - r - 9, iy - 5, ix - r - 3, iy, ix - r - 9, iy + 5)
		lg.line(ix + r + 9, iy - 5, ix + r + 3, iy, ix + r + 9, iy + 5)
	elseif e.kind == "boss_suppression" then
		lg.setColor(0.9, 0.25, 0.3, (0.55 + sin(animT * 2) * 0.15) * enemyAlpha)
		lg.setLineWidth(4)
		lg.arc("line", "open", ix, iy, r + 8, pi * 0.12, pi * 0.88)
	elseif e.kind == "boss_aegis" then
		local shieldAlpha = e.bossShieldActive and 0.95 or 0.38
		lg.setColor(0.3, 0.9, 1, shieldAlpha * enemyAlpha)
		lg.setLineWidth(e.bossShieldActive and 5 or 2)
		for n = 0, 2 do
			local a = -HALF_PI + n * pi * 2 / 3
			lg.arc("line", "open", ix, iy, r + 8, a - 0.62, a + 0.62)
		end
	elseif e.kind == "boss_ravager" then
		lg.setColor(1, 0.28, 0.18, (e.enraged and 0.95 or 0.5) * enemyAlpha)
		lg.setLineWidth(e.enraged and 4 or 2)
		local trail = e.enraged and 14 or 8
		lg.line(ix - r - trail, iy - 7, ix - r - 3, iy - 7)
		lg.line(ix - r - trail - 4, iy, ix - r - 3, iy)
		lg.line(ix - r - trail, iy + 7, ix - r - 3, iy + 7)
	elseif e.kind == "boss_phasewalker" then
		lg.setColor(0.38, 0.85, 1, (e.phaseActive and 0.95 or 0.55) * enemyAlpha)
		lg.setLineWidth(e.phaseActive and 4 or 2)
		lg.arc("line", "open", ix, iy, r + 8, pi * 0.08, pi * 0.92)
		lg.arc("line", "open", ix, iy, r + 8, pi * 1.08, pi * 1.92)
	elseif e.kind == "boss_gatecrasher" then
		local winding = e.lungeWindup ~= nil
		local dx, dy = e.eyeDX or 1, e.eyeDY or 0
		local pulse = 0.65 + sin(animT * 9) * 0.25
		lg.setColor(1, 0.46, 0.14, (winding and pulse or 0.45) * enemyAlpha)
		lg.setLineWidth(winding and 4 or 2)
		local tipX, tipY = ix + dx * (r + 19), iy + dy * (r + 19)
		local sideX, sideY = -dy * 7, dx * 7
		lg.line(ix + dx * (r + 4), iy + dy * (r + 4), tipX, tipY)
		lg.polygon("fill", tipX, tipY, tipX - dx * 9 + sideX, tipY - dy * 9 + sideY,
			tipX - dx * 9 - sideX, tipY - dy * 9 - sideY)
	end
	if e.kind == "bulwark" then
		lg.setColor(outR, outG, outB, enemyAlpha)
		for a = 0, 3 do
			local ang = a * HALF_PI + pi * 0.25
			local px, py = ix + cos(ang) * r, iy + sin(ang) * r
			lg.push(); lg.translate(px, py); lg.rotate(ang)
			lg.rectangle("fill", -r * 0.35, -r * 0.55, r * 0.7, r * 1.1, 2, 2); lg.pop()
		end
	elseif e.kind == "regenerator" then
		lg.setColor(outR, outG, outB, enemyAlpha)
		lg.setLineWidth(3)
		drawRegeneratorArcs(ix, iy, r + 4, animT * 0.08)
	end

    -- Boss Horns
    if e.boss then
        lg.setColor(outR, outG, outB, enemyAlpha)

        local hornW = e.radius * 0.60
        local hornH = e.radius * 0.82
        local hornY = iy - e.radius * 1.02

        lg.push()
        lg.translate(ix - e.radius * 0.46, hornY)
        lg.rotate(-0.26)
        lg.polygon("fill", 0, 0, -hornW, hornH * 0.5, -hornW, -hornH * 0.5)
        lg.pop()

        lg.push()
        lg.translate(ix + e.radius * 0.46, hornY)
        lg.rotate(0.26)
        lg.polygon("fill", 0, 0, hornW, -hornH * 0.5, hornW, hornH * 0.5)
        lg.pop()
    end

	-- Body outline
	lg.setColor(outR, outG, outB, enemyAlpha)
	lg.circle("fill", ix, iy, e.radius + 3)

	-- Body lighting (canonical system)
	-- Base (shadowed)
	lg.setColor(eR * darkMul, eG * darkMul, eB * darkMul, enemyAlpha)
	lg.circle("fill", ix, iy, r)

	-- Top highlight
	local hx = ix
	local hy = iy - r * highlightOffset
	local hr = r * highlightScale

	lg.setColor(eR, eG, eB, enemyAlpha)
	lg.circle("fill", hx, hy, hr)

    -- Hit flash
    if e.hitFlash > 0 then
        local a = min(1, e.hitFlash / 0.05)

        lg.setColor(0.92, 0.96, 1.0, a * 0.55)
        lg.circle("fill", ix, iy, e.radius)
    end

	-- Slow (frost shell + shards)
	if e.slowTimer > 0 then
		local pulse = 0.6 + sin(animT * 3.5) * 0.4
		local alpha = (0.35 + pulse * 0.25) * enemyAlpha

		-- Outer frost shell
		lg.setColor(sr, sg, sb, alpha)
		lg.circle("line", ix, iy, e.radius + 3)

		-- Subtle frost tint (desaturating feel)
		lg.setColor(sr * 0.7, sg * 0.85, sb, 0.10 * enemyAlpha)
		lg.circle("fill", ix, iy, e.radius - 3)
	end

	-- Poison inner rim (clean green accent)
	if e.poisonStacks and e.poisonStacks > 0 then
		local stacks = e.poisonStacks
		local intensity = min(1.0, 0.3 + stacks * 0.12)

		-- Slightly desaturated green (less neon)
		local pr = 0.35
		local pg = 0.85
		local pb = 0.40

		lg.setColor(pr, pg, pb, 0.6 * intensity * enemyAlpha)
		lg.circle("line", ix, iy, e.radius - 1)
	end

	-- Trait status glyphs provide state, not just identity. A recovering
	-- Regenerator lights an inner track of its permanent halo; boosted units carry
	-- backward speed streaks.
	if e.regeneration and e.regenDelay <= 0 and e.hp < e.maxHp and e.poisonStacks <= 0 then
		lg.setColor(0.55, 1, 0.55, enemyAlpha)
		lg.setLineWidth(2)
		drawRegeneratorArcs(ix, iy, r + 1, animT * 0.08)
		if e.regenVisualPulse > 0 then
			local a = e.regenVisualPulse / 0.28
			lg.circle("line", ix, iy, r + 4 + (1 - a) * 8)
		end
	end
	if (e.supportBoost or 1) > 1 then
		lg.setColor(1, 0.8, 0.35, 0.8 * enemyAlpha); lg.setLineWidth(2)
		lg.line(ix - r - 8, iy - 4, ix - r - 2, iy - 4)
		lg.line(ix - r - 10, iy + 3, ix - r - 2, iy + 3)
	end

	-- Eyes
	local eyeSep = e.radius * 0.38
	local eyeSize = max(1.6, e.radius * 0.16)
	local eyeY = iy - e.radius * 0.22

	lg.setColor(efR, efG, efB, enemyAlpha)

	if e.boss and e.dying then
		local bigR = eyeSize + 1
		local smallR = max(2, eyeSize - 1)
		local p = 1 - (e.deathT / e.deathDur)
		local pop = 1 + (1 - (p * p)) * 0.15

		lg.push()
		lg.translate(ix, eyeY)
		lg.scale(pop, pop)

		lg.setLineWidth(3)

		lg.setColor(0.9, 0.9, 0.9, enemyAlpha)
		lg.circle("fill", -eyeSep, 0, bigR + 1)

		lg.setColor(efR, efG, efB, enemyAlpha)

		lg.circle("line", -eyeSep, 0, bigR)
		lg.circle("fill", eyeSep, 0, smallR)

		lg.setLineWidth(1)
		lg.pop()
	elseif e.boss then
		local browLen = eyeSize * 2.5
		local browDrop = eyeSize * 0.85
		local browTension = sin(animT * 1.6) * 0.6
		local browLift = eyeSize * 0.35
		local browIn = eyeSize * 0.35

		if e.enraged then lg.setColor(1, 0.18, 0.12, enemyAlpha) end
		lg.circle("fill", ix - eyeSep, eyeY, eyeSize)
		lg.circle("fill", ix + eyeSep, eyeY, eyeSize)

		lg.setLineWidth(2)

		lg.line(ix - eyeSep - browLen * 0.65 + browIn, eyeY - browDrop - browLift, ix - eyeSep + browLen * 0.35 + browIn, eyeY - browDrop * 0.15 + browTension - browLift)
		lg.line(ix + eyeSep - browLen * 0.35 - browIn, eyeY - browDrop * 0.15 + browTension - browLift, ix + eyeSep + browLen * 0.65 - browIn, eyeY - browDrop - browLift)
	elseif e.face == "shock" then
		local bigR = eyeSize + 1
		local smallR = max(2, eyeSize - 1)
		local p = 1 - (e.faceT / e.faceDur)
		local pop = 1 + (1 - (p * p)) * 0.15

		lg.push()
		lg.translate(ix, eyeY)
		lg.scale(pop, pop)

		lg.setLineWidth(2)

		lg.setColor(0.9, 0.9, 0.9, enemyAlpha)
		lg.circle("fill", -eyeSep, 0, bigR + 1)

		lg.setColor(efR, efG, efB, enemyAlpha)

		lg.circle("line", -eyeSep, 0, bigR)
		lg.circle("fill", eyeSep, 0, smallR)

		lg.setLineWidth(1)
		lg.pop()
	else
		-- Eye direction follows movement
		local dx = e.eyeDX or (e.rx - (e.prevRX or e.rx))
		local dy = e.eyeDY or (e.ry - (e.prevRY or e.ry))

		local m = 1.2 -- max

		-- Tiny movement deadzone to avoid twitching when almost stationary.
		if abs(dx) < EYE_DEADZONE then dx = 0 end
		if abs(dy) < EYE_DEADZONE then dy = 0 end

		-- Soft clamp avoids hard pops at limit.
		dx = (dx * m) / (abs(dx) + m)
		dy = (dy * m) / (abs(dy) + m)

		lg.circle("fill", ix - eyeSep + dx, eyeY + dy, eyeSize)
		lg.circle("fill", ix + eyeSep + dx, eyeY + dy, eyeSize)
    end

	lg.pop()

	-- Selection Ring
	if State.selectedEnemy == e then
		lg.setColor(selR, selG, selB)
		lg.circle("line", ix, iy, e.radius + 4)
	end
end

local function drawEnemyHealth(e)
	if not EnemyHealthVisibility.isVisible(e, State.selectedEnemy) then
		return
	end

	local w = e.boss and 44 or 28
	local h = e.boss and 7 or 5

	local ix = e.drawX or e.rx
	local iy = e.drawY or e.ry

	local bx = ix - w / 2
	local by = iy - e.radius - (e.boss and 18 or 12)

	local t = max(0, e.hp / e.maxHp)
	-- Muted health color
	local r, g, b

	if t > 0.5 then
		local p = (t - 0.5) / 0.5

		r = 0.85 - p * 0.55
		g = 0.75 + p * 0.20
		b = 0.20
	else
		local p = t / 0.5

		r = 0.85
		g = 0.45 + p * 0.30
		b = 0.20
	end

	-- Background
	lg.setColor(0, 0, 0, 0.5)
	lg.rectangle("fill", bx, by, w, h, 3, 3)
	local drawSubmissions = 1

	local fillW = w * t

	if fillW > 0 then
		local minW = 4
		local visibleW = max(fillW, minW)

		local alphaScale = 1

		if t < 0.10 then
			alphaScale = t / 0.10
		end

		local radius = min(3, visibleW * 0.5, h * 0.5)

		-- Base
		lg.setColor(r * darkMul, g * darkMul, b * darkMul, 0.9 * alphaScale)
		lg.rectangle("fill", bx, by, visibleW, h, radius, radius)
		drawSubmissions = drawSubmissions + 1

		-- Highlight
		local hw = visibleW * 0.92
		local hh = h * highlightScale
		local hx = bx + visibleW * 0.5
		local hy = by + (hh * 0.5)

		-- Clamp height so it never spills out the bar
		if hh > h then
			hh = h
		end

		lg.setColor(r, g, b, 0.9 * alphaScale)
		lg.rectangle("fill", hx - hw * 0.5, hy - hh * 0.5, hw, hh, radius)
		drawSubmissions = drawSubmissions + 1
	end

	EnemyHealthVisibility.recordBar(drawSubmissions)
end

-- Draw all enemies
local function drawEnemies()
	local enemies = Enemies.enemies
	EnemyHealthVisibility.beginFrame()

	lg.setLineWidth(2)


	-- Draw bodies
	for i = 1, #enemies do
		local e = enemies[i]

		drawEnemy(e)
	end

	-- Draw health bars above bodies
	for i = 1, #enemies do
		local e = enemies[i]

		drawEnemyHealth(e)
	end

	lg.setLineWidth(1)
end

-- Build the render-only enemy used by UI portraits. Keeping this here ensures
-- cards use the same silhouette code as enemies in the world without registering
-- a fake enemy with simulation, targeting, or spatial systems.
local function newEnemyPortrait(kind)
	local def = require("world.enemy_defs")[kind]
	if not def then return nil end

	return {
		kind = kind,
		radius = def.radius,
		boss = def.boss or false,
		alpha = 1,
		rx = 0, ry = 0, prevRX = 0, prevRY = 0,
		eyeDX = 0.8, eyeDY = 0,
		rAnimT = 0,
		hitSquash = 0,
		hitFlash = 0,
		shadow = false,
		portrait = true,
		support = def.support,
		supportPulse = 0,
		summon = def.summon,
		summonTimer = def.summon and def.summon.period or 0,
		regeneration = def.regeneration,
		bossShield = def.bossShield,
		bossShieldActive = false,
		enrage = def.enrage,
		enraged = false,
		phase = def.phase,
		phaseActive = false,
		regenDelay = 1,
		hp = def.hp,
		maxHp = def.hp,
		poisonStacks = 0,
		slowTimer = 0,
		supportBoost = 1,
		face = "normal",
	}
end

local function drawEnemyPortrait(enemy, x, y, animT)
	if not enemy then return end

	enemy.rx, enemy.ry = x, y
	enemy.rAnimT = animT or 0
	if enemy.support then
		enemy.supportPulse = (animT or 0) % enemy.support.pulsePeriod
	end
	if enemy.summon then
		enemy.summonTimer = ((animT or 0) * 0.7) % enemy.summon.period
	end
	drawEnemy(enemy)
end

return { drawEnemy = drawEnemy, drawEnemies = drawEnemies, newEnemyPortrait = newEnemyPortrait, drawEnemyPortrait = drawEnemyPortrait, getEnemyHealthRenderCounters = EnemyHealthVisibility.getCounters }

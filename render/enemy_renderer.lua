local Theme = require("core.theme")
local State = require("core.state")
local Enemies = require("world.enemies")
local EnemyDecorators = require("render.enemy_decorators")
local EnemyHealthVisibility = require("render.enemy_health_visibility")
local lg = love.graphics
local min, max = math.min, math.max
local enemyShadow, enemyBody = Theme.enemy.shadow, Theme.enemy.body
local colorSelected = Theme.ui.selected
local lighting = Theme.lighting
local darkMul, highlightOffset, highlightScale = lighting.shadowMul, lighting.highlightOffset, lighting.highlightScale
local outlineColor = Theme.outline.color
local outR, outG, outB = outlineColor[1], outlineColor[2], outlineColor[3]
local eR, eG, eB = enemyBody[1], enemyBody[2], enemyBody[3]
local esR, esG, esB, esA = enemyShadow[1], enemyShadow[2], enemyShadow[3], enemyShadow[4]
local selR, selG, selB = colorSelected[1], colorSelected[2], colorSelected[3]
local HIT_SQUASH_DUR = 0.12

local function drawShadow(e, x, y, alpha)
	if not e.shadow then return end
	lg.setColor(esR, esG, esB, esA * alpha * alpha)
	lg.ellipse("fill", x, y + e.radius, e.radius * 1.4, e.radius * 0.4)
end

local function drawBody(e, x, y, r, alpha)
	lg.setColor(outR, outG, outB, alpha); lg.circle("fill", x, y, r + 3)
	lg.setColor(eR * darkMul, eG * darkMul, eB * darkMul); lg.circle("fill", x, y, r)
	lg.setColor(eR, eG, eB, alpha)
	lg.circle("fill", x, y - r * highlightOffset, r * highlightScale)
end

local function drawSelection(e, x, y)
	if State.selectedEnemy ~= e then return end
	lg.setColor(selR, selG, selB, 0.25); lg.circle("fill", x, y, e.radius + 4)
	lg.setColor(selR, selG, selB); lg.circle("line", x, y, e.radius + 4)
end

-- The profile is resolved at spawn/portrait construction, so this hot path is a
-- fixed ordered pipeline with no enemy-kind dispatch or per-frame allocations.
local function drawEnemy(e)
	local x, y, r, alpha = e.rx, e.ry, e.radius, e.alpha
	local animT, profile = e.rAnimT or 0, e.renderProfile
	e.drawX, e.drawY = x, y
	drawShadow(e, x, y, alpha)

	local squash = min(1, (e.hitSquash or 0) / HIT_SQUASH_DUR) * (e.hitSquashStrength or 1)
	lg.push(); lg.translate(x, y); lg.scale(1 + squash * 0.12, 1 - squash * 0.16); lg.translate(-x, -y)
	profile.identity(e, x, y, r, animT, alpha)
	drawBody(e, x, y, r, alpha)
	EnemyDecorators.drawStatuses(e, x, y, r, animT, alpha)
	profile.face(e, x, y, r, animT, alpha)
	lg.setLineWidth(2)
	lg.pop()

	drawSelection(e, x, y)
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
	local renderProfile = EnemyDecorators.profiles[kind]
	if not def or not renderProfile then return nil end

	return {
		kind = kind,
		renderProfile = renderProfile,
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

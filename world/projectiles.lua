local State = require("core.state")
local Sound = require("systems.sound")
local Effects = require("world.effects")
local Enemies = require("world.enemies")
local MapMod = require("world.map")
local Spatial = require("world.spatial_grid")

local projectiles = {}
local projectilePool = {}

local lg = love.graphics
local random = love.math.random
local sampleFast = MapMod.sampleFast

local pi = math.pi
local sqrt = math.sqrt
local atan2 = math.atan2
local min = math.min
local max = math.max
local sin = math.sin
local cos = math.cos
local abs = math.abs
local tinsert = table.insert

local pulseSpeed = 3.0

local function swapRemove(list, i)
	local last = #list

	list[i] = list[last]
	list[last] = nil
end

local EPS = 0.000001

local function wobble(t, amp)
	return sin(t * 6.0) * amp, cos(t * 4.5) * amp
end

local minPush = 0.35 -- Ensure minimum push

local function applyHitImpulse(e, fromX, fromY, strength)
	local ex = e.x
	local ey = e.y

	local dx = ex - fromX
	local dy = ey - fromY

	-- Cheap "normalization" (no sqrt)
	local denom = abs(dx) + abs(dy) + 1
	dx = dx / denom
	dy = dy / denom

	-- Use sim tangent
	local tx = e.simPathDX or 1
	local ty = e.simPathDY or 0

	-- Path normal
	local nx = -ty
	local ny = tx

	local lateral = dx * nx + dy * ny

	if lateral > -minPush and lateral < minPush then
		if lateral >= 0 then
			lateral = minPush
		else
			lateral = -minPush
		end
	end

	e.lateralVelocity = e.lateralVelocity + lateral * strength

	-- Clamp
	if e.lateralVelocity > 120 then
		e.lateralVelocity = 120
	elseif e.lateralVelocity < -120 then
		e.lateralVelocity = -120
	end
end

local function spawnImpactFX(p)
	local x = p.lastTX or p.x
	local y = p.lastTY or p.y

	local kind = p.sourceKind

	if kind == "slow" then
		Effects.spawnFrostBurst(x, y)
	elseif kind == "poison" then
		Effects.spawnPoisonSplash(x, y)
	elseif kind == "lancer" then
		Effects.spawnLancerHit(x, y)
	end
end

local function acquireProjectile()
	local p = projectilePool[#projectilePool]

	if p then
		projectilePool[#projectilePool] = nil

		return p
	end

	return {}
end

local function releaseProjectile(p)
	p.x = nil
	p.y = nil
	p.vx = nil
	p.vy = nil
	p.target = nil
	p.sourceTower = nil
	p.tx = nil
	p.ty = nil
	p.slow = nil
	p.poison = nil
	p.splash = nil
	p.plasma = nil

	projectilePool[#projectilePool + 1] = p
end

local function spawn(fromTower, targetEnemy)
	local isCannon = fromTower.splash ~= nil

	local tx, ty = targetEnemy.x, targetEnemy.y

	if isCannon then
		local speedFactor = min(targetEnemy.speed / 120, 0.18)
		local leadTime = 0.28 + speedFactor

		if targetEnemy.slowTimer and targetEnemy.slowTimer > 0 then
			leadTime = leadTime * 0.85
		end

		local futureDist = (targetEnemy.dist or 0) + (targetEnemy.speed or 0) * leadTime
		local nx, ny = sampleFast(futureDist)

		tx = tx + (nx - targetEnemy.x)
		ty = ty + (ny - targetEnemy.y)
	end

	local p = acquireProjectile()

	p.x = fromTower.x
	p.y = fromTower.renderY or fromTower.y
	p.r = 4.5
	p.life = 3.0
	p.t = 0
	p.rotation = fromTower.angle or 0
	p.sourceTower = fromTower
	p.sourceKind = fromTower.kind
	p.speed = fromTower.projSpeed or 0
	p.damage = fromTower.damage
	p.target = targetEnemy
	p.lastTX = targetEnemy.x
	p.lastTY = targetEnemy.y
	p.tx = isCannon and tx or nil
	p.ty = isCannon and ty or nil
	p.splash = fromTower.splash
	p.slow = fromTower.slow
	p.poison = fromTower.poison
	p.plasma = fromTower.plasma

	if fromTower.plasma then
		p.hitTimer = 0
		p.hitCooldown = p.plasma.tickRate or 0.2
		p.r = p.plasma.radius
		p.pulse = 0
		p.pulseDir = 1
	end

	p.hitRadius = p.r + targetEnemy.radius
	p.hitRadius2 = p.hitRadius * p.hitRadius
	p.impactRadius2 = (p.r + 1) * (p.r + 1)

	if fromTower.plasma ~= nil then
		local ang = fromTower.angle or 0

		p.vx = cos(ang)
		p.vy = sin(ang)

		--p.life = 1.0
	end

	if isCannon then
		p.mode = "ground"
	elseif fromTower.plasma ~= nil then
		p.mode = "linear"
	else
		p.mode = "homing"
	end

	if fromTower.slow then
		local base = fromTower.projSpeed or 0
		p.minSpeed = base * 0.30
		p.maxSpeed = base * 1.05
		p.accelT = 0
		p.accelDur = 0.25
	else
		p.minSpeed = nil
		p.maxSpeed = nil
		p.accelT = nil
		p.accelDur = nil
	end

	Sound.play(fromTower.kind)

	projectiles[#projectiles + 1] = p
end

local function update(dt)
	for i = #projectiles, 1, -1 do
		local p = projectiles[i]

		p.life = p.life - dt
		p.t = p.t + dt

		if p.life <= 0 then
			local dead = projectiles[i]

			swapRemove(projectiles, i)
			releaseProjectile(dead)

			goto continue
		end

		-- Homing projectiles
		if p.mode == "homing" then
			local e = p.target

			-- Determine target position
			local tx, ty
			local ex, ey
			local alive = e and e.hp > 0

			if alive then
				ex, ey = e.x, e.y
				tx, ty = ex, ey
				p.lastTX, p.lastTY = tx, ty
			else
				tx, ty = p.lastTX, p.lastTY
				ex, ey = tx, ty
			end

			-- Speed (with slow ramp)
			local speed = p.speed or 0

			if p.minSpeed then
				local accelT = min(p.accelT + dt, p.accelDur)
				p.accelT = accelT

				local t = accelT / p.accelDur
				t = t * t * t
				speed = p.minSpeed + (p.maxSpeed - p.minSpeed) * t
			end

			-- Move toward target
			local dx = tx - p.x
			local dy = ty - p.y
			local d2 = dx * dx + dy * dy

			if d2 < EPS then
				d2 = EPS
			end

			local wave = p.slow and (1 + sin(p.t * 10) * 0.18) or 1
			local maxStep = speed * dt * wave
			local maxStep2 = maxStep * maxStep

			if d2 <= maxStep2 then
				p.x = tx
				p.y = ty
			else
				local invDist = 1 / sqrt(d2)
				p.x = p.x + dx * invDist * maxStep
				p.y = p.y + dy * invDist * maxStep
			end

			-- Hit resolution
			local dxh = p.x - ex
			local dyh = p.y - ey

			if dxh * dxh + dyh * dyh <= p.hitRadius2 then
				if alive then
					local dmg = p.damage
					e.hp = e.hp - dmg

					local tower = p.sourceTower
					tower.damageDealt = tower.damageDealt + dmg
					e.lastHitTower = tower

					-- Slow
					local slow = p.slow

					if slow then
						local duration = slow.dur or 0
						local slowAmount = slow.factor or 0
						local slowMult = (e.modifiers and e.modifiers.slow) or 1.0
						local effectiveSlow = min(slowAmount * slowMult, 0.9)
						local newFactor = 1 - effectiveSlow

						if (not e.slowFactor) or (newFactor < e.slowFactor) then
							e.slowFactor = newFactor
						end

						e.slowTimer = max(e.slowTimer or 0, duration)
						e.slowDuration = max(e.slowDuration or 0, duration)

						Effects.spawnFrostBurst(p.x, p.y)
					end

					-- Poison
					local poison = p.poison

					if poison then
						local duration = poison.dur

						e.poisonStacks = e.poisonStacks or 0
						e.poisonMaxStacks = max(e.poisonMaxStacks or 0, poison.maxStacks)
						e.poisonDPS = max(e.poisonDPS or 0, poison.dps)
						e.poisonStacks = min(e.poisonStacks + 1, e.poisonMaxStacks)

						e.poisonTimer = max(e.poisonTimer or 0, duration)
						e.poisonDuration = max(e.poisonDuration or 0, duration)
						e.poisonSource = tower

						Effects.spawnPoisonSplash(p.x, p.y)
					end

					if tower.kind == "lancer" then
						Effects.spawnLancerHit(p.x, p.y)
					end

					if e.hitFlash <= 0 then
						e.hitFlash = 0.05
					end

					if not e.boss then
						applyHitImpulse(e, p.x, p.y, 28)
					end

					State.addDamage(p.sourceKind, dmg, e.boss == true)
				end

				-- Always remove projectile once it reaches impact position
				local dead = projectiles[i]

				if not alive then
					spawnImpactFX(p)
				end

				swapRemove(projectiles, i)
				releaseProjectile(dead)

				goto continue
			end
		end

		-- Ground projectiles (Cannon)
		if p.mode == "ground" then
			local tx, ty = p.tx, p.ty
			local dx = tx - p.x
			local dy = ty - p.y
			local d2 = dx * dx + dy * dy

			if d2 < EPS then
				d2 = EPS
			end

			local speed = p.speed or 0
			local maxStep = speed * dt
			local maxStep2 = maxStep * maxStep

			if d2 <= maxStep2 then
				p.x = tx
				p.y = ty
			else
				local invDist = 1 / sqrt(d2)
				p.x = p.x + dx * invDist * maxStep
				p.y = p.y + dy * invDist * maxStep
			end

			-- Impact check
			local ddx = tx - p.x
			local ddy = ty - p.y
			local dd2 = ddx * ddx + ddy * ddy

			if dd2 <= p.impactRadius2 then
				local splash = p.splash
				local r = splash.radius
				local r2 = r * r
				local falloff = splash.falloff

				local enemies = Enemies.enemies
				local px, py = p.x, p.y
				local baseDamage = p.damage
				local tower = p.sourceTower
				local kind = p.sourceKind

				local nearby = Spatial.queryCells(px, py)

				for j = 1, #nearby do
					local e = nearby[j]
					local ex, ey = e.x, e.y
					local dx2 = ex - px
					local dy2 = ey - py
					local ed2 = dx2 * dx2 + dy2 * dy2

					if ed2 <= r2 then
						local t = 1 - (ed2 / r2)

						if t < 0 then
							t = 0
						end

						local dmg = baseDamage * (falloff + (1 - falloff) * t)

						e.hp = e.hp - dmg
						tower.damageDealt = tower.damageDealt + dmg
						e.lastHitTower = tower

						if e.hitFlash <= 0 then
							e.hitFlash = 0.05
						end

						if not e.boss then
							applyHitImpulse(e, px, py, 64)
						end

						State.addDamage(kind, dmg, e.boss == true)
					end
				end

				--tinsert(Effects.splashes, {x = px, y = py, r = r, t = 0, life = 0.21})
				Effects.spawnCannonImpact(tx, ty, r)

				local dead = projectiles[i]
				swapRemove(projectiles, i)
				releaseProjectile(dead)

				goto continue
			end
		end

		-- Linear projectiles (Plasma)
		if p.mode == "linear" then
			local speed = p.speed or 0

			p.x = p.x + p.vx * speed * dt
			p.y = p.y + p.vy * speed * dt

			-- Tick timer
			p.hitTimer = (p.hitTimer or 0) - dt

			p.pulse = p.pulse + p.pulseDir * pulseSpeed * dt

			if p.pulse >= 1 then
				p.pulse = 1
				p.pulseDir = -1
			elseif p.pulse <= 0 then
				p.pulse = 0
				p.pulseDir = 1
			end

			if p.hitTimer <= 0 then
				local nearby = Spatial.queryCells(p.x, p.y)

				for j = 1, #nearby do
					local e = nearby[j]

					if e.hp > 0 then
						local dx = e.x - p.x
						local dy = e.y - p.y

						if dx * dx + dy * dy <= p.hitRadius2 then
							local dmg = p.damage

							e.hp = e.hp - dmg

							local tower = p.sourceTower
							tower.damageDealt = tower.damageDealt + dmg
							e.lastHitTower = tower

							if e.hitFlash <= 0 then
								e.hitFlash = 0.05
							end

							if not e.boss then
								applyHitImpulse(e, p.x, p.y, 24)
							end

							State.addDamage(p.sourceKind, dmg, e.boss == true)

							Effects.spawnPlasmaHit(p.x, p.y, p.vx, p.vy)
						end
					end
				end

				-- Reset AFTER processing all enemies
				p.hitTimer = p.hitCooldown
			end
		end

		::continue::
	end
end

local function draw()
	for i = 1, #projectiles do
		local p = projectiles[i]
		local rotation = 0
		local fadeStart = 0.2 -- seconds before death to start fading

		local lifeAlpha = 1

		if p.life < fadeStart then
			lifeAlpha = p.life / fadeStart
		end

		local a = min(1, p.t * 10) * lifeAlpha

		-- Aim at target (or last known)
		if p.mode == "homing" then
			local dx = (p.lastTX or p.x) - p.x
			local dy = (p.lastTY or p.y) - p.y

			rotation = atan2(dy, dx)
		-- Aim at targetted impact point
		elseif p.mode == "ground" then
			rotation = p.rotation
		end

		if p.splash then
			lg.setColor(1, 0.8, 0.4, a)
			lg.push()
			lg.translate(p.x, p.y)
			lg.rotate(rotation)
			lg.rectangle("fill", -7, -4, 14, 8, 4, 4)
			lg.pop()
		elseif p.slow then
			lg.setColor(0.7, 0.85, 1, a)
			lg.push()
			lg.translate(p.x, p.y)
			lg.rotate(rotation + pi / 4)
			lg.rectangle("fill", -4, -4, 8, 8, 2, 2)
			lg.pop()
		elseif p.poison then
			local wx, wy = wobble(p.t or 0, 1.5)
			lg.setColor(0.6, 0.9, 0.5, a)
			lg.circle("fill", p.x + wx, p.y + wy, p.r + 1.5)
		elseif p.plasma then
			lg.push()
			lg.translate(p.x, p.y)

			local pulse = p.pulse or 0

			local outerR = 8 + pulse * 1.2
			local innerR = 4.5 + pulse * 0.6

			-- Outer glow
			lg.setColor(0.85, 0.55, 1.0, a)
			lg.circle("fill", 0, 0, outerR)

			-- Inner core
			lg.setColor(1, 0.75, 1.0, a * 0.9)
			lg.circle("fill", 0, 0, innerR)

			lg.pop()
		else -- Lancer
			lg.push()
			lg.translate(p.x, p.y)
			lg.rotate(rotation)

			lg.setColor(1, 1, 1, a)
			lg.ellipse("fill", 0, 0, 6, 3)

			lg.pop()
		end
	end
end

local function clear()
	for i = #projectiles, 1, -1 do
		projectiles[i] = nil
	end
end

return {
	projectiles = projectiles,
	spawn = spawn,
	update = update,
	draw = draw,
	clear = clear,
}
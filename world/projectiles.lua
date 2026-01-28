local State = require("core.state")
local Sound = require("systems.sound")
local Effects = require("world.effects")
local Enemies = require("world.enemies")
local WorldMap = require("world.map")

local projectiles = {}

local lg = love.graphics

local pi = math.pi
local sqrt = math.sqrt
local atan2 = math.atan2
local min = math.min
local max = math.max
local sin = math.sin
local cos = math.cos
local tinsert = table.insert
local tremove = table.remove

local function wobble(t, amp)
	return sin(t * 6.0) * amp, cos(t * 4.5) * amp
end

local function spawn(fromTower, targetEnemy)
    local isCannon = fromTower.splash ~= nil

    local tx, ty = targetEnemy.x, targetEnemy.y

	if isCannon then
		-- base lead scaled by enemy speed
		local speedFactor = min(targetEnemy.speed / 120, 0.18)
		local lead = 0.28 + speedFactor

		-- if enemy is slowed, reduce prediction slightly
		if targetEnemy.slowTimer and targetEnemy.slowTimer > 0 then
			lead = lead * 0.85
		end

		local nextIdx = min(targetEnemy.pathIndex + 1, #WorldMap.map.path)
		local gx, gy = WorldMap.map.path[nextIdx][1], WorldMap.map.path[nextIdx][2]
		local nx, ny = WorldMap.gridToCenter(gx, gy)

		tx = tx + (nx - targetEnemy.x) * lead
		ty = ty + (ny - targetEnemy.y) * lead
	end

    local p = {
        x = fromTower.x,
        y = fromTower.y,
        r = 4.5,
        life = 2.0,
		t = 0,
        sourceTower = fromTower,
        speed = fromTower.projSpeed,
        mode = isCannon and "ground" or "homing",
        target = targetEnemy or nil,
		lastTX = targetEnemy.x,
		lastTY = targetEnemy.y,
        tx = isCannon and tx or nil,
        ty = isCannon and ty or nil,
        damage = fromTower.damage,
		sourceKind = fromTower.kind,
        splash = fromTower.splash and {radius = fromTower.splash.radius, falloff = fromTower.splash.falloff} or nil,
        slow = fromTower.slow and {factor = fromTower.slow.factor, dur = fromTower.slow.dur} or nil,
		poison = fromTower.poison and {dps = fromTower.poison.dps, dur = fromTower.poison.dur, maxStacks = fromTower.poison.maxStacks} or nil,
    }

	p.hitRadius = p.r + targetEnemy.radius
	p.hitRadius2 = p.hitRadius * p.hitRadius

	if fromTower.slow then
		-- start very slow, ramp deliberately
		p.minSpeed = fromTower.projSpeed * 0.30
		p.maxSpeed = fromTower.projSpeed * 1.05
		p.accelT   = 0
		p.accelDur = 0.25
	end

	local kind = fromTower.kind

	if kind == "lancer" then
		Sound.play("lancer")
	elseif kind == "slow" then
		Sound.play("slow")
	elseif kind == "cannon" then
		Sound.play("cannon")
	elseif kind == "poison" then
		Sound.play("poison")
	end

    tinsert(projectiles, p)
end

local function update(dt)
	for i = #projectiles, 1, -1 do
		local p = projectiles[i]

		p.life = p.life - dt
		p.t = p.t + dt

		if p.life <= 0 then
			tremove(projectiles, i)
			goto continue
		end

		----------------------------------------------------------------
		-- HOMING PROJECTILES (Lancer / Slow / Poison)
		----------------------------------------------------------------
		if p.mode == "homing" then
			local speed = p.speed
			local e = p.target

			-- Target tracking
			local tx, ty
			if e and e.hp > 0 then
				tx, ty = e.x, e.y
				p.lastTX, p.lastTY = tx, ty
			else
				tx, ty = p.lastTX, p.lastTY
			end

			-- Acceleration ramp (Slow tower)
			if p.minSpeed then
				p.accelT = min(p.accelT + dt, p.accelDur)
				local t = p.accelT / p.accelDur
				t = t * t * t -- cubic ease-in
				speed = p.minSpeed + (p.maxSpeed - p.minSpeed) * t
			end

			-- Direction + distance
			local dx = tx - p.x
			local dy = ty - p.y
			local d2 = dx * dx + dy * dy

			if d2 < 0.000001 then
				d2 = 0.000001
			end

			local invDist = 1 / sqrt(d2)
			local nx = dx * invDist
			local ny = dy * invDist
			local dist = d2 * invDist

			-- Slow projectile wave modulation
			local wave = p.slow and (1 + sin(p.t * 10) * 0.18) or 1
			local step = min(speed * dt * wave, dist)

			p.x = p.x + nx * step
			p.y = p.y + ny * step

			-- Hit check (squared)
			local dxh = p.x - e.x
			local dyh = p.y - e.y

			if dxh * dxh + dyh * dyh <= p.hitRadius2 then
				local dmg = p.damage
				e.hp = e.hp - dmg

				-- Attribution
				p.sourceTower.damageDealt = p.sourceTower.damageDealt + dmg
				e.lastHitTower = p.sourceTower

				-- Slow application
				if p.slow then
					local duration = p.slow.dur or 0
					local slowAmount = p.slow.factor or 0
					local slowMult = (e.modifiers and e.modifiers.slow) or 1.0
					local effectiveSlow = min(slowAmount * slowMult, 0.9)
					local newFactor = 1 - effectiveSlow

					if not e.slowFactor or newFactor < e.slowFactor then
						e.slowFactor = newFactor
					end

					e.slowTimer = max(e.slowTimer or 0, duration)
					e.slowDuration = max(e.slowDuration or 0, duration)
				end

				-- Poison application
				if p.poison then
					local def = p.poison
					local duration = def.dur

					e.poisonStacks = e.poisonStacks or 0
					e.poisonMaxStacks = max(e.poisonMaxStacks or 0, def.maxStacks)
					e.poisonDPS = max(e.poisonDPS or 0, def.dps)
					e.poisonStacks = min(e.poisonStacks + 1, e.poisonMaxStacks)

					e.poisonTimer = max(e.poisonTimer or 0, duration)
					e.poisonDuration = max(e.poisonDuration or 0, duration)
					e.poisonSource = p.sourceTower
				end

				if e.hitFlash <= 0 then
					e.hitFlash = 0.05
				end

				State.addDamage(p.sourceKind, dmg, e.boss == true)
				tremove(projectiles, i)
				goto continue
			end
		end

		----------------------------------------------------------------
		-- GROUND PROJECTILES (Cannon)
		----------------------------------------------------------------
		if p.mode == "ground" then
			local dx = p.tx - p.x
			local dy = p.ty - p.y
			local d2 = dx * dx + dy * dy

			if d2 < 0.000001 then
				d2 = 0.000001
			end

			local invDist = 1 / sqrt(d2)
			local nx = dx * invDist
			local ny = dy * invDist
			local dist = d2 * invDist

			local step = min(p.speed * dt, dist)

			p.x = p.x + nx * step
			p.y = p.y + ny * step

			-- Impact check (squared)
			local hitR = p.r + 1
			if d2 <= hitR * hitR then
				local falloff = p.splash.falloff
				local enemies = Enemies.enemies
				local r = p.splash.radius
				local r2 = r * r

				for j = #enemies, 1, -1 do
					local e = enemies[j]
					local dx2 = e.x - p.x
					local dy2 = e.y - p.y
					local ed2 = dx2 * dx2 + dy2 * dy2

					if ed2 <= r2 then
						-- Squared falloff (no sqrt)
						local t = 1 - (ed2 / r2)
						if t < 0 then t = 0 end

						local dmg = p.damage * (falloff + (1 - falloff) * t)
						e.hp = e.hp - dmg

						p.sourceTower.damageDealt = p.sourceTower.damageDealt + dmg
						e.lastHitTower = p.sourceTower
						e.hitFlash = max(e.hitFlash, 0.03)

						State.addDamage(p.sourceKind, dmg, e.boss == true)
					end
				end

				tinsert(Effects.splashes, {
					x = p.x,
					y = p.y,
					r = p.splash.radius,
					t = 0,
					life = 0.21,
				})

				tremove(projectiles, i)
				goto continue
			end
		end

		::continue::
	end
end

local function draw()
	for _, p in ipairs(projectiles) do
		local rotation = 0
		local a = min(1, p.t * 10)

		-- Homing: aim at target (or last known)
		if p.mode == "homing" then
			local dx = (p.lastTX or p.x) - p.x
			local dy = (p.lastTY or p.y) - p.y

			rotation = atan2(dy, dx)
		-- Ground (Cannon): aim at targetted impact point
		elseif p.mode == "ground" then
			local dx = (p.tx or p.x) - p.x
			local dy = (p.ty or p.y) - p.y

			rotation = atan2(dy, dx)
		end

		if p.splash then
			lg.setColor(1, 0.8, 0.4, a)

			lg.push()
			lg.translate(p.x, p.y)
			lg.rotate(rotation)
			lg.rectangle("fill", -8, -4, 14, 8, 4, 4)
			lg.pop()
		elseif p.slow then
			--local speedStretch = min(1.25, 1 + (p.speed or 300) / 600)

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
		else
			--local speedStretch = min(1.25, 1 + (p.speed or 300) / 600)

			lg.setColor(1, 1, 1, a)
			lg.circle("fill", p.x, p.y, 4)
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
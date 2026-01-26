local State = require("core.state")
local Sound = require("systems.sound")
local Effects = require("world.effects")

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
		local WorldMap = require("world.map")

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
	local Enemies = require("world.enemies")

	for i = #projectiles, 1, -1 do
		local p = projectiles[i]

		p.life = p.life - dt
		p.t = p.t + dt

		if p.life <= 0 then
			tremove(projectiles, i)
			goto continue
		end

		-- Homing projectiles (Lancer / Slow / Poison)
		if p.mode == "homing" then
			local tx, ty
			local speed = p.speed
			local e = p.target

			if p.target and p.target.hp > 0 then
				tx, ty = p.target.x, p.target.y
				p.lastTX, p.lastTY = tx, ty
			else
				tx, ty = p.lastTX, p.lastTY
			end

			local dx = tx - p.x
			local dy = ty - p.y
			local dist = sqrt(dx * dx + dy * dy)

			if dist < 0.001 then
				dist = 0.001
			end

			-- Acceleration ramp (Slow tower)
			if p.minSpeed then
				p.accelT = min(p.accelT + dt, p.accelDur)
				local t = p.accelT / p.accelDur
				t = t * t * t -- cubic ease-in
				speed = p.minSpeed + (p.maxSpeed - p.minSpeed) * t
			end

			-- Base forward step
			local step = min(speed * dt, dist)
			local nx = dx / dist
			local ny = dy / dist

			-- Slow projectile, wave
			if p.slow then
				-- Subtle speed wave along forward direction
				local wave = sin(p.t * 10) * 0.18 -- +/-18% speed modulation
				local waveStep = step * (1 + wave)

				p.x = p.x + nx * waveStep
				p.y = p.y + ny * waveStep
			-- Normal homing
			else
				p.x = p.x + nx * step
				p.y = p.y + ny * step
			end

			-- Hit check
			local rr = p.r + p.target.radius

			if (p.x - p.target.x) ^ 2 + (p.y - p.target.y) ^ 2 <= rr * rr then
				local dmg = p.damage
				p.target.hp = p.target.hp - dmg

				-- Attribute damage
				p.sourceTower.damageDealt = p.sourceTower.damageDealt + dmg
				p.target.lastHitTower = p.sourceTower

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

				if p.target.hitFlash <= 0 then
					p.target.hitFlash = 0.05
				end

				State.addDamage(p.sourceKind, dmg, p.target.boss == true)
				tremove(projectiles, i)
				goto continue
			end
		end

		-- Ground projectiles (Cannon)
		if p.mode == "ground" then
			local dx = p.tx - p.x
			local dy = p.ty - p.y
			local dist = sqrt(dx * dx + dy * dy)

			if dist < 0.001 then
				dist = 0.001
			end

			local step = min(p.speed * dt, dist)
			p.x = p.x + (dx / dist) * step
			p.y = p.y + (dy / dist) * step

			if dist <= p.r + 1 then
				local falloff = p.splash.falloff

				for j = #Enemies.enemies, 1, -1 do
					local e = Enemies.enemies[j]
					local dx2 = e.x - p.x
					local dy2 = e.y - p.y
					local d2 = dx2 * dx2 + dy2 * dy2
					local r = p.splash.radius

					if d2 <= r * r then
						local t = max(0, 1 - sqrt(d2) / r)
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
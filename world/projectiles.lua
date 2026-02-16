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

local function swapRemove(list, i)
	local last = #list

	list[i] = list[last]
	list[last] = nil
end

local EPS = 0.000001

local function wobble(t, amp)
	return sin(t * 6.0) * amp, cos(t * 4.5) * amp
end

local function spawn(fromTower, targetEnemy)
	local isCannon = fromTower.splash ~= nil

	local tx, ty = targetEnemy.x, targetEnemy.y

	if isCannon then
		-- Base lead scaled by enemy speed
		local speedFactor = min(targetEnemy.speed / 120, 0.18)
		local lead = 0.28 + speedFactor

		-- If enemy is slowed, reduce prediction slightly
		if targetEnemy.slowTimer and targetEnemy.slowTimer > 0 then
			lead = lead * 0.85
		end

		local path = WorldMap.map.path
		local nextIdx = min(targetEnemy.pathIndex + 1, #path)
		local cell = path[nextIdx]
		local gx, gy = cell[1], cell[2]
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
		sourceKind = fromTower.kind,

		speed = fromTower.projSpeed or 0,
		damage = fromTower.damage,

		mode = isCannon and "ground" or "homing",

		target = targetEnemy,
		lastTX = targetEnemy.x,
		lastTY = targetEnemy.y,

		tx = isCannon and tx or nil,
		ty = isCannon and ty or nil,

		splash = fromTower.splash,
		slow = fromTower.slow,
		poison = fromTower.poison,
	}

	p.hitRadius = p.r + targetEnemy.radius
	p.hitRadius2 = p.hitRadius * p.hitRadius

	-- Cannon impact check radius
	p.impactRadius2 = (p.r + 1) * (p.r + 1)

	if fromTower.slow then
		-- Start very slow, ramp deliberately
		local base = fromTower.projSpeed or 0

		p.minSpeed = base * 0.30
		p.maxSpeed = base * 1.05
		p.accelT = 0
		p.accelDur = 0.25
	end

	Sound.play(fromTower.kind)

	tinsert(projectiles, p)
end

local function update(dt)
	for i = #projectiles, 1, -1 do
		local p = projectiles[i]

		p.life = p.life - dt
		p.t = p.t + dt

		if p.life <= 0 then
			swapRemove(projectiles, i)
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
			if d2 < EPS then d2 = EPS end

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

			-- Hit resolution (always resolve when reaching position)
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
					end

					if e.hitFlash <= 0 then
						e.hitFlash = 0.03
					end

					State.addDamage(p.sourceKind, dmg, e.boss == true)
				end

				-- Always remove projectile once it reaches impact position
				swapRemove(projectiles, i)
				goto continue
			end
		end

		-- Ground projectiles (Cannon)
		if p.mode == "ground" then
			local tx, ty = p.tx, p.ty
			local dx = tx - p.x
			local dy = ty - p.y
			local d2 = dx * dx + dy * dy
			if d2 < EPS then d2 = EPS end

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

				for j = #enemies, 1, -1 do
					local e = enemies[j]
					local ex, ey = e.x, e.y
					local dx2 = ex - px
					local dy2 = ey - py
					local ed2 = dx2 * dx2 + dy2 * dy2

					if ed2 <= r2 then
						local t = 1 - (ed2 / r2)
						if t < 0 then t = 0 end

						local dmg = baseDamage * (falloff + (1 - falloff) * t)

						e.hp = e.hp - dmg
						tower.damageDealt = tower.damageDealt + dmg
						e.lastHitTower = tower

						State.addDamage(kind, dmg, e.boss == true)
					end
				end

				tinsert(Effects.splashes, {
					x = px,
					y = py,
					r = r,
					t = 0,
					life = 0.21,
				})

				swapRemove(projectiles, i)
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
		-- Ground: aim at targetted impact point
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
local State = require("core.state")
local Maps = require("world.maps")
local Enemies = require("world.enemies")
local Difficulty = require("systems.difficulty")

local Waves = {}

local bossAddTimer = 0

local min = math.min
local max = math.max

local spawner = {
	active = false,
	remaining = 0,
	gap = 0.6,
	timer = 0,
	hpMult = 1.0,
	spdMult = 1.0,
	mix = nil,
}

-- Utility
local function pickEnemyType(mix)
	local total = 0

	for _, m in ipairs(mix) do
		total = total + m.w
	end

	local r = love.math.random() * total
	local acc = 0

	for _, m in ipairs(mix) do
		acc = acc + m.w

		if r <= acc then
			return m.type
		end
	end

	return mix[#mix].type
end

-- Wave start
function Waves.startWave()
	local diff = Difficulty.get()
	local map = Maps[State.mapIndex]
	local waveData = map.waves

	State.wave = State.wave + 1
	State.waveAnim = State.waveAnim + (1 - State.waveAnim) * 0.6

	-- Boss waves (every 10th wave)
	local isBossWave = (State.wave % 10 == 0)

	if isBossWave and waveData.bosses then
		local bossIndex = State.wave / 10
		local boss = waveData.bosses[bossIndex]

		if boss then
			spawner.active = true
			spawner.remaining = 1
			spawner.timer = 0
			spawner.gap = 0
			spawner.mix = {{type = boss.type, w = 1.0}}

			-- Boss HP
			local baseHp = boss.hpBase * (boss.hpRamp ^ (bossIndex - 1))

			spawner.hpMult = baseHp * diff.bossHp

			-- Boss Speed
			local baseSpeed = 1.0 + (bossIndex - 1) * boss.spdRamp

			spawner.spdMult = baseSpeed * diff.enemySpeed

			State.inPrep = false

			return
		end
	end

	-- Normal waves
	local plan = waveData.normal[min(State.wave, #waveData.normal)]

	spawner.active = true
	spawner.timer = 0
	spawner.mix = plan.mix

	-- Count (unchanged by difficulty)
	spawner.remaining = plan.count + max(0, State.wave - #waveData.normal) * 3

	-- Spawn gap
	spawner.gap = plan.gap * max(0.75, 1.0 - (State.wave - 1) * 0.02)

	-- HP scaling
	local baseHp = (plan.hpMult or 1.0) * (1.15 + (State.wave - 1) * 0.20)

	spawner.hpMult = baseHp * diff.enemyHp

	-- Speed scaling
	local baseSpeed = (plan.spdMult or 1.0) * (1.0 + (State.wave - 1) * 0.06)

	spawner.spdMult = baseSpeed * diff.enemySpeed

	State.inPrep = false
end

-- Spawning update
function Waves.updateSpawner(dt)
	if spawner.active then
		spawner.timer = spawner.timer - dt

		if spawner.timer <= 0 and spawner.remaining > 0 then
			local kind = pickEnemyType(spawner.mix)

			Enemies.spawnEnemy(kind, spawner.hpMult, spawner.spdMult)
			spawner.remaining = spawner.remaining - 1
			spawner.timer = spawner.gap
		end

		if spawner.remaining <= 0 then
			spawner.active = false
		end
	end

	-- Boss add trickle (unchanged behavior)
	if State.wave % 10 == 0 then
		local bossAlive = false

		for _, e in ipairs(Enemies.enemies) do
			if e.boss then
				bossAlive = true

				break
			end
		end

		if bossAlive then
			bossAddTimer = bossAddTimer - dt

			if bossAddTimer <= 0 then
				bossAddTimer = (State.wave == 10) and 2.0 or 1.0
				Enemies.spawnEnemy("runner", 1.0, 1.0)

				if State.wave == 20 then
					Enemies.spawnEnemy("grunt", 1.0, 1.0)
				end
			end
		else
			bossAddTimer = 0
		end
	end
end

-- Prep + helpers
function Waves.updatePrep(dt)
	if not State.inPrep then
		return
	end

	State.prepTimer = State.prepTimer - dt

	if State.prepTimer <= 0 then
		State.prepTimer = 0
		Waves.startWave()
	end
end

function Waves.allEnemiesCleared()
	return #Enemies.enemies == 0 and not spawner.active
end

function Waves.resetSpawner()
	spawner.active = false
	spawner.remaining = 0
	spawner.timer = 0
	spawner.hpMult = 1.0
	spawner.spdMult = 1.0
	spawner.mix = nil
	bossAddTimer = 0
end

function Waves.getSpawner()
	return spawner
end

return Waves
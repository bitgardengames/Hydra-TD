local State = require("core.state")
local Maps = require("world.map_defs")
local Enemies = require("world.enemies")
local Difficulty = require("systems.difficulty")
local WaveDefs = require("systems.wave_defs")
local WaveBuilder = require("systems.wave_builder")
local WaveEndless = require("systems.wave_endless")

local Waves = {}

local bossAddTimer = 0

local min = math.min
local max = math.max

-- Keep spawner table shape so nothing else breaks (UI, debug, etc.)
local spawner = {
	active = false,
	remaining = 0,
	gap = 0.6,
	timer = 0,
	hpMult = 1.0,
	spdMult = 1.0,

	-- Legacy field (kept for compatibility; no longer used)
	mix = nil,

	-- New deterministic spawn list
	spawnList = nil,
	spawnIndex = 1,
}

-- Deterministic spawn order (feel free to tweak)
--local SPAWN_ORDER = {"tank", "splitter", "grunt", "runner"}
local SPAWN_ORDER = {"runner", "grunt", "splitter", "tank"}

local function getCount(tbl, key)
	if not tbl then return 0 end
	return tbl[key] or 0
end

local function buildSpawnList(enemies)
	local list = {}
	local n = 0

	for _, kind in ipairs(SPAWN_ORDER) do
		local count = getCount(enemies, kind)

		for i = 1, count do
			n = n + 1
			list[n] = kind
		end
	end

	return list
end

local function beginSpawner(list, gap, hpMult, spdMult)
	spawner.active = true
	spawner.timer = 0
	spawner.gap = gap or 0.6
	spawner.hpMult = hpMult or 1.0
	spawner.spdMult = spdMult or 1.0

	spawner.spawnList = list
	spawner.spawnIndex = 1
	spawner.remaining = list and #list or 0

	-- Legacy (unused now)
	spawner.mix = nil

	State.inPrep = false
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

	if isBossWave and waveData and waveData.bosses then
		local bossIndex = State.wave / 10
		local boss = waveData.bosses[bossIndex]

		if boss then
			-- Boss HP
			local baseHp = boss.hpBase * (boss.hpRamp ^ (bossIndex - 1))
			local hpMult = baseHp * diff.bossHp

			-- Boss Speed
			local baseSpeed = 1.0 + (bossIndex - 1) * boss.spdRamp
			local spdMult = baseSpeed * diff.enemySpeed

			-- Deterministic single spawn
			beginSpawner({ boss.type }, 0, hpMult, spdMult)
			return
		end
	end

	-- Normal waves: authored + deterministic
	-- Build base wave from anchors/interpolation
	local wave = WaveBuilder.build(State.wave)

	-- Apply endless scaling automatically past last anchor, OR if State.endless is enabled
	if State.wave > WaveDefs.LAST_ANCHOR or State.endless then
		local depth = max(0, State.wave - WaveDefs.LAST_ANCHOR)
		WaveEndless.apply(wave, depth)
	end

	-- Convert wave to spawner settings
	local gap = wave.gap or 0.6

	-- Ramps are explicit now, then difficulty multiplies on top
	local hpMult = (wave.ramps and wave.ramps.hp or 1.0) * diff.enemyHp
	local spdMult = (wave.ramps and wave.ramps.speed or 1.0) * diff.enemySpeed

	-- Build deterministic spawn list (no RNG)
	local list = buildSpawnList(wave.enemies)

	beginSpawner(list, gap, hpMult, spdMult)
end

-- Spawning update
function Waves.updateSpawner(dt)
	if not spawner.active then
		return
	end

	spawner.timer = spawner.timer - dt

	if spawner.timer <= 0 and spawner.remaining > 0 then
		local list = spawner.spawnList

		-- Safety
		if not list or spawner.spawnIndex > #list then
			spawner.remaining = 0
			spawner.active = false
			return
		end

		local kind = list[spawner.spawnIndex]

		Enemies.spawnEnemy(kind, spawner.hpMult, spawner.spdMult)

		spawner.spawnIndex = spawner.spawnIndex + 1
		spawner.remaining = spawner.remaining - 1
		spawner.timer = spawner.gap
	end

	if spawner.remaining <= 0 then
		spawner.active = false
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
	spawner.gap = 0.6
	spawner.timer = 0
	spawner.hpMult = 1.0
	spawner.spdMult = 1.0
	spawner.mix = nil

	spawner.spawnList = nil
	spawner.spawnIndex = 1

	bossAddTimer = 0
end

function Waves.getSpawner()
	return spawner
end

return Waves
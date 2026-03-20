local State = require("core.state")
local Maps = require("world.map_defs")
local Enemies = require("world.enemies")
local Difficulty = require("systems.difficulty")
local DifficultyCurve = require("systems.difficulty_curve")
local WaveBuilder = require("systems.wave_builder")
local Steam = require("core.steam")
local L = require("core.localization")

local Waves = {}

local max = math.max

-- Keep spawner table shape so nothing else breaks (UI, debug, etc.)
local spawner = {
	active = false,
	remaining = 0,
	gap = 0.6,
	timer = 0,
	hpMult = 1.0,
	spdMult = 1.0,

	-- Deterministic spawn list
	spawnList = nil,
	spawnIndex = 1,
}

local function beginSpawner(list, gap, hpMult, spdMult)
	spawner.active = true
	spawner.timer = 0
	spawner.gap = gap or 0.6
	spawner.hpMult = hpMult or 1.0
	spawner.spdMult = spdMult or 1.0

	spawner.spawnList = list
	spawner.spawnIndex = 1
	spawner.remaining = list and #list or 0

	State.inPrep = false
end

local function buildRepeatList(kind, count)
	local list = {}

	for i = 1, count do
		list[i] = kind
	end

	return list
end

-- Wave start
function Waves.startWave()
	local map = Maps[State.mapIndex]
	local mapMult = State.mapCoverageMult or 1.0

	State.waveLeaks = 0

	if State.mode == "game" then -- Make sure the background scene doesn't set the status
		local diffKey = Difficulty.key()
		local diffText = L("difficulty." .. diffKey)

		Steam.setRichPresence(L("presence.gameStatus", State.wave, diffText))
	end

	-- WaveBuilder enforces boss invariant and returns a simple descriptor
	local wave = WaveBuilder.build(State.wave)

	-- Boss waves
	if wave.boss then
		local bossKind = wave.enemy or "boss"

		if map and map.waves and map.waves.bosses then
			local bossIndex = State.wave / 10
			local bossDef = map.waves.bosses[bossIndex]

			if bossDef and bossDef.type then
				bossKind = bossDef.type
			end
		end

		local hpMult = DifficultyCurve.getBossHpMultiplier(State.wave) * mapMult
		local spdMult = DifficultyCurve.getEnemySpeedMultiplier(State.wave)

		beginSpawner({bossKind}, 0, hpMult, spdMult)

		return
	end

	-- Normal waves: single enemy kind with count + spacing
	local count = max(1, wave.count or 1)
	local kind = wave.enemy or "grunt"

	local hpMult = DifficultyCurve.getEnemyHpMultiplier(State.wave) * mapMult
	local spdMult = DifficultyCurve.getEnemySpeedMultiplier(State.wave)

	local list = buildRepeatList(kind, count)
	local gap = wave.spacing or 1.0

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
	spawner.spawnList = nil
	spawner.spawnIndex = 1
end

function Waves.getSpawner()
	return spawner
end

return Waves
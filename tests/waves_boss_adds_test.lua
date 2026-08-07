-- Deterministic regression for boss reinforcements corrupting authored groups.
local state = {
	mapIndex = 1,
	wave = 10,
	endless = false,
	mode = "test",
	inPrep = true,
}

local map = {id = "test_map", biome = "default"}
local authoredGroups = {
	{kind = "boss", count = 1, spacing = 0, delay = 0},
	{kind = "runner", count = 5, spacing = 0.10, delay = 0.30},
	{kind = "tank", count = 6, spacing = 0.10, delay = 0.30},
}
local wave = {boss = true, count = 12, groups = authoredGroups}
local enemies = {enemies = {}}
local spawned = {}

local function stub(name, value)
	package.loaded[name] = value
end

stub("core.state", state)
stub("world.map_defs", {map})
stub("systems.difficulty", {key = function() return "normal" end, get = function() return {perfectWaveBonus = 0} end})
stub("systems.difficulty_curve", {
	campaignEnd = 10,
	getBossHpMultiplier = function() return 1 end,
	getEnemyHpMultiplier = function() return 1 end,
	getEnemySpeedMultiplier = function() return 1 end,
})
stub("systems.wave_builder", {
	build = function() return wave end,
	getIntensityTier = function() return 0 end,
})
stub("core.steam", {setRichPresence = function() end})
stub("core.localization", setmetatable({}, {__call = function(_, key) return key end}))
stub("world.enemy_defs", {
	boss_summoner = {boss = true, traits = {}}, runner = {traits = {}}, tank = {traits = {}}, grunt = {traits = {}},
})
stub("world.enemy_traits", {get = function() return nil end})
stub("world.enemy_affix_defs", {})
stub("world.effects", {trigger = function() end})
stub("world.enemies", enemies)
stub("world.spatial_grid", {
	queryCells = function()
		local result = {}
		for _, enemy in ipairs(enemies.enemies) do result[#result + 1] = enemy end
		return result, #result
	end,
})

function enemies.spawnEnemy(kind)
	local enemy = {kind = kind, hp = 1, x = 0, y = 0, boss = kind == "boss_summoner"}
	enemies.enemies[#enemies.enemies + 1] = enemy
	spawned[#spawned + 1] = kind
	if enemy.boss then state.activeBoss = enemy end
	return enemy
end

package.loaded["systems.waves"] = nil
local Waves = require("systems.waves")
local preview = Waves.getWavePreview(10)
assert(preview.total == 12, "fixture preview must advertise every authored enemy")
assert(Waves.startWave(), "wave should start")

local peakActive = 0
for _ = 1, 500 do
	Waves.updateSpawner(0.10)
	peakActive = math.max(peakActive, #enemies.enemies)
	-- Simulate towers promptly killing non-bosses so every reinforcement timer can
	-- run without making the test depend on combat or pathing.
	for i = #enemies.enemies, 1, -1 do
		if not enemies.enemies[i].boss then table.remove(enemies.enemies, i) end
	end
end

local counts = {}
for _, kind in ipairs(spawned) do counts[kind] = (counts[kind] or 0) + 1 end
assert(counts.boss_summoner == 1, "the authored boss should spawn once")
assert(counts.runner == 5, "all of the first authored escort group should spawn")
assert(counts.tank == 6, "all of the second authored escort group should spawn")
assert((counts.grunt or 0) > 0, "the first timed reinforcement burst should spawn")
assert((counts.grunt or 0) <= 34, "reinforcements must respect maxTotal")
assert(peakActive <= Waves.getActiveEnemyCap(), "both spawn sources must respect the active cap")
assert(#spawned - (counts.grunt or 0) == preview.total,
	"the live spawner must deliver the preview's complete authored total")

-- A pending add queue is wave work even if combat removes the boss before the
-- next update gets a chance to discard that queue.
state.activeBoss = {kind = "boss_summoner", boss = true, hp = 1, x = 0, y = 0}
Waves.resetSpawner()
assert(Waves.startWave())
Waves.updateSpawner(2.40)
enemies.enemies = {}
assert(not Waves.allEnemiesCleared(), "pending boss adds must prevent wave completion")

print("waves_boss_adds_test: ok")

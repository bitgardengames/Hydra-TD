local storedData
local writes = 0

love = {
	filesystem = {
		getInfo = function(path)
			if path == "saves/save.lua" then return storedData and {} or nil end
			return nil
		end,
		load = function()
			return function() return storedData end
		end,
		createDirectory = function() return true end,
		write = function()
			writes = writes + 1
			return true
		end,
	},
}

local Save = require("core.save")

-- Fresh saves and loaded saves share the same default-building path.
Save.load()
assert(Save.data.version == 6)
assert(Save.data.settings.screenShake == true)
assert(Save.data.settings.reducedFlash == false)
assert(Save.data.settings.keybinds.actions.escape == "escape")
assert(Save.data.meta.TOWER_PLASMA_KILLS == 0)
assert(type(Save.data.meta.enemyHistory) == "table")
assert(writes == 0, "a fresh in-memory save should not be written until requested")

-- One normalization pass repairs every section and persists it only once.
storedData = {
	version = 6,
	settings = {musicVolume = 0, screenShake = false, keybinds = {actions = {escape = ""}}},
	meta = {ENEMIES_KILLED = 12, enemyHistory = "invalid"},
	mapStats = {riverbend = {bestWave = 4}},
	mapIdMigrationDone = true,
}
writes = 0
Save.load()
assert(Save.data.settings.musicVolume == 0, "valid falsey settings must be preserved")
assert(Save.data.settings.screenShake == false, "explicitly disabled settings must be preserved")
assert(Save.data.settings.keybinds.actions.escape == "escape")
assert(Save.data.meta.ENEMIES_KILLED == 12)
assert(type(Save.data.meta.enemyHistory) == "table")
assert(Save.data.mapStats.riverbend.bestEndlessWave == 0)
assert(type(Save.data.mapStats.riverbend.medalEarnedAt) == "table")
assert(writes == 1, "all normalization changes should be flushed together")

-- Legacy progression still migrates before the common defaults are applied.
storedData = {
	version = 5,
	unlockedMaps = {alpha = true},
	mapStats = {alpha = {bestWave = 25, completedDifficulty = "normal"}},
}
writes = 0
Save.load()
assert(Save.data.version == 6)
assert(Save.data.unlockedMaps.alpha == nil and Save.data.unlockedMaps.riverbend == true)
assert(Save.data.mapStats.alpha == nil)
assert(Save.data.mapStats.riverbend.bestWave == 20)
assert(Save.data.mapStats.riverbend.bestEndlessWave == 25)
assert(Save.data.mapIdMigrationDone == true)
assert(writes == 1, "version and map migrations should share one flush")


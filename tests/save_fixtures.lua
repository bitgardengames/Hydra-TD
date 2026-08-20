-- Dependency-free recovery fixtures. Run from the repository root with Lua/LuaJIT.
package.path = "./?.lua;" .. package.path

local function compiler(source, name)
	if loadstring then return loadstring(source, name) end
	return load(source, name, "t", {})
end

local files = {}
local directories = {}

love = {
	filesystem = {
		getInfo = function(path)
			if files[path] then return {type = "file"} end
			if directories[path] then return {type = "directory"} end
		end,
		createDirectory = function(path) directories[path] = true; return true end,
		write = function(path, contents) files[path] = contents; return true end,
		load = function(path)
			if not files[path] then return nil, "missing" end
			return compiler(files[path], "@" .. path)
		end,
		remove = function(path) files[path] = nil; return true end,
		rename = function(from, to)
			if not files[from] then return false, "missing source" end
			files[to], files[from] = files[from], nil
			return true
		end,
	},
}

package.loaded["core.hotkeys"] = {
	getDefaultBindings = function() return {shop = {}, actions = {}} end,
}
local Save = require("core.save")

local function reset(seed)
	files, directories = seed or {}, {saves = true}
	Save.data, Save.dirty, Save.dirtyTimer = nil, false, nil
end

local function check(value, message)
	assert(value, message)
end

-- Malformed primaries are retained for diagnosis instead of overwritten.
reset({["saves/save.lua"] = "return { broken ="})
Save.load()
local diagnostic
for path in pairs(files) do
	if path:match("^saves/save%.corrupt%-%d%d%d%d%d%d%d%d%-%d%d%d%d%d%d") then diagnostic = path end
end
check(diagnostic and files[diagnostic], "malformed primary was not preserved")
check(Save.data.version == 8, "malformed save did not produce fresh data")

-- Older saves migrate while retaining fields this version does not know about.
reset({["saves/save.lua"] = "return { version = 1, unknownFutureField = { enabled = true } }"})
Save.load()
check(Save.data.version == 8, "old version was not migrated")
check(Save.data.unknownFutureField.enabled, "unknown field was discarded")
check(files["saves/save.bak.lua"], "pre-migration save was not backed up")

-- An interrupted temporary write never supersedes a known-good primary.
reset({
	["saves/save.lua"] = "return { version = 6, sentinel = 'primary' }",
	["saves/save.tmp.lua"] = "return { version = 6, sentinel = 'temporary' }",
})
Save.load()
check(Save.data.sentinel == "primary", "temporary file was loaded as primary")

-- A corrupt primary recovers from backup and promotes the recovered data.
reset({
	["saves/save.lua"] = "not valid lua",
	["saves/save.bak.lua"] = "return { version = 6, sentinel = 'backup' }",
})
Save.load()
check(Save.data.sentinel == "backup", "backup was not restored")
local restored = assert(love.filesystem.load("saves/save.lua"))()
check(restored.sentinel == "backup", "backup data was not promoted")

-- Dirty writes are coalesced until the timer expires.
Save.data.sentinel = "coalesced"
Save.markDirty()
Save.update(0.1)
check(assert(love.filesystem.load("saves/save.lua"))().sentinel == "backup", "dirty save flushed too early")
Save.update(0.3)
check(assert(love.filesystem.load("saves/save.lua"))().sentinel == "coalesced", "dirty save did not flush")

-- Ability selections only dirty the save when the normalized two-slot loadout changes.
Save.data.equippedAbilities = {"meteor", "frost_nova"}
Save.dirty, Save.dirtyTimer = false, nil
local accepted, changed = Save.setEquippedAbilities({"meteor", "frost_nova", "ignored_third_slot"})
check(accepted and not changed, "unchanged ability selection was not reported as a no-op")
check(not Save.dirty and Save.dirtyTimer == nil, "unchanged ability selection marked the save dirty")

accepted, changed = Save.setEquippedAbilities({"frost_nova", "meteor"})
check(accepted and changed, "reordered ability selection was not reported as changed")
check(Save.dirty, "reordered ability selection did not mark the save dirty")

Save.dirty, Save.dirtyTimer = false, nil
accepted, changed = Save.setEquippedAbilities({"frost_nova", "lightning"})
check(accepted and changed, "replaced ability selection was not reported as changed")
check(Save.dirty, "replaced ability selection did not mark the save dirty")

accepted, changed = Save.setEquippedAbilities("meteor")
check(not accepted and not changed, "invalid ability selection was not rejected")

-- Map history retains only completion difficulty and the time each medal was earned.
reset({["saves/save.lua"] = [[return {
	version = 7,
	mapStats = {riverbend = {
		bestWave = 19, legacyPeakWave = 42, wins = 3, losses = 4,
		completedDifficulty = "normal", medalEarnedAt = {easy = 100, normal = 200},
	}, failed_map = {bestWave = 12, losses = 2}},
}]]})
Save.load()
local mapStats = Save.data.mapStats.riverbend
check(mapStats.completedDifficulty == "normal", "map completion difficulty was discarded")
check(mapStats.medalEarnedAt.easy == 100 and mapStats.medalEarnedAt.normal == 200,
	"map completion timestamps were discarded")
check(type(mapStats.records) == "table", "version 7 map records were not explicitly migrated")
check(mapStats.bestWave == nil and mapStats.legacyPeakWave == nil
	and mapStats.wins == nil and mapStats.losses == nil, "excess map statistics survived migration")
check(Save.data.mapStats.failed_map == nil, "an uncleared map record survived migration")

Save.recordMapResult("switchback", "hard", false)
check(Save.data.mapStats.switchback == nil, "a failed run created map statistics")
Save.recordMapResult("switchback", "hard", true)
check(Save.data.mapStats.switchback.completedDifficulty == "hard", "a map clear was not recorded")
check(type(Save.data.mapStats.switchback.medalEarnedAt.hard) == "number",
	"a map clear timestamp was not recorded")

-- Version 9 records are isolated by map/mode/difficulty and only strict
-- improvements replace a best. Failed runs may improve score, but never clear
-- quality; cancelled runs are rejected before persistence.
local first = Save.recordRun("switchback", "campaign", "normal", {
	outcome = "completed", score = 100, duration = 90, remainingLives = 8, leaks = 3, wave = 20,
})
check(#first == 4, "first clear did not establish all campaign records")
check(#Save.recordRun("switchback", "campaign", "normal", {
	outcome = "completed", score = 100, duration = 90, remainingLives = 8, leaks = 3,
}) == 0, "a tied result was reported as a new record")
Save.recordRun("switchback", "campaign", "normal", {
	outcome = "completed", score = 120, duration = 80, remainingLives = 10, leaks = 1,
})
local normal = Save.getMapRecords("switchback", "campaign", "normal")
check(normal.bestScore == 120 and normal.fastestClear == 80 and normal.highestRemainingLives == 10
	and normal.fewestLeaks == 1, "strict improvements were not retained")
Save.recordRun("switchback", "campaign", "easy", {outcome = "completed", score = 999,
	duration = 20, remainingLives = 20, leaks = 0})
check(normal.bestScore == 120, "a lower-difficulty result contaminated another difficulty")
Save.recordRun("switchback", "campaign", "normal", {outcome = "failed", score = 130,
	duration = 10, remainingLives = 0, leaks = 20})
check(normal.bestScore == 130 and normal.fastestClear == 80 and normal.fewestLeaks == 1,
	"a failed run updated clear-only records")
check(#Save.recordRun("switchback", "campaign", "normal", {outcome = "abandoned", score = 9999}) == 0
	and normal.bestScore == 130, "an abandoned run updated records")
Save.recordRun("switchback", "endless", "hard", {outcome = "failed", score = 20, wave = 31})
check(Save.getMapRecords("switchback", "endless", "hard").highestEndlessWave == 31,
	"endless wave was not recorded")

-- Contract migration is additive, attempts are idempotent, and only better
-- objective results replace a personal best.
check(type(Save.data.contracts.attempted) == "table"
	and type(Save.data.contracts.completed) == "table"
	and type(Save.data.contracts.personalBests) == "table", "contract history was not migrated")
local contract = require("systems.contracts").generate(20000 * 86400, "daily", 1)
check(Save.recordContractAttempt(contract.id), "first contract attempt was not recorded")
check(not Save.recordContractAttempt(contract.id), "repeat attempt was recorded twice")
contract.objective = {id = "score", direction = "max", label = "Highest score"}
check(Save.recordContractCompletion(contract, {score = 100}), "first personal best was not recorded")
check(not Save.recordContractCompletion(contract, {score = 90}), "worse repeat result replaced personal best")
check(Save.data.contracts.personalBests[contract.id].value == 100, "personal best value changed")
check(Save.data.contracts.completed[contract.id] == true, "completion ID was not persisted")

print("save fixtures passed")

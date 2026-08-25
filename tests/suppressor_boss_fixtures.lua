-- Dependency-free regression checks for the Suppressor's encounter identity.
-- Run from the repository root with: lua tests/suppressor_boss_fixtures.lua
local defs = dofile("world/enemy_defs.lua")
local suppressor = assert(defs.boss_suppression)

assert(suppressor.hp >= 400 and suppressor.hp <= 500,
	"Suppressor health must remain in line with the other specialist bosses")
assert(suppressor.suppression.period == 20 and suppressor.suppression.duration == 5,
	"Suppressor must disable one tower for five seconds on a twenty-second cadence")

local wavesSource = assert(io.open("systems/waves.lua", "r")):read("*a")
local templateBlock = wavesSource:match("local bossEncounterTemplates = {(.-)\n}") or ""
assert(not templateBlock:find("boss_suppression", 1, true),
	"Suppressor must not have a reinforcement-spawning encounter template")

local towersSource = assert(io.open("world/towers.lua", "r")):read("*a")
assert(towersSource:find("target.suppressedTimer = suppression.duration", 1, true),
	"Suppressor casts must apply their authored duration to one tower")
assert(towersSource:find("if (t.suppressedTimer or 0) > 0 then", 1, true),
	"suppressed towers must be gated out of the firing update")

print("suppressor boss fixtures passed")

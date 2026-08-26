-- Dependency-free regression checks for the Suppressor's encounter identity.
-- Run from the repository root with: lua tests/suppressor_boss_fixtures.lua
local defs = dofile("world/enemy_defs.lua")
local suppressor = assert(defs.boss_suppression)

assert(suppressor.hp >= 400 and suppressor.hp <= 500,
	"Suppressor health must remain in line with the other specialist bosses")
assert(suppressor.suppression.period == 8 and suppressor.suppression.duration == 5,
	"Suppressor must disable one tower for five seconds on an eight-second cadence")
assert(suppressor.suppression.initialDelay == nil,
	"Suppressor must use the same eight-second delay before and between casts")
assert(suppressor.suppression.range == 240 and suppressor.suppression.projectileSpeed > 0,
	"Suppressor casts must have a finite vicinity and a visible travel time")

local wavesSource = assert(io.open("systems/waves.lua", "r")):read("*a")
local templateBlock = wavesSource:match("local bossEncounterTemplates = {(.-)\n}") or ""
assert(not templateBlock:find("boss_suppression", 1, true),
	"Suppressor must not have a reinforcement-spawning encounter template")

local towersSource = assert(io.open("world/towers.lua", "r")):read("*a")
assert(towersSource:find("distance2 <= range2", 1, true),
	"Suppressor casts must only target a tower in the boss's vicinity")
assert(towersSource:find("candidate.gy < target.gy", 1, true),
	"Suppressor targeting must use a deterministic grid-position tie-break")
assert(towersSource:find("applySuppression(target, p.duration)", 1, true),
	"Suppression must be applied when the boss projectile reaches its tower")
assert(towersSource:find("if (t.suppressedTimer or 0) > 0 then", 1, true),
	"suppressed towers must be gated out of the firing update")

local renderSource = assert(io.open("render/draw_entities.lua", "r")):read("*a")
assert(renderSource:find("local function drawSuppressionProjectiles()", 1, true),
	"Suppressor casts must have a dedicated visible projectile")

print("suppressor boss fixtures passed")

-- Dependency-free source checks for player-facing active-ability hooks.
local function read(path)
	local file = assert(io.open(path, "r"))
	local source = file:read("*a")
	file:close()
	return source
end

local bottomBar = read("ui/bottom_bar.lua")
assert(not bottomBar:find('require("ui.ability_bar")', 1, true),
	"the in-game HUD must not load the active-ability bar")
assert(not bottomBar:find("AbilityBar.draw()", 1, true),
	"the in-game HUD must not draw the active-ability bar")

local input = read("ui/input.lua")
assert(not input:find("systems.abilities", 1, true)
	and not input:find("abilityTargeting", 1, true),
	"gameplay input must not load or access active abilities")

local settings = read("ui/menu/screens/settings.lua")
assert(not settings:find('id = "abilitySlot1"', 1, true)
	and not settings:find('id = "abilitySlot2"', 1, true),
	"active-ability hotkeys must be hidden from settings")

local hotkeys = read("core/hotkeys.lua")
assert(not hotkeys:find("abilitySlot1", 1, true)
	and not hotkeys:find("abilitySlot2", 1, true),
	"active-ability hotkeys must not be available through saved bindings")

local sim = read("core/sim.lua")
assert(not sim:find("systems.abilities", 1, true)
	and not sim:find("Abilities.update", 1, true),
	"the simulation loop must not load or update active abilities")

local draw = read("render/draw.lua")
local drawWorld = read("render/draw_world.lua")
assert(not draw:find("drawAbilityPreview", 1, true)
	and not drawWorld:find("systems.abilities", 1, true),
	"draw loops must not load or render active abilities")

local enemies = read("world/enemies.lua")
assert(not enemies:find("systems.abilities", 1, true),
	"enemy deaths must not execute active-ability income or charge hooks")

local rewards = read("systems/campaign_unlocks.lua")
assert(not rewards:find('{type = "ability"', 1, true),
	"experimental active abilities must not be offered as campaign rewards")

print("inactive ability integration fixtures passed")

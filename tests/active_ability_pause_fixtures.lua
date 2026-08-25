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
assert(not input:find("abilitySlot1 = function", 1, true)
	and not input:find("abilitySlot2 = function", 1, true),
	"active-ability hotkeys must not dispatch gameplay actions")

local settings = read("ui/menu/screens/settings.lua")
assert(not settings:find('id = "abilitySlot1"', 1, true)
	and not settings:find('id = "abilitySlot2"', 1, true),
	"active-ability hotkeys must be hidden from settings")

print("active ability pause fixtures passed")

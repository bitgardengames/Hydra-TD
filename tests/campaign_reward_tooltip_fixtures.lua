-- Dependency-free source checks for campaign map reward presentation.
local file = assert(io.open("ui/menu/screens/campaign.lua", "r"))
local source = file:read("*a")
file:close()

assert(not source:find('require("ui.ability_tooltip")', 1, true),
	"campaign screen must not load the active ability tooltip")
assert(not source:find("AbilityTooltip.show", 1, true),
	"campaign map rewards must not show active ability tooltips")

print("campaign reward presentation fixtures passed")

-- Dependency-free source checks for campaign map reward tooltips.
local file = assert(io.open("ui/menu/screens/campaign.lua", "r"))
local source = file:read("*a")
file:close()

assert(source:find('local AbilityTooltip = require("ui.ability_tooltip")', 1, true),
	"campaign screen must use the shared active ability tooltip")
assert(source:find('hoveredReward and hoveredReward.type == "ability"', 1, true),
	"campaign rewards must only use the active ability tooltip for ability rewards")
assert(source:find("AbilityTooltip.show(hoveredReward.id)", 1, true),
	"hovering an ability map reward must show that ability's informational tooltip")

print("campaign reward tooltip fixtures passed")

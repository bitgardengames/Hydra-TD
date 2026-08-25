-- Dependency-free source checks for campaign active-ability slot mouseovers.
local file = assert(io.open("ui/menu/screens/campaign.lua", "r"))
local source = file:read("*a")
file:close()

assert(source:find("local hoveredAbilitySlot", 1, true),
	"campaign screen must track the active ability slot under the mouse")
assert(source:find("hoveredAbilitySlot == slot", 1, true),
	"campaign ability cards must receive their hovered presentation state")
assert(source:find("AbilityTooltip.show(equipped[hoveredAbilitySlot])", 1, true),
	"hovering an equipped campaign ability slot must expose its tooltip data")
assert(not source:find('L("campaign.abilityLevel"', 1, true),
	"equipped campaign ability slots must not display a level label")

print("campaign ability slot hover fixtures passed")

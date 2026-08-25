-- Dependency-free source checks for the paused campaign active-ability UI.
local file = assert(io.open("ui/menu/screens/campaign.lua", "r"))
local source = file:read("*a")
file:close()

assert(not source:find('Text.printShadow(L("campaign.abilityLoadout")', 1, true),
	"campaign map selection must not show the active-ability heading")
assert(not source:find("hoveredAbilitySlot == slot", 1, true),
	"campaign map selection must not draw active-ability slots")
assert(not source:find("showAbilitySlotTooltip(hoveredAbilitySlot", 1, true),
	"campaign map selection must not expose active-ability slot tooltips")
assert(not source:find("\n\tdrawAbilityPicker(l)\n", 1, true),
	"campaign map selection must not draw the active-ability picker")
assert(not source:find("selectedAbilitySlot = slot", 1, true),
	"campaign map selection must not open active-ability selection")

print("paused campaign ability UI fixtures passed")

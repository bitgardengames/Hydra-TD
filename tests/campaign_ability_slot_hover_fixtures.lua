-- Dependency-free source checks for campaign active-ability slot mouseovers.
local file = assert(io.open("ui/menu/screens/campaign.lua", "r"))
local source = file:read("*a")
file:close()

assert(source:find("local hoveredAbilitySlot", 1, true),
	"campaign screen must track the active ability slot under the mouse")
assert(source:find("hoveredAbilitySlot == slot", 1, true),
	"campaign ability cards must receive their hovered presentation state")
assert(source:find("showAbilitySlotTooltip(hoveredAbilitySlot, equipped[hoveredAbilitySlot])", 1, true),
	"hovering an equipped campaign ability slot must expose its tooltip data")
assert(source:find('L(unlocked and "campaign.selectAbility" or "abilityUnlock.slotLocked")', 1, true),
	"empty campaign slots must distinguish unlocked selection prompts from locked slots")
assert(source:find("if x and mx >= x", 1, true),
	"empty and locked campaign ability cards must participate in hover detection")
assert(source:find("local ABILITY_SLOT_COUNT = 2", 1, true),
	"campaign map selection must only present two active ability slots")
assert(source:find("local ABILITY_CARD_SIZE = 140", 1, true),
	"campaign map selection must use compact active ability cards")
assert(source:find("ABILITY_CARD_SIZE, ABILITY_CARD_SIZE", 1, true),
	"campaign active ability cards must stay square")
assert(not source:find("for slot = 1, 3", 1, true),
	"campaign map selection must not draw or inspect a third active ability slot")
assert(not source:find('L("campaign.abilityLevel"', 1, true),
	"equipped campaign ability slots must not display a level label")
assert(not source:find("editLoadout", 1, true),
	"campaign map selection must not show an edit loadout button")

print("campaign ability slot hover fixtures passed")

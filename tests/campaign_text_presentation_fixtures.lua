-- Dependency-free source checks for campaign screen text presentation.
local campaignFile = assert(io.open("ui/menu/screens/campaign.lua", "r"))
local campaignSource = campaignFile:read("*a")
campaignFile:close()

assert(not campaignSource:find("lg.print", 1, true),
	"campaign screen text must use the shadowed text helpers")
assert(campaignSource:find("Text.printShadow", 1, true),
	"campaign screen must render unaligned text with a shadow")
assert(campaignSource:find("Text.printfShadow", 1, true),
	"campaign screen must render aligned text with a shadow")
assert(campaignSource:find("lg.setColor(Theme.ui.text)\n\t\tText.printShadow(index", 1, true),
	"selected and unselected map names must use the same text color")
assert(not campaignSource:find('lg.rectangle("line", rowX, highlightY', 1, true),
	"map selection rows must not draw an animated outline")
assert(campaignSource:find("local CAMPAIGN_CARD_MAX_H = 680", 1, true),
	"campaign card must use the compact height")
assert(campaignSource:find("local BUTTON_BOTTOM_GAP = 31", 1, true),
	"campaign actions must share a consistent bottom gap")

local buttonFile = assert(io.open("ui/button.lua", "r"))
local buttonSource = buttonFile:read("*a")
buttonFile:close()

assert(buttonSource:find('btn.label:gsub("\\n", "")', 1, true),
	"button labels must account for every line when vertically centered")
assert(buttonSource:find("(h - labelHeight) * 0.5", 1, true),
	"button label blocks must be vertically centered")

print("campaign text presentation fixtures passed")

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
assert(campaignSource:find("local CAMPAIGN_CARD_MAX_H = 676", 1, true),
	"campaign card must match the reference layout height")
assert(campaignSource:find("local SPACE = 12", 1, true)
	and campaignSource:find("local PANEL_PAD = 24", 1, true)
	and campaignSource:find("local SECTION_INSET = 32", 1, true),
	"campaign columns must derive their geometry from shared spacing tokens")
assert(campaignSource:find("local LIST_ROW_STEP = LIST_ROW_H + SPACE", 1, true)
	and campaignSource:find("local DIFFICULTY_CARD_STEP = DIFFICULTY_CARD_H + SPACE", 1, true),
	"campaign lists and difficulty cards must use the shared gap")
assert(campaignSource:find("local LIST_ROW_H = 73", 1, true)
	and campaignSource:find("local DIFFICULTY_CARD_H = 78", 1, true),
	"campaign selection controls must use the compact heights")
assert(campaignSource:find("local LIST_SCROLL_REDUCTION = 30", 1, true)
	and campaignSource:find("l.left.h - 112 - LIST_SCROLL_REDUCTION", 1, true),
	"campaign map list and scrollbar must use the shortened scroll area")
assert(campaignSource:find("local BUTTON_BOTTOM_GAP = 24", 1, true),
	"campaign actions must align to the shared panel padding")
assert(campaignSource:find("local BACK_BUTTON_H = 54", 1, true)
	and campaignSource:find("local PLAY_BUTTON_H = 78", 1, true),
	"campaign action geometry must use shared height tokens")

local buttonFile = assert(io.open("ui/button.lua", "r"))
local buttonSource = buttonFile:read("*a")
buttonFile:close()

assert(buttonSource:find('btn.label:gsub("\\n", "")', 1, true),
	"button labels must account for every line when vertically centered")
assert(buttonSource:find("(h - labelHeight) * 0.5", 1, true),
	"button label blocks must be vertically centered")

print("campaign text presentation fixtures passed")

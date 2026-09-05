-- Upcoming-enemy tooltips describe the enemy without repeating threat tags.
local file = assert(io.open("ui/wave_preview.lua", "r"))
local source = file:read("*a")
file:close()

assert(source:find("local function buildEnemyTooltip", 1, true),
	"wave preview must continue to build enemy tooltips")
assert(source:find("L(def.descriptionKey)", 1, true),
	"upcoming-enemy tooltips must retain enemy descriptions")
assert(not source:find('L("hud.threatTags"', 1, true),
	"upcoming-enemy tooltips must not include threat lines")

print("wave preview tooltip fixtures passed")

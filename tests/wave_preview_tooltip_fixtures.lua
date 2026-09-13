-- Upcoming-enemy tooltips describe enemies using their authored descriptions.
local file = assert(io.open("ui/wave_preview.lua", "r"))
local source = file:read("*a")
file:close()

assert(source:find("local function buildEnemyTooltip", 1, true),
	"wave preview must continue to build enemy tooltips")
assert(source:find("L(def.descriptionKey)", 1, true),
	"upcoming-enemy tooltips must retain enemy descriptions")
assert(source:find('L("hud.enemyHealth")', 1, true),
	"upcoming-enemy tooltips must label enemy health")
assert(source:find("Util.formatInt(group.health)", 1, true),
	"upcoming-enemy tooltips must show formatted, scaled enemy health")

local defs = dofile("world/enemy_defs.lua")
for kind, def in pairs(defs) do
	assert(def.descriptionKey, kind .. " must provide a wave-preview description")
end

print("wave preview tooltip fixtures passed")

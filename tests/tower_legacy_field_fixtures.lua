-- Static regression checks for the behavior-plan migration. Run from the
-- repository root with: lua tests/tower_legacy_field_fixtures.lua
package.path = "./?.lua;./?/init.lua;" .. package.path

package.loaded["core.theme"] = { tower = {
	slow = {}, lancer = {}, poison = {}, cannon = {}, shock = {}, plasma = {},
} }

local TowerDefs = require("world.tower_defs")
local removedDefinitionFields = {"onHitSlow", "splash", "chain", "poison", "plasma"}

for kind, def in pairs(TowerDefs) do
	for _, field in ipairs(removedDefinitionFields) do
		assert(def[field] == nil, kind .. " restored removed definition field " .. field)
	end
end

local cannonTargeting = assert(TowerDefs.cannon.targeting,
	"Cannon must explicitly declare its exceptional targeting behavior")
assert(cannonTargeting.leadPathTargetsAboveSpeed == 20,
	"Cannon path-leading threshold changed unexpectedly")
for kind, def in pairs(TowerDefs) do
	if kind ~= "cannon" then
		assert(def.targeting == nil, kind .. " unexpectedly opted into Cannon path leading")
	end
end

local function read(path)
	local file = assert(io.open(path, "r"))
	local source = file:read("*a")
	file:close()
	return source
end

local towersSource = read("world/towers.lua")
for _, field in ipairs(removedDefinitionFields) do
	assert(not towersSource:find("def." .. field, 1, true),
		"tower construction still reads removed definition field " .. field)
	assert(not towersSource:find("t." .. field, 1, true),
		"tower runtime still reads removed instance field " .. field)
end
assert(not towersSource:find("SPLASH_LEAD_SPEED_THRESHOLD", 1, true),
	"legacy splash-leading threshold returned")

local exportSource = read("tools/achievement_export.lua")
for _, field in ipairs(removedDefinitionFields) do
	assert(not exportSource:find("def." .. field, 1, true),
		"achievement export still reads removed definition field " .. field)
	assert(not exportSource:find("t." .. field, 1, true),
		"achievement export still reads removed tower-instance field " .. field)
end

print("tower legacy field fixtures passed")

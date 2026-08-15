-- Dependency-free projectile color fixtures. Run from the repository root with Lua/LuaJIT.
package.path = "./?.lua;" .. package.path

local colors = {}
local graphics = {}

function graphics.setColor(r, g, b, a)
	colors[#colors + 1] = {r, g, b, a}
end

for _, name in ipairs({"circle", "ellipse", "pop", "push", "rectangle", "rotate", "translate"}) do
	graphics[name] = function() end
end

love = {graphics = graphics}

local ProjectileBehaviors = require("world.projectile_behaviors")
local towerColor = {0.12, 0.34, 0.56}
local fixtures = {
	{id = "draw_lancer", fallback = {0.97, 0.97, 0.97}},
	{id = "draw_slow", fallback = {0.7, 0.85, 1.0}},
	{id = "draw_poison", fallback = {0.55, 0.85, 0.45}},
	{id = "draw_cannon", fallback = {1.0, 0.8, 0.4}},
	{id = "draw_plasma", fallback = {0.85, 0.55, 1.0}},
	{id = "draw_shock_orb", fallback = {0.6, 0.9, 1.0}},
}

local function firstDrawColor(behaviorId, sourceTower)
	local p = {
		behaviors = {{id = behaviorId}},
		baseR = 4.5,
		r = 4.5,
		t = 0,
		sourceTower = sourceTower,
	}
	colors = {}
	ProjectileBehaviors.compileHooks(p)
	ProjectileBehaviors.draw(p, 1)
	assert(colors[1], behaviorId .. " did not set a draw color")
	return colors[1]
end

local function assertRGB(actual, expected, message)
	for i = 1, 3 do
		assert(actual[i] == expected[i], message .. " component " .. i)
	end
end

for _, fixture in ipairs(fixtures) do
	assertRGB(firstDrawColor(fixture.id), fixture.fallback, fixture.id .. " fallback color changed")
	assertRGB(firstDrawColor(fixture.id, {color = towerColor}), towerColor,
		fixture.id .. " did not prefer its source tower color")
end

print("projectile color fixtures passed")

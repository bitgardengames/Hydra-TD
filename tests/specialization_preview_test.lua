-- Run with: lua tests/specialization_preview_test.lua (no LÖVE context needed).
package.path = "./?.lua;./?/init.lua;" .. package.path

local Preview = require("ui.specialization_preview")
local EnemyDefs = require("world.enemy_defs")
local expected = {
	"marksman", "rupture", "deep_freeze", "cold_field", "virulent", "contagion",
	"siege", "bombardment", "capacitor", "forked_lightning", "accelerator", "overcharged",
}

for i = 1, #expected do
	local id, def = expected[i], Preview.definitions[expected[i]]
	assert(def, "missing definition for " .. id)
	assert(def.duration and def.tower and def.enemies and def.shots and def.speed and def.impact and def.effect)
	for enemyIndex = 1, #def.enemies do
		local kind = def.enemies[enemyIndex][1]
		assert(EnemyDefs[kind], id .. " preview uses unknown enemy kind " .. tostring(kind))
	end
end

local function snapshot(p)
	local out = {p.elapsed, p.lastEvent, p.projectile.active, p.effect.active}
	for i=1,#p.enemies do
		local e=p.enemies[i]; out[#out+1]=e.x; out[#out+1]=e.y; out[#out+1]=e.poisonStacks
	end
	return table.concat(out, ":")
end

for i = 1, #expected do
	local p = Preview.new(expected[i])
	Preview.update(p, p.def.duration + 0.83)
	local first = snapshot(p)
	Preview.reset(p)
	Preview.update(p, 0.83)
	assert(snapshot(p) == first, expected[i] .. " loop did not reset deterministically")
	Preview.reset(p)
	Preview.update(p, p.def.duration * 2 + 2.1) -- crosses two loops in one update
	assert(p.lastEvent == #p.def.shots, expected[i] .. " did not fire each crossed event exactly once")
	assert(p.eventCount == #p.def.shots * 3, expected[i] .. " duplicated or skipped a large-dt event")
end

-- Records are private copies: neither construction nor mutation aliases authored
-- data (and therefore cannot alias live tower/enemy records either).
local a, b = Preview.new("marksman"), Preview.new("marksman")
a.tower.x, a.enemies[1].x = -99, -99
assert(b.tower.x ~= -99 and b.enemies[1].x ~= -99)
assert(Preview.definitions.marksman.tower[1] ~= -99)

print("specialization preview timeline tests passed")

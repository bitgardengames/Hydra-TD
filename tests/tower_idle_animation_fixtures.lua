local Idle = require("render.tower_idle_animation")

local kinds = {"lancer", "slow", "cannon", "shock", "poison", "plasma"}
local signatures = {}

for _, kind in ipairs(kinds) do
	local found = false
	local signature = {}
	for step = 0, 240 do
		local x, y, turn, effect = Idle.pose(step * 0.05, kind, 2, 0.25, true)
		assert(math.abs(x) <= 0.81 and math.abs(y) <= 0.66,
			"idle offsets must remain small")
		assert(math.abs(turn) <= 0.14 and effect >= 0 and effect <= 0.29,
			"idle turn and effect must remain restrained")
		if x ~= 0 or y ~= 0 or turn ~= 0 or effect ~= 0 then found = true end
		signature[#signature + 1] = string.format("%.2f:%.2f:%.2f:%.2f", x, y, turn, effect)
	end
	assert(found, kind .. " must eventually perform an idle gesture")
	signatures[kind] = table.concat(signature, "|")
end

for i = 1, #kinds do
	for j = i + 1, #kinds do
		assert(signatures[kinds[i]] ~= signatures[kinds[j]],
			"built-in idle gestures must be distinct")
	end
end

local x, y, turn, effect = Idle.pose(8, "lancer", 1, 0, false)
assert(x == 0 and y == 0 and turn == 0 and effect == 0,
	"disabled camera motion must suppress idle animation")

local a = {Idle.pose(8.2, "custom", 4, 0.1, true)}
local b = {Idle.pose(8.2, "custom", 4, 0.1, true)}
for i = 1, 4 do assert(a[i] == b[i], "idle poses must be deterministic") end
assert(a[1] == 0 and a[2] == 0 and math.abs(a[3]) <= 0.035 and a[4] == 0,
	"modded tower fallback must remain restrained")

print("tower idle animation fixtures passed")

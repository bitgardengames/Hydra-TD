-- Dependency-free checks for the render-only victory choreography.
local Dance = require("render.tower_victory_dance")

local function pose(t, i)
	local bob, nod = Dance.pose(t, i)
	assert(type(bob) == "number" and type(nod) == "number", "poses must be numeric")
	assert(math.abs(bob) <= 7.001, "turret bob must stay within its visual budget")
	assert(math.abs(nod) <= 0.181, "turret nod must stay within its visual budget")
	return bob, nod
end

local b1, n1 = pose(1.25, 1)
local b2, n2 = pose(1.25, 2)
local b3, n3 = pose(1.25, 3)
assert(b1 ~= b2 or n1 ~= n2, "adjacent towers should use different rhythms")
assert(b2 ~= b3 or n2 ~= n3, "all three choreography lanes should differ")

local delayedBob, delayedNod = pose(0.02, 4)
assert(delayedBob == 0 and delayedNod == 0, "the opening cheer should stagger across towers")

print("tower victory dance fixtures passed")

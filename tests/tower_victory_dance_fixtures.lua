-- Dependency-free checks for the render-only victory choreography.
local Dance = require("render.tower_victory_dance")

local function pose(t, kind, i)
	local bob, nod = Dance.pose(t, kind, i)
	assert(type(bob) == "number" and type(nod) == "number", "poses must be numeric")
	assert(math.abs(bob) <= 7.001, "turret bob must stay within its visual budget")
	assert(math.abs(nod) <= 0.181, "turret nod must stay within its visual budget")
	return bob, nod
end

local kinds = {"lancer", "slow", "cannon", "shock", "poison", "plasma"}
local seen = {}
for _, kind in ipairs(kinds) do
	local bob, nod = pose(1.25, kind, 1)
	local signature = string.format("%.4f:%.4f", bob, nod)
	assert(not seen[signature], "each tower type should have a unique dance pose")
	seen[signature] = kind
end

local b1, n1 = pose(1.25, "cannon", 1)
local b2, n2 = pose(1.25, "cannon", 2)
assert(b1 ~= b2 or n1 ~= n2, "duplicate towers should be slightly out of phase")

local delayedBob, delayedNod = pose(0.02, "lancer", 4)
assert(delayedBob == 0 and delayedNod == 0, "the opening cheer should stagger across towers")

print("tower victory dance fixtures passed")

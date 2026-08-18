-- Dependency-free checks for the render-only victory choreography.
local Dance = require("render.tower_victory_dance")

local function pose(t, kind, i)
	local sway, bob, turn = Dance.pose(t, kind, i)
	assert(type(sway) == "number" and type(bob) == "number" and type(turn) == "number",
		"poses must be numeric")
	assert(math.abs(sway) <= 4.201, "turret sway must stay within its visual budget")
	assert(math.abs(bob) <= 4.201, "turret bob must stay within its visual budget")
	return sway, bob, turn
end

local kinds = {"lancer", "slow", "cannon", "shock", "poison", "plasma"}
local seen = {}
for _, kind in ipairs(kinds) do
	local sway, bob, turn = pose(1.25, kind, 1)
	local signature = string.format("%.4f:%.4f:%.4f", sway, bob, turn)
	assert(not seen[signature], "each tower type should have a unique dance pose")
	seen[signature] = kind
end

local x1, b1, n1 = pose(1.25, "cannon", 1)
local x2, b2, n2 = pose(1.25, "cannon", 2)
assert(x1 ~= x2 or b1 ~= b2 or n1 ~= n2, "duplicate towers should be slightly out of phase")

local delayedSway, delayedBob, delayedTurn = pose(0.02, "lancer", 4)
assert(delayedSway == 0 and delayedBob == 0 and delayedTurn == 0,
	"the opening cheer should stagger across towers")

-- Tiny time steps should produce tiny pose changes: no hard kick or snap at a beat edge.
local beforeX, beforeY, beforeTurn = pose(1.25, "shock", 1)
local afterX, afterY, afterTurn = pose(1.251, "shock", 1)
assert(math.abs(afterX - beforeX) < 0.05 and math.abs(afterY - beforeY) < 0.05
	and math.abs(afterTurn - beforeTurn) < 0.05, "dance motion should remain fluid between frames")

-- Spins are individual dance moves rather than an angle that grows forever.
-- The turret should spend part of the choreography back near its neutral turn.
for _, kind in ipairs({"shock", "plasma"}) do
	local maxTurn = 0
	local foundNeutral = false
	for step = 10, 120 do
		local _, _, turn = pose(step * 0.05, kind, 1)
		maxTurn = math.max(maxTurn, math.abs(turn))
		if step > 30 and math.abs(turn) < 0.35 then
			foundNeutral = true
		end
		assert(math.abs(turn) <= math.pi * 2 + 0.31,
			kind .. " rotation should stay bounded instead of accumulating forever")
	end
	assert(maxTurn > math.pi, kind .. " should still include a full-spin move")
	assert(foundNeutral, kind .. " should return to non-spinning dance moves")
end

print("tower victory dance fixtures passed")

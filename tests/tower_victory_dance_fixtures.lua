-- Dependency-free checks for the render-only victory choreography.
local Dance = require("render.tower_victory_dance")

local function pose(t, kind, i)
	local sway, bob, turn = Dance.pose(t, kind, i)
	assert(type(sway) == "number" and type(bob) == "number" and type(turn) == "number",
		"poses must be numeric")
	assert(math.abs(sway) <= 7.001, "turret sway must stay within its visual budget")
	assert(math.abs(bob) <= 7.001, "turret bob must stay within its visual budget")
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

-- The entrance should leave rest without an acceleration kick. A quintic ease
-- makes the first two frame-to-frame deltas almost identical at either seam.
local function delta(kind, from, step)
	local x1, y1, turn1 = pose(from, kind, 1)
	local x2, y2, turn2 = pose(from + step, kind, 1)
	return x2 - x1, y2 - y1, turn2 - turn1
end

local entranceDx, entranceDy, entranceTurn = delta("lancer", 0, 0.001)
assert(math.abs(entranceDx) < 0.00001 and math.abs(entranceDy) < 0.00001
	and math.abs(entranceTurn) < 0.00001,
	"the dance entrance should ease away from a complete rest")

-- Signature flourishes should make each tower's movement distinct across a
-- whole phrase, not merely at one lucky sample in the base loop.
local phrases = {}
for _, kind in ipairs(kinds) do
	local samples = {}
	for step = 0, 23 do
		local sway, bob, turn = pose(2.75 + step * 0.05, kind, 1)
		samples[#samples + 1] = string.format("%.2f:%.2f:%.2f", sway, bob, turn)
	end
	local phrase = table.concat(samples, "|")
	assert(not phrases[phrase], "each tower type should have unique signature choreography")
	phrases[phrase] = kind
end

-- Plasma's zero-gravity hop and Shock's quick shimmy are intentionally
-- recognizable silhouettes, while still remaining compact around the base.
local _, plasmaBob, plasmaTurn = pose(3.35, "plasma", 1)
assert(plasmaBob < -2 and plasmaTurn > 2, "plasma should hop into a happy half-twirl")
local shockLeft = select(1, pose(3.03, "shock", 1))
local shockRight = select(1, pose(3.13, "shock", 1))
assert(shockLeft * shockRight < 0, "shock should shimmy rapidly from side to side")

-- Signature moves join the base choreography at 2.75 seconds. Their combined
-- motion should retain the base curve's tiny acceleration at that boundary.
for _, kind in ipairs(kinds) do
	local epsilon = 0.001
	local beforeX, beforeY, beforeTurn = pose(2.75 - epsilon, kind, 1)
	local edgeX, edgeY, edgeTurn = pose(2.75, kind, 1)
	local afterX, afterY, afterTurn = pose(2.75 + epsilon, kind, 1)
	local flourishAcceleration = math.abs((afterX - edgeX) - (edgeX - beforeX))
		+ math.abs((afterY - edgeY) - (edgeY - beforeY))
		+ math.abs((afterTurn - edgeTurn) - (edgeTurn - beforeTurn))
	assert(flourishAcceleration < 0.001,
		kind .. " signature should blend into its nod without an acceleration kick")
end

-- Tiny time steps should produce tiny pose changes: no hard kick or snap at a beat edge.
local beforeX, beforeY, beforeTurn = pose(1.25, "shock", 1)
local afterX, afterY, afterTurn = pose(1.251, "shock", 1)
assert(math.abs(afterX - beforeX) < 0.05 and math.abs(afterY - beforeY) < 0.05
	and math.abs(afterTurn - beforeTurn) < 0.05, "dance motion should remain fluid between frames")

-- Every tower occasionally adds a spin, then returns to its regular dance
-- instead of accumulating an ever-growing angle. Include the fallback dance so
-- custom tower kinds receive the extra move too.
for _, kind in ipairs({"lancer", "slow", "cannon", "shock", "poison", "plasma", "custom"}) do
	local maxTurn = 0
	local foundNeutral = false
	for step = 10, 240 do
		local _, _, turn = pose(step * 0.05, kind, 1)
		maxTurn = math.max(maxTurn, math.abs(turn))
		if step > 30 and math.abs(turn) < 0.35 then
			foundNeutral = true
		end
		assert(math.abs(turn) <= math.pi * 3 + 0.63,
			kind .. " rotation should stay bounded instead of accumulating forever")
	end
	assert(maxTurn > math.pi, kind .. " should still include a full-spin move")
	assert(foundNeutral, kind .. " should return to non-spinning dance moves")
end

-- Full spins should remain an occasional flourish rather than repeating during
-- the first several beats of the dance.
for _, kind in ipairs({"lancer", "slow", "cannon", "shock", "poison", "custom"}) do
	for step = 10, 120 do
		local _, _, turn = pose(step * 0.05, kind, 1)
		assert(math.abs(turn) < math.pi,
			kind .. " should save its full-spin flourish for later in the dance")
	end
end

print("tower victory dance fixtures passed")

-- Dependency-free campaign selection transition fixtures. Run from the repository root.
package.path = package.path .. ";./?.lua;./?/init.lua"

local Transition = require("ui.campaign_selection_transition")

local start = Transition.sample(2, 4, 0, false)
assert(start.markerIndex == 2 and start.rowIndex == 2, "selection indicators must begin on the old selection")

local middle = Transition.sample(4, 2, Transition.DURATION * 0.5, false)
assert(middle.markerIndex == 3 and middle.rowIndex == 3, "selection indicators must interpolate between nodes")

local finished = Transition.sample(2, 4, Transition.DURATION * 2, false)
assert(finished.complete and finished.markerIndex == 4 and finished.rowIndex == 4,
	"completed indicator transitions must settle exactly on the incoming selection")

local reduced = Transition.sample(2, 4, 0, true)
assert(reduced.complete and reduced.markerIndex == 4 and reduced.rowIndex == 4,
	"reduced motion must move selection indicators immediately")

print("campaign selection transition fixtures passed")

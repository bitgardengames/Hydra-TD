-- Dependency-free campaign selection transition fixtures. Run from the repository root.
package.path = package.path .. ";./?.lua;./?/init.lua"

local Transition = require("ui.campaign_selection_transition")

local start = Transition.sample(2, 4, 0, false)
assert(start.outgoingAlpha == 1 and start.incomingAlpha == 0, "transition must begin on the old selection")
assert(start.markerIndex == 2 and start.incomingOffset > 0, "forward navigation must offset from the right")

local middle = Transition.sample(4, 2, Transition.DURATION * 0.5, false)
assert(middle.markerIndex == 3 and middle.rowIndex == 3, "selection indicators must interpolate between nodes")
assert(middle.incomingOffset < 0, "backward navigation must offset from the left")

local finished = Transition.sample(2, 4, Transition.DURATION * 2, false)
assert(finished.complete and finished.incomingAlpha == 1 and finished.incomingOffset == 0,
	"completed transitions must settle exactly on the incoming selection")

local reduced = Transition.sample(2, 4, 0, true)
assert(reduced.complete and reduced.incomingAlpha == 1 and reduced.outgoingAlpha == 0,
	"reduced motion must swap selection immediately")
assert(reduced.incomingOffset == 0 and reduced.markerIndex == 4, "reduced motion must not retain movement")

print("campaign selection transition fixtures passed")

local Reveal = require("ui.reward_reveal")

assert(Reveal.delayFor(1) == 0, "the first new reward must start immediately")
assert(Reveal.delayFor(2) > Reveal.delayFor(1), "new rewards must retain authored ordering")

local pending = Reveal.sample(0, Reveal.delayFor(2), false)
assert(pending.progress == 0 and not pending.complete, "staggered rewards must remain pending")
local complete = Reveal.sample(10, Reveal.delayFor(2), false)
assert(complete.progress == 1 and complete.complete, "a finished reveal must settle exactly")
assert(complete.lift == 0 and complete.scale == 1, "completed motion must return to rest")

local moving = Reveal.sample(0.25, 0, false)
assert(moving.alpha > 0 and moving.alpha < 1 and moving.lift > 0,
	"normal reveals must fade and lift into place")
local reduced = Reveal.sample(0.25, 0, true)
assert(reduced.alpha == 1 and reduced.lift == 0 and reduced.scale == 1,
	"reduced motion must suppress position, scale, and opacity motion")
assert(reduced.glint > 0 and reduced.glint < 1,
	"reduced motion must retain the non-moving outline highlight")

local file = assert(io.open("ui/menu/screens/victory.lua", "r"))
local victorySource = file:read("*a")
file:close()
assert(victorySource:find("Screen.finishAnimations()", 1, true),
	"keyboard and pointer skip paths must share one completion operation")
assert(victorySource:find("Medals.finishReveal()", 1, true)
	and victorySource:find("runStats:finish()", 1, true),
	"skip must complete both preceding animation stages")
assert(not victorySource:find('require("ui.reward_reveal")', 1, true),
	"the victory screen must not retain reward reveal state after removing rewards")

print("reward reveal fixtures passed")

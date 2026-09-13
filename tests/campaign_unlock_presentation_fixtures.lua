-- Dependency-free campaign unlock presentation fixtures. Run from the repository root.

local Presentation = require("ui.campaign_unlock_presentation")

local function victory(rewards)
	return {
		wasFirstClear = true, worldMapIndex = 2, mapIndex = 2,
		unlockedRewardsThisVictory = rewards or {},
		unlockedTowersThisVictory = {"fixture"}, unlockedAbilitiesThisVictory = {"fixture"},
	}
end

local function verifyCompletionBoundary(rewardCount, reducedMotion)
	local rewards = {}
	for index = 1, rewardCount do
		rewards[index] = {type = "tower", id = "reward-" .. index}
	end
	local event = assert(Presentation.capture(Presentation.new(), victory(rewards), 5, reducedMotion))
	local completionTime
	if reducedMotion then
		completionTime = Presentation.REDUCED_HIGHLIGHT_DURATION
	else
		local rewardTime = rewardCount > 0
			and (rewardCount - 1) * Presentation.REWARD_STAGGER + Presentation.REWARD_DURATION or 0
		completionTime = math.max(Presentation.ROW_DURATION, rewardTime)
	end

	event.elapsed = completionTime - 0.000001
	assert(not Presentation.isComplete(event),
		("%s-motion presentation with %d rewards should be incomplete before its boundary")
			:format(reducedMotion and "reduced" or "normal", rewardCount))
	event.elapsed = completionTime
	assert(Presentation.isComplete(event),
		("%s-motion presentation with %d rewards should complete at its boundary")
			:format(reducedMotion and "reduced" or "normal", rewardCount))
	assert(Presentation.sample(event).complete,
		"sampled pose should report the same completion state as the allocation-free helper")
end

for _, reducedMotion in ipairs({false, true}) do
	for _, rewardCount in ipairs({0, 1, 3}) do
		verifyCompletionBoundary(rewardCount, reducedMotion)
	end
end

-- A first clear identifies the newly available map and acknowledges state only after capture.
local controller = Presentation.new()
local state = victory({{type = "ability", id = "meteor"}})
local event = assert(Presentation.capture(controller, state, 5, false))
assert(event.sourceIndex == 2 and event.targetIndex == 3, "first clear should identify the next map")
assert(not state.wasFirstClear and #state.unlockedRewardsThisVictory == 0,
	"campaign entry should acknowledge transient victory fields after copying them")
assert(Presentation.sample(event).row == 0, "map-row highlight should begin hidden")

-- Multiple reward icons retain deterministic order and independently settle.
controller = Presentation.new()
state = victory({{type = "tower", id = "cannon"}, {type = "ability", id = "meteor"}})
event = assert(Presentation.capture(controller, state, 5, false))
assert(#event.rewards == 2 and event.rewards[1].id == "cannon" and event.rewards[2].id == "meteor")
event.elapsed = Presentation.REWARD_DURATION
local pose = Presentation.sample(event)
assert(pose.rewards[1].progress > pose.rewards[2].progress, "reward settling should be staggered")

-- Returning without a new unlock cannot replay an acknowledged presentation.
controller.active = nil
assert(Presentation.capture(controller, state, 5, false) == nil, "revisit should not replay")

-- Interrupted navigation preserves the locally captured event and resumes it on re-entry.
controller = Presentation.new()
state = victory({{type = "ability", id = "meteor"}})
event = Presentation.capture(controller, state, 5, false)
Presentation.update(controller, 0.2)
local elapsed = event.elapsed
assert(Presentation.capture(controller, state, 5, false) == event and event.elapsed == elapsed,
	"interrupted entry should resume rather than restart")

-- Reduced motion uses only a brief color highlight.
controller = Presentation.new()
state = victory({{type = "ability", id = "meteor"}})
event = Presentation.capture(controller, state, 5, true)
pose = Presentation.sample(event)
assert(pose.row == 1, "reduced motion should retain a color highlight")
Presentation.update(controller, Presentation.REDUCED_HIGHLIGHT_DURATION + Presentation.REWARD_DURATION + 0.1)
assert(controller.active == nil, "reduced-motion highlight should finish deterministically")

print("campaign unlock presentation fixtures passed")

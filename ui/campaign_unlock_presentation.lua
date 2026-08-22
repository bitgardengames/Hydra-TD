local Presentation = {}

Presentation.LINE_DURATION = 0.65
Presentation.STAMP_DURATION = 0.48
Presentation.ROW_DURATION = 0.62
Presentation.REWARD_DURATION = 0.72
Presentation.REWARD_STAGGER = 0.16
Presentation.REDUCED_HIGHLIGHT_DURATION = 0.55

local function clamp01(value)
	return math.max(0, math.min(1, value))
end

local function smoothstep(value)
	value = clamp01(value)
	return value * value * (3 - 2 * value)
end

local function copyRewards(rewards)
	local result = {}
	for _, reward in ipairs(rewards or {}) do
		result[#result + 1] = {type = reward.type, id = reward.id, label = reward.label,
			labelKey = reward.labelKey}
	end
	return result
end

local function eventKey(sourceIndex, targetIndex, rewards)
	local parts = {tostring(sourceIndex), tostring(targetIndex)}
	for _, reward in ipairs(rewards) do
		parts[#parts + 1] = tostring(reward.type) .. ":" .. tostring(reward.id)
	end
	return table.concat(parts, "|")
end

function Presentation.new()
	return {active = nil, acknowledged = {}}
end

-- Capture before acknowledging the run-local fields. This means leaving the
-- campaign partway through cannot lose the presentation, while later entries
-- cannot reconstruct it forever from stale victory state.
function Presentation.capture(controller, state, mapCount, reducedMotion)
	if controller.active then return controller.active end
	if not state.wasFirstClear then return nil end

	local sourceIndex = tonumber(state.worldMapIndex) or tonumber(state.mapIndex) or 1
	local targetIndex = math.min(mapCount, sourceIndex + 1)
	local rewards = copyRewards(state.unlockedRewardsThisVictory)
	local key = eventKey(sourceIndex, targetIndex, rewards)
	if not controller.acknowledged[key] then
		controller.active = {
			key = key, sourceIndex = sourceIndex, targetIndex = targetIndex,
			rewards = rewards, elapsed = 0, reducedMotion = reducedMotion == true,
		}
		controller.acknowledged[key] = true
	end

	-- These are a handoff, not durable progression. Clear them only now, after
	-- the campaign owns a copy of everything needed to finish the sequence.
	state.wasFirstClear = false
	state.unlockedRewardsThisVictory = {}
	state.unlockedTowersThisVictory = {}
	state.unlockedAbilitiesThisVictory = {}
	return controller.active
end

function Presentation.update(controller, dt)
	local event = controller.active
	if not event then return end
	event.elapsed = event.elapsed + math.max(0, dt or 0)
	local pose = Presentation.sample(event)
	if pose.complete then controller.active = nil end
end

function Presentation.sample(event)
	if not event then return {complete = true, line = 1, stamp = 0, row = 0, rewards = {}} end
	local elapsed = event.elapsed
	local line, stamp, row
	local rewardStart
	if event.reducedMotion then
		line, stamp = 1, 0
		row = 1 - clamp01(elapsed / Presentation.REDUCED_HIGHLIGHT_DURATION)
		rewardStart = 0
	else
		line = smoothstep(elapsed / Presentation.LINE_DURATION)
		stamp = math.sin(math.pi * clamp01((elapsed - Presentation.LINE_DURATION) / Presentation.STAMP_DURATION))
		row = math.sin(math.pi * clamp01((elapsed - Presentation.LINE_DURATION * 0.72) / Presentation.ROW_DURATION))
		rewardStart = Presentation.LINE_DURATION + Presentation.STAMP_DURATION * 0.45
	end

	local rewardPoses, lastComplete = {}, true
	for index = 1, #event.rewards do
		local progress = event.reducedMotion and 1 or
			clamp01((elapsed - rewardStart - (index - 1) * Presentation.REWARD_STAGGER)
				/ Presentation.REWARD_DURATION)
		rewardPoses[index] = {progress = smoothstep(progress), visible = progress > 0 and progress < 1}
		lastComplete = lastComplete and progress >= 1
	end
	local baseComplete = event.reducedMotion
		and elapsed >= Presentation.REDUCED_HIGHLIGHT_DURATION
		or elapsed >= Presentation.LINE_DURATION + Presentation.STAMP_DURATION + Presentation.ROW_DURATION * 0.35
	return {complete = baseComplete and lastComplete, line = line, stamp = stamp, row = row,
		rewards = rewardPoses, sourceIndex = event.sourceIndex, targetIndex = event.targetIndex}
end

return Presentation

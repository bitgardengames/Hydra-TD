local Theme = require("core.theme")
local L = require("core.localization")

local DisplayStatuses = {}

local min = math.min
local max = math.max

local function fraction(remaining, duration)
	if not remaining or not duration or duration <= 0 then return nil end
	return max(0, min(1, remaining / duration))
end

-- Calls visitor(context, index, id, label, icon, color, stacks, value,
-- remainingFraction) for each active status, in display order. No temporary
-- status tables are created by this traversal.
function DisplayStatuses.visit(enemy, visitor, context)
	if not enemy then return 0 end

	local count = 0
	if (enemy.slowTimer or 0) > 0 then
		count = count + 1
		visitor(context, count, "slow", L("status.slow"), "▼", Theme.tower.slow,
			nil, nil, fraction(enemy.slowTimer, enemy.slowDuration))
	end
	if (enemy.poisonTimer or 0) > 0 and (enemy.poisonStacks or 0) > 0 then
		count = count + 1
		visitor(context, count, "poison", L("status.poison"), "●", Theme.tower.poison,
			enemy.poisonStacks, nil, fraction(enemy.poisonTimer, enemy.poisonDuration))
	end
	if enemy.support then
		count = count + 1
		visitor(context, count, "support_aura", L("status.supportAura"), "◉", Theme.ui.good)
	end
	if (enemy.supportBoost or 1) > 1 then
		count = count + 1
		visitor(context, count, "support_boost", L("status.supportBoost"), "▲", Theme.ui.good,
			nil, L("status.multiplier", enemy.supportBoost))
	end
	if enemy.regeneration and (enemy.regenDelay or 0) > 0 then
		count = count + 1
		visitor(context, count, "regeneration_suppressed", L("status.regenerationSuppressed"), "⊘", Theme.ui.bad,
			nil, nil, fraction(enemy.regenDelay, enemy.regeneration.delay))
	end
	if enemy.summon and (enemy.summonTimer or 0) > 0 then
		count = count + 1
		visitor(context, count, "summon_preparing", L("status.summonPreparing"), "✦", Theme.ui.money,
			nil, nil, fraction(enemy.summonTimer, enemy.summon.period))
	end

	return count
end

local function appendSnapshot(result, _, id, label, icon, color, stacks, value, remainingFraction)
	result[#result + 1] = {
		id = id,
		label = label,
		icon = icon,
		color = color,
		stacks = stacks,
		value = value,
		remainingFraction = remainingFraction,
	}
end

-- Returns an owned snapshot for non-render callers that need to retain results.
function DisplayStatuses.snapshot(enemy)
	local result = {}
	DisplayStatuses.visit(enemy, appendSnapshot, result)
	return result
end

return DisplayStatuses

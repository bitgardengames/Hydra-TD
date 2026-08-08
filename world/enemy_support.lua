local Spatial = require("world.spatial_grid")

local Support = {}

local max = math.max
local sources = {}

local function removeContribution(source, target)
	local contributions = target.supportContributions
	if contributions then
		contributions[source.id] = nil
	end
	if source.supportAffected then
		source.supportAffected[target] = nil
	end
end

local function recomputeBoost(target)
	local boost = 1
	local contributions = target.supportContributions
	if contributions then
		for sourceID, contribution in pairs(contributions) do
			local source = contribution.source
			if not source or source.id ~= sourceID or source.hp <= 0 or source._supportRemoved then
				contributions[sourceID] = nil
				if source and source.supportAffected then
					source.supportAffected[target] = nil
				end
			else
				boost = max(boost, contribution.multiplier)
			end
		end
	end
	target.supportBoost = boost
end

local function clearSource(source, removed)
	local affected = source.supportAffected
	if affected then
		for target in pairs(affected) do
			removeContribution(source, target)
			recomputeBoost(target)
		end
	end
	source._supportRemoved = removed == true
	source._supportAura = source.support
	source._supportRadius = source.support and source.support.radius or nil
	source._supportMultiplier = source.support and source.support.speedMultiplier or nil
end

function Support.remove(source)
	clearSource(source, true)
	local index = source.supportSourceIndex
	if not index then
		return
	end

	local last = sources[#sources]
	sources[index] = last
	sources[#sources] = nil
	if last and last ~= source then
		last.supportSourceIndex = index
	end
	source.supportSourceIndex = nil
end

function Support.detachDead(source)
	if source.supportSourceIndex and source.hp <= 0 then
		-- Damage may occur during the enemy update. Detach immediately so every
		-- target in that update observes the same boost state.
		Support.remove(source)
	end
end

local function refreshSource(source)
	local aura = source.support
	if not aura or source.hp <= 0 or source._supportRemoved then
		clearSource(source, source._supportRemoved or source.hp <= 0)
		return
	end

	local affected = source.supportAffected
	for target in pairs(affected) do
		affected[target] = false
	end

	local nearby, count = Spatial.queryCells(source.x, source.y, aura.radius)
	for i = 1, count do
		local target = nearby[i]
		if target ~= source and target.hp > 0 then
			affected[target] = true
			local contributions = target.supportContributions
			if not contributions then
				contributions = {}
				target.supportContributions = contributions
			end
			local contribution = contributions[source.id]
			if not contribution then
				contribution = {source = source}
				contributions[source.id] = contribution
			end
			contribution.multiplier = aura.speedMultiplier
			recomputeBoost(target)
		end
	end

	for target, present in pairs(affected) do
		if not present then
			removeContribution(source, target)
			recomputeBoost(target)
		end
	end

	source._supportAura = aura
	source._supportRadius = aura.radius
	source._supportMultiplier = aura.speedMultiplier
end

local function syncDefinition(source)
	local aura = source.def.support
	if aura ~= source.support then
		source.support = aura
	end
	if source.hp <= 0 then
		Support.detachDead(source)
	elseif aura ~= source._supportAura or (aura and (aura.radius ~= source._supportRadius
		or aura.speedMultiplier ~= source._supportMultiplier)) then
		refreshSource(source)
	end
end

local function touchesCell(source, cx, cy)
	local aura = source.support
	return aura ~= nil and cx ~= nil
		and Spatial.queryIncludesCell(source.x, source.y, aura.radius, cx, cy)
end

function Support.onEnemyCellChanged(enemy, oldCX, oldCY, newCX, newCY)
	if enemy.supportSourceIndex then
		syncDefinition(enemy)
	end
	if enemy.supportSourceIndex then
		refreshSource(enemy)
	end

	local i = 1
	while i <= #sources do
		local source = sources[i]
		syncDefinition(source)
		if source.supportSourceIndex and source ~= enemy
			and (touchesCell(source, oldCX, oldCY) or touchesCell(source, newCX, newCY)) then
			refreshSource(source)
		end
		if sources[i] == source then
			i = i + 1
		end
	end
end

function Support.onEnemyRemoved(enemy, oldCX, oldCY)
	if enemy.supportSourceIndex then
		Support.remove(enemy)
	end

	local i = 1
	while i <= #sources do
		local source = sources[i]
		syncDefinition(source)
		if source.supportSourceIndex and touchesCell(source, oldCX, oldCY) then
			refreshSource(source)
		end
		if sources[i] == source then
			i = i + 1
		end
	end

	local contributions = enemy.supportContributions
	if contributions then
		for _, contribution in pairs(contributions) do
			local source = contribution.source
			if source and source.supportAffected then
				source.supportAffected[enemy] = nil
			end
		end
		for sourceID in pairs(contributions) do
			contributions[sourceID] = nil
		end
	end
end

function Support.register(source)
	if not source.support or source.supportSourceIndex then
		return
	end
	source.supportAffected = source.supportAffected or {}
	source._supportRemoved = false
	sources[#sources + 1] = source
	source.supportSourceIndex = #sources
end

function Support.update(dt)
	local i = 1
	while i <= #sources do
		local source = sources[i]
		syncDefinition(source)
		local aura = source.support
		if aura and source.hp > 0 then
			source.supportPulse = ((source.supportPulse or 0) + dt) % aura.pulsePeriod
		end
		if sources[i] == source then
			i = i + 1
		end
	end
end

function Support.clear()
	for i = #sources, 1, -1 do
		local source = sources[i]
		clearSource(source, true)
		source.supportSourceIndex = nil
		sources[i] = nil
	end
end

return Support

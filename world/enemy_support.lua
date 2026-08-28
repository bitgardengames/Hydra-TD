local Spatial = require("world.spatial_grid")
local spatialQueryContext = Spatial.newQueryContext(false)

local Support = {}

local max = math.max
local sources = {}
local dirtySources = {}
local dirtySourceSet = {}
local changedTargets = {}
local changedTargetSet = {}
local coveredSources = {}
local lifecycleStats = {sourceCandidatesExamined = 0}
local markDirty

local function coveredCell(cx, cy)
	local column = coveredSources[cx]
	if not column then
		column = {}
		coveredSources[cx] = column
	end
	local cell = column[cy]
	if not cell then
		cell = {}
		column[cy] = cell
	end
	return cell
end

local function insertCoveredCell(cx, cy, source)
	local cell = coveredCell(cx, cy)
	local entry = {source = source, cell = cell, index = #cell + 1, cx = cx, cy = cy}
	cell[entry.index] = entry
	local entries = source._supportCoveredCells
	entries[#entries + 1] = entry
end

local function removeCoveredCells(source)
	local entries = source._supportCoveredCells
	if not entries then return end
	for i = #entries, 1, -1 do
		local entry = entries[i]
		local cell = entry.cell
		local last = cell[#cell]
		cell[entry.index] = last
		cell[#cell] = nil
		if last and last ~= entry then
			last.index = entry.index
		end
		if #cell == 0 then
			local column = coveredSources[entry.cx]
			column[entry.cy] = nil
			if next(column) == nil then coveredSources[entry.cx] = nil end
		end
		entries[i] = nil
	end
end

local function indexCoveredCells(source)
	removeCoveredCells(source)
	local aura = source.support
	if not aura or source.hp <= 0 or source._supportRemoved then return end
	source._supportCoveredCells = source._supportCoveredCells or {}
	Spatial.forEachQueryCell(source.x, source.y, aura.radius, insertCoveredCell, source)
end

local function markCellSources(cx, cy, excluded)
	if cx == nil then return end
	local column = coveredSources[cx]
	local cell = column and column[cy]
	if not cell then return end
	for i = 1, #cell do
		local source = cell[i].source
		lifecycleStats.sourceCandidatesExamined = lifecycleStats.sourceCandidatesExamined + 1
		if source ~= excluded then markDirty(source) end
	end
end

markDirty = function(source)
	if source and source.supportSourceIndex and not dirtySourceSet[source] then
		dirtySourceSet[source] = true
		dirtySources[#dirtySources + 1] = source
	end
end

local function markTargetChanged(target)
	if not changedTargetSet[target] then
		changedTargetSet[target] = true
		changedTargets[#changedTargets + 1] = target
	end
end

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
	removeCoveredCells(source)
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

	local nearby, count = Spatial.queryCells(source.x, source.y, aura.radius, spatialQueryContext)
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
				markTargetChanged(target)
			elseif contribution.multiplier ~= aura.speedMultiplier then
				markTargetChanged(target)
			end
			contribution.multiplier = aura.speedMultiplier
		end
	end

	for target, present in pairs(affected) do
		if not present then
			removeContribution(source, target)
			markTargetChanged(target)
		end
	end

	for i = 1, #changedTargets do
		local target = changedTargets[i]
		recomputeBoost(target)
		changedTargetSet[target] = nil
		changedTargets[i] = nil
	end

	source._supportAura = aura
	source._supportRadius = aura.radius
	source._supportMultiplier = aura.speedMultiplier
end

local function syncDefinition(source)
	local aura = source.def.support
	if aura ~= source.support then
		source.support = aura
		indexCoveredCells(source)
	end
	if source.hp <= 0 then
		Support.detachDead(source)
	end
end

function Support.markSourceDirty(source)
	markDirty(source)
end

function Support.onEnemyCellChanged(enemy, oldCX, oldCY, newCX, newCY)
	markCellSources(oldCX, oldCY, enemy)
	if newCX ~= oldCX or newCY ~= oldCY then
		markCellSources(newCX, newCY, enemy)
	end
	if enemy.supportSourceIndex then
		-- A source can move within an unchanged cell neighborhood while its aura
		-- membership changes, so its own movement always invalidates it.
		markDirty(enemy)
		indexCoveredCells(enemy)
	end
end

function Support.onEnemyRemoved(enemy, oldCX, oldCY)
	if enemy.supportSourceIndex then
		Support.remove(enemy)
	end
	markCellSources(oldCX, oldCY, enemy)

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
	indexCoveredCells(source)
	markDirty(source)
end

function Support.update(dt)
	local i = 1
	while i <= #sources do
		local source = sources[i]
		local aura = source.def.support
		local supportChanged = aura ~= source.support
		local definitionChanged = supportChanged or aura ~= source._supportAura
		if supportChanged then
			source.support = aura
			indexCoveredCells(source)
		end
		if source.hp <= 0 then
			Support.detachDead(source)
		end
		if source.supportSourceIndex and source.hp > 0
		and (definitionChanged or (aura and (aura.radius ~= source._supportRadius
			or aura.speedMultiplier ~= source._supportMultiplier))) then
			if not supportChanged then
				indexCoveredCells(source)
			end
			markDirty(source)
		end
		if aura and source.hp > 0 then
			source.supportPulse = ((source.supportPulse or 0) + dt) % aura.pulsePeriod
		end
		if sources[i] == source then
			i = i + 1
		end
	end
end

function Support.resetLifecycleStats()
	lifecycleStats.sourceCandidatesExamined = 0
end

function Support.getLifecycleStats()
	return lifecycleStats.sourceCandidatesExamined
end

-- Called after all enemy Spatial.updateEnemy calls for the tick. Lifecycle
-- hooks only enqueue work, allowing any number of crossings to collapse into a
-- single definition sync and membership refresh per source.
function Support.flushDirtySources()
	for i = 1, #dirtySources do
		local source = dirtySources[i]
		dirtySourceSet[source] = nil
		dirtySources[i] = nil
		if source.supportSourceIndex then
			syncDefinition(source)
			if source.supportSourceIndex then
				refreshSource(source)
			end
		end
	end
end

function Support.clear()
	for i = #sources, 1, -1 do
		local source = sources[i]
		clearSource(source, true)
		removeCoveredCells(source)
		source.supportSourceIndex = nil
		sources[i] = nil
	end
	for i = #dirtySources, 1, -1 do
		dirtySourceSet[dirtySources[i]] = nil
		dirtySources[i] = nil
	end
end

return Support

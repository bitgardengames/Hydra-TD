local Spatial = require("world.spatial_grid")

local Support = {}

local max = math.max
local sources = {}
local dirtySources = {}
local dirtySourceSet = {}
-- Sparse reverse index: coveredCells[cx][cy][source] = true.
local coveredCells = {}

local function markDirty(source)
	if source and source.supportSourceIndex and not dirtySourceSet[source] then
		dirtySourceSet[source] = true
		dirtySources[#dirtySources + 1] = source
	end
end

local function removeContribution(source, target)
	if target.supportContributions then
		target.supportContributions[source.id] = nil
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

local function setMembership(source, target, inside)
	local wasInside = source.supportAffected[target] ~= nil
	local aura = source.support
	if inside and target ~= source and target.hp > 0 and aura then
		source.supportAffected[target] = true
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
		local changed = not wasInside or contribution.multiplier ~= aura.speedMultiplier
		contribution.multiplier = aura.speedMultiplier
		if changed then recomputeBoost(target) end
	elseif wasInside then
		removeContribution(source, target)
		recomputeBoost(target)
	end
end

local function evaluateTarget(source, target)
	local aura = source.support
	local dx, dy = target.x - source.x, target.y - source.y
	setMembership(source, target, aura and dx * dx + dy * dy <= aura.radius * aura.radius)
end

local function unindexSource(source)
	local minX, minY, maxX, maxY = source._supportMinX, source._supportMinY,
		source._supportMaxX, source._supportMaxY
	if minX then
		for cx = minX, maxX do
			local column = coveredCells[cx]
			if column then
				for cy = minY, maxY do
					local cell = column[cy]
					if cell then
						cell[source] = nil
						if not next(cell) then column[cy] = nil end
					end
				end
				if not next(column) then coveredCells[cx] = nil end
			end
		end
	end
	source._supportMinX, source._supportMinY = nil, nil
	source._supportMaxX, source._supportMaxY = nil, nil
end

local function indexSource(source, minX, minY, maxX, maxY)
	unindexSource(source)
	for cx = minX, maxX do
		local column = coveredCells[cx]
		if not column then column = {}; coveredCells[cx] = column end
		for cy = minY, maxY do
			local cell = column[cy]
			if not cell then cell = {}; column[cy] = cell end
			cell[source] = true
		end
	end
	source._supportMinX, source._supportMinY = minX, minY
	source._supportMaxX, source._supportMaxY = maxX, maxY
end

local function clearSource(source, removed)
	unindexSource(source)
	for target in pairs(source.supportAffected or {}) do
		removeContribution(source, target)
		recomputeBoost(target)
	end
	source._supportRemoved = removed == true
	source._supportAura = source.support
	source._supportRadius = source.support and source.support.radius or nil
	source._supportMultiplier = source.support and source.support.speedMultiplier or nil
end

function Support.remove(source)
	clearSource(source, true)
	local index = source.supportSourceIndex
	if not index then return end
	local last = sources[#sources]
	sources[index], sources[#sources] = last, nil
	if last and last ~= source then last.supportSourceIndex = index end
	source.supportSourceIndex = nil
end

function Support.detachDead(source)
	if source.supportSourceIndex and source.hp <= 0 then Support.remove(source) end
end

local function refreshSource(source, minX, minY, maxX, maxY)
	local aura = source.support
	if not aura or source.hp <= 0 or source._supportRemoved then
		clearSource(source, source._supportRemoved or source.hp <= 0)
		return
	end
	for target in pairs(source.supportAffected) do source.supportAffected[target] = false end
	local nearby, count = Spatial.queryCells(source.x, source.y, aura.radius)
	for i = 1, count do evaluateTarget(source, nearby[i]) end
	for target, present in pairs(source.supportAffected) do
		if present == false then setMembership(source, target, false) end
	end
	indexSource(source, minX, minY, maxX, maxY)
end

-- When a source stays in the same cell footprint, only points in the swept
-- circular boundary can change membership. Exact final-distance checks retain
-- deterministic boundary behavior without rebuilding the affected set.
local function refreshMovingBoundary(source, oldX, oldY)
	local aura = source.support
	local mx, my = source.x - oldX, source.y - oldY
	local movement = math.sqrt(mx * mx + my * my)
	if movement == 0 then return end
	local inner = max(0, aura.radius - movement)
	local outer = aura.radius + movement
	local inner2, outer2 = inner * inner, outer * outer
	local nearby, count = Spatial.queryCells(source.x, source.y, aura.radius)
	for i = 1, count do
		local target = nearby[i]
		local dx, dy = target.x - oldX, target.y - oldY
		local oldDistance2 = dx * dx + dy * dy
		if oldDistance2 >= inner2 and oldDistance2 <= outer2 then evaluateTarget(source, target) end
	end
end

local function sourcesInCell(cx, cy)
	local column = cx ~= nil and coveredCells[cx]
	return column and column[cy]
end

local function visitCellSources(cx, cy, seen, fn)
	for source in pairs(sourcesInCell(cx, cy) or {}) do
		if not seen[source] then seen[source] = true; fn(source) end
	end
end

function Support.markSourceDirty(source)
	if source and source.supportSourceIndex and not dirtySourceSet[source] then
		source._supportDirtyX, source._supportDirtyY = source.x, source.y
		markDirty(source)
	end
end

function Support.onEnemyMoved(enemy, oldX, oldY)
	if enemy.supportSourceIndex then
		Support.markSourceDirty(enemy)
		-- markSourceDirty may already have been called by the preceding cell hook;
		-- retain the actual pre-movement center for the swept-boundary check.
		enemy._supportDirtyX, enemy._supportDirtyY = oldX, oldY
	end
	local seen = {}
	visitCellSources(enemy.cellX, enemy.cellY, seen, function(source)
		if source ~= enemy then evaluateTarget(source, enemy) end
	end)
end

function Support.onEnemyCellChanged(enemy, oldCX, oldCY, newCX, newCY)
	if enemy.supportSourceIndex then Support.markSourceDirty(enemy) end
	local seen = {}
	local function update(source)
		if source ~= enemy then evaluateTarget(source, enemy) end
	end
	visitCellSources(oldCX, oldCY, seen, update)
	visitCellSources(newCX, newCY, seen, update)
end

function Support.onEnemyRemoved(enemy, oldCX, oldCY)
	if enemy.supportSourceIndex then Support.remove(enemy) end
	local seen = {}
	visitCellSources(oldCX, oldCY, seen, function(source) setMembership(source, enemy, false) end)
	for _, contribution in pairs(enemy.supportContributions or {}) do
		local source = contribution.source
		if source and source.supportAffected then source.supportAffected[enemy] = nil end
	end
	enemy.supportContributions = nil
end

function Support.register(source)
	if not source.support or source.supportSourceIndex then return end
	source.supportAffected = source.supportAffected or {}
	source._supportRemoved = false
	sources[#sources + 1] = source
	source.supportSourceIndex = #sources
	markDirty(source)
end

function Support.update(dt)
	local i = 1
	while i <= #sources do
		local source = sources[i]
		local aura = source.def.support
		local changed = aura ~= source.support or aura ~= source._supportAura
		source.support = aura
		if source.hp <= 0 then Support.detachDead(source) end
		if source.supportSourceIndex and (changed or not aura
			or aura.radius ~= source._supportRadius
			or aura.speedMultiplier ~= source._supportMultiplier) then markDirty(source) end
		if aura and source.hp > 0 then
			source.supportPulse = ((source.supportPulse or 0) + dt) % aura.pulsePeriod
		end
		if sources[i] == source then i = i + 1 end
	end
end

function Support.flushDirtySources()
	for i = 1, #dirtySources do
		local source = dirtySources[i]
		dirtySourceSet[source], dirtySources[i] = nil, nil
		if source.supportSourceIndex then
			local aura = source.def.support
			local definitionChanged = aura ~= source.support or aura ~= source._supportAura
				or not aura or aura.radius ~= source._supportRadius
				or aura.speedMultiplier ~= source._supportMultiplier
			source.support = aura
			if source.hp <= 0 then
				Support.detachDead(source)
			elseif aura then
				local minX, minY, maxX, maxY = Spatial.queryCellBounds(source.x, source.y, aura.radius)
				local boundsChanged = minX ~= source._supportMinX or minY ~= source._supportMinY
					or maxX ~= source._supportMaxX or maxY ~= source._supportMaxY
				if definitionChanged or boundsChanged then
					refreshSource(source, minX, minY, maxX, maxY)
				else
					refreshMovingBoundary(source, source._supportDirtyX or source.x,
						source._supportDirtyY or source.y)
				end
				source._supportAura, source._supportRadius = aura, aura.radius
				source._supportMultiplier = aura.speedMultiplier
			else
				clearSource(source, false)
			end
			source._supportDirtyX, source._supportDirtyY = nil, nil
		end
	end
end

function Support.clear()
	for i = #sources, 1, -1 do
		local source = sources[i]
		clearSource(source, true)
		source.supportSourceIndex, sources[i] = nil, nil
	end
	for i = #dirtySources, 1, -1 do
		dirtySourceSet[dirtySources[i]], dirtySources[i] = nil, nil
	end
	for cx in pairs(coveredCells) do coveredCells[cx] = nil end
end

return Support

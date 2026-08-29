local Spatial = require("world.spatial_grid")
local DevelopmentCounters = require("core.development_counters")

local Spawner = {}
local max, min = math.max, math.min
local ACTIVE_CAP, CATCHUP_LIMIT, BACKPRESSURE_DELAY = 140, 12, .10

local spawnerDefaults = {active=false, remaining=0, gap=.6, timer=0, hpMult=1, spdMult=1, groups=nil,
	groupIndex=1, groupRemaining=0, totalScheduled=0, spawned=0, livingScheduledEnemies=0,
	clearedScheduledEnemies=0, waitingGroupDelay=false}
local bossDefaults = {active=false, kind=nil, burst=0, timer=0, interval=0, maxAlive=0, maxTotal=0,
	totalSpawned=0, queued=0, queueTimer=0, queueGap=.18, hpMult=1, spdMult=1}
local state, bossAdds = {}, {}
local spatialQueryContext = Spatial.newQueryContext(true)
local nearbyBossAddsContext = {count=0, cap=0, kind=nil}

local function reset(target, defaults, overrides)
	for key in pairs(target) do target[key] = nil end
	for key, value in pairs(defaults) do target[key] = value end
	for key, value in pairs(overrides or {}) do if value ~= nil then target[key] = value end end
end
reset(state, spawnerDefaults)
reset(bossAdds, bossDefaults)

function Spawner.begin(count, hpMult, spdMult, groups)
	local first = groups and groups[1]
	reset(state, spawnerDefaults, {active=true, remaining=count or 0, timer=first and first.delay or 0,
		hpMult=hpMult or 1, spdMult=spdMult or 1, groups=groups, groupIndex=1,
		groupRemaining=first and first.count or 0, totalScheduled=count or 0,
		waitingGroupDelay=first ~= nil and (first.delay or 0) > 0})
end

function Spawner.configureBossAdds(config)
	reset(bossAdds, bossDefaults, config)
end

function Spawner.reset()
	reset(state, spawnerDefaults)
	reset(bossAdds, bossDefaults)
end

local function finalize(pending, timer, activeCap, loops, enemyCount)
	if loops == CATCHUP_LIMIT and timer <= 0 then
		DevelopmentCounters.add("spawnBackpressureEvents")
		timer = 0
	elseif pending > 0 and enemyCount >= activeCap then
		DevelopmentCounters.add("spawnBackpressureEvents")
		timer = max(timer, BACKPRESSURE_DELAY)
	end
	return timer
end

local function advance(group)
	state.remaining, state.spawned = state.remaining - 1, state.spawned + 1
	state.groupRemaining = state.groupRemaining - 1
	if state.groupRemaining > 0 or state.remaining <= 0 then
		state.timer = state.timer + (group.spacing or state.gap)
		return
	end
	state.groupIndex = state.groupIndex + 1
	local nextGroup = state.groups[state.groupIndex]
	if nextGroup then
		state.groupRemaining = nextGroup.count
		state.timer = state.timer + (nextGroup.delay or 0)
		state.waitingGroupDelay = (nextGroup.delay or 0) > 0
	else
		state.remaining, state.active = 0, false
	end
end

local function updateWave(dt, context, cap, loops)
	if not state.active then return loops, false end
	state.timer = state.timer - dt
	while state.timer <= 0 and state.active and state.remaining > 0 and loops < CATCHUP_LIMIT and context.enemyCount() < cap do
		state.waitingGroupDelay = false
		local group = state.groups and state.groups[state.groupIndex]
		if not (group and group.kind) then state.remaining, state.active = 0, false; return loops, true end
		local enemy = context.spawnEnemy(group.kind, group.hpMult or state.hpMult, group.spdMult or state.spdMult)
		if group.rewardMult then enemy.reward = min(1e6, enemy.reward * group.rewardMult) end
		if group.eliteTrait then enemy.eliteTrait = group.eliteTrait end
		enemy.scheduledWaveEnemy = true
		state.livingScheduledEnemies = state.livingScheduledEnemies + 1
		if enemy.boss and context.onBossSpawn then context.onBossSpawn(enemy) end
		advance(group)
		loops = loops + 1
	end
	state.active = state.remaining > 0
	state.timer = finalize(state.active and state.remaining or 0, state.timer, cap, loops, context.enemyCount())
	return loops, false
end

local function countVisitor(enemy, context)
	if not enemy.boss and enemy.kind == context.kind then
		context.count = context.count + 1
		if context.count >= context.cap then return false end
	end
end

local function nearbyAdds(boss)
	nearbyBossAddsContext.count, nearbyBossAddsContext.cap, nearbyBossAddsContext.kind = 0, bossAdds.maxAlive, bossAdds.kind
	Spatial.visitRadius(boss.x, boss.y, 320, countVisitor, nearbyBossAddsContext, spatialQueryContext, Spatial.radiusOptions.living)
	return nearbyBossAddsContext.count
end

local function updateBoss(dt, context, cap, loops)
	if not bossAdds.active then return end
	local boss = context.activeBoss()
	if not (boss and boss.hp and boss.hp > 0 and not boss.dying) then
		bossAdds.active, bossAdds.queued = false, 0
		return
	end
	if context.onBossPosition then context.onBossPosition(boss) end
	bossAdds.timer, bossAdds.queueTimer = bossAdds.timer - dt, bossAdds.queueTimer - dt
	if bossAdds.timer <= 0 and bossAdds.totalSpawned < bossAdds.maxTotal then
		local count = context.enemyCount()
		local available = min(bossAdds.maxAlive - nearbyAdds(boss) - bossAdds.queued, cap - count - bossAdds.queued)
		local remaining = bossAdds.maxTotal - bossAdds.totalSpawned - bossAdds.queued
		bossAdds.queued = bossAdds.queued + max(0, min(bossAdds.burst, available, remaining))
		bossAdds.timer = bossAdds.interval
	end
	while bossAdds.queueTimer <= 0 and bossAdds.queued > 0 and loops < CATCHUP_LIMIT and context.enemyCount() < cap do
		context.spawnEnemy(bossAdds.kind, bossAdds.hpMult, bossAdds.spdMult)
		bossAdds.queued, bossAdds.totalSpawned = bossAdds.queued - 1, bossAdds.totalSpawned + 1
		bossAdds.queueTimer, loops = bossAdds.queueTimer + bossAdds.queueGap, loops + 1
	end
	bossAdds.queueTimer = finalize(bossAdds.queued, bossAdds.queueTimer, cap, loops, context.enemyCount())
end

function Spawner.update(dt, context)
	local cap = context.activeCap or ACTIVE_CAP
	local loops, invalid = updateWave(dt, context, cap, 0)
	if not invalid then updateBoss(dt, context, cap, loops) end
end

function Spawner.allEnemiesCleared(enemyCount) return enemyCount == 0 and not state.active and bossAdds.queued == 0 end
function Spawner.getState() return state end
function Spawner.getActiveEnemyCap() return ACTIVE_CAP end
function Spawner.onScheduledEnemyRemoved(enemy)
	if not enemy or not enemy.scheduledWaveEnemy then return end
	enemy.scheduledWaveEnemy = false
	state.livingScheduledEnemies = max(0, state.livingScheduledEnemies - 1)
	state.clearedScheduledEnemies = state.clearedScheduledEnemies + 1
end

local snapshot = {_currentAuthoredGroup={}}
function Spawner.getProgress(enemyCount, out)
	out = out or snapshot
	local group = state.groups and state.groups[state.groupIndex]
	local current = out._currentAuthoredGroup or {}; out._currentAuthoredGroup = current
	if group then
		current.index, current.total, current.kind, current.remaining = state.groupIndex, #state.groups, group.kind, state.groupRemaining
		out.currentAuthoredGroup = current
	else out.currentAuthoredGroup = nil end
	out.totalScheduled, out.spawnedCount = state.totalScheduled, state.spawned
	out.livingCount, out.clearedCount = state.livingScheduledEnemies, state.clearedScheduledEnemies
	out.remainingQueuedCount = state.remaining
	out.waitingOnGroupDelay = state.active and state.waitingGroupDelay and state.timer > 0
	out.waitingOnPopulationBackpressure = state.active and state.remaining > 0 and enemyCount >= ACTIVE_CAP
	return out
end

return Spawner

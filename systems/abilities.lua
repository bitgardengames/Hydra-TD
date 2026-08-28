local AbilityDefs = require("systems.ability_defs")
local CampaignUnlocks = require("systems.campaign_unlocks")
local Enemies = require("world.enemies")
local Towers = require("world.towers")
local Effects = require("world.effects")
local Spatial = require("world.spatial_grid")
local spatialQueryContext = Spatial.newQueryContext(true)
local State = require("core.state")
local Constants = require("core.constants")

local Abilities = {}
-- Active effects are an unordered simulation set. Consumers aggregate by
-- ability or render each effect independently, so removal may change indices.
local active = {}
local clock = 0
local previewAffected = {}
local previewAffectedCount = 0
local preview = {affected = previewAffected}

local function clearBuffer(buffer, count)
	for i = 1, count do
		buffer[i] = nil
	end
end

local function newRadiusVisitContext()
	return {spatial = Spatial.newQueryContext(false)}
end

local slowVisitContext = newRadiusVisitContext()
local gravityPullVisitContext = newRadiusVisitContext()
local gravityDamageVisitContext = newRadiusVisitContext()
local meteorDamageVisitContext = newRadiusVisitContext()
local abilityDamageSource = {sourceKind = "ability"}

local function visitEnemyInRadius(enemy, context)
	local enemyX = context.useRenderedPosition and (enemy.rx or enemy.x) or enemy.x
	local enemyY = context.useRenderedPosition and (enemy.ry or enemy.y) or enemy.y
	local dx, dy = enemyX - context.x, enemyY - context.y
	if enemy.hp > 0 and dx * dx + dy * dy <= context.radiusSquared then
		context.visitor(enemy, context)
	end
end

local function forEachEnemyInRadius(x, y, radius, visitor, context, useRenderedPosition)
	context.x = x
	context.y = y
	context.radiusSquared = radius * radius
	context.visitor = visitor
	context.useRenderedPosition = useRenderedPosition or false
	Spatial.visitCells(x, y, radius, visitEnemyInRadius, context, context.spatial)
end

local function slowEnemy(enemy, context)
	Enemies.applySlow(enemy, context.factor, context.duration)
end

local function pullEnemy(enemy, context)
	local resistsPull = enemy.def and (enemy.def.boss or enemy.def.heavy)
	local resistance = resistsPull and 0.2 or 1
	Enemies.setPathDistance(enemy, enemy.dist - context.pullDistance * resistance)
end

local function damageEnemy(enemy, context)
	Enemies.applyDamage(enemy, context.damage, abilityDamageSource)
end

local function addActive(effect)
	active[#active + 1] = effect
end

local function addTimedEffect(effect, fields)
	fields.kind = effect.kind
	fields.expires = clock + effect.duration
	addActive(fields)
end

local function forEachTowerInRadius(x, y, radius, callback)
	local radiusSquared = radius * radius
	for _, tower in ipairs(Towers.towers) do
		local dx, dy = tower.x - x, tower.y - y
		if dx * dx + dy * dy <= radiusSquared then
			callback(tower)
		end
	end
end

function Abilities.getEquipped(abilityId)
	local id = abilityId or (State.equippedAbilities and State.equippedAbilities[1])
	if not id or not CampaignUnlocks.isAbilityUnlocked(id) then
		return nil
	end

	for slotIndex, equippedId in ipairs(State.equippedAbilities or {}) do
		if equippedId == id and CampaignUnlocks.isAbilitySlotUnlocked(slotIndex) then
			return AbilityDefs[id]
		end
	end
end

local function getEffect(def)
	return def.effect
end

function Abilities.getEffect(def)
	return getEffect(def)
end

function Abilities.isReady(id)
	local def = Abilities.getEquipped(id)
	return def and (State.abilityCharges[def.id] or 0) >= def.chargeRequired or false
end

-- Awarded only by the canonical enemy-death path. Summoned enemies and
-- ability-caused kills are excluded to prevent farming and self-recharging
-- area abilities; a boss is explicitly worth several normal enemies.
function Abilities.chargeFromKill(enemy, sourceKind)
	if not enemy or enemy.summoned or sourceKind == "ability" then return 0 end
	local amount = (enemy.boss or (enemy.def and enemy.def.boss)) and AbilityDefs.bossCharge or 1
	for _, id in ipairs(State.equippedAbilities or {}) do
		local def = AbilityDefs[id]
		if def then
			State.abilityCharges[id] = math.min(def.chargeRequired,
				(State.abilityCharges[id] or 0) + amount)
		end
	end
	return amount
end

function Abilities.beginTargeting(id)
	local def = Abilities.getEquipped(id)
	if not def or not Abilities.isReady(def.id) or State.mode ~= "game" or State.modulePicker.active then
		return false
	end

	State.abilityTargeting = { abilityId = def.id, x = nil, y = nil, firstTower = nil }
	State.placing = nil
	State.selectedTower = nil
	State.selectedEnemy = nil
	if def.targeting == "instant" then
		return Abilities.activate()
	end
	return true
end

function Abilities.cancelTargeting()
	State.abilityTargeting = nil
end

local function buffTower(tower, effect)
	-- Expiries and multipliers never rewrite the authored tower statistics.
	Towers.addAbilityBuff(tower, {
		kind = effect.kind,
		expires = clock + effect.duration,
		attackSpeed = effect.attackSpeed or 1,
		range = effect.range or 1,
	})
end

local function activateIncomeMultiplier(effect, _x, _y, abilityId)
	addTimedEffect(effect, {
		abilityId = abilityId,
		multiplier = effect.multiplier,
		bossMultiplier = effect.bossMultiplier,
	})
end

local function activateTowerArea(effect, x, y, abilityId)
	local affected = {}
	forEachTowerInRadius(x, y, effect.radius, function(tower)
		buffTower(tower, effect)
		affected[#affected + 1] = tower
	end)

	addTimedEffect(effect, {
		abilityId = abilityId,
		x = x,
		y = y,
		radius = effect.radius,
		towers = affected,
		volleys = effect.volleys,
		lastVolley = -math.huge,
		inside = {},
	})
end

local function activateGravityWell(effect, x, y, abilityId)
	addTimedEffect(effect, {
		abilityId = abilityId,
		x = x,
		y = y,
		radius = effect.radius,
		damage = effect.damage,
		pullSpeed = effect.pullSpeed,
	})
end

local function activateDamageArea(effect, x, y, abilityId)
	local travelTime = effect.travelTime or 0
	addActive({
		kind = "meteor_incoming",
		abilityId = abilityId,
		x = x,
		y = y,
		radius = effect.radius,
		damage = effect.damage,
		approachDirection = love.math.random(0, 1) == 0 and -1 or 1,
		started = clock,
		expires = clock + travelTime,
	})
end

local function activateSlowArea(effect, x, y)
	slowVisitContext.factor = effect.factor
	slowVisitContext.duration = effect.duration
	forEachEnemyInRadius(x, y, effect.radius, slowEnemy, slowVisitContext, true)
end

local effectActivators = {
	damage_area = activateDamageArea,
	slow_area = activateSlowArea,
	income_multiplier = activateIncomeMultiplier,
	tower_haste_area = activateTowerArea,
	last_stand = activateTowerArea,
	gravity_well = activateGravityWell,
}

local function playFrostEffect(_, x, y)
	Effects.spawnFrostBurst(x, y)
	Effects.shake(1)
end

local activationEffects = {
	slow_area = playFrostEffect,
}

local function playActivationEffect(effect, x, y)
	local play = activationEffects[effect.kind]
	if play then
		play(effect, x, y)
	else
		Effects.shake(1)
	end
end

-- Cinematic scenes can launch the authored meteor without depending on the
-- player's equipped abilities, unlocks, targeting state, or charge.
function Abilities.launchMeteor(x, y)
	local def = AbilityDefs.meteor
	local effect = def and getEffect(def)
	if not effect or not x or not y then
		return false
	end

	activateDamageArea(effect, x, y, def.id)
	playActivationEffect(effect, x, y)
	return true
end

local function collectAffected(entityKind, effect, x, y, affected, occupied)
	clearBuffer(affected, occupied)
	if not entityKind or not effect.radius or not x or not y then return 0 end
	local count = 0
	if entityKind == "enemies" then
		local radiusSquared = effect.radius * effect.radius
		local candidates, candidateCount = Spatial.queryCells(x, y, effect.radius, spatialQueryContext)
		for i = 1, candidateCount do
			local enemy = candidates[i]
			local dx = (enemy.rx or enemy.x) - x
			local dy = (enemy.ry or enemy.y) - y
			if enemy.hp > 0 and dx * dx + dy * dy <= radiusSquared then
				count = count + 1
				affected[count] = enemy
			end
		end
	elseif entityKind == "towers" then
		local radiusSquared = effect.radius * effect.radius
		for _, tower in ipairs(Towers.towers) do
			local dx, dy = tower.x - x, tower.y - y
			if dx * dx + dy * dy <= radiusSquared then
				count = count + 1
				affected[count] = tower
			end
		end
	end
	return count
end

function Abilities.getTargetPreview(x, y)
	local target = State.abilityTargeting
	local def = target and Abilities.getEquipped(target.abilityId)
	if not def then return nil end
	local effect = getEffect(def)
	previewAffectedCount = collectAffected(def.target and def.target.entities, effect,
		x, y, previewAffected, previewAffectedCount)
	local valid, reason = true, nil
	if def.targeting ~= "instant" and (not x or not y or x < 0 or y < 0
		or x > Constants.GRID_W * Constants.TILE or y > Constants.GRID_H * Constants.TILE) then
		valid, reason = false, "outside"
	elseif def.target and def.target.requireAffected and previewAffectedCount == 0 then
		valid = false
		reason = def.target.entities == "towers" and "no_towers" or "no_enemies"
	end
	preview.def, preview.effect = def, effect
	preview.count, preview.valid, preview.reason = previewAffectedCount, valid, reason
	return preview
end

function Abilities.activate(x, y)
	local target = State.abilityTargeting
	local def = target and Abilities.getEquipped(target.abilityId)
	if not def or not Abilities.isReady(def.id) then
		return false
	end

	local effect = getEffect(def)
	if def.targeting ~= "instant" then
		local preview = Abilities.getTargetPreview(x, y)
		if not preview or not preview.valid then
			return false, preview and preview.reason or "invalid"
		end
	end
	local activateEffect = effectActivators[effect.kind]
	if not activateEffect then
		return false
	end

	-- Every activator follows the same contract, regardless of whether it
	-- creates a timed effect or resolves immediately.
	activateEffect(effect, x, y, def.id)
	playActivationEffect(effect, x, y)
	require("systems.run_stats").recordAbilityUse()
	State.abilityCharges[def.id] = 0
	State.abilityTargeting = nil
	return true
end

local function triggerVolley(effect, enemy)
	for _, tower in ipairs(effect.towers) do
		local dx, dy = enemy.x - tower.x, enemy.y - tower.y
		local range = tower.range * (tower.abilityRangeMultiplier or 1)
		if enemy.hp > 0 and dx * dx + dy * dy <= range * range then
			tower.cooldown = 0
			tower.windUp = 0
			tower.target = enemy
		end
	end
	effect.volleys = effect.volleys - 1
	effect.lastVolley = clock
end

local function updateGravityWell(effect, dt)
	gravityPullVisitContext.pullDistance = effect.pullSpeed * dt
	forEachEnemyInRadius(effect.x, effect.y, effect.radius, pullEnemy, gravityPullVisitContext)
end

local function updateLastStand(effect)
	if effect.volleys <= 0 then
		return
	end

	local radiusSquared = effect.radius * effect.radius
	local candidates, candidateCount = Spatial.queryCells(effect.x, effect.y, effect.radius, spatialQueryContext)
	for enemy, wasInside in pairs(effect.inside) do
		if wasInside then
			local dx, dy = enemy.x - effect.x, enemy.y - effect.y
			if dx * dx + dy * dy > radiusSquared then
				if clock - effect.lastVolley >= 1.5 then
					triggerVolley(effect, enemy)
				end
				effect.inside[enemy] = false
			end
		end
	end
	for i = 1, candidateCount do
		local enemy = candidates[i]
		local dx, dy = enemy.x - effect.x, enemy.y - effect.y
		local inside = dx * dx + dy * dy <= radiusSquared
		if effect.inside[enemy] and not inside and clock - effect.lastVolley >= 1.5 then
			triggerVolley(effect, enemy)
		end
		effect.inside[enemy] = inside
	end
end

local function expireGravityWell(effect)
	gravityDamageVisitContext.damage = effect.damage
	forEachEnemyInRadius(effect.x, effect.y, effect.radius, damageEnemy, gravityDamageVisitContext)
	Effects.spawnCannonImpact(effect.x, effect.y, effect.radius)
end

local function expireMeteor(effect)
	meteorDamageVisitContext.damage = effect.damage
	forEachEnemyInRadius(effect.x, effect.y, effect.radius, damageEnemy, meteorDamageVisitContext, true)
	Effects.spawnCannonImpact(effect.x, effect.y, effect.radius * 1.2)
	Effects.spawnMeteorDust(effect.x, effect.y, effect.radius)
	Effects.shake(10, .4)
end

-- Timed-effect behavior lives in one registry so adding a lifecycle does not
-- require keeping separate kind-to-callback tables in sync.
local timedEffectHandlers = {
	meteor_incoming = { expire = expireMeteor },
	gravity_well = { update = updateGravityWell, expire = expireGravityWell },
	last_stand = { update = updateLastStand },
}

function Abilities.update(dt)
	clock = clock + dt
	State.abilityClock = clock
	for i = #active, 1, -1 do
		local effect = active[i]
		local handlers = timedEffectHandlers[effect.kind]
		if handlers and handlers.update then
			handlers.update(effect, dt)
		end

		if clock >= effect.expires then
			if handlers and handlers.expire then
				handlers.expire(effect)
			end
			local finalIndex = #active
			if i ~= finalIndex then
				active[i] = active[finalIndex]
			end
			active[finalIndex] = nil
		end
	end
end

function Abilities.getEntitiesInActiveArea(effect, entityKind)
	if not effect then return nil, 0 end
	effect._affectedCaches = effect._affectedCaches or {}
	local cache = effect._affectedCaches[entityKind]
	if not cache then
		cache = {entities = {}, count = 0}
		effect._affectedCaches[entityKind] = cache
	end
	if not effect.x or not effect.radius then
		clearBuffer(cache.entities, cache.count)
		cache.count = 0
		return cache.entities, 0
	end

	-- `clock` advances once per simulation tick. Each active effect owns its
	-- buffer, so rendering another simultaneous effect cannot invalidate it.
	if cache.tick ~= clock or cache.x ~= effect.x or cache.y ~= effect.y or cache.radius ~= effect.radius then
		cache.count = collectAffected(entityKind, effect, effect.x, effect.y, cache.entities, cache.count)
		cache.tick, cache.x, cache.y, cache.radius = clock, effect.x, effect.y, effect.radius
	end
	return cache.entities, cache.count
end

function Abilities.getActive()
	return active, clock
end

function Abilities.getKillIncomeMultiplier(enemy)
	local isBoss = enemy and (enemy.boss or (enemy.def and enemy.def.boss))
	if isBoss then
		return 1
	end

	local multiplier = 1
	for _, effect in ipairs(active) do
		if effect.kind == "income_multiplier" and clock < effect.expires then
			multiplier = math.max(multiplier, effect.multiplier or 1)
		end
	end
	return multiplier
end

function Abilities.reset()
	active = {}
	clock = 0
	clearBuffer(previewAffected, previewAffectedCount)
	previewAffectedCount = 0
	State.abilityClock = 0
	State.abilityCharges = State.abilityCharges or {}
	for _, id in ipairs(State.equippedAbilities or {}) do
		local def = AbilityDefs[id]
		if def then State.abilityCharges[id] = 0 end
	end
end

return Abilities

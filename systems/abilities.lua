local AbilityDefs = require("systems.ability_defs")
local CampaignUnlocks = require("systems.campaign_unlocks")
local Enemies = require("world.enemies")
local Towers = require("world.towers")
local Effects = require("world.effects")
local State = require("core.state")

local Abilities = {}
local active = {}
local clock = 0

local function forEachEnemyInRadius(x, y, radius, callback, useRenderedPosition)
	local radiusSquared = radius * radius
	for _, enemy in ipairs(Enemies.enemies) do
		local enemyX = useRenderedPosition and (enemy.rx or enemy.x) or enemy.x
		local enemyY = useRenderedPosition and (enemy.ry or enemy.y) or enemy.y
		local dx, dy = enemyX - x, enemyY - y
		if enemy.hp > 0 and dx * dx + dy * dy <= radiusSquared then
			callback(enemy)
		end
	end
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
	local upgraded = def.upgradeId and CampaignUnlocks.isAbilityUpgradeUnlocked(def.upgradeId)
	return upgraded and (def.upgradedEffect or def.effect) or def.effect
end

function Abilities.getEffect(def)
	return getEffect(def)
end

function Abilities.isReady(id)
	local def = Abilities.getEquipped(id)
	return def and (State.abilityCooldowns[def.id] or 0) <= 0 or false
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
	tower.abilityBuffs = tower.abilityBuffs or {}
	tower.abilityBuffs[#tower.abilityBuffs + 1] = {
		kind = effect.kind,
		expires = clock + effect.duration,
		attackSpeed = effect.attackSpeed or 1,
		range = effect.range or 1,
	}
end

local function activateIncomeMultiplier(effect, _x, _y, abilityId)
	addTimedEffect(effect, {
		abilityId = abilityId,
		multiplier = effect.multiplier,
		bossMultiplier = effect.bossMultiplier,
	})
end

local function activateTowerArea(x, y, effect)
	local affected = {}
	forEachTowerInRadius(x, y, effect.radius, function(tower)
		buffTower(tower, effect)
		affected[#affected + 1] = tower
	end)

	addTimedEffect(effect, {
		x = x,
		y = y,
		radius = effect.radius,
		towers = affected,
		volleys = effect.volleys,
		lastVolley = -math.huge,
		inside = {},
	})
end

local function activateGravityWell(x, y, effect)
	addTimedEffect(effect, {
		x = x,
		y = y,
		radius = effect.radius,
		damage = effect.damage,
		pullSpeed = effect.pullSpeed,
	})
end

local function activateDamageArea(effect, x, y)
	forEachEnemyInRadius(x, y, effect.radius, function(enemy)
		Enemies.applyDamage(enemy, effect.damage, { sourceKind = "ability" })
	end, true)
end

local function activateSlowArea(effect, x, y)
	forEachEnemyInRadius(x, y, effect.radius, function(enemy)
		Enemies.applySlow(enemy, effect.factor, effect.duration)
	end, true)
end

local function activateTowerAreaEffect(effect, x, y)
	activateTowerArea(x, y, effect)
end

local function activateGravityWellEffect(effect, x, y)
	activateGravityWell(x, y, effect)
end

local effectActivators = {
	damage_area = activateDamageArea,
	slow_area = activateSlowArea,
	income_multiplier = activateIncomeMultiplier,
	tower_haste_area = activateTowerAreaEffect,
	last_stand = activateTowerAreaEffect,
	gravity_well = activateGravityWellEffect,
}

local function playMeteorEffect(effect, x, y)
	Effects.spawnCannonImpact(x, y, effect.radius)
	Effects.trigger("ability_meteor", { intensity = 3, shake = 4 })
end

local function playFrostEffect(_, x, y)
	Effects.spawnFrostBurst(x, y)
	Effects.trigger("ability_frost", { intensity = 2, shake = 1 })
end

local activationEffects = {
	damage_area = playMeteorEffect,
	slow_area = playFrostEffect,
}

local function playActivationEffect(effect, x, y)
	local play = activationEffects[effect.kind]
	if play then
		play(effect, x, y)
	else
		Effects.trigger("ability_cast", { intensity = 2, shake = 1 })
	end
end

function Abilities.activate(x, y)
	local target = State.abilityTargeting
	local def = target and Abilities.getEquipped(target.abilityId)
	if not def or not Abilities.isReady(def.id) then
		return false
	end

	local effect = getEffect(def)
	local activateEffect = effectActivators[effect.kind]
	if not activateEffect then
		return false
	end

	-- Every activator follows the same contract, regardless of whether it
	-- creates a timed effect or resolves immediately.
	activateEffect(effect, x, y, def.id)
	playActivationEffect(effect, x, y)
	State.abilityCooldowns[def.id] = def.cooldown
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
	forEachEnemyInRadius(effect.x, effect.y, effect.radius, function(enemy)
		local resistsPull = enemy.def and (enemy.def.boss or enemy.def.heavy)
		local resistance = resistsPull and 0.2 or 1
		Enemies.setPathDistance(enemy, enemy.dist - effect.pullSpeed * resistance * dt)
	end)
end

local function updateLastStand(effect)
	if effect.volleys <= 0 then
		return
	end

	local radiusSquared = effect.radius * effect.radius
	for _, enemy in ipairs(Enemies.enemies) do
		local dx, dy = enemy.x - effect.x, enemy.y - effect.y
		local inside = dx * dx + dy * dy <= radiusSquared
		if effect.inside[enemy] and not inside and clock - effect.lastVolley >= 1.5 then
			triggerVolley(effect, enemy)
		end
		effect.inside[enemy] = inside
	end
end

local function expireGravityWell(effect)
	forEachEnemyInRadius(effect.x, effect.y, effect.radius, function(enemy)
		Enemies.applyDamage(enemy, effect.damage, { sourceKind = "ability" })
	end)
	Effects.spawnCannonImpact(effect.x, effect.y, effect.radius)
end

-- Timed-effect behavior lives in one registry so adding a lifecycle does not
-- require keeping separate kind-to-callback tables in sync.
local timedEffectHandlers = {
	gravity_well = { update = updateGravityWell, expire = expireGravityWell },
	last_stand = { update = updateLastStand },
}

function Abilities.update(dt)
	clock = clock + dt
	State.abilityClock = clock
	for id, cooldown in pairs(State.abilityCooldowns) do
		State.abilityCooldowns[id] = math.max(0, cooldown - dt)
	end

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
			table.remove(active, i)
		end
	end
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
	State.abilityClock = 0
end

return Abilities

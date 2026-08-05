local AbilityDefs = require("systems.ability_defs")
local CampaignUnlocks = require("systems.campaign_unlocks")
local Enemies = require("world.enemies")
local Effects = require("world.effects")
local State = require("core.state")

local Abilities = {}

function Abilities.getEquipped(abilityId)
	local id = abilityId or (State.equippedAbilities and State.equippedAbilities[1])
	if not id or not CampaignUnlocks.isAbilityUnlocked(id) then return nil end

	for slotIndex, equippedId in ipairs(State.equippedAbilities or {}) do
		if equippedId == id then
			if CampaignUnlocks.isAbilitySlotUnlocked(slotIndex) then
				return AbilityDefs[id]
			end

			return nil
		end
	end

	return nil
end

local function getEffect(def)
	if CampaignUnlocks.isAbilityUpgradeUnlocked("enhanced_abilities") then
		return def.upgradedEffect or def.effect
	end

	return def.effect
end

function Abilities.isReady(abilityId)
	local def = Abilities.getEquipped(abilityId)
	return def ~= nil and (State.abilityCooldowns[def.id] or 0) <= 0
end

function Abilities.beginTargeting(abilityId)
	local def = Abilities.getEquipped(abilityId)
	if not def or not Abilities.isReady(def.id) or State.mode ~= "game" or State.modulePicker.active then return false end
	State.abilityTargeting = {abilityId = def.id, x = nil, y = nil}
	State.placing = nil
	State.selectedTower = nil
	State.selectedEnemy = nil
	return true
end

function Abilities.cancelTargeting()
	State.abilityTargeting = nil
end

function Abilities.activate(x, y)
	local abilityId = State.abilityTargeting and State.abilityTargeting.abilityId
	local def = Abilities.getEquipped(abilityId)
	if not def or not Abilities.isReady(abilityId) or not State.abilityTargeting then return false end
	local effect = getEffect(def)
	local radius2 = effect.radius * effect.radius
	for i = 1, #Enemies.enemies do
		local enemy = Enemies.enemies[i]
		local ex, ey = enemy.rx or enemy.x, enemy.ry or enemy.y
		local dx, dy = ex - x, ey - y
		if enemy.hp > 0 and dx * dx + dy * dy <= radius2 then
			if effect.kind == "damage_area" then
				Enemies.applyDamage(enemy, effect.damage, {sourceKind = "ability"})
			elseif effect.kind == "slow_area" then
				Enemies.applySlow(enemy, effect.factor, effect.duration)
			end
		end
	end
	if effect.kind == "damage_area" then
		Effects.spawnCannonImpact(x, y, effect.radius)
		Effects.trigger("ability_meteor", {intensity = 3, shake = 4, hitStop = 0.025})
	else
		Effects.spawnFrostBurst(x, y)
		Effects.trigger("ability_frost", {intensity = 2, shake = 1})
	end
	State.abilityCooldowns[def.id] = def.cooldown
	State.abilityTargeting = nil
	return true
end

function Abilities.update(dt)
	for abilityId, cooldown in pairs(State.abilityCooldowns) do
		State.abilityCooldowns[abilityId] = math.max(0, cooldown - dt)
	end
end

return Abilities

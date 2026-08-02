local AbilityDefs = require("systems.ability_defs")
local Enemies = require("world.enemies")
local Effects = require("world.effects")
local State = require("core.state")

local Abilities = {}

function Abilities.getEquipped()
	return AbilityDefs[State.equippedAbility]
end

function Abilities.isReady()
	return Abilities.getEquipped() ~= nil and (State.abilityCooldown or 0) <= 0
end

function Abilities.beginTargeting()
	local def = Abilities.getEquipped()
	if not def or not Abilities.isReady() or State.mode ~= "game" or State.modulePicker.active then return false end
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
	local def = Abilities.getEquipped()
	if not def or not Abilities.isReady() or not State.abilityTargeting then return false end
	local effect = def.effect
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
	State.abilityCooldown = def.cooldown
	State.abilityTargeting = nil
	return true
end

function Abilities.update(dt)
	State.abilityCooldown = math.max(0, (State.abilityCooldown or 0) - dt)
end

return Abilities

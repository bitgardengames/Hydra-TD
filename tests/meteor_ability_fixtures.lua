package.path = "./?.lua;./?/init.lua;" .. package.path

local damageCalls = 0
local impacts = 0
local impactRadius = 0
local shakeStrength = 0
local shakeDuration = 0
local dustBursts = 0

package.loaded["systems.campaign_unlocks"] = {
	isAbilityUnlocked = function() return true end,
	isAbilitySlotUnlocked = function() return true end,
	isAbilityUpgradeUnlocked = function() return false end,
}
package.loaded["world.enemies"] = {
	enemies = {{x = 100, y = 100, rx = 100, ry = 100, hp = 100}},
	applyDamage = function(enemy, damage)
		damageCalls = damageCalls + 1
		enemy.hp = enemy.hp - damage
	end,
}
package.loaded["world.towers"] = {towers = {}}
package.loaded["world.effects"] = {
	shake = function(strength, duration)
		shakeStrength, shakeDuration = strength, duration
	end,
	spawnCannonImpact = function(_, _, radius)
		impacts = impacts + 1
		impactRadius = radius
	end,
	spawnMeteorDust = function() dustBursts = dustBursts + 1 end,
}

local State = require("core.state")
local Abilities = require("systems.abilities")

State.mode = "game"
State.modulePicker.active = false
State.equippedAbilities = {"meteor"}
State.abilityCooldowns = {}
Abilities.reset()

assert(Abilities.beginTargeting("meteor"), "meteor targeting did not begin")
assert(Abilities.activate(100, 100), "meteor did not activate on a valid target")
assert(damageCalls == 0, "meteor damaged its target before travelling")

local active = Abilities.getActive()
assert(#active == 1 and active[1].kind == "meteor_incoming", "incoming meteor was not exposed for rendering")
assert(active[1].expires > active[1].started, "meteor has no travel time")

Abilities.update(.84)
assert(damageCalls == 0 and impacts == 0, "meteor landed before its travel time elapsed")
Abilities.update(.02)
assert(damageCalls == 1, "meteor did not damage enemies when it landed")
assert(impacts == 1, "meteor landing did not create an impact effect")
assert(impactRadius == active[1].radius * 1.2, "meteor impact effect was not scaled up")
assert(dustBursts == 1, "meteor landing did not create a dust burst")
assert(shakeStrength == 8.5 and shakeDuration == .34, "meteor landing did not use the stronger impact shake")
assert(#Abilities.getActive() == 0, "landed meteor was not removed")

State.abilityCooldowns.meteor = 0
assert(Abilities.beginTargeting("meteor"), "meteor targeting did not restart")
local emptyPreview = Abilities.getTargetPreview(250, 250)
assert(emptyPreview.valid and emptyPreview.count == 0, "meteor required an enemy at its target")
assert(Abilities.activate(250, 250), "meteor did not activate on empty ground")
Abilities.update(.86)
assert(damageCalls == 1, "meteor damaged an enemy outside its landing area")
assert(impacts == 2, "meteor did not create an impact effect on empty ground")
assert(dustBursts == 2, "meteor did not create dust on empty ground")

print("meteor ability fixtures passed")

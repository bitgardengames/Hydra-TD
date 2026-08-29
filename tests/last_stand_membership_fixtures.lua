package.path = "./?.lua;./?/init.lua;" .. package.path

package.loaded["systems.campaign_unlocks"] = {
	isAbilityUnlocked = function() return true end,
	isAbilitySlotUnlocked = function() return true end,
}
package.loaded["world.enemies"] = {applyDamage = function() end}
package.loaded["world.effects"] = {shake = function() end}

local tower = {x = 100, y = 100, range = 200, cooldown = 4, windUp = 2}
package.loaded["world.towers"] = {
	towers = {tower},
	addAbilityBuff = function() end,
}
package.loaded["systems.run_stats"] = {recordAbilityUse = function() end}

local Spatial = require("world.spatial_grid")
local State = require("core.state")
local Abilities = require("systems.abilities")

State.mode = "game"
State.equippedAbilities = {"last_stand"}
State.abilityCharges = {last_stand = require("systems.ability_defs").last_stand.chargeRequired}
Abilities.reset()
State.abilityCharges.last_stand = require("systems.ability_defs").last_stand.chargeRequired

assert(Abilities.beginTargeting("last_stand") and Abilities.activate(100, 100),
	"last stand did not activate around its tower")
local effect = Abilities.getActive()[1]

local live = {id = 1, x = 100, y = 100, hp = 10, dying = false}
local dead = {id = 2, x = 100, y = 100, hp = 0, dying = false}
local dying = {id = 3, x = 100, y = 100, hp = 10, dying = true}
local invalid = {id = 4, x = 100, y = 100, hp = 10, dying = false}
Spatial.updateEnemy(live)
Spatial.updateEnemy(dead)
Spatial.updateEnemy(dying)
Spatial.updateEnemy(invalid)
invalid.x = nil

Abilities.update(.1)
assert(effect.inside[live], "a live enemy in the circle was not recorded")
assert(not effect.inside[dead] and not effect.inside[dying] and not effect.inside[invalid],
	"dead, dying, or invalid enemies entered the membership set")

live.x = 250
Abilities.update(.1)
assert(not effect.inside[live] and not effect.previousInside[live],
	"an enemy remained in either membership table after its exit was resolved")
assert(effect.volleys == 0 and effect.lastVolley == State.abilityClock,
	"a valid live exiting enemy did not consume exactly one volley")
assert(tower.target == live and tower.cooldown == 0 and tower.windUp == 0,
	"the exit volley did not ready the affected tower")

local later = {id = 5, x = 100, y = 100, hp = 10, dying = false}
Spatial.updateEnemy(later)
Abilities.update(.1)
assert(effect.inside[later], "membership stopped updating after all volleys were consumed")
later.hp = 0
Abilities.update(.1)
assert(not effect.inside[later] and not effect.previousInside[later],
	"a dead enemy was not pruned from both reusable membership tables")
assert(effect.volleys == 0, "an invalid exit decremented the exhausted volley count")

Spatial.clear()
print("last stand membership fixtures passed")

-- Dependency-light kill-charge and ability-bar regression fixtures.
package.path = "./?.lua;./?/init.lua;" .. package.path

love = {math = {random = function() return 0 end}, mouse = {getPosition = function() return 0, 0 end}, graphics = {}}
local lg = love.graphics
lg.getDimensions = function() return 800, 600 end
lg.setColor = function() end
lg.rectangle = function() end
lg.setLineWidth = function() end

package.loaded["systems.campaign_unlocks"] = {
	isAbilityUnlocked = function() return true end,
	isAbilitySlotUnlocked = function() return true end,
	isAbilityUpgradeUnlocked = function() return false end,
	getAbilityLockMessage = function() return nil end,
}
package.loaded["world.enemies"] = {enemies = {}, applyDamage = function() end, applySlow = function() end}
package.loaded["world.towers"] = {towers = {}}
package.loaded["world.effects"] = {shake = function() end, expirationPulse = function() return 0 end}
package.loaded["world.spatial_grid"] = {queryCells = function() return {}, 0 end}

local State = require("core.state")
local Defs = require("systems.ability_defs")
local Abilities = require("systems.abilities")
State.mode = "game"
State.modulePicker.active = false
State.equippedAbilities = {"meteor"}
State.abilityCharges = {}
Abilities.reset()
assert(State.abilityCharges.meteor == Defs.meteor.chargeRequired and Abilities.isReady("meteor"),
	"new runs must initialize equipped abilities ready")
assert(Abilities.beginTargeting("meteor") and Abilities.activate(100, 100), "ready ability must activate")
assert(State.abilityCharges.meteor == 0 and not Abilities.isReady("meteor"),
	"activation must consume all required charge")
Abilities.update(1000)
assert(State.abilityCharges.meteor == 0, "waiting without kills must not restore charge")

assert(Abilities.chargeFromKill({boss = false}, "cannon") == 1 and State.abilityCharges.meteor == 1,
	"one normal kill must grant one charge")
assert(Abilities.chargeFromKill({summoned = true}, "cannon") == 0 and State.abilityCharges.meteor == 1,
	"summoned enemies must grant no charge")
assert(Abilities.chargeFromKill({boss = true}, "cannon") == Defs.bossCharge
	and State.abilityCharges.meteor == 1 + Defs.bossCharge, "boss charge policy must be honored")
assert(Abilities.chargeFromKill({boss = false}, "ability") == 0
	and State.abilityCharges.meteor == 1 + Defs.bossCharge, "ability kills must not self-recharge")
for _ = 1, 100 do Abilities.chargeFromKill({boss = false}, "cannon") end
assert(State.abilityCharges.meteor == Defs.meteor.chargeRequired, "charge must cap at its requirement")

-- Exercise the HUD threshold transition without loading rendering dependencies.
local readySounds = 0
package.loaded["core.save"] = {data = {equippedAbilities = {"meteor"}}}
package.loaded["core.theme"] = {outline = {color = {0,0,0}, width = 2}, ui = {backdrop = {0,0,0}, button = {1,1,1}, buttonHover = {1,1,1}}}
package.loaded["ui.text"] = {printfShadow = function() end}
package.loaded["ui.button"] = {
	newAnimation = function(extra) return extra or {} end,
	updateAnimation = function() end,
	getHoverColor = function() return 1, 1, 1 end,
}
package.loaded["core.hotkeys"] = {getDisplay = function() return nil end}
package.loaded["ui.ability_icons"] = {draw = function() end}
package.loaded["ui.ability_tooltip"] = {show = function() end}
package.loaded["systems.sound"] = {playAbilityReady = function() readySounds = readySounds + 1 end}
package.loaded["ui.ability_bar"] = nil
local AbilityBar = require("ui.ability_bar")
State.abilityCharges.meteor = Defs.meteor.chargeRequired - 1
AbilityBar.update(.01, 0, 0)
assert(not AbilityBar.getButtons()[1].enabled, "ability bar must be disabled below the threshold")
Abilities.chargeFromKill({boss = false}, "cannon")
AbilityBar.update(.01, 0, 0)
assert(AbilityBar.getButtons()[1].enabled and readySounds == 1,
	"ability bar must transition and notify exactly once at the threshold")
AbilityBar.update(.01, 0, 0)
assert(readySounds == 1, "ready notification must not repeat while capped")

local enemySource = assert(io.open("world/enemies.lua", "r")):read("*a")
local _, awardSites = enemySource:gsub('chargeFromKill%(e, e%.lastDamageSourceKind%)', '')
assert(awardSites == 1, "canonical enemy death path must contain exactly one charge award")
print("ability charge fixtures passed")

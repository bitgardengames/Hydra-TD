-- Dependency-light regression fixtures for the tower ability-buff lifecycle.
package.path = "./?.lua;./?/init.lua;" .. package.path

package.loaded["core.constants"] = {TOWER_RETARGET_INTERVAL = .1, GRID_W = 20, GRID_H = 20, TILE = 32}
package.loaded["core.tower_stat_display"] = {attackSpeed = function(v) return v end, range = function(v) return v end}
package.loaded["core.theme"] = {ui = {good = {0, 1, 0}, warn = {1, 0, 0}}}
package.loaded["world.tower_defs"] = {}
package.loaded["systems.sound"] = {play = function() end}
package.loaded["world.map"] = {map = {blocked = {}}, sampleFast = function() return 0, 0 end}
package.loaded["ui.floaters"] = {add = function() end}
package.loaded["world.targeting"] = {
	beginFrame = function() end,
	findTarget = function() return nil end,
	isSemanticallyValidTarget = function() return false end,
	clearFrameCache = function() end,
}
package.loaded["systems.difficulty"] = {get = function() return {sellRefund = .5} end}
package.loaded["world.enemies"] = {enemies = {}}
package.loaded["world.effects"] = {spawnPlacePuff = function() end, shake = function() end}
package.loaded["systems.achievements"] = {increment = function() end}
package.loaded["world.emissions"] = {emit = function() end, emitUpgradeTransformation = function() end}
package.loaded["core.localization"] = setmetatable({}, {__call = function(_, key) return key end})
package.loaded["systems.modules"] = {
	getTowerStatModifiers = function() return {damageMult = 1, fireRateMult = 1, rangeAdd = 0} end,
	getFireProfile = function() return {behaviors = {}} end,
	invalidateTower = function() end,
	isEnabled = function() return false end,
}
package.loaded["systems.run_stats"] = {recordPurchase = function() end}
package.loaded["core.save"] = {recordTowerPlacement = function() end, recordTowerUpgrade = function() end}
package.loaded["systems.campaign_unlocks"] = {isTowerUnlocked = function() return true end}

local State = require("core.state")
State.money = 1000
State.abilityClock = 0
local Towers = require("world.towers")

local tower = {
	range = 100, cooldown = 1, windUp = 0, retargetT = 1, fireInterval = 1,
	fireAnim = 0, levelUpAnim = 0, recoil = 0, x = 0, y = 0, renderY = 0,
	height = 0, angle = 0, canRotate = false, suppressedTimer = 1,
}
Towers.towers[1] = tower
Towers.addAbilityBuff(tower, {expires = 2, attackSpeed = 1.5, range = 1.2})
Towers.addAbilityBuff(tower, {expires = 5, attackSpeed = 2, range = 1.1})
assert(#Towers.activeAbilityBuffTowers == 1, "overlapping buffs must index a tower only once")
assert(tower.abilityAttackSpeed == 2.5 and tower.abilityRangeMultiplier == 1.2 and tower.range2 == 14400,
	"overlapping buff modifiers must combine using their authored policies")

-- Suppression prevents firing, but does not discard or recompute an active buff.
State.abilityClock = 1
Towers.updateTowers(.1)
assert(tower.abilityAttackSpeed == 2.5 and #tower.abilityBuffs == 2 and tower.target == nil,
	"suppression must coexist with active ability modifiers")

-- A single catch-up step may cross an expiry by much more than one fixed tick.
State.abilityClock = 3.5
Towers.expireAbilityBuffs(State.abilityClock)
assert(#tower.abilityBuffs == 1 and tower.abilityAttackSpeed == 2 and tower.abilityRangeMultiplier == 1.1,
	"fast-forward catch-up must expire every elapsed buff in one pass")

-- Upgrades replace base range; the effective squared range must retain the buff.
tower.def = {cost = 100, damage = 10, fireRate = 1, range = 100, upgrade = {rangeAdd = 20}}
tower.level, tower.sellValue = 1, 50
assert(Towers.upgradeTower(tower))
assert(tower.range == 120 and tower.range2 == (120 * 1.1) ^ 2,
	"upgrading a buffed tower must recompute effective range from the new base")

State.abilityClock = 10
Towers.expireAbilityBuffs(State.abilityClock)
assert(not tower.abilityBuffs and tower.abilityAttackSpeed == 1 and tower.range2 == 120 ^ 2,
	"the final expiry must restore base modifiers and remove the active index")

Towers.addAbilityBuff(tower, {expires = 20, attackSpeed = 2, range = 1.25})
tower.gx, tower.gy = 1, 1
Towers.sellTower(tower)
assert(#Towers.activeAbilityBuffTowers == 0 and not tower._activeAbilityBuffIndex and not tower.abilityBuffs,
	"selling a buffed tower must remove all active-buff bookkeeping")

local abilitiesSource = assert(io.open("systems/abilities.lua", "r")):read("*a")
assert(abilitiesSource:find("Towers.addAbilityBuff(tower", 1, true),
	"ability creation must use the centralized tower buff helper")

print("ability buff fixtures passed")

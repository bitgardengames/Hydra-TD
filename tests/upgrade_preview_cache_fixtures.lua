-- Dependency-light regression fixtures for upgrade-preview and inspect caches.
package.path = "./?.lua;./?/init.lua;" .. package.path

package.loaded["core.constants"] = {TOWER_RETARGET_INTERVAL = .1, GRID_W = 20, GRID_H = 20, TILE = 32}
package.loaded["core.tower_stat_display"] = {attackSpeed = tostring, range = tostring}
package.loaded["core.theme"] = {ui = {good = {0, 1, 0}, warn = {1, 0, 0}}}
package.loaded["world.tower_defs"] = {}
package.loaded["systems.sound"] = {play = function() end}
package.loaded["world.map"] = {map = {blocked = {}}, sampleFast = function() return 0, 0 end}
package.loaded["ui.floaters"] = {add = function() end}
package.loaded["world.targeting"] = {
	beginFrame = function() end, findTarget = function() end,
	isSemanticallyValidTarget = function() return false end, clearFrameCache = function() end,
}
package.loaded["systems.difficulty"] = {get = function() return {sellRefund = .5} end}
package.loaded["world.enemies"] = {enemies = {}}
package.loaded["world.effects"] = {spawnPlacePuff = function() end, shake = function() end}
package.loaded["systems.achievements"] = {increment = function() end}
package.loaded["world.emissions"] = {emitUpgradeTransformation = function() end}
package.loaded["core.localization"] = setmetatable({}, {__call = function(_, key) return key end})
package.loaded["systems.run_stats"] = {recordPurchase = function() end}
package.loaded["core.save"] = {recordTowerPlacement = function() end, recordTowerUpgrade = function() end}
package.loaded["systems.campaign_unlocks"] = {isTowerUnlocked = function() return true end}

local calls = 0
local Modules = {version = 1, enabled = true}
function Modules.isEnabled() return Modules.enabled end
function Modules.getTowerStatModifiers(tower)
	calls = calls + 1
	return {damageMult = tower.statMultiplier or 1, fireRateMult = 1, rangeAdd = 0}
end
function Modules.getFireProfile(tower)
	calls = calls + 1
	return {behaviors = {{id = "hit_damage", data = {mult = tower.behaviorMultiplier or 1}}}}
end
function Modules.invalidateTower(tower)
	tower._cacheVersion = (tower._cacheVersion or 0) + 1
	tower._fireProfileLocalVersion = (tower._fireProfileLocalVersion or 0) + 1
end
package.loaded["systems.modules"] = Modules

local State = require("core.state")
State.money = 10000
local Towers = require("world.towers")
local tower = {
	kind = "fixture", level = 1, appliedModules = {}, _cache = {}, _cacheVersion = 0,
	def = {cost = 100, damage = 10, fireRate = 1, range = 80, upgrade = {dmgMult = 2}},
	height = 0, renderY = 0, x = 0, y = 0, sellValue = 50,
}

local first = Towers.getUpgradePreview(tower)
local warmedCalls = calls
assert(Towers.getUpgradePreview(tower) == first and calls == warmedCalls,
	"unchanged calls must reuse the preview result without re-deriving module state")

assert(Towers.upgradeTower(tower), "fixture upgrade must succeed")
local upgraded = Towers.getUpgradePreview(tower)
assert(upgraded ~= first and upgraded.nextLevel == 3,
	"a tower upgrade must invalidate the cached preview")

local beforeModule = upgraded
tower.appliedModules[1] = "fixture_module"
local moduleChanged = Towers.getUpgradePreview(tower)
assert(moduleChanged ~= beforeModule,
	"an applied-module configuration change must invalidate the cached preview")

local beforeStatState = moduleChanged
tower.statMultiplier = 1.5
Modules.invalidateTower(tower)
local statChanged = Towers.getUpgradePreview(tower)
assert(statChanged ~= beforeStatState and statChanged.current.damage > beforeStatState.current.damage,
	"other invalidated stat state consumed by module modifiers must refresh the preview")

local beforeFireState = statChanged
tower.behaviorMultiplier = 2
tower._fireProfileLocalVersion = tower._fireProfileLocalVersion + 1
local fireChanged = Towers.getUpgradePreview(tower)
assert(fireChanged ~= beforeFireState and fireChanged.current.directDamage > beforeFireState.current.directDamage,
	"fire-profile-local state must participate in the preview cache key")

local inspectSource = assert(io.open("ui/bottom_bar_inspect.lua", "r")):read("*a")
assert(inspectSource:find("upgradeTooltipCache.preview == preview", 1, true)
	and inspectSource:find("upgradeTooltipCache.localeRevision == localeRevision", 1, true)
	and inspectSource:find("Tooltip.show(getUpgradeTooltip(t))", 1, true),
	"inspect must retain localized tooltip rows by preview and locale revisions")

print("upgrade preview cache fixtures passed")

-- Run with a Lua interpreter from the repository root.
package.path = "./?.lua;./?/init.lua;" .. package.path

local emitted = {}
local validTarget = true
local foundTarget

local function stub(name, value)
	package.loaded[name] = value or {}
end

stub("core.constants", {TILE = 32, TOWER_RETARGET_INTERVAL = 0.1})
stub("core.tower_stat_display")
stub("core.theme", {ui = {good = {1, 1, 1}, warn = {1, 1, 1}}})
stub("world.tower_defs")
stub("systems.sound", {play = function() end})
stub("core.state", {frameId = 1})
stub("world.map", {sampleFast = function(distance) return distance, 0 end})
stub("ui.floaters", {add = function() end})
stub("world.targeting", {
	findTarget = function() return foundTarget end,
	isSemanticallyValidTarget = function() return validTarget end,
	beginFrame = function() end,
	clearFrameCache = function() end,
})
stub("systems.difficulty")
stub("world.enemies", {enemies = {}})
stub("world.effects", {spawnPlacePuff = function() end})
stub("systems.achievements")
stub("world.emissions", {emit = function(tower, target) emitted[#emitted + 1] = {tower, target} end})
stub("core.localization")
stub("systems.modules")
stub("systems.run_stats")
stub("core.save")
stub("systems.campaign_unlocks")
stub("systems.branch_tier_resolver")

local Towers = require("world.towers")
local updateTower = Towers._test.updateTower

local function tower(overrides)
	local result = {
		x = 0, y = 0, height = 0, angle = 0,
		cooldown = 0, windUp = 0, retargetT = 1,
		fireAnim = 0, levelUpAnim = 0, placementAnim = 0, upgradeFlash = 0,
		recoil = 0, recoilStrength = 1, fireInterval = 2,
	}
	for key, value in pairs(overrides or {}) do result[key] = value end
	return result
end

-- Suppression clears combat state but still ticks timers and visuals.
local suppressed = tower({target = {x = 10, y = 0}, suppressedTimer = 1, windUp = 0.04, cooldown = 1})
updateTower(suppressed, 0.02)
assert(suppressed.target == nil and suppressed.windUp == 0)
assert(suppressed.cooldown == 0.98)

-- Losing a target during cooldown does not bypass the retarget interval.
local lost = tower({target = {x = 10, y = 0}, cooldown = 1, retargetT = 0.5})
validTarget = false
updateTower(lost, 0.1)
assert(lost.target == nil and lost.retargetT == 0.4)
validTarget = true

-- A completed wind-up fires immediately and establishes the authored cooldown.
local target = {id = 1, x = 10, y = 0}
local ready = tower({target = target, windUp = 0.04, canRotate = false})
updateTower(ready, 0.05)
assert(#emitted == 1 and emitted[1][1] == ready and emitted[1][2] == target)
assert(ready.cooldown == ready.fireInterval and ready.windUp == 0)

-- Rotating towers wait for alignment; fixed towers may begin wind-up immediately.
local rotating = tower({target = {id = 2, x = 0, y = 10}, canRotate = true, turnSpeed = 0})
updateTower(rotating, 0)
assert(rotating.windUp == 0)
local fixed = tower({target = {id = 3, x = 0, y = 10}, canRotate = false})
updateTower(fixed, 0)
assert(fixed.windUp == 0.08)

print("tower update tests passed")

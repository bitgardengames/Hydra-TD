-- Focused regression coverage for definition and localized presentation caches.
local function stub(name, value)
	package.loaded[name] = value or {}
end

stub("core.constants", { TILE = 32, TOWER_RETARGET_INTERVAL = 0.1 })
stub("core.tower_stat_display", {
	attackSpeed = function(value) return math.floor(value * 60 + 0.5) end,
	range = function(value) return math.floor(value + 0.5) end,
})
local theme = {
	ui = {
		good = { 0, 1, 0 }, warn = { 1, 1, 0 }, bad = { 1, 0, 0 },
		text = { 1, 1, 1 }, buttonDisabled = { .5, .5, .5 },
		backdrop = { 0, 0, 0 }, panel2 = { 0, 0, 0 },
	},
	outline = { color = { 0, 0, 0 }, width = 1 },
}
stub("core.theme", theme)
stub("world.tower_defs", {})
stub("core.state", { money = 1000 })
stub("world.map", { sampleFast = function() end })
stub("world.targeting", { findTarget = function() end, isSemanticallyValidTarget = function() end,
	beginFrame = function() end, clearFrameCache = function() end })
stub("systems.difficulty", { get = function() return { sellRefund = .5 } end })
stub("world.enemies", { enemies = {} })
stub("systems.achievements", { increment = function() end })
stub("systems.run_stats", {})
stub("systems.campaign_unlocks", {})
stub("core.save", {})
stub("systems.sound", {})
stub("ui.floaters", {})
stub("world.effects", {})
stub("world.emissions", {})

local builds = 0
stub("world.projectile_profiles", {
	get = function()
		builds = builds + 1
		return { behaviors = {} }
	end,
})
local localeRevision = 1
local localePrefix = "en:"
local localization = setmetatable({
	getRevision = function() return localeRevision end,
}, { __call = function(_, key, value) return localePrefix .. key .. (value and (":" .. value) or "") end })
stub("core.localization", localization)

local Towers = dofile("world/towers.lua")
local tower = {
	kind = "fixture", level = 1,
	def = { damage = 10, fireRate = 1, range = 50, cost = 10,
		upgrade = { dmgMult = 2, fireMult = 1.5, rangeAdd = 2 } },
}
local first = Towers.getUpgradePreview(tower)
local second = Towers.getUpgradePreview(tower)
assert(first == second, "same kind and level did not share the preview")
assert(builds == 2, "cached preview rebuilt definition-derived projectile profiles")
assert(first.rows[1].current == second.rows[1].current)
assert(not pcall(function() first.nextLevel = 99 end), "cached preview was mutable")

tower.level = 2
assert(Towers.getUpgradePreview(tower) ~= first, "level change retained stale preview")
assert(builds == 4, "new level did not rebuild preview")

stub("core.util", { formatInt = tostring })
stub("ui.tooltip", {})
stub("ui.text", {})
stub("ui.hotkey_visual", {})
stub("ui.button", { newAnimation = function(value) return value end })
_G.love = { graphics = {} }
local Inspect = dofile("ui/bottom_bar_inspect.lua")
local localized = Inspect.getUpgradeTooltipPresentation(tower)
assert(Inspect.getUpgradeTooltipPresentation(tower) == localized,
	"unchanged tooltip presentation was rebuilt")

tower.level = 3
local upgraded = Inspect.getUpgradeTooltipPresentation(tower)
assert(upgraded ~= localized and upgraded.title:match(":4$"),
	"upgrade did not refresh localized tooltip rows")

localeRevision = localeRevision + 1
localePrefix = "fr:"
local translated = Inspect.getUpgradeTooltipPresentation(tower)
assert(translated ~= upgraded and translated.rows[1].label:match("^fr:"),
	"locale revision did not refresh tooltip rows")

local beforeDefinitions = translated
Towers.invalidateUpgradePreviewCache()
assert(Inspect.getUpgradeTooltipPresentation(tower) ~= beforeDefinitions,
	"definition invalidation did not refresh tooltip presentation")

print("upgrade preview cache fixtures: ok")

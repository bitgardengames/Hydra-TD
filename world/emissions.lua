local Projectiles = require("world.projectiles")
local Effects = require("world.effects")

local Emissions = {}

-- Upgrade transformations live on the emission boundary so firing and upgrade
-- feedback share one tower-specific presentation entry point. No projectile or
-- damage is created here.
function Emissions.emitUpgradeTransformation(tower, preview, finalTier)
	if not tower then return end

	local before = preview and preview.current or {}
	local after = preview and preview.postUpgrade or {}
	local rangeChanged = before.range and after.range and before.range ~= after.range
	local cadenceChanged = before.fireRate and after.fireRate and before.fireRate ~= after.fireRate

	if cadenceChanged then
		-- A single accelerated dry-fire pose: Towers.update naturally decays both
		-- values without invoking the projectile emission path.
		tower.fireAnim = 1
		tower.recoil = math.max(tower.recoil or 0, (tower.recoilStrength or 0) * 0.55)
	end

	Effects.spawnTowerTransformation(tower.x, tower.renderY or tower.y, {
		color = tower.color or (tower.def and tower.def.color),
		range = rangeChanged and after.range or nil,
		cadencePulse = cadenceChanged,
		finalTier = finalTier,
	})
end

function Emissions.emit(t, target)
	return Projectiles.spawn(t, target)
end

return Emissions

local Modules = require("systems.modules")
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
	local profile = Modules.getFireProfile(t)
	local ctx = profile or Modules.buildContext(t)

	if ctx.output == "beam" then
		return Emissions.emitBeam(t, target, ctx)
	else
		return Emissions.emitProjectile(t, target, ctx)
	end
end

-- =========================
-- PROJECTILE (existing path)
-- =========================
function Emissions.emitProjectile(t, target, ctx)
	return Projectiles.spawnFromContext(t, target, ctx)
end

-- =========================
-- BEAM
-- =========================
function Emissions.emitBeam(t, target, ctx)
	-- Spawn a "pseudo projectile" that is stationary.
	-- Avoid allocating a per-shot overrides table in this hot path.
	local life = math.max(0.12, (t.fireInterval or 0.2) * 0.9)
	return Projectiles.spawnFromContext(t, target, ctx, 0, life)
end

return Emissions

local Modules = require("systems.modules")
local Projectiles = require("world.projectiles")

local Emissions = {}

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

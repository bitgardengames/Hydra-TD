local Modules = require("systems.modules")
local Projectiles = require("world.projectiles")

local Emissions = {}

function Emissions.emit(t, target)
	local ctx = Modules.buildContext(t)

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
	-- spawn a "pseudo projectile" that is stationary
	return Projectiles.spawnFromContext(t, target, ctx, {
		speed = 0,
		life = 0.2 -- short-lived, refreshed by fire rate
	})
end

return Emissions
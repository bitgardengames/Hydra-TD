local Save = require("core.save")
local Camera = require("core.camera")
local Theme = require("core.theme")
local Shared = require("world.effects.shared")
local Registry = require("world.effects.registry")

local Effects = {}

function Effects.expirationPulse(remaining, clock)
	if not remaining or remaining > 1 then return 1 end
	local fade = math.max(0, remaining)
	local pulse = 0.45 + 0.55 * math.abs(math.sin((clock or 0) * math.pi * 6))
	return fade * pulse
end

local function settings()
	return Save.data and Save.data.settings or {}
end

function Effects.particleCount(base, intensity, criticalTell)
	if criticalTell then return math.max(1, base) end
	if settings().highDensityParticles == false then base = base * 0.5 end
	return math.max(intensity >= Theme.effects.intensity.strong and 1 or 0, math.floor(base + 0.5))
end

function Effects.shake(amount, duration)
	local s = settings()
	local shakeScale = (s.screenShake == false or s.cameraMotion == false) and 0 or 1
	Camera.shake((amount or 0.8) * shakeScale, duration or 0.14)
end

local context = {Effects = Effects, particleCount = Effects.particleCount}
-- This order is the established world-space draw order. Explosions are built
-- first only so cannon splashes can delegate their particle component to them.
local constructors = {
	"presentation", "tower_transformations", "explosions", "splashes", "zaps",
	"zap_lines", "frost", "poison", "lancer", "plasma", "place_puffs", "death",
}
local byName = {}
for i = 1, #constructors do
	local family = require("world.effects." .. constructors[i])(context)
	byName[family.name] = family
	Effects[family.name] = family.list
end
local drawOrder = {
	"presentation", "towerTransformations", "splashes", "explosions", "zaps",
	"zapLines", "frost", "poison", "lancer", "plasmaParticles", "placePuffs", "death",
}
local families = {}
for i = 1, #drawOrder do families[i] = byName[drawOrder[i]] end
local registry = Registry.new(families, Shared.graphics)

function Effects.update(dt) registry:update(dt) end
function Effects.draw() registry:draw() end
function Effects.drawOverlay() registry:drawOverlay() end
function Effects.load() registry:load() end
function Effects.clear() registry:clear() end
Effects.spawnFX = registry.spawnFX

return Effects

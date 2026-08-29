local Constants = require("core.constants")
local Spatial = require("world.spatial_grid")

--[[
	NOTE; ALL SYSTEMS MUST WORK TOGETHER FLUIDLY. This rule cannot be broken.

	Any tower should be able to emit any effect, behavior, or visual.

	Any mixture of projectile + behavior + visual has to work, period.

	Don't hard code things, that's already a broken contract.
--]]

local pi = math.pi
local min = math.min
local max = math.max
local sin = math.sin
local cos = math.cos
local sqrt = math.sqrt
local atan2 = math.atan2
local floor = math.floor
local random = math.random
local abs = math.abs

local B = {}

local lg = love.graphics

local function clearMap(t)
	if not t then
		return
	end

	for k in pairs(t) do
		t[k] = nil
	end
end

local function clearArray(t)
	if not t then
		return
	end

	for i = #t, 1, -1 do
		t[i] = nil
	end
end

-- helpers

--[[
	more ideas

	just a split shot that goes out in 2 directions

	either a 4x or even crazy 8x shot outwards from the tower

	shockwave type ring that expands out from the tower?

	can we make any projectile pierce? (even cannon shells, poison ticks, lancer shots) they just deal their damage but aren't consumed and move on

	we haven't even touched behaviors that modify tower targeting behavior, so currently all towers still shoot at the furthest enemy along the path

	maybe a behavior just turns the projectiles into an aura around the tower in some manner, but is this any different than orbital?

	a behavior that makes projectiles just larger/more damage
	make projectiles considerably wider

	make projectiles spin around like crazy

	projectiles bounce off the enemy
--]]

local function pushEvent(p, evt)
	if not p or not evt then return end
	if not evt.id then return end

	local events = p.events
	if not events then
		events = {}
		p.events = events
		p.eventRead = 1
		p.eventCount = 0
	end

	local count = (p.eventCount or 0) + 1
	events[count] = evt
	p.eventCount = count
end


local function takeEvent(p, id)
	local eventPool = p and p._eventPool
	local eventPoolCount = p and (p._eventPoolCount or 0) or 0
	local evt

	if eventPool and eventPoolCount > 0 then
		evt = eventPool[eventPoolCount]
		eventPool[eventPoolCount] = nil
		p._eventPoolCount = eventPoolCount - 1
	else
		evt = {}
	end

	evt.id = id
	return evt
end


local function emitEvent(p, id)
	local evt = takeEvent(p, id)
	pushEvent(p, evt)
	return evt
end

local function emitFX(p, kind)
	local evt = emitEvent(p, "fx")
	evt.kind = kind
	return evt
end

local function emitSpawnProjectile(p)
	return emitEvent(p, "spawn_projectile")
end

local function getStat(p, key, fallback)
	local t = p.sourceTower
	if t and t[key] ~= nil then return t[key] end
	if p[key] ~= nil then return p[key] end
	return fallback
end

local function emitDamage(p, e, dmg, metadata)
	local evt = emitEvent(p, "damage")
	evt.target = e
	evt.amount = dmg
	-- Damage semantics belong to the behavior that emitted the event. Keeping
	-- these defaults explicit prevents attribution fields from selecting combat.
	evt.chain = metadata and metadata.chain == true or false
	evt.armorHeavy = metadata and metadata.armorHeavy == true or false
	-- Presentation metadata survives the pooled event path and is resolved after
	-- authoritative damage, so spectacular attacks never alter combat outcomes.
	evt.effectIntensity = evt.armorHeavy and e and e.armor and "armor_heavy"
		or (dmg >= 100 and "strong" or "normal")
end

local function beginChainDamageBudget(p)
	p._chainBudgetUsed = 0
end

local function consumeChainDamageBudget(p, rawDmg)
	if rawDmg <= 0 then
		return 0
	end

	local base = p._baseDamage or p.damage or rawDmg
	local cap = base * 4.5
	local used = p._chainBudgetUsed or 0
	local remaining = max(0, cap - used)
	if remaining <= 0 then
		return 0
	end

	-- Soft-cap after first few secondary hits, then hard-cap at total budget.
	local secondaryCount = p._chainSecondaryHitCount or 0
	local diminished = rawDmg
	if secondaryCount >= 6 then
		diminished = diminished * 0.85
	end
	if secondaryCount >= 10 then
		diminished = diminished * 0.7
	end

	local allowed = min(diminished, remaining)
	if allowed > 0 then
		p._chainBudgetUsed = used + allowed
		p._chainSecondaryHitCount = secondaryCount + 1
	end

	return allowed
end

local function emitImpulse(p, e, px, py, strength)
	local evt = emitEvent(p, "impulse")
	evt.target = e
	evt.dx = e.x - px
	evt.dy = e.y - py
	evt.strength = strength
end

local function canHitTarget(p, enemy)
	local profile = p.profile
	local functions = profile and profile.canHitFns
	if not functions then
		return true
	end

	local data = profile.canHitData
	for i = 1, #functions do
		if not functions[i](p, enemy, data[i]) then
			return false
		end
	end

	return true
end

local function projectileHasHit(p, id)
	if p.hasHit then
		return p.hasHit(p, id)
	end

	return p.hitSet[id] == true
end

local function canProcTarget(p, procKey, enemy, cooldown)
	if not p or not procKey or not enemy then
		return false
	end
	local id = enemy.id or enemy
	p._procCooldowns = p._procCooldowns or {}
	local map = p._procCooldowns[procKey]
	if not map then
		map = {}
		p._procCooldowns[procKey] = map
	end
	local now = p.t or 0
	local nextAt = map[id] or -1
	if now < nextAt then
		return false
	end
	map[id] = now + (cooldown or 0)
	return true
end


-- visual stuff
local function getProjectileColor(p, fallback)
	local t = p.sourceTower
	local c = t and t.color

	if c then
		return c[1], c[2], c[3]
	end

	return fallback[1], fallback[2], fallback[3]
end

local function colorMul(r, g, b, mul)
	return min(1, r * mul), min(1, g * mul), min(1, b * mul)
end

local function getTowerMuzzle(t)
	if not t then
		return 0, 0
	end

	local size = Constants.TILE * 0.42
	local tipX = t.def and t.def.projectileMuzzleOffset or size * 0.9

	local localX = tipX - (t.recoil or 0)
	local ca = cos(t.angle or 0)
	local sa = sin(t.angle or 0)

	local x = t.x + localX * ca
	local y = (t.renderY or t.y) + localX * sa

	return x, y
end


return {
	Constants = Constants,
	Spatial = Spatial,
	lg = lg,
	pi = pi,
	min = min,
	max = max,
	sin = sin,
	cos = cos,
	sqrt = sqrt,
	atan2 = atan2,
	floor = floor,
	random = random,
	abs = abs,
	clearMap = clearMap,
	clearArray = clearArray,
	pushEvent = pushEvent,
	takeEvent = takeEvent,
	emitEvent = emitEvent,
	emitFX = emitFX,
	emitSpawnProjectile = emitSpawnProjectile,
	getStat = getStat,
	emitDamage = emitDamage,
	beginChainDamageBudget = beginChainDamageBudget,
	consumeChainDamageBudget = consumeChainDamageBudget,
	emitImpulse = emitImpulse,
	canHitTarget = canHitTarget,
	projectileHasHit = projectileHasHit,
	canProcTarget = canProcTarget,
	getProjectileColor = getProjectileColor,
	colorMul = colorMul,
	getTowerMuzzle = getTowerMuzzle,
}

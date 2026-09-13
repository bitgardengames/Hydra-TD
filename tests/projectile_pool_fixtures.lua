-- Projectile pool lifecycle regression fixture.
package.path = "./?.lua;./?/init.lua;" .. package.path
love = { graphics = {} }

local eventSerial = 0
local PB = {}

function PB.takeEvent(p, id)
	local count = p._eventPoolCount or 0
	local event
	if count > 0 then
		event = p._eventPool[count]
		p._eventPool[count] = nil
		p._eventPoolCount = count - 1
	else
		eventSerial = eventSerial + 1
		event = { serial = eventSerial }
	end
	event.id = id
	return event
end

function PB.pushEvent(p, event)
	p.eventCount = p.eventCount + 1
	p.events[p.eventCount] = event
end

function PB.compileHooks(p)
	p._hooks = { plan = p.behaviors }
	p._drawHandlers = { p.behaviors }
	p._canHitPredicates = { p.behaviors }
end

function PB.init() end
function PB.update() end
function PB.draw() end
function PB.hit() end

package.loaded["world.projectile_behaviors"] = PB
package.loaded["core.state"] = { addDamage = function() end }
local damageCalls = 0
package.loaded["world.enemies"] = {
	applyDamage = function(_, amount)
		damageCalls = damageCalls + 1
		return amount, 0
	end,
}
package.loaded["world.effects"] = {
	spawnFX = function() end,
	shake = function()
		error("projectile damage must not shake the screen")
	end,
}
package.loaded["systems.sound"] = { play = function() end }
package.loaded["systems.run_stats"] = { recordDamage = function() end }
package.loaded["core.save"] = {}
package.loaded["ui.floaters"] = { add = function() end }

local Projectiles = require("world.projectiles")
local source = {
	x = 10, y = 20, kind = "fixture", angle = 0, projSpeed = 30, damage = 5,
	def = { behaviors = {} },
}
local firstPlan = { { id = "first" } }
local secondPlan = { { id = "second" } }

local first = Projectiles.spawnEvent({ source = source, life = 0.01, behaviors = firstPlan })
first.markHit(first, "enemy-a")
first.setHitCooldownExpiry(first, "enemy-b", 99)
first._defaultHitCtx.hitX = 123
first._defaultHitCtx.hitY = 456
first.allowRepeatHits = true
first._didExpireHook = true

local queued = PB.takeEvent(first, "fixture_unresolved")
queued.payload = "old shot"
PB.pushEvent(first, queued)

-- Expiry releases the projectile while its event is still queued.
Projectiles.update(0.02)
assert(#Projectiles.projectiles == 0)

local second = Projectiles.spawnEvent({ source = source, life = 1, behaviors = secondPlan })
assert(second == first, "fixture must reacquire the released projectile")
assert(second.behaviors == secondPlan, "behavior plan leaked between uses")
assert(second._hooks.plan == secondPlan, "compiled behavior hooks were not replaced")
assert(second.eventRead == 1 and second.eventCount == 0 and next(second.events) == nil,
	"queued events leaked between uses")
assert(second._eventPoolCount == 1, "queued event was not returned to its owner pool")
assert(second._eventPool[1] == queued and queued.id == nil and queued.payload == nil,
	"returned event was not cleared")
assert(not second.hasHit(second, "enemy-a"), "hit stamp leaked between uses")
assert(second.getHitCooldownExpiry(second, "enemy-b") == nil, "hit cooldown leaked between uses")
assert(second._defaultHitCtx.origin == "primary" and second._defaultHitCtx.hitX == nil
	and second._defaultHitCtx.hitY == nil, "default hit context leaked between uses")
assert(second.allowRepeatHits == nil and second._didExpireHook == nil,
	"per-use projectile flags leaked between uses")

local damageEvent = PB.takeEvent(second, "damage")
damageEvent.target = { hp = 1000, maxHp = 1000, hitFlash = 0, x = 0, y = 0, radius = 10 }
damageEvent.amount = 500
PB.pushEvent(second, damageEvent)
Projectiles.update(0)
assert(damageCalls == 1, "large projectile hit did not resolve damage")

Projectiles.clear()
print("projectile pool fixtures passed")

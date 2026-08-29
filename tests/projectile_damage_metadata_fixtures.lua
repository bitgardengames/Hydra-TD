-- Damage events, rather than tower attribution, own chain semantics.
package.path = "./?.lua;./?/init.lua;" .. package.path
love = { graphics = {} }

local captured = {}
local PB = {}
function PB.takeEvent(_, id) return { id = id } end
function PB.pushEvent(p, evt)
	p.eventCount = (p.eventCount or 0) + 1
	p.events[p.eventCount] = evt
end
function PB.init() end
function PB.draw() end
function PB.hit() end
function PB.expire() end
function PB.consume() return "consume" end
function PB.update(p)
	if p.fixtureEmitted then return end
	p.fixtureEmitted = true
	PB.pushEvent(p, {
		id = "damage",
		target = p.target,
		amount = 5,
		chain = p.fixtureChain,
	})
end

package.loaded["world.projectile_behaviors"] = PB
package.loaded["world.projectile_profiles"] = { get = function() return { behaviors = {} } end }
package.loaded["core.state"] = { addDamage = function() end }
package.loaded["world.enemies"] = {
	applyDamage = function(_, amount, context)
		captured[#captured + 1] = context
		return amount, 0
	end,
}
package.loaded["world.effects"] = { shake = function() end }
package.loaded["systems.sound"] = { play = function() end }
package.loaded["systems.run_stats"] = { recordDamage = function() end }
package.loaded["core.save"] = { data = { settings = { showDamageNumbers = false } } }
package.loaded["ui.floaters"] = { add = function() end }

local Projectiles = require("world.projectiles")
local target = { id = 1, hp = 100, maxHp = 100, x = 0, y = 0, radius = 5, hitFlash = 0 }
local source = { x = 0, y = 0, kind = "shock", damage = 5, def = { behaviors = {} } }

local chain = Projectiles.spawn(source, target)
chain.fixtureChain = true
Projectiles.update(0.01)
assert(captured[1].sourceKind == "shock" and captured[1].chain == true,
	"explicit Shock chain damage must retain its attribution")

local ordinary = Projectiles.spawn(source, target)
ordinary.fixtureChain = false
Projectiles.update(0.01)
assert(captured[2].sourceKind == "shock" and captured[2].chain == false,
	"ordinary damage must remain non-chain even when attributed to Shock")

Projectiles.clear()
print("projectile damage metadata fixtures passed")

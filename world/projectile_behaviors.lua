local BehaviorContext = require("systems.behavior_context")
local Registry = require("world.projectile_behaviors.registry")
local Shared = require("world.projectile_behaviors.shared")

local ProjectileBehaviors = {
	pushEvent = Shared.pushEvent,
	takeEvent = Shared.takeEvent,
	canProcTarget = Shared.canProcTarget,
	registry = Registry,
}
local B = Registry.definitions()
local HOOKS = { "on_shot", "on_tick", "on_hit", "on_kill", "on_expire" }
local compiledPlans = setmetatable({}, { __mode = "k" })

local function hookIsDeclared(declared, hook)
	if not declared then return true end
	for i = 1, #declared do
		if declared[i] == hook then return true end
	end
	return false
end

local function compilePlan(behaviors)
	local hooks, drawHandlers, canHitPredicates = {}, {}, {}
	for i = 1, #HOOKS do hooks[HOOKS[i]] = {} end
	for i = 1, #behaviors do
		local behavior = behaviors[i]
		local def = B[behavior.id]
		if def then
			if def.draw then drawHandlers[#drawHandlers + 1] = { fn = def.draw, data = behavior.data } end
			if def.canHit then canHitPredicates[#canHitPredicates + 1] = { fn = def.canHit, data = behavior.data } end
			for j = 1, #HOOKS do
				local hook = HOOKS[j]
				if def[hook] and hookIsDeclared(behavior.hooks, hook) then
					hooks[hook][#hooks[hook] + 1] = { fn = def[hook], data = behavior.data }
				end
			end
		end
	end
	return { hooks = hooks, drawHandlers = drawHandlers, canHitPredicates = canHitPredicates }
end

function ProjectileBehaviors.compileHooks(p)
	local plan = compiledPlans[p.behaviors]
	if not plan then
		Registry.validateBehaviorIds(p.behaviors)
		plan = compilePlan(p.behaviors)
		compiledPlans[p.behaviors] = plan
	end
	p._hooks, p._drawHandlers, p._canHitPredicates = plan.hooks, plan.drawHandlers, plan.canHitPredicates
end

local function consumeProjectile(p)
	if p and not p._didExpireHook then
		p._didExpireHook = true
		local hooks = p._hooks and p._hooks.on_expire
		if hooks then for i = 1, #hooks do hooks[i].fn(p, hooks[i].data) end end
	end
	return "consume"
end

function ProjectileBehaviors.build(t)
	local b = {}
	if t.def.behaviors then for i = 1, #t.def.behaviors do b[#b + 1] = t.def.behaviors[i] end end
	if t.modBehaviors then for i = 1, #t.modBehaviors do b[#b + 1] = t.modBehaviors[i] end end
	return b
end

function ProjectileBehaviors.buildChildBehaviors(parentBehaviors)
	local out, hasRole = {}, { collision = false, damage = false }
	for i = 1, #parentBehaviors do
		local behavior = parentBehaviors[i]
		if not behavior.noInherit then
			out[#out + 1] = BehaviorContext.cloneBehavior(behavior)
			local role = Registry.getRole(behavior.id)
			if hasRole[role] ~= nil then hasRole[role] = true end
		end
	end
	if not hasRole.collision then out[#out + 1] = { id = "hit_circle", data = { radius = 10 } } end
	if not hasRole.damage then out[#out + 1] = { id = "hit_damage" } end
	return out
end

function ProjectileBehaviors.init(p)
	local hooks = p._hooks and p._hooks.on_shot
	if hooks then for i = 1, #hooks do hooks[i].fn(p, hooks[i].data) end end
end
function ProjectileBehaviors.update(p, dt)
	local hooks = p._hooks and p._hooks.on_tick
	if hooks then for i = 1, #hooks do
		local result = hooks[i].fn(p, dt, hooks[i].data)
		if result == "consume" then return consumeProjectile(p) end
		if result then return result end
	end end
end
function ProjectileBehaviors.hit(p, e, ctx)
	ctx = ctx or p._defaultHitCtx or { origin = p.hitOrigin or "primary" }
	local oldX, oldY = p.x, p.y
	if ctx.hitX and ctx.hitY then p.x, p.y = ctx.hitX, ctx.hitY end
	local shouldConsume = false
	local hooks = p._hooks and p._hooks.on_hit
	if hooks then for i = 1, #hooks do if hooks[i].fn(p, e, hooks[i].data, ctx) == "consume" then shouldConsume = true end end end
	if e and e.hp and e.hp <= 0 then
		hooks = p._hooks and p._hooks.on_kill
		if hooks then for i = 1, #hooks do hooks[i].fn(p, e, hooks[i].data, ctx) end end
	end
	p.x, p.y = oldX, oldY
	if shouldConsume then return consumeProjectile(p) end
end
function ProjectileBehaviors.draw(p, a)
	local handlers = p._drawHandlers
	if handlers then for i = 1, #handlers do handlers[i].fn(p, a, handlers[i].data) end end
end
return ProjectileBehaviors

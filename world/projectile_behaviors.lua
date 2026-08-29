local Registry = require("world.projectile_behaviors.registry")
local Shared = require("world.projectile_behaviors.shared")

local ProjectileBehaviors = {
	pushEvent = Shared.pushEvent,
	takeEvent = Shared.takeEvent,
	canProcTarget = Shared.canProcTarget,
	registry = Registry,
}

local function run(profile, operation, p, ...)
	local handlers = profile and profile[operation]
	if not handlers then return end
	for i = 1, #handlers do
		local handler = handlers[i]
		local result = handler.fn(p, ..., handler.data)
		if result then return result end
	end
end

function ProjectileBehaviors.init(p)
	return run(p.profile, "init", p)
end

function ProjectileBehaviors.expire(p)
	if not p or p._didExpire then return end
	p._didExpire = true
	return run(p.profile, "expire", p)
end

function ProjectileBehaviors.consume(p)
	ProjectileBehaviors.expire(p)
	return "consume"
end

function ProjectileBehaviors.update(p, dt)
	local result = run(p.profile, "update", p, dt)
	if result == "consume" then return ProjectileBehaviors.consume(p) end
	return result
end

function ProjectileBehaviors.hit(p, enemy, ctx)
	ctx = ctx or p._defaultHitCtx or { origin = p.hitOrigin or "primary" }
	local oldX, oldY = p.x, p.y
	if ctx.hitX and ctx.hitY then p.x, p.y = ctx.hitX, ctx.hitY end
	local handlers = p.profile and p.profile.hit
	local shouldConsume = false
	if handlers then
		for i = 1, #handlers do
			local handler = handlers[i]
			if handler.fn(p, enemy, handler.data, ctx) == "consume" then shouldConsume = true end
		end
	end
	p.x, p.y = oldX, oldY
	if shouldConsume then return ProjectileBehaviors.consume(p) end
end

function ProjectileBehaviors.draw(p, alpha)
	return run(p.profile, "draw", p, alpha)
end

return ProjectileBehaviors

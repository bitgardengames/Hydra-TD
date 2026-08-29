local Registry = require("world.projectile_behaviors.registry")
local Shared = require("world.projectile_behaviors.shared")

local ProjectileBehaviors = {
	pushEvent = Shared.pushEvent,
	takeEvent = Shared.takeEvent,
	canProcTarget = Shared.canProcTarget,
	registry = Registry,
}

function ProjectileBehaviors.init(p)
	local profile = p.profile
	local functions = profile and profile.initFns
	if not functions then return end
	local data = profile.initData
	for i = 1, #functions do
		local result = functions[i](p, data[i])
		if result then return result end
	end
end

function ProjectileBehaviors.expire(p)
	if not p or p._didExpire then return end
	p._didExpire = true
	local profile = p.profile
	local functions = profile and profile.expireFns
	if not functions then return end
	local data = profile.expireData
	for i = 1, #functions do
		local result = functions[i](p, data[i])
		if result then return result end
	end
end

function ProjectileBehaviors.consume(p)
	ProjectileBehaviors.expire(p)
	return "consume"
end

function ProjectileBehaviors.update(p, dt)
	local profile = p.profile
	local functions = profile and profile.updateFns
	if not functions then return end
	local data = profile.updateData
	for i = 1, #functions do
		local result = functions[i](p, dt, data[i])
		if result == "consume" then return ProjectileBehaviors.consume(p) end
		if result then return result end
	end
end

function ProjectileBehaviors.hit(p, enemy, ctx)
	ctx = ctx or p._defaultHitCtx or { origin = p.hitOrigin or "primary" }
	local oldX, oldY = p.x, p.y
	if ctx.hitX and ctx.hitY then p.x, p.y = ctx.hitX, ctx.hitY end
	local profile = p.profile
	local functions = profile and profile.hitFns
	local shouldConsume = false
	if functions then
		local data = profile.hitData
		for i = 1, #functions do
			if functions[i](p, enemy, data[i], ctx) == "consume" then shouldConsume = true end
		end
	end
	p.x, p.y = oldX, oldY
	if shouldConsume then return ProjectileBehaviors.consume(p) end
end

function ProjectileBehaviors.draw(p, alpha)
	local profile = p.profile
	local functions = profile and profile.drawFns
	if not functions then return end
	local data = profile.drawData
	for i = 1, #functions do
		local result = functions[i](p, alpha, data[i])
		if result then return result end
	end
end

return ProjectileBehaviors

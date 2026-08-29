local SimulationClock = require("core.simulation_clock")

local Shared = {
	graphics = love.graphics,
	random = love.math.random,
	sin = math.sin, cos = math.cos, min = math.min, max = math.max,
	sqrt = math.sqrt, pi = math.pi,
	fixedStep = SimulationClock.step,
}

function Shared.acquire(pool, factory)
	local object = pool[#pool]
	if object then pool[#pool] = nil; return object end
	return factory and factory() or {}
end

function Shared.reserve(pool, count, factory)
	for _ = 1, count do pool[#pool + 1] = factory() end
end

function Shared.clear(object, fields)
	for i = 1, #fields do object[fields[i]] = nil end
end

function Shared.integrate(object, dt)
	object.x = object.x + object.vx * dt
	object.y = object.y + object.vy * dt
end

function Shared.drag(object, dt, multiplier)
	Shared.integrate(object, dt)
	object.vx = object.vx * multiplier
	object.vy = object.vy * multiplier
end

function Shared.family(name, capacity, factory, fields)
	local record = {name = name, list = {}, pool = {}, capacity = capacity, factory = factory or function() return {} end}
	record.reserve = Shared.reserve
	function record.release(object)
		Shared.clear(object, fields)
		record.pool[#record.pool + 1] = object
	end
	record.reset = record.release
	return record
end

return Shared

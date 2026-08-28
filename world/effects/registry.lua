local Registry = {}
Registry.__index = Registry

local function swapRemove(list, index)
	local last = #list
	list[index] = list[last]
	list[last] = nil
end

function Registry.new(families, graphics)
	local self = setmetatable({families = families, graphics = graphics}, Registry)
	local dispatch = {}
	for i = 1, #families do
		local family = families[i]
		for id, handler in pairs(family.ids or {}) do dispatch[id] = handler end
	end
	self.spawnFX = function(fx)
		if not fx or not fx.id then return end
		local handler = dispatch[fx.id]
		if handler then handler(fx) end
	end
	return self
end

function Registry:load()
	for i = 1, #self.families do
		local family = self.families[i]
		if family.capacity and family.capacity > 0 then
			family.reserve(family.pool, family.capacity, family.factory)
		end
	end
end

function Registry:update(dt)
	local frameExponent = dt * 60
	local drag96, drag92 = 0.96 ^ frameExponent, 0.92 ^ frameExponent
	for f = 1, #self.families do
		local family, list = self.families[f], self.families[f].list
		for i = #list, 1, -1 do
			local object = list[i]
			object.t = object.t + dt
			if family.update then family.update(object, dt, frameExponent, drag96, drag92) end
			if object.t >= object.life then
				swapRemove(list, i)
				family.release(object)
			end
		end
	end
end

function Registry:draw()
	for i = 1, #self.families do self.families[i].draw(self.families[i].list) end
	self.graphics.setLineWidth(1)
end

function Registry:drawOverlay()
	for i = 1, #self.families do
		local family = self.families[i]
		if family.drawOverlay then family.drawOverlay(family.list) end
	end
end

function Registry:clear()
	for f = 1, #self.families do
		local family, list = self.families[f], self.families[f].list
		for i = #list, 1, -1 do
			local object = list[i]
			list[i] = nil
			family.release(object)
		end
	end
end

return Registry

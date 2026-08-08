-- Mutable projectile behavior context used while tower modules are applied.
-- Keeping behavior manipulation here gives module definitions one small API and
-- keeps the module inventory system independent from projectile internals.
local BehaviorContext = {}

local roles = {
	move_homing = "movement",
	move_linear = "movement",
	move_boomerang = "movement",
	move_wave = "movement",
	move_spiral = "movement",
	move_orbit = "movement",
	move_suspend = "movement",
	hit_circle = "hit",
	hit_line = "hit",
	instant_hit = "hit",
	emit_on_target = "hit",
	hit_damage = "damage",
	aoe_damage = "damage",
	tick_damage = "damage",
	hit_chain = "damage",
	chain_zap_fx = "impact_fx",
	lancer_hit_fx = "impact_fx",
}

local function getRole(id)
	if id and id:sub(1, 5) == "draw_" then
		return "draw"
	end

	return roles[id]
end

local function cloneBehavior(behavior)
	local copy = { id = behavior.id }

	if behavior.data and next(behavior.data) ~= nil then
		copy.data = {}
		for key, value in pairs(behavior.data) do
			copy.data[key] = value
		end
	end

	if behavior.hooks then
		copy.hooks = {}
		for i = 1, #behavior.hooks do
			copy.hooks[i] = behavior.hooks[i]
		end
	end

	return copy
end

local function cloneBehaviors(behaviors)
	local copies = {}
	for i = 1, #behaviors do
		copies[i] = cloneBehavior(behaviors[i])
	end
	return copies
end

local Context = {}
Context.__index = Context

function Context:addBehavior(behavior)
	self.behaviors[#self.behaviors + 1] = behavior
end

function Context:replaceBehavior(id, replacement)
	for i = 1, #self.behaviors do
		if self.behaviors[i].id == id then
			self.behaviors[i] = replacement
			return true
		end
	end
	return false
end

function Context:modifyBehavior(id, fn)
	for i = 1, #self.behaviors do
		local behavior = self.behaviors[i]
		if behavior.id == id then
			behavior.data = behavior.data or {}
			fn(behavior.data, behavior)
			return true
		end
	end
	return false
end

function Context:replaceBehaviorByRole(role, replacement)
	for i = 1, #self.behaviors do
		if getRole(self.behaviors[i].id) == role then
			self.behaviors[i] = replacement
			return true
		end
	end
	return false
end

function Context:setTargetMode(mode)
	self.targetMode = mode
end

function Context:getBehaviorRole(id)
	return getRole(id)
end

function Context:removeByType(role)
	for i = #self.behaviors, 1, -1 do
		if getRole(self.behaviors[i].id) == role then
			table.remove(self.behaviors, i)
		end
	end
end

function Context:restoreRequiredBehaviors(base)
	local missing = {}
	for i = 1, #base do
		local role = getRole(base[i].id)
		if role then
			missing[role] = missing[role] or base[i]
		end
	end

	for i = 1, #self.behaviors do
		local role = getRole(self.behaviors[i].id)
		if role then
			missing[role] = nil
		end
	end

	for _, behavior in pairs(missing) do
		self:addBehavior(cloneBehavior(behavior))
	end
end

function BehaviorContext.new(base)
	return setmetatable({
		behaviors = cloneBehaviors(base),
		output = "projectile",
	}, Context)
end

return BehaviorContext

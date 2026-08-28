-- Mutable projectile behavior context used while tower modules are applied.
-- Keeping behavior manipulation here gives module definitions one small API and
-- keeps the module inventory system independent from projectile internals.
local BehaviorContext = {}

local ProjectileBehaviorRegistry = require("world.projectile_behaviors.registry")

local function getRole(id)
	return ProjectileBehaviorRegistry.getRole(id)
end

-- Cloning contract: a behavior is a plain descriptor table. Every table-valued
-- field (including open-ended metadata, hooks, and data) is recursively copied
-- to arbitrary depth. Shared references and cycles inside one descriptor remain
-- shared/cyclic in its clone, but no cloned table is shared with the source.
-- Scalar values and functions (including hook functions) are retained. Table
-- keys and metatables are not cloned; behavior descriptors must not rely on
-- mutable table keys or metatable state.
local function cloneTable(source, seen)
	local existing = seen[source]
	if existing then
		return existing
	end

	local copy = {}
	seen[source] = copy
	for key, value in pairs(source) do
		if type(value) == "table" then
			copy[key] = cloneTable(value, seen)
		else
			copy[key] = value
		end
	end
	return copy
end

local function cloneBehavior(behavior)
	assert(type(behavior) == "table", "behavior must be a table")
	return cloneTable(behavior, {})
end

local function cloneBehaviors(behaviors)
	local copies = {}
	for i = 1, #behaviors do
		copies[i] = cloneBehavior(behaviors[i])
	end
	return copies
end

BehaviorContext.cloneBehavior = cloneBehavior
BehaviorContext.cloneBehaviors = cloneBehaviors
BehaviorContext.getBehaviorRole = getRole

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

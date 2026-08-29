-- Mutable projectile behavior context used while tower modules are applied.
-- Keeping behavior manipulation here gives module definitions one small API and
-- keeps the module inventory system independent from projectile internals.
local BehaviorContext = {}

local ProjectileBehaviorRegistry = require("world.projectile_behaviors.registry")
local Util = require("core.util")

local function getRole(id)
	return ProjectileBehaviorRegistry.getRole(id)
end

-- Cloning contract: a behavior is a plain descriptor table. Every table-valued
-- field (including open-ended metadata, hooks, and data) is recursively copied
-- to arbitrary depth. Shared references and cycles inside one descriptor remain
-- shared/cyclic in its clone, but no cloned table is shared with the source.
-- Scalar values and functions (including hook functions) are retained. The
-- shared clone primitive retains table keys and discards metatables; behavior
-- descriptors must not rely on mutable table keys or metatable state.

local function cloneBehavior(behavior)
	assert(type(behavior) == "table", "behavior must be a table")
	return Util.deepCloneGraph(behavior)
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
	local count = #self.behaviors
	local writeIndex = 1
	for readIndex = 1, count do
		local behavior = self.behaviors[readIndex]
		if getRole(behavior.id) ~= role then
			self.behaviors[writeIndex] = behavior
			writeIndex = writeIndex + 1
		end
	end

	for i = writeIndex, count do
		self.behaviors[i] = nil
	end
end

function Context:restoreRequiredBehaviors(base)
	local present = {}
	for i = 1, #self.behaviors do
		local role = getRole(self.behaviors[i].id)
		if role then
			present[role] = true
		end
	end

	for i = 1, #base do
		local behavior = base[i]
		local role = getRole(behavior.id)
		if role and not present[role] then
			self:addBehavior(cloneBehavior(behavior))
			present[role] = true
		end
	end
end

function BehaviorContext.new(base)
	return setmetatable({
		behaviors = cloneBehaviors(base),
		output = "projectile",
	}, Context)
end

return BehaviorContext

local ProjectileBehaviorRegistry = require("world.projectile_behaviors.registry")
local BehaviorContext = require("systems.behavior_context")

local cloneBehavior = BehaviorContext.cloneBehavior
local cloneBehaviors = BehaviorContext.cloneBehaviors
local towerKinds = { "slow", "lancer", "poison", "cannon", "shock", "plasma" }

local function appendUnique(list, value)
	for i = 1, #list do
		if list[i] == value then return end
	end
	list[#list + 1] = value
end

local function inferTowerKind(id)
	for i = 1, #towerKinds do
		local kind = towerKinds[i]
		if id == kind or id:sub(1, #kind + 1) == kind .. "_" then return kind end
	end
end

local function normalizeMetadata(id, def)
	def.id = id
	def.slot = def.slot or def.category or "utility"
	def.tags = def.tags or {}
	appendUnique(def.tags, def.category or def.slot)
	if def.category == "movement" then
		def.exclusiveGroup = def.exclusiveGroup or "movement_conversion"
		def.conflictsWith = def.conflictsWith or { "output_conversion" }
		appendUnique(def.tags, "movement")
	elseif id == "beam_conversion" then
		def.slot = "output"
		def.exclusiveGroup = def.exclusiveGroup or "output_conversion"
		def.conflictsWith = def.conflictsWith or { "movement_conversion" }
		appendUnique(def.tags, "beam")
		appendUnique(def.tags, "output")
	elseif def.behaviors then
		def.slot = "identity"
		def.exclusiveGroup = def.exclusiveGroup or "tower_identity"
		def.requiresTowerKind = def.requiresTowerKind or inferTowerKind(id)
		appendUnique(def.tags, "tower_identity")
	end
	if not def.stackLimit then def.stackLimit = def.exclusiveGroup and 1 or nil end
end

local function copyBehaviorFields(target, source)
	local copy = cloneBehavior(source)
	for key in pairs(target) do target[key] = nil end
	for key, value in pairs(copy) do target[key] = value end
end

local Catalog = {}
Catalog.__index = Catalog
function Catalog:add(id, def)
	assert(type(id) == "string" and id ~= "", "module id must be a non-empty string")
	assert(self.registry[id] == nil, "duplicate module id: " .. id)
	normalizeMetadata(id, def)
	self.registry[id] = def
end

function Catalog:addSpecialization(id, nameKey, descKey, behaviors, towerStats)
	local operations = {}
	for i = 1, #behaviors do
		local behavior = cloneBehavior(behaviors[i])
		operations[#operations + 1] = { op = "addOrModify", behavior = behavior, role = ProjectileBehaviorRegistry.getRole(behavior.id) }
	end
	self:add(id, {
		nameKey = nameKey, descKey = descKey, category = "special", slot = "identity",
		tags = { "tower_identity" }, exclusiveGroup = "tower_identity", stackLimit = 1,
		requiresTowerKind = inferTowerKind(id), behaviors = cloneBehaviors(behaviors),
		branchOps = operations, towerStats = towerStats,
		apply = function(ctx)
			for i = 1, #operations do
				local op = operations[i]
				local updated = ctx:modifyBehavior(op.behavior.id, function(data, behavior)
					copyBehaviorFields(behavior, op.behavior)
				end)
				if not updated and op.role then updated = ctx:replaceBehaviorByRole(op.role, cloneBehavior(op.behavior)) end
				if not updated then ctx:addBehavior(cloneBehavior(op.behavior)) end
			end
		end,
	})
end

return {
	newCatalog = function(registry) return setmetatable({ registry = registry }, Catalog) end,
	normalizeMetadata = normalizeMetadata,
	cloneBehavior = cloneBehavior,
	cloneBehaviors = cloneBehaviors,
	inferTowerKind = inferTowerKind,
}

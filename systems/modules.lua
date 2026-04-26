local ModuleDefs = require("systems.module_defs")
local TowerBranchDefs = require("world.tower_branch_defs")

local Modules = {}

Modules.active = {
	global = {},
	slow = {},
	lancer = {},
	poison = {},
	cannon = {},
	shock = {},
	plasma = {},
}

Modules.version = 0


-- CORE
function Modules.clear()
	for k in pairs(Modules.active) do
		Modules.active[k] = {}
	end

	Modules.version = Modules.version + 1
end

function Modules.add(moduleId, towerType)
	local mod = ModuleDefs[moduleId]
	if not mod then return end

	local list = Modules.active[towerType]
	if not list then return end

	list[#list + 1] = mod
	Modules.version = Modules.version + 1
end

-- CONTEXT BUILDER
local function copyBehaviors(list)
	local out = {}

	for i = 1, #list do
		local b = list[i]

		local copy = {
			id = b.id
		}

		if b.data and next(b.data) ~= nil then
			local d = {}
			for k, v in pairs(b.data) do
				d[k] = v
			end
			copy.data = d
		end

		out[#out + 1] = copy
	end

	return out
end

local ContextMethods = {}

function ContextMethods:addBehavior(b)
	self.behaviors[#self.behaviors + 1] = b
end

function ContextMethods:replaceBehavior(id, newB)
	for i = 1, #self.behaviors do
		if self.behaviors[i].id == id then
			self.behaviors[i] = newB
		end
	end
end

function ContextMethods:modifyBehavior(id, fn)
	for i = 1, #self.behaviors do
		local b = self.behaviors[i]
		if b.id == id then
			b.data = b.data or {}
			fn(b.data)
		end
	end
end

function ContextMethods:removeBehavior(id)
	local write = 1
	local behaviors = self.behaviors

	for read = 1, #behaviors do
		local behavior = behaviors[read]

		if behavior.id ~= id then
			behaviors[write] = behavior
			write = write + 1
		end
	end

	for i = #behaviors, write, -1 do
		behaviors[i] = nil
	end
end

function ContextMethods:forEachBehavior(fn)
	for i = 1, #self.behaviors do
		fn(self.behaviors[i])
	end
end

function ContextMethods:removeByType(typeName)
	local write = 1
	local behaviors = self.behaviors

	for read = 1, #behaviors do
		local behavior = behaviors[read]

		if behavior.type ~= typeName then
			behaviors[write] = behavior
			write = write + 1
		end
	end

	for i = #behaviors, write, -1 do
		behaviors[i] = nil
	end
end

local ContextMetatable = { __index = ContextMethods }

local function createContext(base)
	local ctx = {
		behaviors = copyBehaviors(base),
		output = "projectile",
	}

	return setmetatable(ctx, ContextMetatable)
end

function Modules.buildContext(tower)
	if tower then
		local cached = tower._moduleContextCache
		local cacheVersion = tower._moduleContextVersion

		if cached and cacheVersion == Modules.version then
			return cached
		end
	end

	local base = tower.def.behaviors
	local ctx = createContext(base)

	-- global modules
	local global = Modules.active.global
	for i = 1, #global do
		global[i].apply(ctx)
	end

	-- tower modules
	local list = Modules.active[tower.kind]
	if list then
		for i = 1, #list do
			list[i].apply(ctx)
		end
	end

	-- tower branch modules (selected through upgrade tiers)
	local branchSelections = tower and tower.branchSelections
	if branchSelections then
		for i = 1, #branchSelections do
			local moduleId = branchSelections[i]
			local branchMod = ModuleDefs[moduleId]
			if branchMod and branchMod.apply then
				branchMod.apply(ctx)
			end
		end
	elseif tower and tower.specializationId then
		-- backward compatibility for older saves
		local specialization = ModuleDefs[tower.specializationId]
		if specialization and specialization.apply then
			specialization.apply(ctx)
		end
	end

	-- =========================================
	-- 🔥 BEAM FIX: ensure hit_damage exists
	-- =========================================
	if ctx.output == "beam" then
		local hasDamage = false

		for i = 1, #ctx.behaviors do
			if ctx.behaviors[i].id == "hit_damage" then
				hasDamage = true
				break
			end
		end

		if not hasDamage then
			ctx:addBehavior({ id = "hit_damage" })
		end
	end

	if tower then
		tower._moduleContextCache = ctx
		tower._moduleContextVersion = Modules.version
	end

	return ctx
end

function Modules.getDef(moduleId)
	return ModuleDefs[moduleId]
end

function Modules.getActive()
	return Modules.active
end

function Modules.getTargetMode(towerOrKind)
	local towerKind = towerOrKind
	local branchSelections = nil
	local legacySpecializationId = nil

	if type(towerOrKind) == "table" then
		towerKind = towerOrKind.kind
		branchSelections = towerOrKind.branchSelections
		legacySpecializationId = towerOrKind.specializationId
	end

	local mode = nil

	local global = Modules.active.global
	for i = 1, #global do
		local mod = global[i]
		if mod and mod.targetMode then
			mode = mod.targetMode
		end
	end

	local towerList = Modules.active[towerKind]
	if towerList then
		for i = 1, #towerList do
			local mod = towerList[i]
			if mod and mod.targetMode then
				mode = mod.targetMode
			end
		end
	end

	if branchSelections then
		for i = 1, #branchSelections do
			local mod = ModuleDefs[branchSelections[i]]
			if mod and mod.targetMode then
				mode = mod.targetMode
			end
		end
	elseif legacySpecializationId then
		local mod = ModuleDefs[legacySpecializationId]
		if mod and mod.targetMode then
			mode = mod.targetMode
		end
	end

	return mode
end

function Modules.rollTowerUpgradeChoices(tower)
	if not tower or not tower.kind then
		return {}
	end

	local nextLevel = (tower.level or 1) + 1
	local branchChoices = TowerBranchDefs.getChoices(tower.kind, nextLevel)

	if not branchChoices then
		return {}
	end

	local out = {}

	for i = 1, #branchChoices do
		local moduleId = branchChoices[i]
		if ModuleDefs[moduleId] then
			out[#out + 1] = {
				moduleId = moduleId,
				target = tower.kind,
			}
		end
	end

	return out
end

return Modules

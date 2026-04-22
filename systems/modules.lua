local Constants = require("core.constants")
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

		if b.data then
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

local function createContext(base)
	local ctx = {}

	ctx.behaviors = copyBehaviors(base)
	ctx.output = "projectile"

	function ctx:addBehavior(b)
		self.behaviors[#self.behaviors + 1] = b
	end

	function ctx:replaceBehavior(id, newB)
		for i = 1, #self.behaviors do
			if self.behaviors[i].id == id then
				self.behaviors[i] = newB
			end
		end
	end

	function ctx:modifyBehavior(id, fn)
		for i = 1, #self.behaviors do
			local b = self.behaviors[i]
			if b.id == id then
				b.data = b.data or {}
				fn(b.data)
			end
		end
	end

	function ctx:removeBehavior(id)
		for i = #self.behaviors, 1, -1 do
			if self.behaviors[i].id == id then
				table.remove(self.behaviors, i)
			end
		end
	end

	function ctx:forEachBehavior(fn)
		for i = 1, #self.behaviors do
			fn(self.behaviors[i])
		end
	end

	function ctx:removeByType(typeName)
		for i = #self.behaviors, 1, -1 do
			if self.behaviors[i].type == typeName then
				table.remove(self.behaviors, i)
			end
		end
	end

	return ctx
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

-- =========================
-- RANDOM SELECTION
-- =========================

local allIds = {}
for id in pairs(ModuleDefs) do
	allIds[#allIds + 1] = id
end

local towerTypes = Constants.TOWER_LIST

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

	local function pickMode(list)
		for i = 1, #list do
			local mod = list[i]
			if mod and mod.targetMode then
				mode = mod.targetMode
			end
		end
	end

	pickMode(Modules.active.global)

	local towerList = Modules.active[towerKind]
	if towerList then
		pickMode(towerList)
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

function Modules.rollChoices(count)
	local totalCombinations = #allIds * #towerTypes
	if totalCombinations == 0 then
		return {}
	end

	count = math.floor(count or 0)
	if count <= 0 then
		return {}
	end

	if count > totalCombinations then
		count = totalCombinations
	end

	local combinations = {}

	for i = 1, #allIds do
		local moduleId = allIds[i]
		for j = 1, #towerTypes do
			combinations[#combinations + 1] = {
				moduleId = moduleId,
				target = towerTypes[j],
			}
		end
	end

	for i = #combinations, 2, -1 do
		local j = love.math.random(1, i)
		combinations[i], combinations[j] = combinations[j], combinations[i]
	end

	local choices = {}
	for i = 1, count do
		choices[i] = combinations[i]
	end

	return choices
end

return Modules

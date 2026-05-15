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

local function bumpTowerCacheState(tower)
	if not tower then
		return nil
	end

	tower._cacheVersion = (tower._cacheVersion or 0) + 1
	tower._cache = tower._cache or {}

	return tower._cache
end


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

function Modules.invalidateTower(tower)
	local cache = bumpTowerCacheState(tower)
	if not cache then
		return
	end

	cache.moduleContext = nil
	cache.fireProfile = nil
	cache.targetMode = nil
	tower._fireProfileLocalVersion = (tower._fireProfileLocalVersion or 0) + 1
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

		if b.hooks then
			local hooks = {}
			for j = 1, #b.hooks do
				hooks[j] = b.hooks[j]
			end
			copy.hooks = hooks
		end

		out[#out + 1] = copy
	end

	return out
end

local function rebuildBehaviorIndex(ctx)
	local index = {}
	local behaviors = ctx.behaviors

	for i = 1, #behaviors do
		local id = behaviors[i].id
		if id and index[id] == nil then
			index[id] = i
		end
	end

	ctx._behaviorIndex = index
end

local ContextMethods = {}

local function mutateBehaviors(ctx, mutator)
	local shouldRebuild = mutator(ctx.behaviors)

	if shouldRebuild then
		rebuildBehaviorIndex(ctx)
	end
end

local function swapRemove(list, i)
	local last = #list
	if i < last then
		list[i] = list[last]
	end
	list[last] = nil
end

function ContextMethods:addBehavior(b)
	self.behaviors[#self.behaviors + 1] = b

	-- Append keeps all existing indexes stable; maintain incrementally.
	if b and b.id and self._behaviorIndex[b.id] == nil then
		self._behaviorIndex[b.id] = #self.behaviors
	end
end

function ContextMethods:addHookBehavior(hookId, behavior)
	if not behavior then
		return
	end

	local b = behavior
	if not b.hooks then
		b.hooks = { hookId }
	end

	self.behaviors[#self.behaviors + 1] = b

	-- Append keeps all existing indexes stable; maintain incrementally.
	if b.id and self._behaviorIndex[b.id] == nil then
		self._behaviorIndex[b.id] = #self.behaviors
	end
end

function ContextMethods:replaceBehavior(id, newB)
	local i = self._behaviorIndex[id]
	if not i then
		return
	end

	-- Replacement can change ids and first-occurrence mappings; rebuild once.
	mutateBehaviors(self, function(behaviors)
		behaviors[i] = newB
		return true
	end)
end

function ContextMethods:modifyBehavior(id, fn)
	local i = self._behaviorIndex[id]
	if not i then
		return
	end

	local behavior = self.behaviors[i]
	behavior.data = behavior.data or {}
	fn(behavior.data)
end

function ContextMethods:removeBehavior(id)
	local i = self._behaviorIndex[id]
	if not i then
		return
	end

	-- Order is not semantically required for single-id removals; swap-remove avoids shifting.
	mutateBehaviors(self, function(behaviors)
		swapRemove(behaviors, i)
		return true
	end)
end

function ContextMethods:forEachBehavior(fn)
	for i = 1, #self.behaviors do
		fn(self.behaviors[i])
	end
end

function ContextMethods:removeByType(typeName)
	-- Preserve hook execution order with in-place compaction; rebuild once afterward.
	mutateBehaviors(self, function(behaviors)
		local write = 1
		local removed = 0

		for read = 1, #behaviors do
			local behavior = behaviors[read]
			if behavior.type == typeName then
				removed = removed + 1
			else
				behaviors[write] = behavior
				write = write + 1
			end
		end

		if removed == 0 then
			return false
		end

		for i = write, #behaviors do
			behaviors[i] = nil
		end

		return true
	end)
end

local ContextMetatable = { __index = ContextMethods }


local function applyTowerUpgradeBehaviorScaling(ctx, tower)
	if not tower or not tower.def then
		return
	end

	local upgrade = tower.def.upgrade or {}
	local level = math.max(1, tower.level or 1)
	local upgrades = math.max(0, level - 1)
	if upgrades <= 0 then
		return
	end

	local poisonDurAdd = upgrade.poisonDurAdd or 0
	local poisonDpsMult = upgrade.poisonDpsMult or 1
	local stackAdd = upgrade.stackAdd or 0
	local splashAdd = upgrade.splashAdd or 0

	for i = 1, #ctx.behaviors do
		local b = ctx.behaviors[i]
		local data = b.data
		if data then
			if b.id == "apply_poison" then
				if poisonDurAdd ~= 0 then
					data.dur = (data.dur or 0) + poisonDurAdd * upgrades
				end
				if poisonDpsMult ~= 1 then
					data.dps = (data.dps or 0) * (poisonDpsMult ^ upgrades)
				end
				if stackAdd ~= 0 then
					data.maxStacks = math.max(1, (data.maxStacks or 1) + stackAdd * upgrades)
				end
			elseif b.id == "aoe_damage" and splashAdd ~= 0 then
				data.radius = math.max(1, (data.radius or 1) + splashAdd * upgrades)
			end
		end
	end
end
local function createContext(base)
	local ctx = {
		behaviors = copyBehaviors(base),
		output = "projectile",
		_behaviorIndex = {},
	}

	rebuildBehaviorIndex(ctx)

	return setmetatable(ctx, ContextMetatable)
end

function Modules.buildContext(tower)
	if tower then
		local cache = tower._cache
		local cached = cache and cache.moduleContext
		local cacheVersion = tower._cacheVersion or 0

		if cached and cached.modulesVersion == Modules.version and cached.cacheVersion == cacheVersion then
			return cached.value
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

	applyTowerUpgradeBehaviorScaling(ctx, tower)

	-- Normalize/validate post-module behavior list in one pass.
	local outputIsBeam = ctx.output == "beam"
	local hasHitDamage = false

	for i = 1, #ctx.behaviors do
		local behavior = ctx.behaviors[i]

		if outputIsBeam and behavior.id == "hit_damage" then
			hasHitDamage = true
		end

		-- Keep additional post-module behavior normalization checks here so
		-- we avoid introducing extra independent scans over ctx.behaviors.
	end

	if outputIsBeam and not hasHitDamage then
		ctx:addBehavior({ id = "hit_damage" })
	end

	if tower then
		tower._cache = tower._cache or {}
		tower._cache.moduleContext = {
			value = ctx,
			modulesVersion = Modules.version,
			cacheVersion = tower._cacheVersion or 0,
		}
	end

	return ctx
end

function Modules.getFireProfile(tower)
	if not tower then
		return nil
	end

	local cache = tower._cache
	local cached = cache and cache.fireProfile
	local version = Modules.version
	local cacheVersion = tower._cacheVersion or 0
	local localVersion = tower._fireProfileLocalVersion or 0

	if cached and cached.modulesVersion == version and cached.cacheVersion == cacheVersion and cached.localVersion == localVersion then
		return cached.profile
	end

	local ctx = Modules.buildContext(tower)
	local profile = {
		output = ctx.output,
		behaviors = ctx.behaviors,
		version = version,
		localVersion = localVersion,
		tag = tostring(version) .. ":" .. tostring(localVersion),
	}

	tower._cache = tower._cache or {}
	tower._cache.fireProfile = {
		profile = profile,
		modulesVersion = version,
		cacheVersion = cacheVersion,
		localVersion = localVersion,
	}

	return profile
end

function Modules.getDef(moduleId)
	return ModuleDefs[moduleId]
end

function Modules.getActive()
	return Modules.active
end

local function applyTargetMode(mode, list, resolver)
	if not list then
		return mode
	end

	for i = 1, #list do
		local mod = resolver(list[i])
		if mod and mod.targetMode then
			mode = mod.targetMode
		end
	end

	return mode
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
	mode = applyTargetMode(mode, Modules.active.global, function(mod)
		return mod
	end)
	mode = applyTargetMode(mode, Modules.active[towerKind], function(mod)
		return mod
	end)
	mode = applyTargetMode(mode, branchSelections, function(id)
		return ModuleDefs[id]
	end)

	if legacySpecializationId and not branchSelections then
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

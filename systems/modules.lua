local ModuleDefs = require("systems.module_defs")
local TowerBranchDefs = require("world.tower_branch_defs")
local State = require("core.state")
local CampaignUnlocks = require("systems.campaign_unlocks")

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


local function getInventory()
	State.moduleInventory = State.moduleInventory or {}

	return State.moduleInventory
end

local function getModule(moduleId)
	local mod = ModuleDefs[moduleId]
	if mod then
		mod.id = mod.id or moduleId
	end

	return mod
end

local function addModuleCandidate(out, moduleId, order, source)
	local mod = getModule(moduleId)
	if mod and mod.apply then
		out[#out + 1] = { id = moduleId, mod = mod, order = order, source = source }
	end
end

local function applyResolvedModules(ctx, candidates)
	local winners = {}
	local skipped = {}

	for i = 1, #candidates do
		local candidate = candidates[i]
		local group = candidate.mod.exclusiveGroup
		if group then
			winners[group] = candidate
		else
			winners[#winners + 1] = candidate
		end
	end

	for i = 1, #candidates do
		local candidate = candidates[i]
		local group = candidate.mod.exclusiveGroup
		if not group or winners[group] == candidate then
			candidate.mod.apply(ctx)
		else
			skipped[#skipped + 1] = { id = candidate.id, replacedBy = winners[group].id, group = group }
		end
	end

	ctx.exclusiveResolutions = skipped
end

local function collectModuleIds(out, moduleIds, source, orderStart)
	local order = orderStart or 0
	if not moduleIds then
		return order
	end

	for i = 1, #moduleIds do
		order = order + 1
		addModuleCandidate(out, moduleIds[i], order, source)
	end

	return order
end

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
	local mod = getModule(moduleId)
	if not mod then return end

	local list = Modules.active[towerType]
	if not list then return end

	list[#list + 1] = mod
	Modules.version = Modules.version + 1
	local Save = require("core.save")
	Save.discoverModule(moduleId)
end

function Modules.getInventory()
	return getInventory()
end

function Modules.addToInventory(moduleId, count)
	local mod = getModule(moduleId)
	if not mod then
		return false, "invalid_module"
	end

	count = count or 1
	if count <= 0 then
		return false, "invalid_count"
	end

	local inventory = getInventory()
	inventory[moduleId] = (inventory[moduleId] or 0) + count
	Modules.version = Modules.version + 1

	local Save = require("core.save")
	Save.discoverModule(moduleId)

	return true
end

function Modules.purchase(moduleId)
	return Modules.addToInventory(moduleId, 1)
end

local function moduleListHasGroup(moduleIds, group)
	if not moduleIds or not group then
		return nil
	end

	for i = 1, #moduleIds do
		local existing = getModule(moduleIds[i])
		if existing and existing.exclusiveGroup == group then
			return moduleIds[i]
		end
	end

	return nil
end

local function moduleListHasConflict(moduleIds, mod)
	if not moduleIds or not mod then
		return nil, nil
	end

	local conflicts = mod.conflictsWith or {}
	for i = 1, #moduleIds do
		local existingId = moduleIds[i]
		local existing = getModule(existingId)
		if existing then
			for j = 1, #conflicts do
				if existing.exclusiveGroup == conflicts[j] then
					return existingId, conflicts[j]
				end
			end
			for j = 1, #(existing.conflictsWith or {}) do
				if mod.exclusiveGroup == existing.conflictsWith[j] then
					return existingId, existing.conflictsWith[j]
				end
			end
		end
	end

	return nil, nil
end

local reasonText = {
	missing_tower = "select a tower first",
	invalid_module = "unknown module",
	not_owned = "not owned",
	incompatible_tower = "wrong tower type",
	requires_tower_kind = "wrong tower type",
	exclusive_group = "replaces existing module",
	stack_limit = "stack limit reached",
	conflicts_with = "cannot combine",
}

function Modules.describeApplyResult(reason, detail)
	if reason == "exclusive_group" and detail and detail.group then
		return "replaces " .. detail.group:gsub("_", " ")
	elseif reason == "conflicts_with" and detail and detail.group then
		return "cannot combine with " .. detail.group:gsub("_", " ")
	end

	return reasonText[reason] or tostring(reason or "unavailable")
end

function Modules.canApplyToTower(moduleId, tower, options)
	options = options or {}
	if not tower or not tower.kind then
		return false, "missing_tower"
	end

	local mod = getModule(moduleId)
	if not mod then
		return false, "invalid_module"
	end

	if not options.ignoreInventory then
		local inventory = getInventory()
		if (inventory[moduleId] or 0) <= 0 then
			return false, "not_owned"
		end
	end

	if mod.target and mod.target ~= "global" and mod.target ~= tower.kind then
		return false, "incompatible_tower"
	end

	if mod.requiresTowerKind and mod.requiresTowerKind ~= tower.kind then
		return false, "requires_tower_kind", { required = mod.requiresTowerKind }
	end

	local appliedModules = tower.appliedModules or {}
	local count = 0
	for i = 1, #appliedModules do
		if appliedModules[i] == moduleId then
			count = count + 1
		end
	end
	if mod.stackLimit and count >= mod.stackLimit then
		return false, "stack_limit", { limit = mod.stackLimit }
	end

	local conflictId, conflictGroup = moduleListHasConflict(appliedModules, mod)
	if conflictId then
		return false, "conflicts_with", { moduleId = conflictId, group = conflictGroup }
	end

	local replacedId = moduleListHasGroup(appliedModules, mod.exclusiveGroup)
	if replacedId and replacedId ~= moduleId then
		return true, "exclusive_group", { moduleId = replacedId, group = mod.exclusiveGroup }
	end

	return true
end

function Modules.getApplyStatus(moduleId, tower, options)
	local ok, reason, detail = Modules.canApplyToTower(moduleId, tower, options)
	return {
		ok = ok,
		reason = reason,
		detail = detail,
		message = reason and Modules.describeApplyResult(reason, detail) or nil,
	}
end

function Modules.applyToTower(moduleId, tower)
	local ok, reason = Modules.canApplyToTower(moduleId, tower)
	if not ok then
		return false, reason
	end

	local inventory = getInventory()
	inventory[moduleId] = inventory[moduleId] - 1
	if inventory[moduleId] <= 0 then
		inventory[moduleId] = nil
	end

	tower.appliedModules = tower.appliedModules or {}
	local mod = getModule(moduleId)
	if mod and mod.exclusiveGroup then
		for i = #tower.appliedModules, 1, -1 do
			local existing = getModule(tower.appliedModules[i])
			if existing and existing.exclusiveGroup == mod.exclusiveGroup and tower.appliedModules[i] ~= moduleId then
				table.remove(tower.appliedModules, i)
			end
		end
	end
	tower.appliedModules[#tower.appliedModules + 1] = moduleId
	Modules.invalidateTower(tower)
	Modules.version = Modules.version + 1

	return true
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

local function applyTargetMode(mode, mod)
	if mod and mod.targetMode and CampaignUnlocks.isTargetingUnlocked(mod.targetMode) then
		return mod.targetMode
	end

	return mode
end

local function applyTargetModeFromModules(modules, mode)
	if not modules then
		return mode
	end

	for i = 1, #modules do
		mode = applyTargetMode(mode, modules[i])
	end

	return mode
end

local function applyTargetModeFromIds(moduleIds, mode)
	if not moduleIds then
		return mode
	end

	for i = 1, #moduleIds do
		mode = applyTargetMode(mode, ModuleDefs[moduleIds[i]])
	end

	return mode
end

local function createContext(base)
	local ctx = {
		behaviors = copyBehaviors(base),
		output = "projectile",
	}

	ctx.addBehavior = function(self, behavior)
		self.behaviors[#self.behaviors + 1] = behavior
	end
	ctx.replaceBehavior = function(self, id, behavior)
		for i = 1, #self.behaviors do
			if self.behaviors[i].id == id then
				self.behaviors[i] = behavior
				return true
			end
		end

		return false
	end
	ctx.modifyBehavior = function(self, id, fn)
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
	ctx.replaceBehaviorByRole = function(self, role, behavior)
		for i = 1, #self.behaviors do
			if self:getBehaviorRole(self.behaviors[i].id) == role then
				self.behaviors[i] = behavior
				return true
			end
		end

		return false
	end
	ctx.setTargetMode = function(self, mode)
		self.targetMode = mode
	end
	ctx.getBehaviorRole = function(self, id)
		if id == "move_homing" or id == "move_linear" or id == "move_boomerang" or id == "move_wave" or id == "move_spiral" or id == "move_orbit" or id == "move_suspend" then
			return "movement"
		end
		if id == "hit_circle" or id == "hit_line" or id == "instant_hit" or id == "emit_on_target" then
			return "hit"
		end
		if id == "hit_damage" or id == "aoe_damage" or id == "tick_damage" or id == "hit_chain" then
			return "damage"
		end
		if id:sub(1, 5) == "draw_" then
			return "draw"
		end
		if id == "chain_zap_fx" or id == "lancer_hit_fx" then
			return "impact_fx"
		end
		return nil
	end
	ctx.removeByType = function(self, typeName)
		for i = #self.behaviors, 1, -1 do
			if self.behaviors[i].type == typeName then
				table.remove(self.behaviors, i)
			end
		end
	end

	return ctx
end

local function validateCoreBehaviors(ctx, base)
	local required = {}

	for i = 1, #base do
		local behavior = base[i]
		local role = ctx:getBehaviorRole(behavior.id)
		if role == "movement" or role == "hit" or role == "damage" or role == "draw" or role == "impact_fx" then
			required[role] = required[role] or behavior
		end
	end

	for i = 1, #ctx.behaviors do
		local role = ctx:getBehaviorRole(ctx.behaviors[i].id)
		if role and required[role] then
			required[role] = nil
		end
	end

	for _, behavior in pairs(required) do
		ctx:addBehavior(copyBehaviors({ behavior })[1])
	end
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

	local candidates = {}
	local order = 0

	-- global modules
	local global = Modules.active.global
	for i = 1, #global do
		order = order + 1
		candidates[#candidates + 1] = { id = global[i].id, mod = global[i], order = order, source = "global" }
	end

	-- tower modules
	local list = Modules.active[tower.kind]
	if list then
		for i = 1, #list do
			order = order + 1
			candidates[#candidates + 1] = { id = list[i].id, mod = list[i], order = order, source = "tower" }
		end
	end

	-- tower-specific inventory modules applied by the player
	order = collectModuleIds(candidates, tower and tower.appliedModules, "applied", order)

	-- tower branch modules (legacy upgrade-tier compatibility path)
	local branchSelections = tower and tower.branchSelections
	if branchSelections then
		collectModuleIds(candidates, branchSelections, "branch", order)
	elseif tower and tower.specializationId then
		-- backward compatibility for older saves
		addModuleCandidate(candidates, tower.specializationId, order + 1, "legacy_specialization")
	end

	applyResolvedModules(ctx, candidates)

	validateCoreBehaviors(ctx, base)
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
	return getModule(moduleId)
end

function Modules.getActive()
	return Modules.active
end

function Modules.getTargetMode(towerOrKind)
	local towerKind = towerOrKind
	local branchSelections = nil
	local appliedModules = nil
	local legacySpecializationId = nil

	if type(towerOrKind) == "table" then
		towerKind = towerOrKind.kind
		branchSelections = towerOrKind.branchSelections
		appliedModules = towerOrKind.appliedModules
		legacySpecializationId = towerOrKind.specializationId
	end

	local mode = nil
	mode = applyTargetModeFromModules(Modules.active.global, mode)
	mode = applyTargetModeFromModules(Modules.active[towerKind], mode)
	mode = applyTargetModeFromIds(appliedModules, mode)
	mode = applyTargetModeFromIds(branchSelections, mode)

	if legacySpecializationId and not branchSelections then
		mode = applyTargetMode(mode, getModule(legacySpecializationId))
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
		local mod = ModuleDefs[moduleId]
		if mod and CampaignUnlocks.isModuleCategoryUnlocked(mod.category or mod.slot) then
			out[#out + 1] = {
				moduleId = moduleId,
				target = tower.kind,
			}
		end
	end

	return out
end

return Modules

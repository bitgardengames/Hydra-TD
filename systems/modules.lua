local ModuleDefs = require("systems.module_defs")
local TowerBranchDefs = require("world.tower_branch_defs")
local State = require("core.state")
local CampaignUnlocks = require("systems.campaign_unlocks")
local BehaviorContext = require("systems.behavior_context")

local Modules = {}

function Modules.isEnabled()
	return State.isReplayMode()
end

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

local function addModuleCandidate(out, moduleId)
	local mod = type(moduleId) == "table" and moduleId or getModule(moduleId)
	if mod and mod.apply then
		out[#out + 1] = { id = mod.id or moduleId, mod = mod }
	end
end

local function resolveModules(candidates, apply)
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
			apply(candidate.mod)
		else
			skipped[#skipped + 1] = { id = candidate.id, replacedBy = winners[group].id, group = group }
		end
	end

	return skipped
end

local function collectModuleIds(out, moduleIds)
	if not moduleIds then
		return
	end

	for i = 1, #moduleIds do
		addModuleCandidate(out, moduleIds[i])
	end
end

-- Keep module precedence in one place. Both behavior construction and targeting
-- consume this list, so they cannot drift into subtly different interpretations
-- of global, tower, applied, branch, and legacy modules.
local function collectTowerModules(towerOrKind)
	local tower = type(towerOrKind) == "table" and towerOrKind or nil
	local towerKind = tower and tower.kind or towerOrKind
	local candidates = {}

	collectModuleIds(candidates, Modules.active.global)
	collectModuleIds(candidates, Modules.active[towerKind])

	if tower then
		collectModuleIds(candidates, tower.appliedModules)
		if tower.branchSelections then
			collectModuleIds(candidates, tower.branchSelections)
		elseif tower.specializationId then
			addModuleCandidate(candidates, tower.specializationId)
		end
	end

	return candidates
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
	if not Modules.isEnabled() then return false, "campaign_disabled" end
	local mod = getModule(moduleId)
	if not mod then return false, "invalid_module" end

	local list = Modules.active[towerType]
	if not list then return false, "invalid_target" end

	list[#list + 1] = mod
	Modules.version = Modules.version + 1
	local Save = require("core.save")
	Save.discoverModule(moduleId)
	return true
end

function Modules.getInventory()
	if not Modules.isEnabled() then
		return {}
	end
	return getInventory()
end

function Modules.addToInventory(moduleId, count)
	if not Modules.isEnabled() then
		return false, "campaign_disabled"
	end
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

local function toSet(values)
	local set = {}
	for i = 1, #(values or {}) do
		set[values[i]] = true
	end
	return set
end

local function contains(values, value)
	if value == nil then return false end
	for i = 1, #(values or {}) do
		if values[i] == value then return true end
	end
	return false
end

-- Inventory validation used to walk the tower's modules separately for stack
-- limits, replacements, and both directions of conflicts. Build that complete
-- picture in one pass instead; this keeps all compatibility rules together and
-- makes adding another validation independent of the size of the module list.
local function inspectAppliedModules(moduleIds, moduleId, mod)
	local result = { count = 0 }
	local conflicts = toSet(mod.conflictsWith)

	for i = 1, #(moduleIds or {}) do
		local existingId = moduleIds[i]
		local existing = getModule(existingId)

		if existingId == moduleId then
			result.count = result.count + 1
		end
		if existing then
			local group = existing.exclusiveGroup
			if mod.exclusiveGroup and group == mod.exclusiveGroup then
				result.replacedId = existingId
			end
			if not result.conflictId and conflicts[group] then
				result.conflictId, result.conflictGroup = existingId, group
			elseif not result.conflictId then
				if contains(existing.conflictsWith, mod.exclusiveGroup) then
					result.conflictId, result.conflictGroup = existingId, mod.exclusiveGroup
				end
			end
		end
	end

	return result
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
	if not Modules.isEnabled() then
		return false, "campaign_disabled"
	end
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
	local applied = inspectAppliedModules(appliedModules, moduleId, mod)
	if mod.stackLimit and applied.count >= mod.stackLimit then
		return false, "stack_limit", { limit = mod.stackLimit }
	end

	if applied.conflictId then
		return false, "conflicts_with", { moduleId = applied.conflictId, group = applied.conflictGroup }
	end

	if applied.replacedId and applied.replacedId ~= moduleId then
		return true, "exclusive_group", { moduleId = applied.replacedId, group = mod.exclusiveGroup }
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

	local slowDurAdd = upgrade.slowDurAdd or 0
	local poisonDurAdd = upgrade.poisonDurAdd or 0
	local poisonDpsMult = upgrade.poisonDpsMult or 1
	local stackAdd = upgrade.stackAdd or 0
	local splashAdd = upgrade.splashAdd or 0

	for i = 1, #ctx.behaviors do
		local b = ctx.behaviors[i]
		local data = b.data
		if data then
			if b.id == "apply_slow" and slowDurAdd ~= 0 then
				data.dur = (data.dur or 0) + slowDurAdd * upgrades
			elseif b.id == "apply_poison" then
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

function Modules.buildContext(tower)
	local experimental = Modules.isEnabled()
	if tower then
		local cache = tower._cache
		local cached = cache and cache.moduleContext
		local cacheVersion = tower._cacheVersion or 0

		if cached and cached.modulesVersion == Modules.version and cached.cacheVersion == cacheVersion and cached.experimental == experimental then
			return cached.value
		end
	end

	local base = tower.def.behaviors
	local ctx = BehaviorContext.new(base)

	local candidates = experimental and collectTowerModules(tower) or {}
	ctx.exclusiveResolutions = resolveModules(candidates, function(mod)
		mod.apply(ctx)
	end)

	ctx:restoreRequiredBehaviors(base)
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
			experimental = experimental,
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
	if not Modules.isEnabled() then
		return nil
	end

	local mode = nil
	resolveModules(collectTowerModules(towerOrKind), function(mod)
		if mod.targetMode and CampaignUnlocks.isTargetingUnlocked(mod.targetMode) then
			mode = mod.targetMode
		end
	end)

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

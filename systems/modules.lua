local Constants = require("core.constants")
local ModuleDefs = require("systems.module_defs")

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


-- CORE
function Modules.clear()
	for k in pairs(Modules.active) do
		Modules.active[k] = {}
	end
end

function Modules.add(moduleId, towerType)
	local mod = ModuleDefs[moduleId]
	if not mod then return end

	local list = Modules.active[towerType]
	if not list then return end

	list[#list + 1] = mod
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
	local base = tower.def.behaviors
	local ctx = createContext(base)

	-- global first
	local global = Modules.active.global
	for i = 1, #global do
		global[i].apply(ctx)
	end

	-- tower specific
	local list = Modules.active[tower.kind]
	if list then
		for i = 1, #list do
			list[i].apply(ctx)
		end
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

local function rand(list)
	return list[love.math.random(1, #list)]
end

function Modules.rollChoices(count)
	local choices = {}

	for i = 1, count do
		local id = rand(allIds)
		local target = rand(towerTypes)

		choices[#choices + 1] = {
			moduleId = id,
			target = target
		}
	end

	return choices
end

return Modules
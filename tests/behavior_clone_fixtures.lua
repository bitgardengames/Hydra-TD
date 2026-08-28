-- Canonical behavior cloning contract fixtures. Run from the repository root.
package.path = "./?.lua;./?/init.lua;" .. package.path

local BehaviorContext = require("systems.behavior_context")

local hook = function() end
local shared = { threshold = { min = 2 } }
local source = {
	id = "hit_damage",
	noInherit = true,
	hooks = { "on_hit", hook },
	metadata = { category = "fixture", nested = shared },
	data = {
		amount = 5,
		nested = { first = { second = { value = 9 } } },
		shared = shared,
	},
}

local function verifyCopy(copy, label)
	assert(copy ~= source, label .. " reused the behavior table")
	assert(copy.id == source.id and copy.noInherit == true, label .. " lost metadata")
	assert(copy.hooks ~= source.hooks and copy.hooks[1] == "on_hit", label .. " did not clone hooks")
	assert(copy.hooks[2] == hook, label .. " did not retain a hook function")
	assert(copy.data ~= source.data, label .. " reused data")
	assert(copy.data.nested.first.second.value == 9, label .. " lost deeply nested data")
	assert(copy.data.nested.first ~= source.data.nested.first, label .. " shallow-copied nested data")
	assert(copy.metadata ~= source.metadata, label .. " reused table-valued metadata")
	assert(copy.metadata.nested == copy.data.shared, label .. " did not preserve internal shared references")

	copy.hooks[1] = "on_tick"
	copy.metadata.nested.threshold.min = 99
	copy.data.nested.first.second.value = 42
	assert(source.hooks[1] == "on_hit", label .. " mutation changed source hooks")
	assert(source.metadata.nested.threshold.min == 2, label .. " mutation changed source metadata")
	assert(source.data.nested.first.second.value == 9, label .. " mutation changed source data")
end

verifyCopy(BehaviorContext.cloneBehavior(source), "cloneBehavior")

local listCopy = BehaviorContext.cloneBehaviors({ source })
assert(listCopy[1] ~= source, "cloneBehaviors reused a source behavior")
verifyCopy(listCopy[1], "cloneBehaviors")

local context = BehaviorContext.new({ source })
verifyCopy(context.behaviors[1], "BehaviorContext.new")

local emptyContext = BehaviorContext.new({})
emptyContext:restoreRequiredBehaviors({ source })
verifyCopy(emptyContext.behaviors[1], "restoreRequiredBehaviors")

local orderedContext = BehaviorContext.new({ { id = "cannon_long_fuse" } })
orderedContext:restoreRequiredBehaviors({
	{ id = "hit_damage", data = { order = "damage" } },
	{ id = "move_linear", data = { order = "movement" } },
	{ id = "aoe_damage", data = { order = "duplicate damage role" } },
	{ id = "hit_circle", data = { order = "collision" } },
})
assert(#orderedContext.behaviors == 4, "restoreRequiredBehaviors did not retain one behavior per role")
assert(orderedContext.behaviors[1].id == "cannon_long_fuse", "restoreRequiredBehaviors reordered existing behaviors")
assert(orderedContext.behaviors[2].id == "hit_damage", "restoreRequiredBehaviors did not preserve base role order")
assert(orderedContext.behaviors[3].id == "move_linear", "restoreRequiredBehaviors did not preserve base role order")
assert(orderedContext.behaviors[4].id == "hit_circle", "restoreRequiredBehaviors did not preserve base role order")

print("behavior clone fixtures passed")

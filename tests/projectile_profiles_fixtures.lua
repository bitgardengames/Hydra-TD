package.path = "./?.lua;./?/init.lua;" .. package.path

local Profiles = require("world.projectile_profiles")
local tower = {
	level = 3,
	def = {
		upgrade = { slowDurAdd = 0.5 },
		behaviors = {
			{ id = "move_homing" },
			{ id = "apply_slow", data = { factor = 0.5, dur = 2 } },
			{ id = "draw_slow" },
		},
	},
}

local profile = Profiles.get(tower)
assert(#profile.behaviors == 3 and profile.behaviors[1].id == "move_homing"
	and profile.behaviors[3].id == "draw_slow",
	"a fixed tower projectile plan must retain its designed behaviors")
assert(profile.behaviors[2].data.dur == 3, "linear upgrades must still tune projectile values")
assert(tower.def.behaviors[2].data.dur == 2, "profile tuning must not mutate tower definitions")
assert(Profiles.get(tower) == profile, "a projectile plan should be cached for its tower level")
assert(#profile.update == 1 and #profile.hit == 2 and #profile.draw == 1,
	"profiles must be compiled when their level-tuned values are built")
assert(profile.init and profile.expire and profile.canHit,
	"compiled profiles must expose the fixed lifecycle operation lists")
assert(Profiles.get({ level = 3, def = tower.def }) == profile,
	"equal definition/level pairs must share their compiled fixed profile")

tower.level = 4
assert(Profiles.get(tower).behaviors[2].data.dur == 3.5, "level changes must rebuild tuned values")

for _, path in ipairs({
	"world/projectiles.lua",
	"world/projectile_behaviors/shared.lua",
	"world/projectile_behaviors/movement.lua",
	"world/projectile_behaviors/collision.lua",
	"world/projectile_behaviors/damage.lua",
	"world/projectile_behaviors/status_proc.lua",
	"world/projectile_behaviors/emission.lua",
	"world/projectile_behaviors/drawing.lua",
}) do
	local source = assert(io.open(path, "r")):read("*a")
	assert(not source:find('sourceKind ==', 1, true), path .. " must not select behavior from attribution")
	assert(not source:find('sourceTower.kind', 1, true), path .. " must not select behavior from tower kind")
end

local damageSource = assert(io.open("world/projectile_behaviors/damage.lua", "r")):read("*a")
assert(damageSource:find('local chainDamageMetadata = { chain = true }', 1, true)
	and damageSource:find('emitDamage(p, current, dealt, chainDamageMetadata)', 1, true),
	"the retained chain core must explicitly attribute its damage events")

print("fixed projectile profile fixtures passed")

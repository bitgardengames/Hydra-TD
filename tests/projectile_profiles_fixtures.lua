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
assert(#profile == 3 and profile[1].id == "move_homing" and profile[3].id == "draw_slow",
	"a fixed tower projectile plan must retain its designed behaviors")
assert(profile[2].data.dur == 3, "linear upgrades must still tune projectile values")
assert(tower.def.behaviors[2].data.dur == 2, "profile tuning must not mutate tower definitions")
assert(Profiles.get(tower) == profile, "a projectile plan should be cached for its tower level")

tower.level = 4
assert(Profiles.get(tower)[2].data.dur == 3.5, "level changes must rebuild tuned values")

print("fixed projectile profile fixtures passed")

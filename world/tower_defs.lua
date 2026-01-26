local Constants = require("core.constants")
local Theme = require("core.theme")

return {
	lancer = {
		nameKey = "tower.lancer",
		cost = 40,
		range = 4.2 * Constants.TILE,
		fireRate = 2.0, -- shots/sec
		damage = 11,
		recoilStrength = Constants.TILE * 0.08,
		recoilDecay = 18,
		projSpeed = 460,
		turnSpeed = 15,
		color = Theme.tower.lancer,
		upgrade = {
			cost = 60,
			dmgMult = 1.15,
			rangeAdd = 0.30 * Constants.TILE,
			fireMult = 1.02,
		}
	},

	slow = {
		nameKey = "tower.slow",
		cost = 50,
		range = 3.8 * Constants.TILE,
		fireRate = 1.4,
		damage = 6,
		recoilStrength = Constants.TILE * 0.06,
		recoilDecay = 18,
		projSpeed = 370,
		turnSpeed = 10,
		color = Theme.tower.slow,
		onHitSlow = {factor = 0.55, dur = 1.4},
		upgrade = {
			cost = 55,
			dmgMult = 1.2,
			rangeAdd = 0.2 * Constants.TILE,
			fireMult = 1.02,
			slowDurAdd = 0.35,
		}
	},

	cannon = {
		nameKey = "tower.cannon",
		cost = 70,
		range = 3.2 * Constants.TILE,
		fireRate = 0.8,
		damage = 20,
		recoilStrength = Constants.TILE * 0.14,
		recoilDecay = 12,
		projSpeed = 320,
		turnSpeed = 6,
		color = Theme.tower.cannon,
		splash = {
			radius = 42, -- AoE radius in pixels
			falloff = 0.65, -- % damage applied at edge
		},
		upgrade = {
			cost = 82,
			dmgMult = 1.14,
			rangeAdd = 0.08 * Constants.TILE,
			fireMult = 1.05,
			splashAdd = 4, -- increase AoE radius per upgrade
		}
	},

	shock = {
		nameKey = "tower.shock",
		cost = 65,
		range = 3.6 * Constants.TILE,
		fireRate = 1.2,
		damage = 10,
		recoilStrength = 0,
		recoilDecay = 0,
		turnSpeed = 20,
		color = Theme.tower.shock,
		chain = {
			jumps = 3, -- number of additional enemies
			radius = 56, -- max distance between jumps
			falloff = 0.75 -- damage multiplier per jump
		},
		upgrade = {
			cost = 78,
			dmgMult = 1.22,
			rangeAdd = 0.12 * Constants.TILE,
			fireMult = 1.08,
		}
	},

	poison = {
		nameKey = "tower.poison",
		cost = 60,
		range = 3.8 * Constants.TILE,
		fireRate = 1.6,
		damage = 5,
		recoilStrength = Constants.TILE * 0.06,
		recoilDecay = 18,
		projSpeed = 360,
		turnSpeed = 10,
		color = Theme.tower.poison,
		poison = {
			dps = 8, -- damage per second per stack
			dur = 4, -- duration per application
			maxStacks = 4,
		},
		upgrade = {
			cost = 72,
			dmgMult = 1.1,
			rangeAdd = 0.25 * Constants.TILE,
			fireMult = 1.02,
			poisonDurAdd = 0.35,
			poisonDpsMult = 1.08,
			stackAdd = 1,
		}
	},
}
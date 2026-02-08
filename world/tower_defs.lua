local Constants = require("core.constants")
local Theme = require("core.theme")

return {
	lancer = {
		nameKey = "tower.lancer",
		cost = 40,
		range = 4.0 * Constants.TILE,
		fireRate = 2.0, -- shots/sec
		damage = 11,
		recoilStrength = Constants.TILE * 0.08,
		recoilDecay = 18,
		projSpeed = 460,
		turnSpeed = 15,
		color = Theme.tower.lancer,
		canRotate = true,
		upgrade = {
			dmgMult = 1.50,
			rangeAdd = 0.12 * Constants.TILE,
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
		recoilDecay = 10,
		projSpeed = 370,
		turnSpeed = 10,
		color = Theme.tower.slow,
		canRotate = true,
		onHitSlow = {factor = 0.55, dur = 1.4},
		upgrade = {
			dmgMult = 1.45,
			rangeAdd = 0.1 * Constants.TILE,
			fireMult = 1.04,
			slowDurAdd = 0.35,
		}
	},

	cannon = {
		nameKey = "tower.cannon",
		cost = 70,
		range = 3.2 * Constants.TILE,
		fireRate = 0.8,
		damage = 18,
		recoilStrength = Constants.TILE * 0.12,
		recoilDecay = 14,
		projSpeed = 320,
		turnSpeed = 8,
		color = Theme.tower.cannon,
		canRotate = true,
		splash = {
			radius = 42, -- AoE radius in pixels
			falloff = 0.45, -- % damage applied at edge
		},
		upgrade = {
			dmgMult = 1.48,
			rangeAdd = 0.08 * Constants.TILE,
			fireMult = 1.06,
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
		canRotate = false,
		chain = {
			jumps = 3, -- number of additional enemies
			radius = 56, -- max distance between jumps
			falloff = 0.75 -- damage multiplier per jump
		},
		upgrade = {
			dmgMult = 1.55,
			rangeAdd = 0.8 * Constants.TILE,
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
		recoilDecay = 16,
		projSpeed = 360,
		turnSpeed = 10,
		color = Theme.tower.poison,
		canRotate = true,
		poison = {
			dps = 6, -- damage per second per stack
			dur = 4, -- duration per application
			maxStacks = 4,
		},
		upgrade = {
			dmgMult = 1.30,
			rangeAdd = 0.12 * Constants.TILE,
			fireMult = 1.02,
			poisonDurAdd = 0.25,
			poisonDpsMult = 1.10,
			stackAdd = 1,
		}
	},
}
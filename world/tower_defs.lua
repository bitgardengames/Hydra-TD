local Constants = require("core.constants")
local Theme = require("core.theme")

return {
	slow = {
		nameKey = "tower.slow",
		descKey = "towerDesc.slow",
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
		onHitSlow = {factor = 0.5, dur = 1.5},
		upgrade = {
			dmgMult = 2.2,
			rangeAdd = 0.1 * Constants.TILE,
			fireMult = 1.0, -- 1.04
			slowDurAdd = 0.35,
		}
	},

	lancer = {
		nameKey = "tower.lancer",
		descKey = "towerDesc.lancer",
		cost = 55,
		range = 3.9 * Constants.TILE,
		fireRate = 2.0, -- shots/sec
		damage = 10,
		recoilStrength = Constants.TILE * 0.08,
		recoilDecay = 18,
		projSpeed = 460,
		turnSpeed = 15,
		color = Theme.tower.lancer,
		canRotate = true,
		upgrade = {
			dmgMult = 2.2,
			rangeAdd = 0.08 * Constants.TILE,
			fireMult = 1.0, -- 1.03
		}
	},

	poison = {
		nameKey = "tower.poison",
		descKey = "towerDesc.poison",
		cost = 60,
		range = 3.6 * Constants.TILE,
		fireRate = 1.6,
		damage = 5,
		recoilStrength = Constants.TILE * 0.06,
		recoilDecay = 16,
		projSpeed = 360,
		turnSpeed = 11,
		color = Theme.tower.poison,
		canRotate = true,
		poison = {
			dps = 6, -- damage per second per stack
			dur = 4, -- duration per application
			maxStacks = 4,
		},
		upgrade = {
			dmgMult = 2.2,
			rangeAdd = 0.06 * Constants.TILE,
			fireMult = 1.0, -- 1.02
			poisonDurAdd = 0.25,
			poisonDpsMult = 1.10,
			stackAdd = 1,
		}
	},

	cannon = {
		nameKey = "tower.cannon",
		descKey = "towerDesc.cannon",
		cost = 65,
		range = 3.2 * Constants.TILE,
		fireRate = 0.85,
		damage = 19,
		recoilStrength = Constants.TILE * 0.12,
		recoilDecay = 14,
		projSpeed = 320,
		turnSpeed = 8,
		color = Theme.tower.cannon,
		canRotate = true,
		splash = {
			radius = 48, -- AoE radius in pixels
			falloff = 0.45, -- % damage applied at edge
		},
		upgrade = {
			dmgMult = 2.2,
			rangeAdd = 0.08 * Constants.TILE,
			fireMult = 1.0, -- 1.05
			splashAdd = 4, -- increase AoE radius per upgrade
		}
	},

	shock = {
		nameKey = "tower.shock",
		descKey = "towerDesc.shock",
		cost = 70,
		range = 3.5 * Constants.TILE,
		fireRate = 1.2,
		damage = 9,
		recoilStrength = Constants.TILE * 0.03,
		recoilDecay = 5, -- Dramatic because the recoil is so small
		turnSpeed = 9,
		color = Theme.tower.shock,
		canRotate = true,
		chain = {
			jumps = 3, -- number of additional enemies
			radius = 56, -- max distance between jumps
			falloff = 0.75 -- damage multiplier per jump
		},
		upgrade = {
			dmgMult = 2.2,
			rangeAdd = 0.06 * Constants.TILE,
			fireMult = 1.0, -- 1.04
		}
	},

	plasma = {
		nameKey = "tower.plasma",
		descKey = "towerDesc.plasma",
		cost = 75,
		range = 3.5 * Constants.TILE,
		fireRate = 0.7,
		damage = 8,
		recoilStrength = Constants.TILE * 0.14,
		recoilDecay = 18,
		projSpeed = 140,
		turnSpeed = 8,
		color = Theme.tower.plasma,
		canRotate = true,
		plasma = {
			radius = 10,
			tickRate = 0.1,
		},
		upgrade = {
			dmgMult = 2.2,
			rangeAdd = 0.08 * Constants.TILE,
			fireMult = 1.0,
		}
	},
}
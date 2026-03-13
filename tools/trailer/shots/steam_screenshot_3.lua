local Camera = require("tools.trailer.camera")
local Actions = require("tools.trailer.actions")
local Constants = require("core.constants")

return {
	map = 2,
	duration = 10.0,

	scene = {
		towers = {
			{kind = "slow", gx = 14, gy = 7},
			{kind = "shock", gx = 16, gy = 7},
			{kind = "lancer", gx = 20, gy = 7},
			{kind = "cannon", gx = 16, gy = 8},
			{kind = "poison", gx = 18, gy = 8},
		},

		wave = {
			index = 16,
			start = true,
			warmup = 11.0,
		},
	},

    actions = {
		{t = 0, fn = Actions.upgradeTowerAt(18, 8, 1)},

		{t = 0, fn = Actions.setMoney(86)},
    },
}
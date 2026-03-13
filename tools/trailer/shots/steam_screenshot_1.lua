local Camera = require("tools.trailer.camera")
local Actions = require("tools.trailer.actions")
local Constants = require("core.constants")

return {
	map = 1,
	duration = 10.0,

	scene = {
		towers = {
			{kind = "slow", gx = 14, gy = 8},
			{kind = "lancer", gx = 16, gy = 8},
			{kind = "cannon", gx = 18, gy = 7},
			{kind = "shock", gx = 16, gy = 7},
			{kind = "poison", gx = 17, gy = 9},
		},

		wave = {
			index = 18,
			start = true,
			warmup = 11.0,
		},
	},

    actions = {
		{t = 0, fn = Actions.upgradeTowerAt(16, 8, 2)},
		{t = 0, fn = Actions.upgradeTowerAt(18, 7, 2)},
		{t = 0, fn = Actions.upgradeTowerAt(16, 7, 2)},
		{t = 0, fn = Actions.upgradeTowerAt(17, 9, 3)},

		{t = 0, fn = Actions.setMoney(92)},
    },
}
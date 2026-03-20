local Camera = require("tools.trailer.camera")
local Actions = require("tools.trailer.actions")
local Constants = require("core.constants")

return {
	map = 3,
	duration = 10.0,

	scene = {
		towers = {
			{kind = "slow", gx = 12, gy = 7},
			{kind = "cannon", gx = 13, gy = 7},
			{kind = "lancer", gx = 20, gy = 8},
			{kind = "slow", gx = 19, gy = 7},
			{kind = "shock", gx = 20, gy = 7},
			{kind = "poison", gx = 18, gy = 8},
		},

		wave = {
			index = 17,
			start = true,
			warmup = 11.0,
		},
	},

    actions = {
		{t = 0, fn = Actions.upgradeTowerAt(12, 7, 1)},
		{t = 0, fn = Actions.upgradeTowerAt(13, 7, 2)},
		{t = 0, fn = Actions.upgradeTowerAt(20, 8, 2)},
		{t = 0, fn = Actions.upgradeTowerAt(19, 7, 1)},
		{t = 0, fn = Actions.upgradeTowerAt(20, 7, 2)},
		{t = 0, fn = Actions.upgradeTowerAt(18, 8, 1)},

		{t = 0, fn = Actions.setMoney(101)},
    },
}
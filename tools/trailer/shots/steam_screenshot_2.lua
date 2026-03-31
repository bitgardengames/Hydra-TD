local Camera = require("tools.trailer.camera")
local Actions = require("tools.trailer.actions")
local Constants = require("core.constants")

return {
	map = 3,
	duration = 10.0,

	scene = {
		towers = {
			{kind = "slow", gx = 12, gy = 6},
			{kind = "cannon", gx = 13, gy = 6},
			{kind = "lancer", gx = 20, gy = 7},
			{kind = "slow", gx = 19, gy = 6},
			{kind = "shock", gx = 20, gy = 6},
			{kind = "poison", gx = 12, gy = 4},
		},

		wave = {
			index = 18,
			start = true,
			warmup = 11.0,
		},
	},

    actions = {
		{t = 0, fn = Actions.upgradeTowerAt(12, 6, 1)},
		{t = 0, fn = Actions.upgradeTowerAt(13, 6, 2)},
		{t = 0, fn = Actions.upgradeTowerAt(20, 7, 2)},
		{t = 0, fn = Actions.upgradeTowerAt(19, 6, 1)},
		{t = 0, fn = Actions.upgradeTowerAt(20, 6, 2)},
		{t = 0, fn = Actions.upgradeTowerAt(12, 4, 1)},
		{t = 0, fn = Actions.setLives(7)},

		{t = 0.1, fn = Actions.setMoney(101)},

		{t = 10, fn = Actions.selectEnemy(3)},
    },
}
local Camera = require("tools.trailer.camera")
local Actions = require("tools.trailer.actions")
local Constants = require("core.constants")

return {
	map = 1,
	duration = 10.0,

	scene = {
		towers = {
			{kind = "slow", gx = 14, gy = 7},
			{kind = "lancer", gx = 16, gy = 7},
			{kind = "cannon", gx = 20, gy = 4},
			{kind = "shock", gx = 16, gy = 6},
			{kind = "poison", gx = 17, gy = 8},
			{kind = "plasma", gx = 20, gy = 8},
		},

		wave = {
			index = 24,
			start = true,
			warmup = 11.0,
		},
	},

    actions = {
		{t = 0, fn = Actions.upgradeTowerAt(16, 7, 2)},
		{t = 0, fn = Actions.upgradeTowerAt(20, 4, 2)},
		{t = 0, fn = Actions.upgradeTowerAt(16, 6, 1)},
		{t = 0, fn = Actions.upgradeTowerAt(17, 8, 2)},
		{t = 0, fn = Actions.upgradeTowerAt(20, 8, 2)},
		{t = 0, fn = Actions.setLives(15)},

		{t = 0.1, fn = Actions.setMoney(278)},

		{t = 0.1, fn = Actions.selectTower(16, 6)},
    },
}
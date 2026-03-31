local Camera = require("tools.trailer.camera")
local Actions = require("tools.trailer.actions")
local Constants = require("core.constants")

return {
	map = 15,
	duration = 14.0,

	scene = {
		towers = {
			{kind = "slow", gx = 17, gy = 8},
			{kind = "shock", gx = 14, gy = 6},
			{kind = "lancer", gx = 16, gy = 6},
			{kind = "slow", gx = 22, gy = 6},
			{kind = "cannon", gx = 19, gy = 6},
			{kind = "plasma", gx = 21, gy = 7},
			{kind = "poison", gx = 19, gy = 8},
			{kind = "poison", gx = 15, gy = 9},
		},

		wave = {
			index = 23,
			start = true,
			warmup = 28.0,
		},
	},

    actions = {
		{t = 0, fn = Actions.upgradeTowerAt(14, 6, 1)},
		{t = 0, fn = Actions.upgradeTowerAt(19, 8, 2)},
		{t = 0, fn = Actions.upgradeTowerAt(17, 6, 2)},
		{t = 0, fn = Actions.upgradeTowerAt(19, 6, 2)},
		{t = 0, fn = Actions.upgradeTowerAt(21, 7, 2)},
		{t = 0, fn = Actions.upgradeTowerAt(16, 6, 1)},
		{t = 0, fn = Actions.setLives(10)},

		{t = 0.1, fn = Actions.setMoney(187)},

		{t = 0, fn = Actions.clearSelection()},
    },
}
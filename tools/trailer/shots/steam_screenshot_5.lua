local Camera = require("tools.trailer.camera")
local Actions = require("tools.trailer.actions")
local Constants = require("core.constants")

return {
	map = 2,
	duration = 10.0,

	scene = {
		towers = {
			{kind = "slow", gx = 14, gy = 6},
			{kind = "shock", gx = 16, gy = 6},
			{kind = "lancer", gx = 20, gy = 6},
			{kind = "cannon", gx = 16, gy = 7},
			{kind = "plasma", gx = 15, gy = 8},
			{kind = "poison", gx = 18, gy = 7},
			{kind = "plasma", gx = 18, gy = 7},
		},

		wave = {
			index = 17,
			start = true,
			warmup = 11.0,
		},
	},

    actions = {
		{t = 0, fn = Actions.upgradeTowerAt(16, 6, 1)},
		{t = 0, fn = Actions.upgradeTowerAt(20, 6, 2)},
		{t = 0, fn = Actions.upgradeTowerAt(16, 7, 2)},
		{t = 0, fn = Actions.upgradeTowerAt(18, 7, 1)},
		{t = 0, fn = Actions.upgradeTowerAt(15, 8, 1)},
		{t = 0, fn = Actions.setLives(12)},

		{t = 0.1, fn = Actions.setMoney(210)},
    },
}
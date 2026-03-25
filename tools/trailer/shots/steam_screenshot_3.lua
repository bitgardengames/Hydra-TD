local Camera = require("tools.trailer.camera")
local Actions = require("tools.trailer.actions")
local Constants = require("core.constants")

return {
	map = 9,
	duration = 14.0,

	scene = {
		towers = {
			{kind = "slow", gx = 17, gy = 8},
			{kind = "shock", gx = 17, gy = 7},
			{kind = "lancer", gx = 20, gy = 7},
			{kind = "slow", gx = 22, gy = 7},
			{kind = "cannon", gx = 19, gy = 7},
			{kind = "poison", gx = 19, gy = 8},
			{kind = "poison", gx = 15, gy = 8},
		},

		wave = {
			index = 21,
			start = true,
			warmup = 50.0,
		},
	},

    actions = {
		{t = 0, fn = Actions.upgradeTowerAt(20, 7, 1)},
		{t = 0, fn = Actions.upgradeTowerAt(19, 8, 2)},
		{t = 0, fn = Actions.upgradeTowerAt(17, 7, 2)},
		{t = 0, fn = Actions.upgradeTowerAt(19, 7, 2)},
		{t = 0, fn = Actions.setLives(14)},

		{t = 0.1, fn = Actions.setMoney(128)},

		{t = 10, fn = Actions.selectEnemy(1)},
		{t = 11, fn = Actions.clearSelection()},
    },
}
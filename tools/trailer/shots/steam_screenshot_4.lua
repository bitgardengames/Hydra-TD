local Camera = require("tools.trailer.camera")
local Actions = require("tools.trailer.actions")
local Constants = require("core.constants")

return {
	map = 15,
	duration = 14.0,

	scene = {
		towers = {
			{kind = "slow", gx = 17, gy = 9},
			{kind = "shock", gx = 14, gy = 7},
			{kind = "lancer", gx = 16, gy = 7},
			{kind = "slow", gx = 22, gy = 7},
			{kind = "cannon", gx = 19, gy = 7},
			{kind = "poison", gx = 19, gy = 9},
			{kind = "poison", gx = 15, gy = 10},
		},

		wave = {
			index = 18,
			start = true,
			warmup = 20.0,
		},
	},

    actions = {
		{t = 0, fn = Actions.upgradeTowerAt(20, 7, 1)},
		{t = 0, fn = Actions.upgradeTowerAt(19, 8, 2)},
		{t = 0, fn = Actions.upgradeTowerAt(17, 7, 2)},
		{t = 0, fn = Actions.upgradeTowerAt(19, 7, 2)},

		{t = 0, fn = Actions.setMoney(187)},
    },
}
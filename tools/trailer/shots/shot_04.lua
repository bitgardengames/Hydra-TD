local Camera = require("tools.trailer.camera")
local Actions = require("tools.trailer.actions")

return {
	map = 5,
	duration = 4.0,
	next = "shot_05",

	scene = {
		towers = {
			{ kind = "poison", gx = 9,  gy = 9 },
			{ kind = "shock",  gx = 8, gy = 9 },
			{ kind = "lancer",  gx = 12, gy = 8 },
		},
		wave = {
			wave = 11,
			start = true,
			warmup = 33,
		},
	},

	actions = {
		-- Upgrades happen on-screen shortly after the word appears
		{ t = 1.05, fn = Actions.upgradeTowerAt(9,  9, 1) },  -- poison +1
		{ t = 1.65, fn = Actions.upgradeTowerAt(12, 8, 1) }, -- lancer +1 -- Optionally do 2 to show a harder power spike
		{ t = 2.25, fn = Actions.upgradeTowerAt(8,  9, 1) },  -- shock +1
	},

	camera = Camera.pan({
		from = { x = 80,  y = 80, zoom = 1.25 },
		to   = { x = 160, y = 80, zoom = 1.25 },
		duration = 4.0,
	}),

	text = {
		{
			t = 0.8,
			text = "Upgrade",
			dur = 3,
			fadeIn = 0.2,
			fadeOut = 0.3,
		},
	},
}

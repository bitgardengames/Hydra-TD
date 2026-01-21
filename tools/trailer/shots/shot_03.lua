local Camera  = require("tools.trailer.camera")
local Actions = require("tools.trailer.actions")

return {
    map = 4,
    duration = 4,
    next = "shot_04",

    scene = {
        towers = {
            { kind = "cannon", gx = 12, gy = 8 },
            { kind = "shock", gx = 9, gy = 9 },
            { kind = "slow", gx = 14, gy = 9 },
        },

        wave = {
			index = 7,
            start = true,
            warmup = 8.0,
        },
    },

    camera = Camera.pan({
        from = { x = 200, y = 40, zoom = 1.4 },
        to = { x = 200, y = 40, zoom = 1.7 },
        duration = 3.5,
    }),

    actions = {
		{ t = 0, fn = Actions.upgradeTowerAt(9, 9, 2)},
        { t = 0.3, fn = Actions.startWave() },
        { t = 1.35, fn = Actions.placeTower("lancer", 14, 6) },
        { t = 2.0, fn = Actions.placeTower("poison", 15, 7) },
    },

	text = {
		{
			t = 0.8,
			text = "Build",
			dur = 3,
			fadeIn = 0.2,
			fadeOut = 0.3,
		},
	}
}

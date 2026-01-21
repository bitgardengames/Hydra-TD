local Camera = require("tools.trailer.camera")
local Actions = require("tools.trailer.actions")

return {
    map = 7,
    duration = 8.0,
	next = "shot_06",

    scene = {
        towers = {
            { kind = "slow",   gx = 10, gy = 6 },
            { kind = "slow",   gx = 17, gy = 5 },
            { kind = "lancer", gx = 12, gy = 7 },
            { kind = "lancer", gx = 12, gy = 9 },
            { kind = "poison", gx = 14, gy = 7 },
            { kind = "shock", gx = 16, gy = 7 },
            { kind = "cannon", gx = 12, gy = 6 },
        },

        wave = {
			index = 10,
            start = true,
            warmup = 8, -- boss already visible
        },
    },

    actions = {
        { t = 0, fn = Actions.upgradeTowerAt(12, 7, 4) },
        { t = 0, fn = Actions.upgradeTowerAt(12, 9, 3) },
        { t = 0, fn = Actions.upgradeTowerAt(14, 8, 4) },
        { t = 0, fn = Actions.upgradeTowerAt(12, 6, 2) },
        { t = 0, fn = Actions.upgradeTowerAt(16, 7, 2) },
        { t = 0, fn = Actions.upgradeTowerAt(14, 7, 3) },
    },

    camera = Camera.pan({
        from = { x = 160, y = 0, zoom = 1.3 },
        to = { x = 160, y = 0, zoom = 1.6 },
        duration = 6.0,
    }),

	text = {
		{
			t = 0.8,
			text = "Survive",
			dur = 3,
			fadeIn = 0.2,
			fadeOut = 0.3,
		},
	}
}

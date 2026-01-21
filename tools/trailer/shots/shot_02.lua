local Camera = require("tools.trailer.camera")

return {
    map = 3,
    duration = 5.0,
    next = "shot_03",

    scene = {
        towers = {
            { kind = "slow",   gx = 12, gy = 7 },
            { kind = "cannon", gx = 12, gy = 4 },
        },
        wave = {
			index = 5,
            start = true,
            warmup = 5.0,
        },
    },

    camera = Camera.pan({
        from = { x = 120, y = 0, zoom = 1.3 },
        to   = { x = 220, y = 0, zoom = 1.3 },
        duration = 4.5,
    }),
	
	text = {
		{
			t = 0.8,
			text = "Strategize",
			dur = 3,
			fadeIn = 0.2,
			fadeOut = 0.3,
		},
	}
}

local Config = {
	mode = "screenshots", -- sequence, single, screenshots
	sequence = "steam_trailer",
	startShot = "survive",

	recorder = true,

	showUI = false,
	showFloaters = true, -- NYI
	vignette = true,

    output = {
        --width = 1080,
        --height = 1920,
		width = 1920,
		height = 1080,
    },

	screenshots = {
		enabled = true,
		prefix = "store",
		list = {
			{shot = "steam_screenshot_1", frame = 728},
			{shot = "steam_screenshot_2", frame = 270},
			{shot = "steam_screenshot_3", frame = 634},
			{shot = "steam_screenshot_4", frame = 480},
			{shot = "steam_screenshot_5", frame = 216},
		}
	},
}

return Config
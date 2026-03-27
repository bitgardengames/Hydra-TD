return {
	mode = "single", -- sequence, single, screenshots
	sequence = "steam_trailer",
	startShot = "plasma_intro",

	recorder = true,

	showUI = false,
	showFloaters = true, -- NYI
	vignette = true,

    output = {
        --width = 1080,
        --height = 1920,
		width = 200,
		height = 200
    },

	screenshots = {
		enabled = true,
		prefix = "store",
		list = {
			{shot = "steam_screenshot_1", frame = 784},
			{shot = "steam_screenshot_2", frame = 272},
			{shot = "steam_screenshot_3", frame = 634},
			{shot = "steam_screenshot_4", frame = 453},
			{shot = "steam_screenshot_5", frame = 190}, -- 355 Original
		}
	},
}
return {
	mode = "single", -- sequence, single, screenshots
	sequence = "steam_trailer",
	startShot = "patch",

	recorder = false,

	showUI = false,
	showFloaters = true, -- NYI
	vignette = true,

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
	}
}
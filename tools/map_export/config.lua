local Theme = require("core.theme")

return {
	enabled = true,

	outDir = "export/maps",

	drawGrass = true,
	forcePathColor = false,
	--forcedPathColor = Theme.tower.lancer,
	forcedPathColor = { 0.10, 0.10, 0.11 },

	-- Output resolutions
	sizes = {
		{w = 1920, h = 1080}, -- 1080p
		--{w = 3840, h = 2160}, -- 4K
	},

	-- Skip maps by id
	skip = {
		line = true,
	},

	seed = 123456,

	stitch = {
		enabled = true,
		height = 1080, -- target height of each map render, 2160 for 4k 540 for 50%, 720 for media
		padding = 0, -- space between maps
		filename = "campaign_atlas"
	},
}
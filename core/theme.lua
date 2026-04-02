local Theme = {}

local function lighten(c, amt)
	return {math.min(1, c[1] + amt), math.min(1, c[2] + amt), math.min(1, c[3] + amt), c[4] or 1}
end

-- Variant switch
Theme.variant = "default" -- "default", "halloween", "winter", "autumn", "desert"
-- Could consider lunar, martian, candy, sci-fi, void, crystal

-- Base Theme
Theme.grid = {0.16, 0.17, 0.2, 0.1}

Theme.outline = {
	color = {0.09, 0.09, 0.1, 1},
	width = 3,
}

Theme.lighting = {
	shadowMul = 0.68,
	highlightOffset = 0.12,
	highlightScale = 0.88,
}

Theme.shadow = {
	alpha = 0.18,
	width = 1.4,
	height = 0.4,
}

Theme.terrain = {
	bg = {0.06, 0.07, 0.09},
	grass = {0.28, 0.58, 0.34},
	path = {0.64, 0.63, 0.60},
	pathOutline = {0.36, 0.35, 0.32},
	water = {0.20, 0.42, 0.55},
}

Theme.world = {
	treeTrunk = {0.36, 0.26, 0.16},
	treeTrunkOutline = {0.22, 0.16, 0.10},

	treeStyles = {
		{fill = {0.46, 0.78, 0.48}, outline = {0.20, 0.44, 0.26}},
		{fill = {0.40, 0.72, 0.42}, outline = {0.18, 0.40, 0.22}},
		{fill = {0.32, 0.62, 0.36}, outline = {0.14, 0.34, 0.18}},
		{fill = {0.54, 0.78, 0.44}, outline = {0.28, 0.46, 0.22}},
		{fill = {0.36, 0.66, 0.38}, outline = {0.16, 0.36, 0.20}},
	},

	rockStyles = {
		{fill = {0.70, 0.68, 0.64}, outline = {0.40, 0.38, 0.35}},
		{fill = {0.64, 0.63, 0.60}, outline = {0.36, 0.35, 0.32}},
		{fill = {0.74, 0.72, 0.68}, outline = {0.44, 0.42, 0.38}},
		{fill = {0.60, 0.60, 0.58}, outline = {0.32, 0.32, 0.30}},
		{fill = {0.68, 0.66, 0.62}, outline = {0.38, 0.36, 0.33}},
	},
}

Theme.enemy = {
	body = {0.90, 0.40, 0.36},
	face = {0.07, 0.07, 0.07},
	shadow = {0.01, 0.01, 0.01, 0.3},
}

Theme.tower = {
	lancer = {0.9, 0.9, 0.86},
	slow = {0.7, 0.66, 0.92},
	cannon = {0.94, 0.58, 0.32},
	shock = {0.45, 0.78, 0.98},
	poison = {0.50, 0.82, 0.44},
	plasma = {0.75, 0.45, 1.0},
}

Theme.projectiles = {
	lancer = {0.97, 0.97, 0.97},
	slow = {0.7, 0.85, 0.98},
	cannon = {0.98, 0.8, 0.4},
	shock = {0.45, 0.78, 0.98},
	poison = {0.55, 0.9, 0.5},
	plasma = {0.85, 0.55, 1.0}, -- 1.0, 0.75, 1.0
}

Theme.ui = {
	text = {0.92, 0.94, 0.96},
	good = {0.35, 0.95, 0.55},
	bad = {0.95, 0.35, 0.35},
	warn = {0.98, 0.82, 0.30},

	panel = {0.18, 0.19, 0.21, 1},
	panel2 = {0.13, 0.14, 0.16, 1},

	hovered = lighten({0.09, 0.1, 0.12}, 0.06),
	selected = {1, 0.88, 0.4},

	button = {0.32, 0.33, 0.36},
	buttonHover = {0.40, 0.42, 0.46},
	buttonSelected = {0.34, 0.48, 0.64, 1},
	buttonDisabled = {0.16, 0.17, 0.19, 1},

	backdrop = {0.20, 0.21, 0.23, 1},
	screenDim = {0.03, 0.04, 0.05, 0.4},

	money = {0.9, 0.82, 0.42, 1},
	lives = {0.92, 0.46, 0.44, 1},
	wave = {0.42, 0.78, 0.92, 1},

	bossHealth = {0.75, 0.15, 0.15, 0.9},
	shadow = {0.01, 0.01, 0.01, 0.3},
}

Theme.medal = {
	bronze = {0.80, 0.52, 0.24},
	silver = {0.82, 0.84, 0.87},
	gold = {0.98, 0.84, 0.24},
}

Theme.towerShadow = {0.01, 0.01, 0.01, 0.3}

Theme.text = {}

-- Variants
Theme.variants = {
	halloween = {
		terrain = {
			grass = {0.27, 0.18, 0.36},
			path = {0.20, 0.14, 0.16},
			pathOutline = {0.12, 0.08, 0.10},
		},

		world = {
			treeStyles = {
				{fill = {0.32, 0.14, 0.08}, outline = {0.18, 0.08, 0.04}},
				{fill = {0.62, 0.24, 0.06}, outline = {0.36, 0.12, 0.04}},
				{fill = {0.26, 0.12, 0.34}, outline = {0.14, 0.06, 0.20}},
				{fill = {0.28, 0.26, 0.30}, outline = {0.16, 0.14, 0.18}},
				{fill = {0.48, 0.18, 0.10}, outline = {0.28, 0.08, 0.04}},
			},

			rockStyles = {
				{fill = {0.20, 0.18, 0.22}, outline = {0.10, 0.08, 0.12}},
				{fill = {0.36, 0.22, 0.48}, outline = {0.18, 0.10, 0.26}},
				{fill = {0.34, 0.42, 0.28}, outline = {0.18, 0.24, 0.14}},
				{fill = {0.48, 0.22, 0.10}, outline = {0.28, 0.10, 0.04}},
				{fill = {0.26, 0.24, 0.30}, outline = {0.14, 0.12, 0.18}},
			},
		},

		enemy = {
			body = {0.92, 0.46, 0.08},
			face = {0.05, 0.02, 0.02},
		},

		ui = {
			panel = {0.14, 0.10, 0.12, 1},
			panel2 = {0.10, 0.07, 0.09, 1},
			warn = {1.0, 0.55, 0.15},
		},

		lighting = {
			shadowMul = 0.75,
		},
	},

	winter = {
		terrain = {
			grass = {0.86, 0.91, 0.95},
			path = {0.52, 0.66, 0.76},
			pathOutline = {0.38, 0.50, 0.60},
		},

		world = {
			treeStyles = {
				{fill = {0.85, 0.90, 0.92}, outline = {0.60, 0.70, 0.75}},
				{fill = {0.75, 0.85, 0.90}, outline = {0.50, 0.60, 0.70}},
				{fill = {0.92, 0.94, 0.96}, outline = {0.70, 0.75, 0.80}},
				{fill = {0.70, 0.80, 0.88}, outline = {0.45, 0.55, 0.65}},
				{fill = {0.88, 0.92, 0.95}, outline = {0.65, 0.70, 0.75}},
			},

			rockStyles = {
				{fill = {0.82, 0.86, 0.90}, outline = {0.60, 0.65, 0.70}},
				{fill = {0.78, 0.82, 0.88}, outline = {0.55, 0.60, 0.65}},
				{fill = {0.90, 0.92, 0.95}, outline = {0.70, 0.75, 0.80}},
				{fill = {0.72, 0.78, 0.85}, outline = {0.50, 0.55, 0.60}},
				{fill = {0.86, 0.90, 0.94}, outline = {0.65, 0.70, 0.75}},
			},
		},

		enemy = {
			body = {0.95, 0.97, 0.99},
		},

		ui = {
			panel = {0.16, 0.18, 0.20, 1},
			panel2 = {0.12, 0.14, 0.16, 1},
		},

		lighting = {
			shadowMul = 0.6,
			highlightScale = 0.95,
		},
	},

	autumn = {
		terrain = {
			grass = {0.48, 0.56, 0.30},        -- slightly brighter + warmer
			path = {0.66, 0.56, 0.42},         -- more golden dirt
			pathOutline = {0.44, 0.34, 0.24},
		},

		world = {
			treeStyles = {
				{fill = {0.84, 0.46, 0.20}, outline = {0.52, 0.24, 0.10}}, -- brighter orange
				{fill = {0.78, 0.36, 0.16}, outline = {0.48, 0.20, 0.08}}, -- warm orange
				{fill = {0.70, 0.28, 0.14}, outline = {0.42, 0.16, 0.08}}, -- burnt but richer
				{fill = {0.92, 0.64, 0.20}, outline = {0.58, 0.38, 0.12}}, -- golden pop (this carries the “happiness”)
				{fill = {0.60, 0.40, 0.20}, outline = {0.36, 0.24, 0.12}}, -- warm brown (less gray)
			},

			rockStyles = {
				{fill = {0.62, 0.54, 0.44}, outline = {0.38, 0.32, 0.26}},
				{fill = {0.56, 0.50, 0.42}, outline = {0.34, 0.30, 0.26}},
				{fill = {0.68, 0.60, 0.50}, outline = {0.42, 0.36, 0.30}},
				{fill = {0.52, 0.46, 0.38}, outline = {0.32, 0.28, 0.24}},
				{fill = {0.64, 0.56, 0.46}, outline = {0.40, 0.34, 0.28}},
			},
		},

		enemy = {
			body = {0.94, 0.52, 0.38}, -- slightly warmer / more alive
		},

		ui = {
			panel = {0.22, 0.18, 0.13, 1},
			panel2 = {0.18, 0.14, 0.11, 1},
			warn = {1.0, 0.70, 0.30},
		},

		lighting = {
			shadowMul = 0.70, -- slightly softer shadows = warmer feel
		},
	},

	desert = {
		terrain = {
			grass = {0.82, 0.72, 0.48},        -- sand base
			path = {0.70, 0.52, 0.34},         -- packed dirt
			pathOutline = {0.46, 0.34, 0.22},  -- darker baked edge
			water = {0.30, 0.60, 0.55},        -- oasis teal (optional, but nice)
		},

		world = {
			treeTrunk = {0.46, 0.34, 0.20},
			treeTrunkOutline = {0.28, 0.20, 0.12},

			-- Think scrub / dry vegetation instead of lush trees
			treeStyles = {
				{fill = {0.58, 0.62, 0.30}, outline = {0.34, 0.38, 0.18}}, -- dry green
				{fill = {0.64, 0.58, 0.26}, outline = {0.38, 0.34, 0.16}}, -- dusty olive
				{fill = {0.72, 0.52, 0.22}, outline = {0.44, 0.30, 0.14}}, -- sunburnt
				{fill = {0.52, 0.48, 0.24}, outline = {0.30, 0.28, 0.14}}, -- muted shrub
				{fill = {0.78, 0.66, 0.34}, outline = {0.48, 0.42, 0.20}}, -- sandy highlight
			},

			-- Rocks carry the biome here
			rockStyles = {
				{fill = {0.72, 0.60, 0.44}, outline = {0.44, 0.36, 0.26}},
				{fill = {0.66, 0.54, 0.40}, outline = {0.40, 0.32, 0.24}},
				{fill = {0.78, 0.66, 0.50}, outline = {0.50, 0.42, 0.32}},
				{fill = {0.60, 0.50, 0.36}, outline = {0.36, 0.28, 0.20}},
				{fill = {0.74, 0.62, 0.46}, outline = {0.46, 0.38, 0.28}},
			},
		},

		enemy = {
			body = {0.92, 0.48, 0.30}, -- slightly warmer enemies (heat vibe)
		},

		ui = {
			panel = {0.24, 0.20, 0.14, 1},
			panel2 = {0.18, 0.15, 0.10, 1},
			warn = {1.0, 0.74, 0.30},
		},

		lighting = {
			shadowMul = 0.75,         -- harsher sun
			highlightOffset = 0.14,   -- slightly stronger top light
			highlightScale = 0.90,
		},
	},
}

-- Deep merge
local function merge(dst, src)
	for k, v in pairs(src) do
		if type(v) == "table" and type(dst[k]) == "table" then
			merge(dst[k], v)
		else
			dst[k] = v
		end
	end
end

local function applyVariant()
	local v = Theme.variants[Theme.variant]
	if not v then return end

	for section, data in pairs(v) do
		if Theme[section] then
			merge(Theme[section], data)
		end
	end
end

applyVariant()

return Theme
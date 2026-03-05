local Theme = {}

local function lighten(c, amt)
    return {math.min(1, c[1] + amt), math.min(1, c[2] + amt), math.min(1, c[3] + amt), c[4] or 1}
end

Theme.outline = {
    color = {0.1, 0.1, 0.11, 1},
    width = 3,
}

Theme.terrain = {
	bg = {0.06, 0.07, 0.09},

	-- Normal
	grass = {0.28, 0.58, 0.34},
	path = {0.62, 0.63, 0.66},

	-- Halloween
	--grass = {0.27, 0.18, 0.36},
	--path = {0.20, 0.14, 0.16},

	-- Winter
	--grass = {0.86, 0.91, 0.95},
	--path = {0.52, 0.66, 0.76},
}

Theme.grid = {0.16, 0.17, 0.2, 0.1}

Theme.enemy = {
	-- Normal
	body = {0.90, 0.40, 0.36},

	-- Halloween
	--body = {0.92, 0.46, 0.08},

	-- Winter
	--body = {0.95, 0.97, 0.99},

	face = {0.07, 0.07, 0.07},
	shadow = {0.01, 0.01, 0.01, 0.3},
}

Theme.tower = {
	lancer = {0.9, 0.9, 0.86},
	slow = {0.7, 0.66, 0.92},
	cannon = {0.94, 0.58, 0.32},
	shock = {0.45, 0.78, 0.98},
	poison = {0.50, 0.82, 0.44},
}

Theme.towerShadow = {0.01, 0.01, 0.01, 0.3}

Theme.projectiles = {
	lancer = {0.97, 0.97, 0.97},
	slow = {0.7, 0.85, 0.98},
	cannon = {0.98, 0.8, 0.4},
	shock = {0.45, 0.78, 0.98},
	poison = {0.55, 0.9, 0.5},
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

Theme.text = {}

return Theme
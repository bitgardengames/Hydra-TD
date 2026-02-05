local Theme = {}

local function lighten(c, amt)
    return {math.min(1, c[1] + amt), math.min(1, c[2] + amt), math.min(1, c[3] + amt), c[4] or 1}
end

Theme.outline = {
    color = {0.04, 0.04, 0.04, 1},
    width = 3,
}

Theme.terrain = {
    bg = {0.06, 0.07, 0.09},
    grass = {0.28, 0.58, 0.34},
    path = {0.62, 0.63, 0.66},
    pathEdge = {0.10, 0.10, 0.10},
}

Theme.grid = {0.16, 0.17, 0.20, 0.10}

Theme.enemy = {
    body = {0.90, 0.40, 0.36},
    face = {0.07, 0.07, 0.07},
    shadow = {0, 0, 0, 0.35},
}

Theme.tower = {
    lancer = {0.90, 0.90, 0.86},
    slow = {0.70, 0.66, 0.92},
    cannon = {0.94, 0.58, 0.32},
    shock = {0.45, 0.78, 0.98},
    poison = {0.50, 0.82, 0.44},
}

Theme.projectiles = {
	lancer = {0.98, 0.98, 0.98},
	slow = {0.7, 0.85, 1},
	cannon = {1, 0.8, 0.4},
	shock = {0.45, 0.78, 0.98},
	poison = {0.6, 0.9, 0.5},
}

Theme.ui = {
    text = {0.92, 0.94, 0.96},
    good = {0.35, 0.95, 0.55},
    bad = {0.95, 0.35, 0.35},
    warn = {0.98, 0.82, 0.30},
    panel = {0.18, 0.19, 0.21, 1},
    panel2 = {0.13, 0.14, 0.16, 1},
    hovered = lighten({0.09, 0.10, 0.12}, 0.06),
    selected = {1.00, 0.88, 0.40},

	button = {0.23, 0.24, 0.27, 1},
	buttonHover = {0.27, 0.28, 0.32, 1},
	buttonSelected = {0.32, 0.44, 0.64, 1},
	buttonDisabled = {0.16, 0.17, 0.19, 1},

	money = {0.90, 0.82, 0.42, 1},
	lives = {0.92, 0.46, 0.44, 1},
	wave = {0.42, 0.78, 0.92, 1},

	bossHealth = {0.75, 0.15, 0.15, 0.9},
	
	shadow = {0, 0, 0, 0.35},
}

Theme.menu = {0.31, 0.57, 0.76, 1}

Theme.towerShadow = {0, 0, 0, 0.35}

Theme.text = {}

return Theme
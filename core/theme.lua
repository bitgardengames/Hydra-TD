local Theme = {}

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

Theme.grid = {0.16, 0.17, 0.20, 0.1} -- 0.18

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
	lancer = {0.95, 0.95, 0.95},
}

Theme.ui = {
    text = {0.92, 0.94, 0.96},
    good = {0.35, 0.95, 0.55},
    bad = {0.95, 0.35, 0.35},
    warn = {0.98, 0.82, 0.30},
    panel = {0.09, 0.10, 0.12},
    panel2 = {0.12, 0.13, 0.16},
    selected = {1.00, 0.88, 0.40},
}

Theme.towerShadow = {0, 0, 0, 0.35}

Theme.text = {}

return Theme
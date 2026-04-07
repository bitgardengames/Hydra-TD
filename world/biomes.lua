local Theme = require("core.theme")

local Biomes = {}

-- Deep copy
local function deepCopy(src)
	if type(src) ~= "table" then
		return src
	end

	local dst = {}

	for k, v in pairs(src) do
		dst[k] = deepCopy(v)
	end

	return dst
end

-- Deep merge (map overrides biome)
local function merge(dst, src)
	if not src then
		return dst
	end

	for k, v in pairs(src) do
		if type(v) == "table" and type(dst[k]) == "table" then
			merge(dst[k], v)
		else
			dst[k] = deepCopy(v)
		end
	end

	return dst
end

--[[
	More ideas;
	Mushrooms. Either like Zangarmarsh vibes or whatever, just a trippy setting would be cool
	Lava/brimstone/hellish
--]]

-- Biome definitions
Biomes.defs = {
	default = { -- Baseline, cozy fantasy
		terrain = {
			grass = {0.28, 0.58, 0.34},
			path = {0.64, 0.63, 0.60},
			pathOutline = {0.36, 0.35, 0.32},
			water = {0.20, 0.42, 0.55},
		},

		ground = {
			detailDensity = 0.25,
			lightMul = 1.06,
			darkMul = 0.94,
		},

		world = {
			tree = {
				trunk = {0.36, 0.26, 0.16},
				trunkOutline = {0.22, 0.16, 0.10},
				shapes = {"round", "square"},

				styles = {
					{fill = {0.46, 0.78, 0.48}, outline = {0.20, 0.44, 0.26}},
					{fill = {0.40, 0.72, 0.42}, outline = {0.18, 0.40, 0.22}},
					{fill = {0.32, 0.62, 0.36}, outline = {0.14, 0.34, 0.18}},
					{fill = {0.54, 0.78, 0.44}, outline = {0.28, 0.46, 0.22}},
					{fill = {0.36, 0.66, 0.38}, outline = {0.16, 0.36, 0.20}},
				},
			},

			rock = {
				styles = {
					{fill = {0.70, 0.68, 0.64}, outline = {0.40, 0.38, 0.35}},
					{fill = {0.64, 0.63, 0.60}, outline = {0.36, 0.35, 0.32}},
					{fill = {0.74, 0.72, 0.68}, outline = {0.44, 0.42, 0.38}},
					{fill = {0.60, 0.60, 0.58}, outline = {0.32, 0.32, 0.30}},
					{fill = {0.68, 0.66, 0.62}, outline = {0.38, 0.36, 0.33}},
				},
			},
		},

		scatter = {
			trees = {
				enabled = true,
				density = 0.18,
				cluster = 0.20,
				minDistFromPath = 1,
			},

			rocks = {
				enabled = true,
				density = 0.10,
				cluster = 0.05,
				minDistFromPath = 1,
			},
		},
	},

	highlands = {
		terrain = {
			grass = {0.42, 0.56, 0.34},
			path = {0.63, 0.61, 0.58},
			pathOutline = {0.34, 0.35, 0.34},
			water = {0.24, 0.46, 0.58},
		},

		ground = {
			detailDensity = 0.18,
			lightMul = 1.05,
			darkMul = 0.95,
		},

		world = {
			tree = {
				trunk = {0.36, 0.26, 0.16},
				trunkOutline = {0.22, 0.16, 0.10},
				shapes = {"round", "square"},

				styles = {
					{fill = {0.46, 0.78, 0.48}, outline = {0.20, 0.44, 0.26}},
					{fill = {0.40, 0.72, 0.42}, outline = {0.18, 0.40, 0.22}},
					{fill = {0.32, 0.62, 0.36}, outline = {0.14, 0.34, 0.18}},
					{fill = {0.54, 0.78, 0.44}, outline = {0.28, 0.46, 0.22}},
					{fill = {0.36, 0.66, 0.38}, outline = {0.16, 0.36, 0.20}},
				},
			},

			rock = {
				styles = {
					{fill = {0.70, 0.68, 0.64}, outline = {0.40, 0.38, 0.35}},
					{fill = {0.64, 0.63, 0.60}, outline = {0.36, 0.35, 0.32}},
					{fill = {0.74, 0.72, 0.68}, outline = {0.44, 0.42, 0.38}},
					{fill = {0.60, 0.60, 0.58}, outline = {0.32, 0.32, 0.30}},
					{fill = {0.68, 0.66, 0.62}, outline = {0.38, 0.36, 0.33}},
				},
			},
		},

		scatter = {
			trees = {
				enabled = true,
				density = 0.10,
				cluster = 0.10,
				minDistFromPath = 1,
			},

			rocks = {
				enabled = true,
				density = 0.18,
				cluster = 0.12,
				minDistFromPath = 1,
			},
		},
	},

	coastal = {
		terrain = {
			grass = {0.30, 0.55, 0.38},
			path = {0.66, 0.65, 0.61},
			pathOutline = {0.37, 0.36, 0.33},
			water = {0.22, 0.50, 0.62},
		},

		ground = {
			detailDensity = 0.22,
			lightMul = 1.08,
			darkMul = 0.93,
		},

		world = {
			tree = {
				trunk = {0.36, 0.26, 0.16},
				trunkOutline = {0.22, 0.16, 0.10},
				shapes = {"round", "square"},

				styles = {
					{fill = {0.46, 0.78, 0.48}, outline = {0.20, 0.44, 0.26}},
					{fill = {0.40, 0.72, 0.42}, outline = {0.18, 0.40, 0.22}},
					{fill = {0.32, 0.62, 0.36}, outline = {0.14, 0.34, 0.18}},
					{fill = {0.54, 0.78, 0.44}, outline = {0.28, 0.46, 0.22}},
					{fill = {0.36, 0.66, 0.38}, outline = {0.16, 0.36, 0.20}},
				},
			},

			rock = {
				styles = {
					{fill = {0.70, 0.68, 0.64}, outline = {0.40, 0.38, 0.35}},
					{fill = {0.64, 0.63, 0.60}, outline = {0.36, 0.35, 0.32}},
					{fill = {0.74, 0.72, 0.68}, outline = {0.44, 0.42, 0.38}},
					{fill = {0.60, 0.60, 0.58}, outline = {0.32, 0.32, 0.30}},
					{fill = {0.68, 0.66, 0.62}, outline = {0.38, 0.36, 0.33}},
				},
			},
		},

		scatter = {
			trees = {
				enabled = true,
				density = 0.14,
				cluster = 0.18,
				minDistFromPath = 1,
			},

			rocks = {
				enabled = true,
				density = 0.08,
				cluster = 0.04,
				minDistFromPath = 1,
			},
		},
	},

	drylands = {
		terrain = {
			grass = {0.72, 0.63, 0.42},
			path = {0.67, 0.49, 0.31},
			pathOutline = {0.42, 0.30, 0.18},
			water = {0.30, 0.60, 0.55},
		},

		ground = {
			detailDensity = 0.12,
			lightMul = 1.04,
			darkMul = 0.96,
		},

		world = {
			rock = {
				styles = {
					{fill = {0.70, 0.68, 0.64}, outline = {0.40, 0.38, 0.35}},
					{fill = {0.64, 0.63, 0.60}, outline = {0.36, 0.35, 0.32}},
					{fill = {0.74, 0.72, 0.68}, outline = {0.44, 0.42, 0.38}},
					{fill = {0.60, 0.60, 0.58}, outline = {0.32, 0.32, 0.30}},
					{fill = {0.68, 0.66, 0.62}, outline = {0.38, 0.36, 0.33}},
				},
			},

			cactus = {
				styles = {
					{fill = {0.34, 0.62, 0.30}, outline = {0.18, 0.34, 0.16}},
					{fill = {0.28, 0.56, 0.26}, outline = {0.14, 0.30, 0.14}},
					{fill = {0.40, 0.68, 0.36}, outline = {0.20, 0.38, 0.18}},
				},
			},
		},

		scatter = {
			rocks = {
				enabled = true,
				density = 0.14,
				cluster = 0.08,
				minDistFromPath = 1,
			},

			cactus = {
				enabled = true,
				density = 0.09,
				cluster = 0.16,
				minDistFromPath = 1,
			},
		},
	},

	autumn = {
		terrain = {
			grass = {0.48, 0.56, 0.30},
			path = {0.66, 0.56, 0.42},
			pathOutline = {0.44, 0.34, 0.24},
			water = {0.30, 0.50, 0.40},
		},

		ground = {
			detailDensity = 0.22,
			lightMul = 1.05,
			darkMul = 0.95,
		},

		world = {
			tree = {
				trunk = {0.42, 0.28, 0.16},
				trunkOutline = {0.24, 0.16, 0.10},
				shapes = {"round", "square", "evergreen"},

				styles = {
					{fill = {0.84, 0.46, 0.20}, outline = {0.52, 0.24, 0.10}},
					{fill = {0.78, 0.36, 0.16}, outline = {0.48, 0.20, 0.08}},
					{fill = {0.92, 0.64, 0.20}, outline = {0.58, 0.38, 0.12}},
					{fill = {0.60, 0.40, 0.20}, outline = {0.36, 0.24, 0.12}},
				},
			},

			rock = {
				styles = {
					{fill = {0.62, 0.54, 0.44}, outline = {0.38, 0.32, 0.26}},
					{fill = {0.68, 0.60, 0.50}, outline = {0.42, 0.36, 0.30}},
				},
			},
		},

		scatter = {
			trees = {enabled = true, density = 0.16, cluster = 0.18},
			rocks = {enabled = true, density = 0.08, cluster = 0.05},
		},
	},

	halloween = {
		terrain = {
			grass = {0.22, 0.14, 0.28},
			path = {0.18, 0.12, 0.14},
			pathOutline = {0.10, 0.06, 0.08},
			water = {0.18, 0.28, 0.32},
		},

		ground = {
			detailDensity = 0.16,
			lightMul = 1.02,
			darkMul = 0.98,
		},

		world = {
			tree = {
				trunk = {0.28, 0.18, 0.10},
				trunkOutline = {0.14, 0.08, 0.04},
				shapes = {"round", "square", "evergreen"},

				styles = {
					{fill = {0.32, 0.14, 0.08}, outline = {0.18, 0.08, 0.04}},
					{fill = {0.62, 0.24, 0.06}, outline = {0.36, 0.12, 0.04}},
					{fill = {0.26, 0.12, 0.34}, outline = {0.14, 0.06, 0.20}},
					{fill = {0.28, 0.26, 0.30}, outline = {0.16, 0.14, 0.18}},
					{fill = {0.48, 0.18, 0.10}, outline = {0.28, 0.08, 0.04}},
				},
			},

			rock = {
				styles = {
					{fill = {0.20, 0.18, 0.22}, outline = {0.10, 0.08, 0.12}},
					{fill = {0.36, 0.22, 0.48}, outline = {0.18, 0.10, 0.26}},
					{fill = {0.34, 0.42, 0.28}, outline = {0.18, 0.24, 0.14}},
					{fill = {0.48, 0.22, 0.10}, outline = {0.28, 0.10, 0.04}},
				},
			},
		},

		scatter = {
			trees = {enabled = true, density = 0.12, cluster = 0.15},
			rocks = {enabled = true, density = 0.10, cluster = 0.08},
		},
	},

	winter = {
		terrain = {
			grass = {0.76, 0.82, 0.88},
			path = {0.42, 0.56, 0.66},
			pathOutline = {0.26, 0.36, 0.46},
			water = {0.62, 0.78, 0.90},
		},

		ground = {
			-- was 0.08 (too flat)
			detailDensity = 0.14,

			-- reduce glare slightly
			lightMul = 1.06, -- was 1.10
			darkMul = 0.92,  -- was 0.90
		},

		world = {
			tree = {
				-- slightly darker trunk for grounding
				trunk = {0.62, 0.64, 0.66},
				trunkOutline = {0.42, 0.44, 0.46},
				shapes = {"evergreen"},

				styles = {
					{fill = {0.88, 0.90, 0.93}, outline = {0.55, 0.59, 0.63}}, -- was {0.60, 0.64, 0.68}
					{fill = {0.78, 0.86, 0.90}, outline = {0.48, 0.53, 0.57}}, -- was {0.52, 0.58, 0.62}
					{fill = {0.72, 0.82, 0.88}, outline = {0.42, 0.48, 0.53}}, -- was {0.46, 0.52, 0.58}
				},
			},

			rock = {
				styles = {
					{fill = {0.80, 0.84, 0.88}, outline = {0.55, 0.60, 0.64}}, -- was {0.60, 0.65, 0.70}
					{fill = {0.72, 0.78, 0.84}, outline = {0.48, 0.53, 0.59}}, -- was {0.52, 0.58, 0.64}
					{fill = {0.76, 0.80, 0.84}, outline = {0.50, 0.55, 0.61}}, -- was {0.54, 0.60, 0.66}
				},
			},
		},

		scatter = {
			trees = {
				enabled = true,
				-- slightly more presence
				density = 0.10, -- was 0.08
				cluster = 0.12,
			},

			rocks = {
				enabled = true,
				density = 0.08, -- was 0.06
				cluster = 0.05,
			},
		},
	},

	candy = { -- Sprinkles would be fun for scatter instead of rocks. Could make jube jubes or whatever instead of rocks. Trees could be lollipops or gumdrops (dome (half-circle))
		terrain = {
			grass = {0.92, 0.78, 0.86}, -- soft pink base
			path = {0.98, 0.92, 0.55}, -- creamy yellow (like frosting)
			pathOutline = {0.82, 0.68, 0.28}, -- caramel outline
			water = {0.55, 0.78, 0.98}, -- candy blue syrup
		},

		ground = {
			detailDensity = 0.30,
			lightMul = 1.08,
			darkMul = 0.92,
		},

		world = {
			tree = {
				trunk = {0.60, 0.42, 0.22},
				trunkOutline = {0.38, 0.26, 0.12},

				styles = {
					{fill = {1.0, 0.55, 0.75}, outline = {0.70, 0.28, 0.46}}, -- pink candy
					{fill = {0.55, 0.85, 1.0}, outline = {0.28, 0.50, 0.70}}, -- blue candy
					{fill = {0.65, 1.0, 0.70}, outline = {0.32, 0.70, 0.38}}, -- mint
					{fill = {1.0, 0.85, 0.45}, outline = {0.72, 0.58, 0.22}}, -- lemon
					{fill = {0.95, 0.65, 1.0}, outline = {0.62, 0.32, 0.70}}, -- grape
				},
			},

			rock = {
				styles = {
					{fill = {1.0, 0.70, 0.80}, outline = {0.70, 0.40, 0.50}},
					{fill = {0.70, 0.90, 1.0}, outline = {0.40, 0.60, 0.70}},
					{fill = {1.0, 0.90, 0.60}, outline = {0.70, 0.65, 0.30}},
				},
			},
		},

		scatter = {
			trees = {
				enabled = true,
				density = 0.20,
				cluster = 0.22,
			},

			rocks = {
				enabled = true,
				density = 0.08,
				cluster = 0.06,
			},
		},
	},

	void = {
		terrain = {
			grass = {0.04, 0.02, 0.08}, -- near-black purple
			path = {0.55, 0.25, 0.75}, -- glowing purple
			pathOutline = {0.20, 0.10, 0.30}, -- deep edge contrast
			water = {0.10, 0.05, 0.18}, -- barely visible
		},

		ground = {
			detailDensity = 0.05, -- almost no noise
			lightMul = 1.02,
			darkMul = 0.98,
		},

		-- No world objects at all
		world = {
			-- intentionally empty
		},

		scatter = {
			-- intentionally empty (no trees/rocks/cactus)
		},
	},
}

-- Resolve biome for a map
function Biomes.resolve(mapDef)
	local id = mapDef.biome or "default"
	local base = Biomes.defs[id] or Biomes.defs.default

	-- Copy so we don't mutate shared defs
	local biome = deepCopy(base)

	-- Optional per-map overrides
	if mapDef.world then
		merge(biome, mapDef.world)
	end

	return biome
end

return Biomes
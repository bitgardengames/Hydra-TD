local maps = {
    {
        id = "alpha",
        nameKey = "map.alpha",
		path = {
			{4, 8}, {13, 8},
			{13, 4}, {19, 4},
			{19, 12}, {15, 12},
			{15, 6}, {21, 6},
			{21, 10}, {27, 10}, {29, 10}, {31, 10},
		},

		waves = {
            normal = {
                {count = 10, gap = 0.65, mix = {{type = "grunt", w = 1.0}}},
                {count = 14, gap = 0.55, mix = {{type = "grunt", w = 0.75}, {type = "runner", w = 0.25}}},
                {count = 16, gap = 0.55, mix = {{type = "grunt", w = 0.6}, {type = "runner", w = 0.4}}},
                {count = 14, gap = 0.65, mix = {{type = "grunt", w = 0.55}, {type = "tank", w = 0.45}}},
                {count = 14, gap = 0.6, mix = {{type = "grunt", w = 0.5}, {type = "splitter", w = 0.3}, {type = "runner", w = 0.2}}},
                {count = 20, gap = 0.48, mix = {{type = "grunt", w = 0.5}, {type = "runner", w = 0.35}, {type = "tank", w = 0.15}}},
                {count = 20, gap = 0.45, mix = {{type = "tank", w = 0.4}, {type = "splitter", w = 0.4}, {type = "runner", w = 0.2}}},
            },

            bosses = {
                [1] = {type = "boss", hpBase = 1.35, hpRamp = 3.0, spdRamp = 0.08},
                [2] = {type = "boss", hpBase = 1.35, hpRamp = 3.0, spdRamp = 0.08},
            },
        },
    },

    {
        id = "zigzag",
        nameKey = "map.zigzag",
		path = {
			{4, 5}, {23, 5},
			{23, 11}, {9, 11},
			{9, 3}, {27, 3},
			{27, 14}, {29, 14}, {31, 14},
		},

		waves = {
            normal = {
                {count = 10, gap = 0.65, mix = {{type = "grunt", w = 1.0}}},
                {count = 14, gap = 0.55, mix = {{type = "grunt", w = 0.75}, {type = "runner", w = 0.25}}},
                {count = 16, gap = 0.55, mix = {{type = "grunt", w = 0.6}, {type = "runner", w = 0.4}}},
                {count = 14, gap = 0.65, mix = {{type = "grunt", w = 0.55}, {type = "tank", w = 0.45}}},
                {count = 14, gap = 0.6, mix = {{type = "grunt", w = 0.5}, {type = "splitter", w = 0.3}, {type = "runner", w = 0.2}}},
                {count = 20, gap = 0.48, mix = {{type = "grunt", w = 0.5}, {type = "runner", w = 0.35}, {type = "tank", w = 0.15}}},
                {count = 20, gap = 0.45, mix = {{type = "tank", w = 0.4}, {type = "splitter", w = 0.4}, {type = "runner", w = 0.2}}},
            },

            bosses = {
                [1] = {type = "boss", hpBase = 1.35, hpRamp = 3.0, spdRamp = 0.08},
                [2] = {type = "boss", hpBase = 1.35, hpRamp = 3.0, spdRamp = 0.08},
            },
        },
    },

    {
        id = "spiral",
        nameKey = "map.spiral",
		path = {
			{4, 8}, {11, 8},
			{11, 3}, {21, 3},
			{21, 13}, {7, 13},
			{7, 6}, {25, 6},
			{25, 10}, {29, 10}, {31, 10},
		},

		waves = {
            normal = {
                {count = 10, gap = 0.65, mix = {{type = "grunt", w = 1.0}}},
                {count = 14, gap = 0.55, mix = {{type = "grunt", w = 0.75}, {type = "runner", w = 0.25}}},
                {count = 16, gap = 0.55, mix = {{type = "grunt", w = 0.6}, {type = "runner", w = 0.4}}},
                {count = 14, gap = 0.65, mix = {{type = "grunt", w = 0.55}, {type = "tank", w = 0.45}}},
                {count = 14, gap = 0.6, mix = {{type = "grunt", w = 0.5}, {type = "splitter", w = 0.3}, {type = "runner", w = 0.2}}},
                {count = 20, gap = 0.48, mix = {{type = "grunt", w = 0.5}, {type = "runner", w = 0.35}, {type = "tank", w = 0.15}}},
                {count = 20, gap = 0.45, mix = {{type = "tank", w = 0.4}, {type = "splitter", w = 0.4}, {type = "runner", w = 0.2}}},
            },

            bosses = {
                [1] = {type = "boss", hpBase = 1.35, hpRamp = 3.0, spdRamp = 0.08},
				[2] = {type = "boss", hpBase = 1.35, hpRamp = 3.0, spdRamp = 0.08},
            },
        },
    },

	{
		id = "figure8",
		nameKey = "map.figure8",
		path = {
			{4, 8}, {13, 8},
			{13, 4}, {21, 4},
			{21, 8}, {13, 8},
			{13, 12}, {21, 12},
			{21, 8}, {29, 8}, {31, 8},
		},

		waves = {
            normal = {
                {count = 10, gap = 0.65, mix = {{type = "grunt", w = 1.0}}},
                {count = 14, gap = 0.55, mix = {{type = "grunt", w = 0.75}, {type = "runner", w = 0.25}}},
                {count = 16, gap = 0.55, mix = {{type = "grunt", w = 0.6}, {type = "runner", w = 0.4}}},
                {count = 14, gap = 0.65, mix = {{type = "grunt", w = 0.55}, {type = "tank", w = 0.45}}},
                {count = 14, gap = 0.6, mix = {{type = "grunt", w = 0.5}, {type = "splitter", w = 0.3}, {type = "runner", w = 0.2}}},
                {count = 20, gap = 0.48, mix = {{type = "grunt", w = 0.5}, {type = "runner", w = 0.35}, {type = "tank", w = 0.15}}},
                {count = 20, gap = 0.45, mix = {{type = "tank", w = 0.4}, {type = "splitter", w = 0.4}, {type = "runner", w = 0.2}}},
            },

            bosses = {
                [1] = {type = "boss", hpBase = 1.35, hpRamp = 3.0, spdRamp = 0.08},
                [2] = {type = "boss", hpBase = 1.35, hpRamp = 3.0, spdRamp = 0.08},
            },
        },
	},

	{
		id = "hairpins",
		nameKey = "map.hairpins",
		path = {
			{4, 4}, {25, 4},
			{25, 7}, {7, 7},
			{7, 10}, {25, 10},
			{25, 13}, {29, 13}, {31, 13},
		},

		waves = {
            normal = {
                {count = 10, gap = 0.65, mix = {{type = "grunt", w = 1.0}}},
                {count = 14, gap = 0.55, mix = {{type = "grunt", w = 0.75}, {type = "runner", w = 0.25}}},
                {count = 16, gap = 0.55, mix = {{type = "grunt", w = 0.6}, {type = "runner", w = 0.4}}},
                {count = 14, gap = 0.65, mix = {{type = "grunt", w = 0.55}, {type = "tank", w = 0.45}}},
                {count = 14, gap = 0.6, mix = {{type = "grunt", w = 0.5}, {type = "splitter", w = 0.3}, {type = "runner", w = 0.2}}},
                {count = 20, gap = 0.48, mix = {{type = "grunt", w = 0.5}, {type = "runner", w = 0.35}, {type = "tank", w = 0.15}}},
                {count = 20, gap = 0.45, mix = {{type = "tank", w = 0.4}, {type = "splitter", w = 0.4}, {type = "runner", w = 0.2}}},
            },

            bosses = {
                [1] = {type = "boss", hpBase = 1.35, hpRamp = 3.0, spdRamp = 0.08},
                [2] = {type = "boss", hpBase = 1.35, hpRamp = 3.0, spdRamp = 0.08},
            },
        },
	},

	{
		id = "gauntlet",
		nameKey = "map.gauntlet",
		path = {
			{4, 8}, {11, 8},
			{11, 5}, {21, 5},
			{21, 11}, {11, 11},
			{11, 8}, {29, 8}, {31, 8},
		},

		waves = {
            normal = {
                {count = 10, gap = 0.65, mix = {{type = "grunt", w = 1.0}}},
                {count = 14, gap = 0.55, mix = {{type = "grunt", w = 0.75}, {type = "runner", w = 0.25}}},
                {count = 16, gap = 0.55, mix = {{type = "grunt", w = 0.6}, {type = "runner", w = 0.4}}},
                {count = 14, gap = 0.65, mix = {{type = "grunt", w = 0.55}, {type = "tank", w = 0.45}}},
                {count = 14, gap = 0.6, mix = {{type = "grunt", w = 0.5}, {type = "splitter", w = 0.3}, {type = "runner", w = 0.2}}},
                {count = 20, gap = 0.48, mix = {{type = "grunt", w = 0.5}, {type = "runner", w = 0.35}, {type = "tank", w = 0.15}}},
                {count = 20, gap = 0.45, mix = {{type = "tank", w = 0.4}, {type = "splitter", w = 0.4}, {type = "runner", w = 0.2}}},
            },

            bosses = {
                [1] = {type = "boss", hpBase = 1.35, hpRamp = 3.0, spdRamp = 0.08},
                [2] = {type = "boss", hpBase = 1.35, hpRamp = 3.0, spdRamp = 0.08},
            },
        },
	},

	{
		id = "centerpull",
		nameKey = "map.centerpull",
		path = {
			{4, 8}, {13, 8},
			{13, 3}, {19, 3},
			{19, 13}, {13, 13},
			{13, 8}, {29, 8}, {31, 8},
		},

		waves = {
            normal = {
                {count = 10, gap = 0.65, mix = {{type = "grunt", w = 1.0}}},
                {count = 14, gap = 0.55, mix = {{type = "grunt", w = 0.75}, {type = "runner", w = 0.25}}},
                {count = 16, gap = 0.55, mix = {{type = "grunt", w = 0.6}, {type = "runner", w = 0.4}}},
                {count = 14, gap = 0.65, mix = {{type = "grunt", w = 0.55}, {type = "tank", w = 0.45}}},
                {count = 14, gap = 0.6, mix = {{type = "grunt", w = 0.5}, {type = "splitter", w = 0.3}, {type = "runner", w = 0.2}}},
                {count = 20, gap = 0.48, mix = {{type = "grunt", w = 0.5}, {type = "runner", w = 0.35}, {type = "tank", w = 0.15}}},
                {count = 20, gap = 0.45, mix = {{type = "tank", w = 0.4}, {type = "splitter", w = 0.4}, {type = "runner", w = 0.2}}},
            },

            bosses = {
                [1] = {type = "boss", hpBase = 1.35, hpRamp = 3.0, spdRamp = 0.08},
                [2] = {type = "boss", hpBase = 1.35, hpRamp = 3.0, spdRamp = 0.08},
            },
        },
	},

	{
		id = "snakepit",
		nameKey = "map.snakepit",
		path = {
			{4, 4}, {25, 4},
			{25, 6}, {7, 6},
			{7, 8}, {25, 8},
			{25, 10}, {7, 10},
			{7, 12}, {29, 12}, {31, 12},
		},

		waves = {
            normal = {
                {count = 10, gap = 0.65, mix = {{type = "grunt", w = 1.0}}},
                {count = 14, gap = 0.55, mix = {{type = "grunt", w = 0.75}, {type = "runner", w = 0.25}}},
                {count = 16, gap = 0.55, mix = {{type = "grunt", w = 0.6}, {type = "runner", w = 0.4}}},
                {count = 14, gap = 0.65, mix = {{type = "grunt", w = 0.55}, {type = "tank", w = 0.45}}},
                {count = 14, gap = 0.6, mix = {{type = "grunt", w = 0.5}, {type = "splitter", w = 0.3}, {type = "runner", w = 0.2}}},
                {count = 20, gap = 0.48, mix = {{type = "grunt", w = 0.5}, {type = "runner", w = 0.35}, {type = "tank", w = 0.15}}},
                {count = 20, gap = 0.45, mix = {{type = "tank", w = 0.4}, {type = "splitter", w = 0.4}, {type = "runner", w = 0.2}}},
            },

            bosses = {
                [1] = {type = "boss", hpBase = 1.35, hpRamp = 3.0, spdRamp = 0.08},
                [2] = {type = "boss", hpBase = 1.35, hpRamp = 3.0, spdRamp = 0.08},
            },
        },
	},

	{
		id = "doublebend",
		nameKey = "map.doublebend",
		path = {
			{4, 6}, {15, 6},
			{15, 10}, {23, 10},
			{23, 4}, {29, 4}, {31, 4},
		},

		waves = {
            normal = {
                {count = 10, gap = 0.65, mix = {{type = "grunt", w = 1.0}}},
                {count = 14, gap = 0.55, mix = {{type = "grunt", w = 0.75}, {type = "runner", w = 0.25}}},
                {count = 16, gap = 0.55, mix = {{type = "grunt", w = 0.6}, {type = "runner", w = 0.4}}},
                {count = 14, gap = 0.65, mix = {{type = "grunt", w = 0.55}, {type = "tank", w = 0.45}}},
                {count = 14, gap = 0.6, mix = {{type = "grunt", w = 0.5}, {type = "splitter", w = 0.3}, {type = "runner", w = 0.2}}},
                {count = 20, gap = 0.48, mix = {{type = "grunt", w = 0.5}, {type = "runner", w = 0.35}, {type = "tank", w = 0.15}}},
                {count = 20, gap = 0.45, mix = {{type = "tank", w = 0.4}, {type = "splitter", w = 0.4}, {type = "runner", w = 0.2}}},
            },

            bosses = {
                [1] = {type = "boss", hpBase = 1.35, hpRamp = 3.0, spdRamp = 0.08},
                [2] = {type = "boss", hpBase = 1.35, hpRamp = 3.0, spdRamp = 0.08},
            },
        },
	},

	{
		id = "offsetloop",
		nameKey = "map.offsetloop",
		path = {
			{4, 7}, {17, 7},
			{17, 3}, {25, 3},
			{25, 13}, {9, 13},
			{9, 7}, {29, 7}, {31, 7},
		},

		waves = {
            normal = {
                {count = 10, gap = 0.65, mix = {{type = "grunt", w = 1.0}}},
                {count = 14, gap = 0.55, mix = {{type = "grunt", w = 0.75}, {type = "runner", w = 0.25}}},
                {count = 16, gap = 0.55, mix = {{type = "grunt", w = 0.6}, {type = "runner", w = 0.4}}},
                {count = 14, gap = 0.65, mix = {{type = "grunt", w = 0.55}, {type = "tank", w = 0.45}}},
                {count = 14, gap = 0.6, mix = {{type = "grunt", w = 0.5}, {type = "splitter", w = 0.3}, {type = "runner", w = 0.2}}},
                {count = 20, gap = 0.48, mix = {{type = "grunt", w = 0.5}, {type = "runner", w = 0.35}, {type = "tank", w = 0.15}}},
                {count = 20, gap = 0.45, mix = {{type = "tank", w = 0.4}, {type = "splitter", w = 0.4}, {type = "runner", w = 0.2}}},
            },

            bosses = {
                [1] = {type = "boss", hpBase = 1.35, hpRamp = 3.0, spdRamp = 0.08},
                [2] = {type = "boss", hpBase = 1.35, hpRamp = 3.0, spdRamp = 0.08},
            },
        },
	},

	{
		id = "sidewinder",
		nameKey = "map.sidewinder",
		path = {
			{4, 4}, {23, 4},
			{23, 8}, {11, 8},
			{11, 12}, {25, 12},
			{25, 8}, {29, 8}, {31, 8},
		},

		waves = {
            normal = {
                {count = 10, gap = 0.65, mix = {{type = "grunt", w = 1.0}}},
                {count = 14, gap = 0.55, mix = {{type = "grunt", w = 0.75}, {type = "runner", w = 0.25}}},
                {count = 16, gap = 0.55, mix = {{type = "grunt", w = 0.6}, {type = "runner", w = 0.4}}},
                {count = 14, gap = 0.65, mix = {{type = "grunt", w = 0.55}, {type = "tank", w = 0.45}}},
                {count = 14, gap = 0.6, mix = {{type = "grunt", w = 0.5}, {type = "splitter", w = 0.3}, {type = "runner", w = 0.2}}},
                {count = 20, gap = 0.48, mix = {{type = "grunt", w = 0.5}, {type = "runner", w = 0.35}, {type = "tank", w = 0.15}}},
                {count = 20, gap = 0.45, mix = {{type = "tank", w = 0.4}, {type = "splitter", w = 0.4}, {type = "runner", w = 0.2}}},
            },

            bosses = {
                [1] = {type = "boss", hpBase = 1.35, hpRamp = 3.0, spdRamp = 0.08},
                [2] = {type = "boss", hpBase = 1.35, hpRamp = 3.0, spdRamp = 0.08},
            },
        },
	},

	{
		id = "crosscurrent",
		nameKey = "map.crosscurrent",
		path = {
			{4, 6}, {27, 6},
			{27, 10}, {7, 10},
			{7, 8}, {23, 8},
			{23, 12}, {29, 12}, {31, 12},
		},

		waves = {
            normal = {
                {count = 10, gap = 0.65, mix = {{type = "grunt", w = 1.0}}},
                {count = 14, gap = 0.55, mix = {{type = "grunt", w = 0.75}, {type = "runner", w = 0.25}}},
                {count = 16, gap = 0.55, mix = {{type = "grunt", w = 0.6}, {type = "runner", w = 0.4}}},
                {count = 14, gap = 0.65, mix = {{type = "grunt", w = 0.55}, {type = "tank", w = 0.45}}},
                {count = 14, gap = 0.6, mix = {{type = "grunt", w = 0.5}, {type = "splitter", w = 0.3}, {type = "runner", w = 0.2}}},
                {count = 20, gap = 0.48, mix = {{type = "grunt", w = 0.5}, {type = "runner", w = 0.35}, {type = "tank", w = 0.15}}},
                {count = 20, gap = 0.45, mix = {{type = "tank", w = 0.4}, {type = "splitter", w = 0.4}, {type = "runner", w = 0.2}}},
            },

            bosses = {
                [1] = {type = "boss", hpBase = 1.35, hpRamp = 3.0, spdRamp = 0.08},
                [2] = {type = "boss", hpBase = 1.35, hpRamp = 3.0, spdRamp = 0.08},
            },
        },
	},
}

return maps
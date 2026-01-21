local maps = {
    {
        id = "alpha",
        nameKey = "map.alpha",
        path = {
            {1, 8}, {10, 8},
            {10, 4}, {16, 4},
            {16, 12}, {12, 12},
            {12, 6}, {18, 6},
            {18, 10}, {24, 10}, {26, 10},
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
            {1, 5}, {20, 5},
            {20, 11}, {6, 11},
            {6, 3}, {24, 3},
            {24, 14}, {26, 14},
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
            {1, 8}, {8, 8},
            {8, 3}, {18, 3},
            {18, 13}, {4, 13},
            {4, 6}, {22, 6},
            {22, 10}, {26, 10},
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
			{1, 8}, {10, 8},
			{10, 4}, {18, 4},
			{18, 8}, {10, 8},
			{10, 12}, {18, 12},
			{18, 8}, {26, 8},
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
			{1, 4}, {22, 4},
			{22, 7}, {4, 7},
			{4, 10}, {22, 10},
			{22, 13}, {26, 13},
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
			{1, 8}, {8, 8},
			{8, 5}, {18, 5},
			{18, 11}, {8, 11},
			{8, 8}, {26, 8},
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
			{1, 8}, {10, 8},
			{10, 3}, {16, 3},
			{16, 13}, {10, 13},
			{10, 8}, {26, 8},
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
			{1, 4}, {22, 4},
			{22, 6}, {4, 6},
			{4, 8}, {22, 8},
			{22, 10}, {4, 10},
			{4, 12}, {26, 12},
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
			{1, 6}, {12, 6},
			{12, 10}, {20, 10},
			{20, 4}, {26, 4},
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
			{1, 7}, {14, 7},
			{14, 3}, {22, 3},
			{22, 13}, {6, 13},
			{6, 7}, {26, 7},
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
			{1, 4}, {20, 4},
			{20, 8}, {8, 8},
			{8, 12}, {22, 12},
			{22, 8}, {26, 8},
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
			{1, 6}, {24, 6},
			{24, 10}, {4, 10},
			{4, 8}, {20, 8},
			{20, 12}, {26, 12},
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
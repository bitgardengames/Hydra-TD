local maps = {
    {
        id = "alpha",
        name = "Alpha Bend",
        path = {
            {1, 8}, {10, 8},
            {10, 4}, {16, 4},
            {16, 12}, {12, 12},
            {12, 6}, {18, 6},
            {18, 10}, {24, 10}, {26, 10},
        },

		waves = {
            normal = {
                {count = 10, gap = 0.65, mix = {{type="grunt", w=1.0}}},
                {count = 14, gap = 0.55, mix = {{type="grunt", w=0.75}, {type="runner", w=0.25}}},
                {count = 16, gap = 0.55, mix = {{type="grunt", w=0.6}, {type="runner", w=0.4}}},
                {count = 14, gap = 0.65, mix = {{type="grunt", w=0.55}, {type="tank", w=0.45}}},
                {count = 14, gap = 0.6, mix = {{type="grunt", w=0.5}, {type="splitter", w=0.3}, {type="runner", w=0.2}}},
                {count = 20, gap = 0.48, mix = {{type="grunt", w=0.5}, {type="runner", w=0.35}, {type="tank", w=0.15}}},
                {count = 20, gap = 0.45, mix = {{type="tank", w=0.4}, {type="splitter", w=0.4}, {type="runner", w=0.2}}},
            },

            bosses = {
                [10] = {type = "boss", hpBase = 1.35, hpRamp = 3.0, spdRamp = 0.08, addTrickle = true},
            },
        },
    },

    {
        id = "zigzag",
        name = "Zig-Zag",
        path = {
            {1, 5}, {20, 5},
            {20, 11}, {6, 11},
            {6, 3}, {24, 3},
            {24, 14}, {26, 14},
        },

		waves = {
            normal = {
                {count = 10, gap = 0.65, mix = {{type="grunt", w=1.0}}},
                {count = 14, gap = 0.55, mix = {{type="grunt", w=0.75}, {type="runner", w=0.25}}},
                {count = 16, gap = 0.55, mix = {{type="grunt", w=0.6}, {type="runner", w=0.4}}},
                {count = 14, gap = 0.65, mix = {{type="grunt", w=0.55}, {type="tank", w=0.45}}},
                {count = 14, gap = 0.6, mix = {{type="grunt", w=0.5}, {type="splitter", w=0.3}, {type="runner", w=0.2}}},
                {count = 20, gap = 0.48, mix = {{type="grunt", w=0.5}, {type="runner", w=0.35}, {type="tank", w=0.15}}},
                {count = 20, gap = 0.45, mix = {{type="tank", w=0.4}, {type="splitter", w=0.4}, {type="runner", w=0.2}}},
            },

            bosses = {
                [10] = {type = "boss", hpBase = 1.35, hpRamp = 3.0, spdRamp = 0.08, addTrickle = true},
            },
        },
    },

    {
        id = "spiral",
        name = "Spiral Run",
        path = {
            {1, 8}, {8, 8},
            {8, 3}, {18, 3},
            {18, 13}, {4, 13},
            {4, 6}, {22, 6},
            {22, 10}, {26, 10},
        },

		waves = {
            normal = {
                {count = 10, gap = 0.65, mix = {{type="grunt", w=1.0}}},
                {count = 14, gap = 0.55, mix = {{type="grunt", w=0.75}, {type="runner", w=0.25}}},
                {count = 16, gap = 0.55, mix = {{type="grunt", w=0.6}, {type="runner", w=0.4}}},
                {count = 14, gap = 0.65, mix = {{type="grunt", w=0.55}, {type="tank", w=0.45}}},
                {count = 14, gap = 0.6, mix = {{type="grunt", w=0.5}, {type="splitter", w=0.3}, {type="runner", w=0.2}}},
                {count = 20, gap = 0.48, mix = {{type="grunt", w=0.5}, {type="runner", w=0.35}, {type="tank", w=0.15}}},
                {count = 20, gap = 0.45, mix = {{type="tank", w=0.4}, {type="splitter", w=0.4}, {type="runner", w=0.2}}},
            },

            bosses = {
                [10] = {type = "boss", hpBase = 1.35, hpRamp = 3.0, spdRamp = 0.08, addTrickle = true},
            },
        },
    },

	{
		id = "figure8",
		name = "Figure Eight",
		path = {
			{1, 8}, {10, 8},
			{10, 4}, {18, 4},
			{18, 8}, {10, 8},
			{10, 12}, {18, 12},
			{18, 8}, {26, 8},
		},

		waves = {
            normal = {
                {count = 10, gap = 0.65, mix = {{type="grunt", w=1.0}}},
                {count = 14, gap = 0.55, mix = {{type="grunt", w=0.75}, {type="runner", w=0.25}}},
                {count = 16, gap = 0.55, mix = {{type="grunt", w=0.6}, {type="runner", w=0.4}}},
                {count = 14, gap = 0.65, mix = {{type="grunt", w=0.55}, {type="tank", w=0.45}}},
                {count = 14, gap = 0.6, mix = {{type="grunt", w=0.5}, {type="splitter", w=0.3}, {type="runner", w=0.2}}},
                {count = 20, gap = 0.48, mix = {{type="grunt", w=0.5}, {type="runner", w=0.35}, {type="tank", w=0.15}}},
                {count = 20, gap = 0.45, mix = {{type="tank", w=0.4}, {type="splitter", w=0.4}, {type="runner", w=0.2}}},
            },

            bosses = {
                [10] = {type = "boss", hpBase = 1.35, hpRamp = 3.0, spdRamp = 0.08, addTrickle = true},
            },
        },
	},

	{
		id = "hairpins",
		name = "Hairpins",
		path = {
			{1, 4}, {22, 4},
			{22, 7}, {4, 7},
			{4, 10}, {22, 10},
			{22, 13}, {26, 13},
		},

		waves = {
            normal = {
                {count = 10, gap = 0.65, mix = {{type="grunt", w=1.0}}},
                {count = 14, gap = 0.55, mix = {{type="grunt", w=0.75}, {type="runner", w=0.25}}},
                {count = 16, gap = 0.55, mix = {{type="grunt", w=0.6}, {type="runner", w=0.4}}},
                {count = 14, gap = 0.65, mix = {{type="grunt", w=0.55}, {type="tank", w=0.45}}},
                {count = 14, gap = 0.6, mix = {{type="grunt", w=0.5}, {type="splitter", w=0.3}, {type="runner", w=0.2}}},
                {count = 20, gap = 0.48, mix = {{type="grunt", w=0.5}, {type="runner", w=0.35}, {type="tank", w=0.15}}},
                {count = 20, gap = 0.45, mix = {{type="tank", w=0.4}, {type="splitter", w=0.4}, {type="runner", w=0.2}}},
            },

            bosses = {
                [10] = {type = "boss", hpBase = 1.35, hpRamp = 3.0, spdRamp = 0.08, addTrickle = true},
            },
        },
	},

	{
		id = "gauntlet",
		name = "The Gauntlet",
		path = {
			{1, 8}, {8, 8},
			{8, 5}, {18, 5},
			{18, 11}, {8, 11},
			{8, 8}, {26, 8},
		},

		waves = {
            normal = {
                {count = 10, gap = 0.65, mix = {{type="grunt", w=1.0}}},
                {count = 14, gap = 0.55, mix = {{type="grunt", w=0.75}, {type="runner", w=0.25}}},
                {count = 16, gap = 0.55, mix = {{type="grunt", w=0.6}, {type="runner", w=0.4}}},
                {count = 14, gap = 0.65, mix = {{type="grunt", w=0.55}, {type="tank", w=0.45}}},
                {count = 14, gap = 0.6, mix = {{type="grunt", w=0.5}, {type="splitter", w=0.3}, {type="runner", w=0.2}}},
                {count = 20, gap = 0.48, mix = {{type="grunt", w=0.5}, {type="runner", w=0.35}, {type="tank", w=0.15}}},
                {count = 20, gap = 0.45, mix = {{type="tank", w=0.4}, {type="splitter", w=0.4}, {type="runner", w=0.2}}},
            },

            bosses = {
                [10] = {type = "boss", hpBase = 1.35, hpRamp = 3.0, spdRamp = 0.08, addTrickle = true},
            },
        },
	},

	{
		id = "centerpull",
		name = "Center Pull",
		path = {
			{1, 8}, {10, 8},
			{10, 3}, {16, 3},
			{16, 13}, {10, 13},
			{10, 8}, {26, 8},
		},

		waves = {
            normal = {
                {count = 10, gap = 0.65, mix = {{type="grunt", w=1.0}}},
                {count = 14, gap = 0.55, mix = {{type="grunt", w=0.75}, {type="runner", w=0.25}}},
                {count = 16, gap = 0.55, mix = {{type="grunt", w=0.6}, {type="runner", w=0.4}}},
                {count = 14, gap = 0.65, mix = {{type="grunt", w=0.55}, {type="tank", w=0.45}}},
                {count = 14, gap = 0.6, mix = {{type="grunt", w=0.5}, {type="splitter", w=0.3}, {type="runner", w=0.2}}},
                {count = 20, gap = 0.48, mix = {{type="grunt", w=0.5}, {type="runner", w=0.35}, {type="tank", w=0.15}}},
                {count = 20, gap = 0.45, mix = {{type="tank", w=0.4}, {type="splitter", w=0.4}, {type="runner", w=0.2}}},
            },

            bosses = {
                [10] = {type = "boss", hpBase = 1.35, hpRamp = 3.0, spdRamp = 0.08, addTrickle = true},
            },
        },
	},

	{
		id = "snakepit",
		name = "Snake Pit",
		path = {
			{1, 4}, {22, 4},
			{22, 6}, {4, 6},
			{4, 8}, {22, 8},
			{22, 10}, {4, 10},
			{4, 12}, {26, 12},
		},

		waves = {
            normal = {
                {count = 10, gap = 0.65, mix = {{type="grunt", w=1.0}}},
                {count = 14, gap = 0.55, mix = {{type="grunt", w=0.75}, {type="runner", w=0.25}}},
                {count = 16, gap = 0.55, mix = {{type="grunt", w=0.6}, {type="runner", w=0.4}}},
                {count = 14, gap = 0.65, mix = {{type="grunt", w=0.55}, {type="tank", w=0.45}}},
                {count = 14, gap = 0.6, mix = {{type="grunt", w=0.5}, {type="splitter", w=0.3}, {type="runner", w=0.2}}},
                {count = 20, gap = 0.48, mix = {{type="grunt", w=0.5}, {type="runner", w=0.35}, {type="tank", w=0.15}}},
                {count = 20, gap = 0.45, mix = {{type="tank", w=0.4}, {type="splitter", w=0.4}, {type="runner", w=0.2}}},
            },

            bosses = {
                [10] = {type = "boss", hpBase = 1.35, hpRamp = 3.0, spdRamp = 0.08, addTrickle = true},
            },
        },
	},

	{
		id = "doublebend",
		name = "Double Bend",
		path = {
			{1, 6}, {12, 6},
			{12, 10}, {20, 10},
			{20, 4}, {26, 4},
		},

		waves = {
            normal = {
                {count = 10, gap = 0.65, mix = {{type="grunt", w=1.0}}},
                {count = 14, gap = 0.55, mix = {{type="grunt", w=0.75}, {type="runner", w=0.25}}},
                {count = 16, gap = 0.55, mix = {{type="grunt", w=0.6}, {type="runner", w=0.4}}},
                {count = 14, gap = 0.65, mix = {{type="grunt", w=0.55}, {type="tank", w=0.45}}},
                {count = 14, gap = 0.6, mix = {{type="grunt", w=0.5}, {type="splitter", w=0.3}, {type="runner", w=0.2}}},
                {count = 20, gap = 0.48, mix = {{type="grunt", w=0.5}, {type="runner", w=0.35}, {type="tank", w=0.15}}},
                {count = 20, gap = 0.45, mix = {{type="tank", w=0.4}, {type="splitter", w=0.4}, {type="runner", w=0.2}}},
            },

            bosses = {
                [10] = {type = "boss", hpBase = 1.35, hpRamp = 3.0, spdRamp = 0.08, addTrickle = true},
            },
        },
	},

	{
		id = "offsetloop",
		name = "Offset Loop",
		path = {
			{1, 7}, {14, 7},
			{14, 3}, {22, 3},
			{22, 13}, {6, 13},
			{6, 7}, {26, 7},
		},

		waves = {
            normal = {
                {count = 10, gap = 0.65, mix = {{type="grunt", w=1.0}}},
                {count = 14, gap = 0.55, mix = {{type="grunt", w=0.75}, {type="runner", w=0.25}}},
                {count = 16, gap = 0.55, mix = {{type="grunt", w=0.6}, {type="runner", w=0.4}}},
                {count = 14, gap = 0.65, mix = {{type="grunt", w=0.55}, {type="tank", w=0.45}}},
                {count = 14, gap = 0.6, mix = {{type="grunt", w=0.5}, {type="splitter", w=0.3}, {type="runner", w=0.2}}},
                {count = 20, gap = 0.48, mix = {{type="grunt", w=0.5}, {type="runner", w=0.35}, {type="tank", w=0.15}}},
                {count = 20, gap = 0.45, mix = {{type="tank", w=0.4}, {type="splitter", w=0.4}, {type="runner", w=0.2}}},
            },

            bosses = {
                [10] = {type = "boss", hpBase = 1.35, hpRamp = 3.0, spdRamp = 0.08, addTrickle = true},
            },
        },
	},

	{
		id = "sidewinder",
		name = "Sidewinder",
		path = {
			{1, 4}, {20, 4},
			{20, 8}, {8, 8},
			{8, 12}, {22, 12},
			{22, 8}, {26, 8},
		},

		waves = {
            normal = {
                {count = 10, gap = 0.65, mix = {{type="grunt", w=1.0}}},
                {count = 14, gap = 0.55, mix = {{type="grunt", w=0.75}, {type="runner", w=0.25}}},
                {count = 16, gap = 0.55, mix = {{type="grunt", w=0.6}, {type="runner", w=0.4}}},
                {count = 14, gap = 0.65, mix = {{type="grunt", w=0.55}, {type="tank", w=0.45}}},
                {count = 14, gap = 0.6, mix = {{type="grunt", w=0.5}, {type="splitter", w=0.3}, {type="runner", w=0.2}}},
                {count = 20, gap = 0.48, mix = {{type="grunt", w=0.5}, {type="runner", w=0.35}, {type="tank", w=0.15}}},
                {count = 20, gap = 0.45, mix = {{type="tank", w=0.4}, {type="splitter", w=0.4}, {type="runner", w=0.2}}},
            },

            bosses = {
                [10] = {type = "boss", hpBase = 1.35, hpRamp = 3.0, spdRamp = 0.08, addTrickle = true},
            },
        },
	},

	{
		id = "crosscurrent",
		name = "Crosscurrent",
		path = {
			{1, 6}, {24, 6},
			{24, 10}, {4, 10},
			{4, 8}, {20, 8},
			{20, 12}, {26, 12},
		},

		waves = {
            normal = {
                {count = 10, gap = 0.65, mix = {{type="grunt", w=1.0}}},
                {count = 14, gap = 0.55, mix = {{type="grunt", w=0.75}, {type="runner", w=0.25}}},
                {count = 16, gap = 0.55, mix = {{type="grunt", w=0.6}, {type="runner", w=0.4}}},
                {count = 14, gap = 0.65, mix = {{type="grunt", w=0.55}, {type="tank", w=0.45}}},
                {count = 14, gap = 0.6, mix = {{type="grunt", w=0.5}, {type="splitter", w=0.3}, {type="runner", w=0.2}}},
                {count = 20, gap = 0.48, mix = {{type="grunt", w=0.5}, {type="runner", w=0.35}, {type="tank", w=0.15}}},
                {count = 20, gap = 0.45, mix = {{type="tank", w=0.4}, {type="splitter", w=0.4}, {type="runner", w=0.2}}},
            },

            bosses = {
                [10] = {type = "boss", hpBase = 1.35, hpRamp = 3.0, spdRamp = 0.08, addTrickle = true},
            },
        },
	},
}

return maps
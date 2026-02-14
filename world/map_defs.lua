local maps = {
    {
        id = "alpha",
        nameKey = "map.alpha",
		path = {
			{4, 8}, {13, 8},
			{13, 4}, {19, 4},
			{19, 12}, {15, 12},
			{15, 6}, {21, 6},
			{21, 8}, {31, 8},
		},
    },

    {
		id = "spiral",
		nameKey = "map.spiral",
		path = {
			{4, 8}, {15, 8},
			{15, 4}, {21, 4},
			{21, 12}, {11, 12},
			{11, 6}, {31, 6},
		},
    },

    {
		id = "zigzag",
		nameKey = "map.zigzag",
		path = {
			{4, 6}, {21, 6},
			{21, 12}, {10, 12},
			{10, 4}, {23, 4},
			{23, 10}, {31, 10},
		},
    },

	{
		id = "turntable",
		nameKey = "map.turntable",
		path = {
			{4, 10}, {12, 10},
			{12, 4}, {18, 4},
			{18, 10}, {25, 10},
			{25, 7}, {15, 7},
			{15, 12}, {31, 12},
		},
	},

	{
		id = "gauntlet",
		nameKey = "map.gauntlet",
		path = {
			{4, 12},  {19, 12},
			{19, 8}, {24, 8},
			{24, 4}, {11, 4},
			{11, 10}, {31, 10},
		},
	},

	{
		id = "hairpins",
		nameKey = "map.hairpins",
		path = {
			{4, 10}, {16, 10},
			{16, 7}, {10, 7},
			{10, 4}, {21, 4},
			{21, 12}, {26, 12},
			{26, 10}, {19, 10},
			{19, 8}, {31, 8},
		},
	},

	--[[{
		id = "centerpull",
		nameKey = "map.centerpull",
		path = {
			{4, 8}, {20, 8},
			{20, 4}, {10, 4},
			{10, 12}, {24, 12},
			{24, 6}, {31, 6},
		},
	},]]

	{
		id = "centerpull",
		nameKey = "map.centerpull",
		path = {
			{4, 8}, {16, 8},
			{16, 4}, {10, 4},
			{10, 12}, {25, 12},
			{25, 4}, {19, 4},
			{19, 6}, {31, 6},
		},
	},

	{
		id = "snakepit",
		nameKey = "map.snakepit",
		path = {
			{4, 6}, {17, 6},
			{17, 4}, {25, 4},
			{25, 9}, {11, 9},
			{11, 12}, {22, 12},
			{22, 7}, {31, 7},
		},
	},

	--[[{
		id = "doublebend",
		nameKey = "map.doublebend",
		path = {
			{4, 7}, {13, 7},
			{13, 12}, {22, 12},
			{22, 8}, {16, 8},
			{16, 4}, {25, 4},
			{25, 7}, {31, 7},
		},
	},]]

	{
		id = "doublebend",
		nameKey = "map.doublebend",
		path = {
			{4, 7},   {11, 7},     -- entry sweep (mid row)
			{11, 11},              -- rise
			{23, 11},              -- short top push
			{23, 7},               -- drop past entry row (offset)
			{13, 7},               -- mid return (different row than entry)
			{13, 4},               -- small drop
			{25, 4},               -- bottom sweep right
			{25, 7},               -- climb to exit row
			{31, 7},               -- exit
		},
	},

	{
		id = "offsetloop",
		nameKey = "map.offsetloop",
		path = {
			{4, 7}, {14, 7},
			{14, 12}, {22, 12},
			{22, 4}, {10, 4},
			{10, 9}, {28, 9},
			{28, 4}, {31, 4},
		},
	},

	{
		id = "sidewinder",
		nameKey = "map.sidewinder",
		path = {
			{4, 4}, {14, 4},
			{14, 12}, {20, 12},
			{20, 6}, {10, 6},
			{10, 9}, {24, 9},
			{24, 6}, {31, 6},
		},
	},

	{
		id = "ridge",
		nameKey = "map.ridge",
		path = {
			{4, 6}, {12, 6},
			{12, 4}, {20, 4},
			{20, 9}, {10, 9},
			{10, 12}, {24, 12},
			{24, 7}, {31, 7},
		},
	},

	-- Trailer usage, don't ship this
	{
		ignore = true,
		id = "line",
		nameKey = "map.line",
		path = {
			{4, 8}, {31, 8},
		},
	},
}

return maps
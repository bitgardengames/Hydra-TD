local maps = {
	{
		id = "riverbend",
		nameKey = "map.riverbend",
		biome = "winter",
		path = {
			{5, 7}, {13, 7},
			{13, 3}, {19, 3},
			{19, 11}, {15, 11},
			{15, 5}, {21, 5},
			{21, 7}, {30, 7},
		},
		water = {
			-- river banks
			{7, 5, 2},
			{8, 6, 2},
			{9, 5, 1},

			-- downstream basin
			{22, 8, 2},
			{23, 8, 2},
			{23, 9, 1},
		}
	},

	{
		id = "switchback",
		nameKey = "map.switchback",
		biome = "default",
		path = {
			{5, 7}, {15, 7},
			{15, 3}, {21, 3},
			{21, 11}, {11, 11},
			{11, 5}, {30, 5},
		},
		-- dry mountain pass
	},

	{
		id = "highpass",
		nameKey = "map.highpass",
		biome = "highlands",
		path = {
			{5, 5}, {21, 5},
			{21, 11}, {10, 11},
			{10, 3}, {23, 3},
			{23, 9}, {30, 9},
		},
		water = {
			-- alpine pool
			{6, 2, 2},
			{7, 2, 1},
		}
	},

	{
		id = "roundabout",
		nameKey = "map.roundabout",
		biome = "default",
		path = {
			{5, 9}, {12, 9},
			{12, 3}, {18, 3},
			{18, 9}, {25, 9},
			{25, 6}, {15, 6},
			{15, 11}, {30, 11},
		},
		water = {
			-- central pond
			{16, 7, 2},
		}
	},

	{
		id = "gauntlet",
		nameKey = "map.gauntlet",
		biome = "drylands",
		path = {
			{5, 11}, {19, 11},
			{19, 7}, {24, 7},
			{24, 3}, {11, 3},
			{11, 9}, {30, 9},
		},
		-- intentionally dry battlefield
	},

	{
		id = "snaketrail",
		nameKey = "map.snaketrail",
		biome = "drylands",
		path = {
			{5, 9}, {16, 9},
			{16, 6}, {10, 6},
			{10, 3}, {21, 3},
			{21, 11}, {26, 11},
			{26, 9}, {19, 9},
			{19, 7}, {30, 7},
		},
		water = {
			-- swamp edges
			{7, 10, 2},
			{8, 10, 1},

			-- marsh basin
			{23, 4, 2},
		}
	},

	{
		id = "backtrack",
		nameKey = "map.backtrack",
		biome = "autumn",
		path = {
			{5, 7}, {16, 7},
			{16, 3}, {10, 3},
			{10, 11}, {25, 11},
			{25, 3}, {19, 3},
			{19, 5}, {30, 5},
		},
		water = {
			-- central pond
			{14, 9, 2},
		}
	},

	{
		id = "lowvalley",
		nameKey = "map.lowvalley",
		biome = "autumn",
		path = {
			{5, 5}, {17, 5},
			{17, 3}, {25, 3},
			{25, 8}, {11, 8},
			{11, 11}, {22, 11},
			{22, 6}, {30, 6},
		},
		water = {
			-- main valley lake
			{7, 8, 2},
			{8, 9, 2},
			{9, 8, 1},

			-- small creek
			{26, 5, 2},
		}
	},

	{
		id = "circuit",
		nameKey = "map.circuit",
		biome = "drylands",
		path = {
			{5, 6}, {11, 6},
			{11, 10}, {23, 10},
			{23, 5}, {18, 5},
			{18, 8}, {13, 8},
			{13, 3}, {25, 3},
			{25, 6}, {30, 6},
		},
		water = {
			-- corner pond
			{7, 3, 2},

			-- opposite corner
			{26, 10, 2},
		}
	},

	{
		id = "outerloop",
		nameKey = "map.outerloop",
		biome = "highlands",
		path = {
			{5, 6}, {14, 6},
			{14, 11}, {22, 11},
			{22, 3}, {10, 3},
			{10, 8}, {28, 8},
			{28, 3}, {30, 3},
		},
		water = {
			-- outer pond
			{7, 10, 2},
			{8, 10, 1},
		}
	},

	{
		id = "terrace",
		nameKey = "map.terrace",
		biome = "autumn",
		path = {
			{5, 3}, {14, 3},
			{14, 11}, {20, 11},
			{20, 5}, {10, 5},
			{10, 8}, {24, 8},
			{24, 5}, {30, 5},
		},
		water = {
			-- terrace basin
			{6, 9, 2},

			-- cliffside pool
			{27, 3, 2},
		}
	},

	{
		id = "highridge",
		nameKey = "map.highridge",
		biome = "highlands",
		path = {
			{5, 5}, {12, 5},
			{12, 3}, {20, 3},
			{20, 8}, {10, 8},
			{10, 11}, {24, 11},
			{24, 6}, {30, 6},
		},
		-- dry ridge terrain
	},

	{
		id = "crossflow",
		nameKey = "map.crossflow",
		biome = "autumn",
		path = {
			{5, 6}, {12, 6},
			{12, 11}, {20, 11},
			{20, 3}, {15, 3},
			{15, 8}, {23, 8},
			{23, 5}, {30, 5},
		},
		water = {
			-- crossing stream
			{9, 4, 2},
			{10, 4, 1},

			-- downstream pool
			{21, 9, 2},
		}
	},

	{
		id = "steppingstones",
		nameKey = "map.steppingstones",
		biome = "winter",
		path = {
			{5, 5}, {14, 5},
			{14, 8}, {10, 8},
			{10, 11}, {22, 11},
			{22, 6}, {17, 6},
			{17, 3}, {25, 3},
			{25, 8}, {30, 8},
		},
		water = {
			-- stream channel
			{12, 6, 2},

			-- broken pool
			{19, 7, 2},
		}
	},

	{
		id = "twinloop",
		nameKey = "map.twinloop",
		biome = "winter",
		path = {
			{5, 7}, {12, 7},
			{12, 3}, {20, 3},
			{20, 7}, {12, 7},
			{12, 11}, {24, 11},
			{24, 5}, {30, 5},
		},
		water = {
			-- asymmetric mirrored ponds
			{8, 4, 2},
			{23, 10, 2},
		}
	},
}

return maps
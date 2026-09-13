-- Campaign map order and authored layouts
local maps = {
	{
		id = "riverbend",
		nameKey = "map.riverbend",
		biome = "default",
		path = {
			{5, 7}, {13, 7},
			{13, 3}, {19, 3},
			{19, 11}, {15, 11},
			{15, 5}, {21, 5},
			{21, 7}, {30, 7},
		},
	},

	{
		id = "switchback",
		nameKey = "map.switchback",
		biome = "highlands",
		path = {
			{5, 7}, {15, 7},
			{15, 3}, {21, 3},
			{21, 11}, {11, 11},
			{11, 5}, {30, 5},
		},
	},

	{
		id = "highpass",
		nameKey = "map.highpass",
		biome = "default",
		path = {
			{5, 5}, {21, 5},
			{21, 11}, {10, 11},
			{10, 3}, {23, 3},
			{23, 9}, {30, 9},
		},
	},

	{
		id = "outerloop",
		nameKey = "map.outerloop",
		biome = "drylands",
		path = {
			{5, 6}, {14, 6},
			{14, 11}, {22, 11},
			{22, 3}, {10, 3},
			{10, 8}, {28, 8},
			{28, 3}, {30, 3},
		},
	},

	{
		id = "gauntlet",
		nameKey = "map.gauntlet",
		biome = "autumn",
		path = {
			{5, 11}, {19, 11},
			{19, 7}, {24, 7},
			{24, 3}, {11, 3},
			{11, 9}, {30, 9},
		},
	},

	{
		id = "snaketrail",
		nameKey = "map.snaketrail",
		biome = "default",
		path = {
			{5, 9}, {16, 9},
			{16, 6}, {10, 6},
			{10, 3}, {21, 3},
			{21, 11}, {26, 11},
			{26, 9}, {19, 9},
			{19, 7}, {30, 7},
		},
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
	},

	{
		id = "lowvalley",
		nameKey = "map.lowvalley",
		biome = "drylands",
		path = {
			{5, 5}, {17, 5},
			{17, 3}, {25, 3},
			{25, 8}, {11, 8},
			{11, 11}, {22, 11},
			{22, 6}, {30, 6},
		},
	},

	{
		id = "circuit",
		nameKey = "map.circuit",
		biome = "default",
		path = {
			{5, 6}, {11, 6},
			{11, 10}, {23, 10},
			{23, 5}, {18, 5},
			{18, 8}, {13, 8},
			{13, 3}, {25, 3},
			{25, 6}, {30, 6},
		},
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
	},

	{
		id = "terrace",
		nameKey = "map.terrace",
		biome = "drylands",
		path = {
			{5, 3}, {14, 3},
			{14, 11}, {20, 11},
			{20, 5}, {10, 5},
			{10, 8}, {24, 8},
			{24, 5}, {30, 5},
		},
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
	},

	{
		id = "crossflow",
		nameKey = "map.crossflow",
		biome = "winter",
		path = {
			{5, 6}, {12, 6},
			{12, 11}, {20, 11},
			{20, 3}, {15, 3},
			{15, 8}, {23, 8},
			{23, 5}, {30, 5},
		},
	},

	{
		id = "steppingstones",
		nameKey = "map.steppingstones",
		biome = "autumn",
		path = {
			{5, 5}, {14, 5},
			{14, 8}, {10, 8},
			{10, 11}, {22, 11},
			{22, 6}, {17, 6},
			{17, 3}, {25, 3},
			{25, 8}, {30, 8},
		},
	},

	{
		id = "twinloop",
		prerequisiteMapId = "steppingstones",
		nameKey = "map.twinloop",
		biome = "winter",
		path = {
			{5, 7}, {12, 7},
			{12, 3}, {20, 3},
			{20, 7}, {12, 7},
			{12, 11}, {24, 11},
			{24, 5}, {30, 5},
		},
	},
}

return maps
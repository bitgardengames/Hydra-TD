local maps = {

{
	id = "riverbend",
	nameKey = "map.riverbend",
	palette = "default",
	path = {
		{4, 8}, {13, 8},
		{13, 4}, {19, 4},
		{19, 12}, {15, 12},
		{15, 6}, {21, 6},
		{21, 8}, {31, 8},
	},
	water = {
		-- river banks
		{7, 6, 2},
		{8, 7, 2},
		{9, 6, 1},

		-- downstream basin
		{22, 9, 2},
		{23, 9, 2},
		{23, 10, 1},
	}
},

{
	id = "switchback",
	nameKey = "map.switchback",
	palette = "highlands",
	path = {
		{4, 8}, {15, 8},
		{15, 4}, {21, 4},
		{21, 12}, {11, 12},
		{11, 6}, {31, 6},
	},
	-- dry mountain pass
},

{
	id = "highpass",
	nameKey = "map.highpass",
	palette = "highlands",
	path = {
		{4, 6}, {21, 6},
		{21, 12}, {10, 12},
		{10, 4}, {23, 4},
		{23, 10}, {31, 10},
	},
	water = {
		-- alpine pool
		{6, 3, 2},
		{7, 3, 1},
	}
},

{
	id = "roundabout",
	nameKey = "map.roundabout",
	palette = "default",
	path = {
		{4, 10}, {12, 10},
		{12, 4}, {18, 4},
		{18, 10}, {25, 10},
		{25, 7}, {15, 7},
		{15, 12}, {31, 12},
	},
	water = {
		-- central pond
		{16, 8, 2},
	}
},

{
	id = "gauntlet",
	nameKey = "map.gauntlet",
	palette = "drylands",
	path = {
		{4, 12}, {19, 12},
		{19, 8}, {24, 8},
		{24, 4}, {11, 4},
		{11, 10}, {31, 10},
	},
	-- intentionally dry battlefield
},

{
	id = "snaketrail",
	nameKey = "map.snaketrail",
	palette = "coastal",
	path = {
		{4, 10}, {16, 10},
		{16, 7}, {10, 7},
		{10, 4}, {21, 4},
		{21, 12}, {26, 12},
		{26, 10}, {19, 10},
		{19, 8}, {31, 8},
	},
	water = {
		-- swamp edges
		{7, 11, 2},
		{8, 11, 1},

		-- marsh basin
		{23, 5, 2},
	}
},

{
	id = "backtrack",
	nameKey = "map.backtrack",
	palette = "default",
	path = {
		{4, 8}, {16, 8},
		{16, 4}, {10, 4},
		{10, 12}, {25, 12},
		{25, 4}, {19, 4},
		{19, 6}, {31, 6},
	},
	water = {
		-- central pond
		{14, 10, 2},
	}
},

{
	id = "lowvalley",
	nameKey = "map.lowvalley",
	palette = "coastal",
	path = {
		{4, 6}, {17, 6},
		{17, 4}, {25, 4},
		{25, 9}, {11, 9},
		{11, 12}, {22, 12},
		{22, 7}, {31, 7},
	},
	water = {
		-- main valley lake
		{7, 9, 2},
		{8, 10, 2},
		{9, 9, 1},

		-- small creek
		{26, 6, 2},
	}
},

{
	id = "circuit",
	nameKey = "map.circuit",
	palette = "drylands",
	path = {
		{4, 7}, {11, 7},
		{11, 11}, {23, 11},
		{23, 6}, {18, 6},
		{18, 9}, {13, 9},
		{13, 4}, {25, 4},
		{25, 7}, {31, 7},
	},
	water = {
		-- corner pond
		{7, 4, 2},

		-- opposite corner
		{26, 11, 2},
	}
},

{
	id = "outerloop",
	nameKey = "map.outerloop",
	palette = "highlands",
	path = {
		{4, 7}, {14, 7},
		{14, 12}, {22, 12},
		{22, 4}, {10, 4},
		{10, 9}, {28, 9},
		{28, 4}, {31, 4},
	},
	water = {
		-- outer pond
		{7, 11, 2},
		{8, 11, 1},
	}
},

{
	id = "terrace",
	nameKey = "map.terrace",
	palette = "coastal",
	path = {
		{4, 4}, {14, 4},
		{14, 12}, {20, 12},
		{20, 6}, {10, 6},
		{10, 9}, {24, 9},
		{24, 6}, {31, 6},
	},
	water = {
		-- terrace basin
		{6, 10, 2},

		-- cliffside pool
		{27, 4, 2},
	}
},

{
	id = "highridge",
	nameKey = "map.highridge",
	palette = "highlands",
	path = {
		{4, 6}, {12, 6},
		{12, 4}, {20, 4},
		{20, 9}, {10, 9},
		{10, 12}, {24, 12},
		{24, 7}, {31, 7},
	},
	-- dry ridge terrain
},

{
	id = "crossflow",
	nameKey = "map.crossflow",
	palette = "default",
	path = {
		{4, 7}, {12, 7},
		{12, 12}, {20, 12},
		{20, 4}, {15, 4},
		{15, 9}, {23, 9},
		{23, 6}, {31, 6},
	},
	water = {
		-- crossing stream
		{9, 5, 2},
		{10, 5, 1},

		-- downstream pool
		{21, 10, 2},
	}
},

{
	id = "steppingstones",
	nameKey = "map.steppingstones",
	palette = "coastal",
	path = {
		{4, 6}, {14, 6},
		{14, 9}, {10, 9},
		{10, 12}, {22, 12},
		{22, 7}, {17, 7},
		{17, 4}, {25, 4},
		{25, 9}, {31, 9},
	},
	water = {
		-- stream channel
		{12, 7, 2},

		-- broken pool
		{19, 8, 2},
	}
},

{
	id = "twinloop",
	nameKey = "map.twinloop",
	palette = "default",
	path = {
		{4, 8}, {12, 8},
		{12, 4}, {20, 4},
		{20, 8}, {12, 8},
		{12, 12}, {24, 12},
		{24, 6}, {31, 6},
	},
	water = {
		-- asymmetric mirrored ponds
		{8, 5, 2},
		{23, 11, 2},
	}
},

}

return maps
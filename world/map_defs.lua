-- Campaign map order and authored layouts. Unlock rewards live in systems/campaign_unlocks.lua.
local maps = {
	{
		id = "riverbend",
		campaignStage = 1,
		nameKey = "map.riverbend",
		introducesEnemies = {"grunt"},
		biome = "default",
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
		campaignStage = 1,
		nameKey = "map.switchback",
		-- Bring durable enemies into the first campaign chapter so players start
		-- making target-priority decisions immediately after the onboarding map.
		introducesEnemies = {"tank"},
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
		campaignStage = 1,
		nameKey = "map.highpass",
		-- Runners follow one map later, adding a contrasting fast threat while the
		-- tank lesson is still fresh.
		introducesEnemies = {"runner"},
		biome = "default",
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
		id = "outerloop",
		campaignStage = 1,
		nameKey = "map.outerloop",
		biome = "drylands",
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
		id = "gauntlet",
		campaignStage = 1,
		nameKey = "map.gauntlet",
		biome = "autumn",
		path = {
			{5, 11}, {19, 11},
			{19, 7}, {24, 7},
			{24, 3}, {11, 3},
			{11, 9}, {30, 9},
		},
		-- intentionally dry battlefield
		waves = {
			encounters = {
				boss_displacement = { flankKind = "grunt", flankBurst = 2, initialDelay = 2.0 },
			},
		},
	},

	{
		id = "snaketrail",
		campaignStage = 2,
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
		campaignStage = 2,
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
		campaignStage = 2,
		nameKey = "map.lowvalley",
		-- Low Valley is the campaign's first Bulwark encounter.
		introducesEnemies = {"bulwark"},
		biome = "drylands",
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
		campaignStage = 2,
		nameKey = "map.circuit",
		-- Circuit is the campaign's first Regenerator encounter.
		introducesEnemies = {"regenerator"},
		biome = "default",
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
		id = "roundabout",
		campaignStage = 2,
		nameKey = "map.roundabout",
		biome = "highlands",
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
		},
		waves = {
			encounters = {
				boss_displacement = { flankKind = "grunt", flankBurst = 3, interval = 5.4, maxAliveAdds = 16 },
				boss_summoner = { flankKind = "grunt", flankBurst = 5, interval = 5.2 },
			},
		},
	},

	{
		id = "terrace",
		campaignStage = 3,
		nameKey = "map.terrace",
		introducesEnemies = {"warcaller"},
		biome = "winter",
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
		},
		waves = {
			encounters = {
				boss_summoner = { flankBurst = 4, interval = 6.5, maxTotalAdds = 40 },
			},
		},
	},

	{
		id = "highridge",
		-- The finale begins with staggered mixed formations.
		campaignStage = 3,
		nameKey = "map.highridge",
		-- High Ridge teaches staggered mixed-wave timing: durable fronts create
		-- openings for faster enemies to pressure the exit.
		introducesEnemies = {},
		biome = "default",
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
		-- Crossflow escalates High Ridge's lesson with tighter, overlapping groups.
		campaignStage = 3,
		nameKey = "map.crossflow",
		biome = "winter",
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
		-- Stepping Stones uses separated pockets to demand deliberate ability timing
		-- before the final map.
		campaignStage = 3,
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
		water = {
			-- stream channel
			{12, 6, 2},

			-- broken pool
			{19, 7, 2},
		}
	},

	{
		id = "twinloop",
		-- Twin Loop is the campaign's final exam: earlier enemy archetypes share the
		-- route with Summoners and its two-loop pressure cycle.
		prerequisiteMapId = "steppingstones",
		campaignStage = 3,
		nameKey = "map.twinloop",
		introducesEnemies = {"summoner"},
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

	{
		id = "frostgate",
		prerequisiteMapId = "twinloop",
		campaignStage = 4,
		nameKey = "map.frostgate",
		-- A long frozen choke tests sustained damage against armored columns.
		biome = "winter",
		path = {
			{5, 4}, {15, 4},
			{15, 10}, {9, 10},
			{9, 7}, {23, 7},
			{23, 3}, {27, 3},
			{27, 9}, {30, 9},
		},
		water = {
			-- Frozen reservoirs divide the long central firing lane.
			{7, 6, 2}, {18, 9, 2}, {25, 11, 1},
		},
	},

	{
		id = "tidelock",
		prerequisiteMapId = "frostgate",
		campaignStage = 4,
		nameKey = "map.tidelock",
		-- Short returning lanes make target switching and support priority decisive.
		biome = "autumn",
		path = {
			{5, 9}, {13, 9},
			{13, 3}, {20, 3},
			{20, 11}, {10, 11},
			{10, 6}, {25, 6},
			{25, 9}, {30, 9},
		},
		water = {
			-- A broad lock and offset spillway constrain the two best build pockets.
			{16, 7, 3}, {22, 9, 2}, {7, 3, 1},
		},
		waves = {
			-- The first boss sends quick pressure through the short return lanes;
			-- the second replaces speed with support escorts that repeatedly ask the
			-- player to switch priority away from the Summoner.
			encounters = {
				[1] = { flankKind = "runner", flankBurst = 3, interval = 5.6, initialDelay = 2.2,
					maxAliveAdds = 12, maxTotalAdds = 28, addSpdMult = 1.2 },
				[2] = { flankKind = "warcaller", flankBurst = 2, interval = 6.4, initialDelay = 3.0,
					maxAliveAdds = 8, maxTotalAdds = 20, addHpMult = 0.85, addSpdMult = 0.95 },
			},
		},
	},

	{
		id = "ashspiral",
		prerequisiteMapId = "tidelock",
		campaignStage = 4,
		nameKey = "map.ashspiral",
		-- The finale compresses every enemy role into an inward spiral with few resets.
		biome = "drylands",
		path = {
			{5, 3}, {27, 3},
			{27, 11}, {9, 11},
			{9, 6}, {23, 6},
			{23, 9}, {14, 9},
			{14, 5}, {30, 5},
		},
		water = {
			-- Sparse oases deny easy coverage at the spiral's outer corners.
			{6, 8, 1}, {18, 7, 2}, {28, 9, 1},
		},
	},
}

return maps

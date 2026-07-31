local Constants = {}

-- Build
Constants.IS_DEMO = false

-- Version
Constants.VERSION = "1.2.0" -- major.minor.patch
Constants.BUILD = 19
Constants.VERSION_STRING = string.format("v%s (build %d)%s", Constants.VERSION, Constants.BUILD, Constants.IS_DEMO and " - Demo" or "")

-- Display
Constants.TILE = 56
Constants.GRID_W = 32
Constants.GRID_H = 14
Constants.UI_H = 155
Constants.TOWER_RETARGET_INTERVAL = 0.10

-- A 20-wave campaign awards 24 points: 20 completions, two elite bonuses
-- (waves 5/15), and two boss bonuses (waves 10/20).
Constants.TALENT_POINTS_PER_WAVE = 1
Constants.TALENT_ELITE_INTERVAL = 5
Constants.TALENT_BOSS_INTERVAL = 10
Constants.TALENT_POINTS_PER_ELITE = 1
Constants.TALENT_POINTS_PER_BOSS = 1
Constants.NORMAL_RUN_TALENT_BUDGET = 24

Constants.TOWER_LIST = {
	"slow",
	"lancer",
	"poison",
	"cannon",
	"shock",
	"plasma",
}

return Constants

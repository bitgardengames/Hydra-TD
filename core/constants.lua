local Constants = {}

-- Build
Constants.IS_DEMO = false

-- Version
Constants.VERSION = "1.1.0" -- major.minor.patch
Constants.BUILD = 12
Constants.VERSION_STRING = string.format("v%s (build %d)%s", Constants.VERSION, Constants.BUILD, Constants.IS_DEMO and " - Demo" or "")

-- Display
Constants.TILE = 56
Constants.GRID_W = 32
Constants.GRID_H = 14
Constants.UI_H = 155

Constants.TOWER_LIST = {
	"slow",
	"lancer",
	"poison",
	"cannon",
	"shock",
	"plasma",
}

return Constants
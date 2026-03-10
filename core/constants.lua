local Constants = {}

-- Build
Constants.IS_DEMO = false

-- Version
Constants.VERSION = "1.0.5" -- major.minor.patch
Constants.BUILD = 6
Constants.VERSION_STRING = string.format("v%s (build %d)%s", Constants.VERSION, Constants.BUILD, Constants.IS_DEMO and " - Demo" or "")

-- Display
Constants.TILE = 56
Constants.GRID_W = 34
Constants.GRID_H = 16
Constants.UI_H = 155

return Constants
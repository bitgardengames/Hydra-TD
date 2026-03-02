local Constants = {}

-- Version
Constants.VERSION = "1.0.1" -- major.minor.patch
Constants.BUILD = 2
Constants.VERSION_STRING = string.format("v%s (build %d)", Constants.VERSION, Constants.BUILD)

-- Display
Constants.TILE = 56
Constants.GRID_W = 34
Constants.GRID_H = 16
Constants.UI_H = 144
Constants.SCREEN_W = Constants.GRID_W * Constants.TILE
Constants.SCREEN_H = Constants.GRID_H * Constants.TILE + Constants.UI_H

return Constants
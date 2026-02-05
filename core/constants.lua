local Constants = {}

Constants.VERSION = "1.0.0" -- major.minor.patch
Constants.BUILD = 1
Constants.VERSION_STRING = string.format("v%s (build %d)", Constants.VERSION, Constants.BUILD)

Constants.TILE = 56
Constants.GRID_W = 34
Constants.GRID_H = 16
Constants.UI_H = 144
Constants.SCREEN_W = Constants.GRID_W * Constants.TILE
Constants.SCREEN_H = Constants.GRID_H * Constants.TILE + Constants.UI_H

return Constants
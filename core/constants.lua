local Constants = {}

Constants.TILE = 56
Constants.GRID_W = 33
Constants.GRID_H = 16
Constants.UI_H = 144
Constants.SCREEN_W = Constants.GRID_W * Constants.TILE
Constants.SCREEN_H = Constants.GRID_H * Constants.TILE + Constants.UI_H
Constants.WORLD_W = Constants.GRID_W * Constants.TILE
Constants.WORLD_H = Constants.GRID_H * Constants.TILE

return Constants
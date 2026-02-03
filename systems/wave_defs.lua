local WaveDefs = {}

WaveDefs.LAST_ANCHOR = 16

WaveDefs.anchors = {
  {
    id = 1,
    gap = 0.68,
    enemies = {grunt = 10, runner = 0, tank = 0, splitter = 0},
    ramps = {hp = 1.00, speed = 1.00},
  },

  {
    id = 4,
    gap = 0.58,
    enemies = {grunt = 8, runner = 6, tank = 0, splitter = 0},
    ramps = {hp = 2.30, speed = 1.05},
  },

  {
    id = 7,
    gap = 0.63,
    enemies = {grunt = 8, runner = 4, tank = 4, splitter = 0},
    ramps = {hp = 3.05, speed = 1.06},
  },

  {
    id = 10,
    gap = 0.61,
    enemies = {grunt = 6, runner = 6, tank = 4, splitter = 4},
    ramps = {hp = 3.95, speed = 1.07},
  },

  {
    id = 13,
    gap = 0.56,
    enemies = {grunt = 6, runner = 6, tank = 4, splitter = 4},
    ramps = {hp = 5.15, speed = 1.08},
  },

  {
    id = 16,
    gap = 0.52,
    enemies = {grunt = 4, runner = 6, tank = 6, splitter = 4},
    ramps = {hp = 6.80, speed = 1.09},
  },
}

return WaveDefs
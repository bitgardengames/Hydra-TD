local lg = love.graphics

local HeroExport = {
  active = false,

  width  = 3840,
  height = 1240,

  zoom   = 7.0,  -- 1.0 = perfect cover, >1 tighter, <1 wider
  output = "library_hero.png",

  canvas = nil,
}

-- Init
function HeroExport.init()
  HeroExport.canvas = lg.newCanvas(HeroExport.width, HeroExport.height, {msaa = 8})
end

-- Trigger capture
function HeroExport.capture()
  HeroExport.active = true
end

-- Draw
function HeroExport.draw(renderWorldFn)
  if not HeroExport.active then
    return false
  end

  local prevCanvas = lg.getCanvas()

  local scale = HeroExport.zoom

	local Camera = require("core.camera")

	lg.setCanvas(HeroExport.canvas)
	lg.clear(0, 0, 0, 0)

	local adjust = Camera.wy * 0.10

	--lg.push()
	--lg.scale(scale, scale)
	--lg.translate(-Camera.wx, -Camera.wy + adjust)

	--local sw, sh = lg.getDimensions()
	
	--local authSw = sw * 0.6
	--local authSh = sh * 0.5

	--Camera.centerOn(authSw, authSh, scale)

  -- Draw EXACT current view (camera untouched)
	renderWorldFn()

	lg.pop()
	lg.setCanvas(prevCanvas)

  -- Export
  local img = HeroExport.canvas:newImageData()
  img:encode("png", HeroExport.output)

  print("[HeroExport] Saved:", HeroExport.output)

  HeroExport.active = false
  return true
end

return HeroExport
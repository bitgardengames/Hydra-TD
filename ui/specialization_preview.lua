-- Specialization cards host the same entities and combat systems as a match.
-- This module authors only the tiny map and cast; GameplaySandbox owns isolation.
local GameplaySandbox = require("world.gameplay_sandbox")
local DrawWorld = require("render.draw_world")
local Constants = require("core.constants")
local Map = require("world.map")
local Preview = {}

local TILE = Constants.TILE
local function cast(spacing, ...)
	local kinds={...}; local result={}
	for i=1,#kinds do result[i]={kind=kinds[i],distance=(i-1)*spacing*TILE} end
	return result
end

-- Every coordinate below is a gameplay grid coordinate and every distance is
-- a world-space pixel distance. Only the camera converts the completed scene
-- to card pixels.
local lane = {{1,3},{8,3}}
local bend = {{1,2},{5,2},{5,5},{8,5}}
local straightCamera = {centerX=4.5,centerY=2.5,zoom=0.64}
local bendCamera = {centerX=4.5,centerY=3,zoom=0.55}
Preview.definitions = {
	marksman={duration=5.2,path=lane,camera=straightCamera,tower={kind="lancer",x=5,y=2},enemies={{kind="tank",hpScale=7,distance=.3*TILE},{kind="runner",hpScale=4,distance=1.4*TILE}}},
	rupture={duration=4.8,path=lane,camera=straightCamera,tower={kind="lancer",x=5,y=2},enemies=cast(.72,"grunt","grunt","grunt")},
	deep_freeze={duration=5.4,path=lane,camera=straightCamera,tower={kind="slow",x=5,y=2},enemies={{kind="tank",hpScale=7,distance=.35*TILE}}},
	cold_field={duration=5.4,path=bend,camera=bendCamera,tower={kind="slow",x=4,y=3},enemies=cast(.68,"grunt","runner","grunt","grunt")},
	virulent={duration=5.8,path=lane,camera=straightCamera,tower={kind="poison",x=5,y=2},enemies={{kind="tank",hpScale=6,distance=.3*TILE}}},
	contagion={duration=5.8,path=bend,camera=bendCamera,tower={kind="poison",x=4,y=3},enemies=cast(.65,"grunt","grunt","runner","grunt")},
	siege={duration=5.4,path=lane,camera=straightCamera,tower={kind="cannon",x=5,y=2},enemies={{kind="tank",hpScale=8,distance=.35*TILE}}},
	bombardment={duration=5.4,path=bend,camera=bendCamera,tower={kind="cannon",x=4,y=3},enemies=cast(.55,"grunt","grunt","runner","grunt","grunt")},
	capacitor={duration=5.8,path=lane,camera=straightCamera,tower={kind="shock",x=5,y=2},enemies={{kind="tank",hpScale=8,distance=.35*TILE}}},
	forked_lightning={duration=5.4,path=bend,camera=bendCamera,tower={kind="shock",x=4,y=3},enemies=cast(.62,"grunt","grunt","runner","grunt","runner")},
	accelerator={duration=5.0,path=lane,camera=straightCamera,tower={kind="plasma",x=5,y=2},enemies=cast(.75,"grunt","grunt","grunt")},
	overcharged={duration=5.8,path=bend,camera=bendCamera,tower={kind="plasma",x=4,y=3},enemies=cast(.65,"grunt","tank","grunt","runner")},
}

local function createWorld(branchId, def)
	return GameplaySandbox.new({branchId=branchId,duration=def.duration,path=def.path,tower=def.tower,enemies=def.enemies})
end

function Preview.new(branchId)
	local def=assert(Preview.definitions[branchId],"missing specialization preview: "..tostring(branchId))
	return {branchId=branchId,def=def,world=createWorld(branchId,def),elapsed=0,cycle=0,canvas=nil,canvasW=0,canvasH=0}
end
function Preview.reset(p) p.world:reset(); p.elapsed=0 end
function Preview.update(p,dt)
	if not p or dt<=0 then return end
	while dt>0 do
		local step=math.min(dt,p.def.duration-p.elapsed)
		p.world:update(step); p.elapsed=p.elapsed+step; dt=dt-step
		if p.elapsed>=p.def.duration then p.world:reset(); p.elapsed=0; p.cycle=p.cycle+1 end
	end
end

local function drawWorld(map, bounds)
	local lg=love.graphics
	-- Match the game's palette without asking the full-map grass renderer to
	-- build decorations for this deliberately tiny scene.
	lg.setColor(map.biome.terrain.grass); lg.rectangle("fill",bounds.x,bounds.y,bounds.w,bounds.h)
	DrawWorld.drawPath(map)
end
Preview.debug = false
function Preview.setDebug(enabled) Preview.debug = not not enabled end
local function drawDebug(p, bounds)
	local lg=love.graphics
	lg.setLineWidth(1)
	lg.setColor(1,1,1,.14)
	for x=math.floor(bounds.x/TILE)*TILE,bounds.x+bounds.w,TILE do lg.line(x,bounds.y,x,bounds.y+bounds.h) end
	for y=math.floor(bounds.y/TILE)*TILE,bounds.y+bounds.h,TILE do lg.line(bounds.x,y,bounds.x+bounds.w,y) end
	lg.setColor(1,.25,.2,.18); lg.setLineWidth(TILE)
	local points=p.world.map.pathWorld
	for i=1,#points-1 do lg.line(points[i][1],points[i][2],points[i+1][1],points[i+1][2]) end
	for i=1,#points do lg.circle("fill",points[i][1],points[i][2],TILE*.5) end
	lg.setColor(1,.25,.2,.9); lg.setLineWidth(2)
	for i=1,#points-1 do lg.line(points[i][1],points[i][2],points[i+1][1],points[i+1][2]) end
	local tower=p.world.towers[1]
	lg.setColor(.25,.7,1,.55); lg.circle("line",tower.x,tower.y,tower.range); lg.rectangle("line",tower.x-TILE*.5,tower.y-TILE*.5,TILE,TILE); lg.circle("fill",tower.x,tower.y,3)
	lg.print(string.format("tower (%g,%g)",tower.gx,tower.gy),tower.x+5,tower.y+5)
	for _,enemy in ipairs(p.world.enemies) do
		lg.setColor(1,.8,.2,.8); lg.circle("line",enemy.x,enemy.y,enemy.radius); lg.circle("fill",enemy.x,enemy.y,2)
		lg.print(string.format("%.1f",enemy.dist),enemy.x+enemy.radius+2,enemy.y-8)
	end
	lg.setColor(1,1,1,.7); lg.rectangle("line",bounds.x,bounds.y,bounds.w,bounds.h)
end
local clipW,clipH,clipRadius
local function drawCanvasClip() love.graphics.rectangle("fill",0,0,clipW,clipH,clipRadius,clipRadius) end
function Preview.resolveCamera(p, width, height)
	local camera=p.def.camera or {}
	if camera.centerX and camera.centerY and camera.zoom then
		local x,y=Map.gridToCenter(camera.centerX,camera.centerY)
		return x,y,camera.zoom
	end
	local minX,minY,maxX,maxY=math.huge,math.huge,-math.huge,-math.huge
	for _,point in ipairs(p.world.map.pathWorld) do
		minX=math.min(minX,point[1]-TILE*.5); minY=math.min(minY,point[2]-TILE*.5)
		maxX=math.max(maxX,point[1]+TILE*.5); maxY=math.max(maxY,point[2]+TILE*.5)
	end
	local tower=p.world.towers[1]
	minX=math.min(minX,tower.x-TILE*.5); minY=math.min(minY,tower.y-TILE*.5)
	maxX=math.max(maxX,tower.x+TILE*.5); maxY=math.max(maxY,tower.y+TILE*.5)
	local padding=camera.padding or TILE*.5
	local zoom=math.min(width/(maxX-minX+padding*2),height/(maxY-minY+padding*2))
	return (minX+maxX)*.5,(minY+maxY)*.5,zoom
end
function Preview.draw(p,x,y,w,h,radius)
	if not p or w<1 or h<1 then return end
	local lg=love.graphics; local cw,ch=math.max(1,math.floor(w+.5)),math.max(1,math.floor(h+.5))
	if not p.canvas or p.canvasW~=cw or p.canvasH~=ch then if p.canvas and p.canvas.release then p.canvas:release() end; p.canvas=lg.newCanvas(cw,ch,{dpiscale=1,msaa=8}); p.canvasW,p.canvasH=cw,ch end
	local old=lg.getCanvas(); lg.push("all"); lg.setCanvas({p.canvas,stencil=true}); lg.origin(); lg.clear(0,0,0,0)
	clipW,clipH,clipRadius=cw,ch,radius or 8; lg.stencil(drawCanvasClip,"replace",1); lg.setStencilTest("greater",0)
	local centerX,centerY,zoom=Preview.resolveCamera(p,cw,ch)
	local bounds={x=centerX-cw/(2*zoom),y=centerY-ch/(2*zoom),w=cw/zoom,h=ch/zoom}
	lg.translate(cw*.5,ch*.5); lg.scale(zoom); lg.translate(-centerX,-centerY)
	p.world:draw(function(map) drawWorld(map,bounds) end); if Preview.debug or p.def.debug then drawDebug(p,bounds) end
	lg.setStencilTest(); lg.pop(); lg.setCanvas(old)
	lg.push("all"); lg.setScissor(x,y,w,h); lg.setColor(1,1,1,1); lg.draw(p.canvas,x,y,0,w/cw,h/ch); lg.pop()
end
function Preview.release(p) if p and p.canvas and p.canvas.release then p.canvas:release() end; if p then p.canvas=nil end end
return Preview

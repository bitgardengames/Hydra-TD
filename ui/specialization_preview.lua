-- Specialization cards host the same entities and combat systems as a match.
-- This module authors only the tiny map and cast; GameplaySandbox owns isolation.
local GameplaySandbox = require("world.gameplay_sandbox")
local Preview = {}

local W, H = 240, 116
local path = {{-28,72},{72,72},{120,48},{268,48}}
local function cast(...)
	local kinds={...}; local result={}
	for i=1,#kinds do result[i]={kind=kinds[i],distance=(i-1)*30} end
	return result
end

Preview.definitions = {
	marksman={duration=5.2,tower={kind="lancer",x=82,y=104},enemies={{kind="tank",hpScale=7,distance=15},{kind="runner",hpScale=4,distance=62}}},
	rupture={duration=4.8,tower={kind="lancer",x=76,y=105},enemies=cast("grunt","grunt","grunt")},
	deep_freeze={duration=5.4,tower={kind="slow",x=82,y=105},enemies={{kind="tank",hpScale=7,distance=18}}},
	cold_field={duration=5.4,tower={kind="slow",x=82,y=105},enemies=cast("grunt","runner","grunt","grunt")},
	virulent={duration=5.8,tower={kind="poison",x=82,y=105},enemies={{kind="tank",hpScale=6,distance=18}}},
	contagion={duration=5.8,tower={kind="poison",x=82,y=105},enemies=cast("grunt","grunt","runner","grunt")},
	siege={duration=5.4,tower={kind="cannon",x=82,y=105},enemies={{kind="tank",hpScale=8,distance=20}}},
	bombardment={duration=5.4,tower={kind="cannon",x=82,y=105},enemies=cast("grunt","grunt","runner","grunt","grunt")},
	capacitor={duration=5.8,tower={kind="shock",x=82,y=105},enemies={{kind="tank",hpScale=8,distance=20}}},
	forked_lightning={duration=5.4,tower={kind="shock",x=82,y=105},enemies=cast("grunt","grunt","runner","grunt","runner")},
	accelerator={duration=5.0,tower={kind="plasma",x=78,y=105},enemies=cast("grunt","grunt","grunt")},
	overcharged={duration=5.8,tower={kind="plasma",x=82,y=105},enemies=cast("grunt","tank","grunt","runner")},
}

local function createWorld(branchId, def)
	return GameplaySandbox.new({branchId=branchId,duration=def.duration,path=path,tower=def.tower,enemies=def.enemies})
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

local function drawPath(points)
	local lg=love.graphics
	lg.setColor(.075,.11,.09,1); lg.rectangle("fill",0,0,W,H)
	lg.setColor(.12,.17,.13,1)
	for x=0,W,24 do for y=0,H,24 do lg.circle("fill",x+8,y+10,1.2) end end
	lg.setLineJoin("bevel"); lg.setLineWidth(31); lg.setColor(.09,.075,.065,1); lg.line(points)
	lg.setLineWidth(25); lg.setColor(.27,.23,.18,1); lg.line(points)
	lg.setLineWidth(2); lg.setColor(.38,.32,.24,.55); lg.line(points)
end
local clipW,clipH,clipRadius
local function drawCanvasClip() love.graphics.rectangle("fill",0,0,clipW,clipH,clipRadius,clipRadius) end
function Preview.draw(p,x,y,w,h,radius)
	if not p or w<1 or h<1 then return end
	local lg=love.graphics; local cw,ch=math.max(1,math.floor(w+.5)),math.max(1,math.floor(h+.5))
	if not p.canvas or p.canvasW~=cw or p.canvasH~=ch then if p.canvas and p.canvas.release then p.canvas:release() end; p.canvas=lg.newCanvas(cw,ch,{dpiscale=1}); p.canvasW,p.canvasH=cw,ch end
	local old=lg.getCanvas(); lg.push("all"); lg.setCanvas({p.canvas,stencil=true}); lg.origin(); lg.clear(0,0,0,0)
	clipW,clipH,clipRadius=cw,ch,radius or 8; lg.stencil(drawCanvasClip,"replace",1); lg.setStencilTest("greater",0); lg.scale(cw/W,ch/H)
	p.world:draw(drawPath); lg.setStencilTest(); lg.pop(); lg.setCanvas(old)
	lg.push("all"); lg.setScissor(x,y,w,h); lg.setColor(1,1,1,1); lg.draw(p.canvas,x,y,0,w/cw,h/ch); lg.pop()
end
function Preview.release(p) if p and p.canvas and p.canvas.release then p.canvas:release() end; if p then p.canvas=nil end end
return Preview

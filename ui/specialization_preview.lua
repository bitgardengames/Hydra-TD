-- Deterministic, render-only specialization vignettes.  Nothing in this module
-- is inserted into a world collection; the small records below belong to a card.
local Preview = {}

local W, H = 240, 116
local min, max = math.min, math.max

local function enemies(...)
	local result = {...}
	return result
end

-- Authored in logical preview pixels.  `shots` are event times; enemy entries are
-- {kind, start x/y, end x/y, durable}.  The remaining values describe projectile
-- motion, impact size, and the branch-specific treatment drawn at impact.
Preview.definitions = {
	marksman = {duration=3.2,tower={28,78,"lancer"}, enemies=enemies({"armored",205,58,150,58,true},{"runner",180,91,95,91}), shots={0.72}, speed=250, impact=20,effect="priority"},
	rupture = {duration=3.0,tower={25,76,"lancer"}, enemies=enemies({"grunt",105,68,78,68},{"grunt",150,68,123,68},{"grunt",197,68,170,68}), shots={0.62}, speed=230, impact=12,effect="pierce"},
	deep_freeze = {duration=3.4,tower={28,83,"slow"}, enemies=enemies({"armored",202,65,102,65,true},{"runner",202,96,82,96}), shots={0.62}, speed=185, impact=25,effect="freeze"},
	cold_field = {duration=3.5,tower={27,83,"slow"}, enemies=enemies({"grunt",142,55,91,55},{"runner",204,75,112,75},{"grunt",174,97,104,97}), shots={0.55}, speed=180, impact=48,effect="field"},
	virulent = {duration=3.6,tower={28,81,"poison"}, enemies=enemies({"armored",190,70,142,70,true}), shots={0.45,0.95,1.45,1.95}, speed=195, impact=12,effect="stacks"},
	contagion = {duration=3.5,tower={27,82,"poison"}, enemies=enemies({"grunt",147,70,114,70},{"grunt",190,48,157,48},{"runner",202,94,163,94}), shots={0.55}, speed=185, impact=52,effect="spread"},
	siege = {duration=3.5,tower={28,84,"cannon"}, enemies=enemies({"armored",190,68,152,68,true}), shots={0.65}, speed=145, impact=28,effect="siege"},
	bombardment = {duration=3.5,tower={28,84,"cannon"}, enemies=enemies({"grunt",128,48,103,48},{"grunt",180,67,150,67},{"runner",211,94,170,94},{"grunt",145,99,116,99}), shots={0.58}, speed=140, impact=62,effect="blast"},
	capacitor = {duration=3.8,tower={31,81,"shock"}, enemies=enemies({"armored",184,68,142,68,true}), shots={0.38,0.78,1.18,1.58}, speed=999, impact=24,effect="charge"},
	forked_lightning = {duration=3.4,tower={29,82,"shock"}, enemies=enemies({"grunt",112,65,91,65},{"grunt",148,43,126,43},{"runner",177,73,151,73},{"grunt",208,49,179,49},{"runner",211,98,180,98}), shots={0.66}, speed=999, impact=15,effect="fork"},
	accelerator = {duration=3.0,tower={25,76,"plasma"}, enemies=enemies({"grunt",105,68,78,68},{"grunt",153,68,126,68},{"grunt",202,68,175,68}), shots={0.48}, speed=330, impact=12,effect="lane"},
	overcharged = {duration=3.8,tower={28,78,"plasma"}, enemies=enemies({"grunt",122,49,98,49},{"armored",165,70,137,70,true},{"grunt",207,91,174,91},{"runner",210,48,174,48}), shots={0.65}, speed=125, impact=34,effect="grow"},
}

local function resetRecords(p, looping)
	local cycle, eventCount = p.cycle or 0, p.eventCount or 0
	p.elapsed, p.cycle, p.lastEvent, p.eventCount = 0, 0, 0, 0
	p.tower.angle, p.tower.recoil, p.tower.fireAnim = 0, 0, 0
	p.projectile.active, p.projectile.started, p.projectile.x, p.projectile.y = false, false, p.def.tower[1], p.def.tower[2]
	p.effect.active, p.effect.age, p.effect.x, p.effect.y = false, 0, 0, 0
	for i = 1, #p.enemies do
		local e, d = p.enemies[i], p.def.enemies[i]
		e.x, e.y, e.hit, e.poisonStacks, e.slow = d[2], d[3], 0, 0, 0
	end
	if looping then p.cycle, p.eventCount = cycle + 1, eventCount end
end

function Preview.new(branchId)
	local def = assert(Preview.definitions[branchId], "missing specialization preview: " .. tostring(branchId))
	local p = {branchId=branchId, def=def, canvas=nil, canvasW=0, canvasH=0, enemies={},
		tower={x=def.tower[1],renderY=def.tower[2],kind=def.tower[3],angle=0,recoil=0,fireAnim=0},
		projectile={}, effect={}}
	for i = 1, #def.enemies do p.enemies[i] = {portrait=nil} end
	resetRecords(p)
	return p
end

function Preview.reset(p) resetRecords(p) end

local function applyEvent(p, eventIndex)
	local d = p.def
	local shot = d.shots[eventIndex]
	p.lastEvent = eventIndex
	p.eventCount = p.eventCount + 1
	p.tower.fireAnim, p.tower.recoil = 1, 4
	p.projectile.active, p.projectile.started = true, shot
	p.projectile.x, p.projectile.y = d.tower[1] + 18, d.tower[2] - 5
	if d.speed > 900 then
		p.projectile.active = false
		p.effect.active, p.effect.age = true, 0
	end
	if d.effect == "stacks" then p.enemies[1].poisonStacks = eventIndex end
end

function Preview.update(p, dt)
	if not p or dt <= 0 then return end
	local d, remaining = p.def, dt
	while remaining > 0 do
		local step = min(remaining, d.duration - p.elapsed)
		local old, newTime = p.elapsed, p.elapsed + step
		for i = p.lastEvent + 1, #d.shots do
			if d.shots[i] > old and d.shots[i] <= newTime then applyEvent(p, i) end
		end
		p.elapsed = newTime
		remaining = remaining - step
		if p.elapsed >= d.duration then
			resetRecords(p, true)
		end
	end
	local t = p.elapsed
	for i = 1, #p.enemies do
		local e, ed = p.enemies[i], d.enemies[i]
		local movement = min(1, t / d.duration)
		if d.effect == "freeze" and i == 1 and t > 1 then movement = .3 + (t-1) * .035 end
		if d.effect == "field" and t > 1 and i <= 3 then movement = .3 + (t-1) * .11 end
		e.x, e.y = ed[2] + (ed[4]-ed[2])*movement, ed[3] + (ed[5]-ed[3])*movement
		e.slow = ((d.effect == "freeze" or d.effect == "field") and t > 1) and 1 or 0
	end
	p.tower.fireAnim = max(0, p.tower.fireAnim - dt * 3.5)
	p.tower.recoil = max(0, p.tower.recoil - dt * 14)
	if p.projectile.active then
		local previousX = p.projectile.x
		p.projectile.x = p.projectile.x + d.speed * dt
		local target = p.enemies[d.effect == "priority" and 1 or 1]
		p.projectile.y = target.y
		for i=1,#p.enemies do
			local enemy=p.enemies[i]
			if enemy.x>=previousX and enemy.x<=p.projectile.x then enemy.hit=.28; p.effect.x,p.effect.y=enemy.x,enemy.y end
		end
		if p.projectile.x >= target.x then
			p.projectile.active = d.effect == "pierce" or d.effect == "lane" or d.effect == "grow"
			p.effect.active, p.effect.age, p.effect.x, p.effect.y = true, 0, target.x, target.y
			for i=1,#p.enemies do if math.abs(p.enemies[i].x-target.x)<d.impact then p.enemies[i].hit=.28 end end
		end
	end
	if p.effect.active then p.effect.age = p.effect.age + dt end
	for i=1,#p.enemies do p.enemies[i].hit=max(0,p.enemies[i].hit-dt) end
end

local function drawProjectile(p)
	local lg, d, q = love.graphics, p.def, p.projectile
	if not q.active then return end
	if d.tower[3] == "plasma" then
		local radius = d.effect == "grow" and (7 + min(13, (q.x-d.tower[1])*.07)) or 6
		lg.setColor(.82,.45,1,.35); lg.circle("fill",q.x,q.y,radius*1.6); lg.setColor(1,.82,1,1); lg.circle("fill",q.x,q.y,radius)
	elseif d.tower[3] == "cannon" then lg.setColor(1,.72,.25,1); lg.circle("fill",q.x,q.y,7)
	elseif d.tower[3] == "slow" then lg.setColor(.55,.85,1,1); lg.rectangle("fill",q.x-5,q.y-5,10,10,3)
	else lg.setColor(d.tower[3]=="poison" and .35 or .95,d.tower[3]=="poison" and .9 or .95,.45,1); lg.ellipse("fill",q.x,q.y,8,3) end
end

local function drawEffect(p)
	if not p.effect.active then return end
	local lg, d, a = love.graphics, p.def, p.effect.age
	local fade = max(0, 1-a/1.35)
	if d.effect=="charge" then
		lg.setColor(.55,.9,1,.85*fade); lg.setLineWidth(2+p.lastEvent)
		if p.lastEvent < #d.shots then lg.circle("line",d.tower[1],d.tower[2]-4,8+p.lastEvent*4)
		else lg.line(d.tower[1]+12,d.tower[2]-5,p.enemies[1].x,p.enemies[1].y); lg.circle("line",p.enemies[1].x,p.enemies[1].y,d.impact) end
	elseif d.effect=="field" then lg.setColor(.35,.72,1,.22*fade); lg.circle("fill",p.effect.x,p.effect.y,d.impact)
	elseif d.effect=="spread" then lg.setColor(.35,1,.4,.7*fade); for i=2,#p.enemies do lg.line(p.enemies[1].x,p.enemies[1].y,p.enemies[i].x,p.enemies[i].y) end
	elseif d.effect=="fork" then lg.setColor(.65,.9,1,fade); lg.setLineWidth(3); local x,y=d.tower[1]+15,d.tower[2]-5; for i=1,#p.enemies do lg.line(x,y,p.enemies[i].x,p.enemies[i].y); x,y=p.enemies[i].x,p.enemies[i].y end
	else lg.setColor(d.tower[3]=="poison" and .35 or 1,d.tower[3]=="slow" and .85 or .65,d.tower[3]=="plasma" and 1 or .25,.65*fade); lg.circle("line",p.effect.x,p.effect.y,d.impact*(1+min(a,.5))) end
end

local function renderCanvas(p)
	local lg = love.graphics
	local TowerRenderer, EnemyRenderer = require("render.tower_renderer"), require("render.enemy_renderer")
	lg.setColor(.035,.045,.07,1); lg.rectangle("fill",0,0,W,H)
	lg.setColor(.12,.15,.2,1); lg.rectangle("fill",0,H-24,W,24)
	TowerRenderer.drawTowerVisual(p.tower.kind,p.tower.x,p.tower.renderY,p.tower.angle,p.tower.recoil,1)
	TowerRenderer.drawTowerFX(p.tower)
	for i=1,#p.enemies do
		local e = p.enemies[i]
		if not e.portrait then e.portrait = EnemyRenderer.newEnemyPortrait(p.def.enemies[i][1]) end
		e.portrait.hitSquash=e.hit; e.portrait.poisonStacks=e.poisonStacks; e.portrait.slowTimer=e.slow
		EnemyRenderer.drawEnemyPortrait(e.portrait,e.x,e.y,p.elapsed)
		if e.poisonStacks>0 then lg.setColor(.45,1,.35,1); for n=1,e.poisonStacks do lg.circle("fill",e.x-10+n*5,e.y-27,2) end end
	end
	drawProjectile(p); drawEffect(p)
end

local clipW, clipH, clipRadius
local function drawCanvasClip()
	love.graphics.rectangle("fill", 0, 0, clipW, clipH, clipRadius, clipRadius)
end

function Preview.draw(p, x, y, w, h, radius)
	if not p or w < 1 or h < 1 then return end
	local lg = love.graphics
	local cw,ch=max(1,math.floor(w+.5)),max(1,math.floor(h+.5))
	if not p.canvas or p.canvasW~=cw or p.canvasH~=ch then
		if p.canvas and p.canvas.release then p.canvas:release() end
		p.canvas=lg.newCanvas(cw,ch,{dpiscale=1}); p.canvasW,p.canvasH=cw,ch
	end
	local oldCanvas, oldShader = lg.getCanvas(), lg.getShader()
	local bm,am=lg.getBlendMode(); local r,g,b,a=lg.getColor(); local lw=lg.getLineWidth()
	local sx,sy,sw,sh=lg.getScissor(); local transform=lg.getTransform()
	lg.push("all"); lg.setCanvas(p.canvas); lg.origin(); lg.clear(0,0,0,0)
	clipW,clipH,clipRadius=cw,ch,(radius or 8)
	lg.stencil(drawCanvasClip,"replace",1); lg.setStencilTest("greater",0)
	lg.scale(cw/W,ch/H); renderCanvas(p); lg.setStencilTest(); lg.pop()
	lg.setCanvas(oldCanvas); lg.setShader(oldShader); lg.setBlendMode(bm,am); lg.setColor(r,g,b,a); lg.setLineWidth(lw); lg.replaceTransform(transform)
	if sx then lg.setScissor(max(x,sx),max(y,sy),min(x+w,sx+sw)-max(x,sx),min(y+h,sy+sh)-max(y,sy)) else lg.setScissor(x,y,w,h) end
	lg.setColor(1,1,1,1); lg.draw(p.canvas,x,y,0,w/cw,h/ch)
	if sx then lg.setScissor(sx,sy,sw,sh) else lg.setScissor() end
end

function Preview.release(p)
	if p and p.canvas and p.canvas.release then p.canvas:release() end
	if p then p.canvas=nil end
end

return Preview

local Theme = require("core.theme")
local lg = love.graphics
local sin, min, max, abs, cos = math.sin, math.min, math.max, math.abs, math.cos
local pi, HALF_PI = math.pi, math.pi / 2

local outline = Theme.outline.color
local face = Theme.enemy.face
local slow = Theme.projectiles.slow
local outR, outG, outB = outline[1], outline[2], outline[3]
local efR, efG, efB = face[1], face[2], face[3]
local sr, sg, sb = slow[1], slow[2], slow[3]
local EYE_DEADZONE = 0.03

local function none() end

-- Authored support and summon traits are silhouette decorations, independent of
-- the round body shared by every enemy.
local function support(e, x, y, r, animT, alpha)
	local direction = (e.eyeDX or 0) < 0 and 1 or -1
	local poleX = x + direction * r * 0.55
	lg.setColor(outR, outG, outB, alpha)
	lg.rectangle("fill", poleX - (direction < 0 and 3 or 0), y - r * 2, 3, r * 1.7)
	lg.polygon("fill", x + direction * r * 0.7, y - r * 1.9,
		x + direction * r * 1.65, y - r * 1.55, x + direction * r * 0.7, y - r * 1.2)
end

local function summon(e, x, y, r, animT, alpha)
	local readiness = 1 - min(1, max(0, (e.summonTimer or 0) / e.summon.period))
	local orbitRadius = r + 7 - readiness * 3
	lg.setColor(0.72, 0.38, 0.95, (0.55 + readiness * 0.35) * alpha)
	for n = 0, 1 do
		local angle = animT * 1.8 + n * pi
		local sx, sy = x + cos(angle) * orbitRadius, y + sin(angle) * orbitRadius
		lg.polygon("fill", sx, sy - 4, sx + 4, sy, sx, sy + 4, sx - 4, sy)
	end
end

local function bossHorns(e, x, y, r, _, alpha)
	lg.setColor(outR, outG, outB, alpha)
	local hornW, hornH, hornY = r * 0.6, r * 0.82, y - r * 1.02
	lg.push(); lg.translate(x - r * 0.46, hornY); lg.rotate(-0.26)
	lg.polygon("fill", 0, 0, -hornW, hornH * 0.5, -hornW, -hornH * 0.5); lg.pop()
	lg.push(); lg.translate(x + r * 0.46, hornY); lg.rotate(0.26)
	lg.polygon("fill", 0, 0, hornW, -hornH * 0.5, hornW, hornH * 0.5); lg.pop()
end

local standardArchetypes = {}
function standardArchetypes.bulwark(e, x, y, r, _, alpha)
	lg.setColor(outR, outG, outB, alpha)
	for a = 0, 3 do
		local angle = a * HALF_PI + pi * 0.25
		local px, py = x + cos(angle) * r, y + sin(angle) * r
		lg.push(); lg.translate(px, py); lg.rotate(angle)
		lg.rectangle("fill", -r * 0.35, -r * 0.55, r * 0.7, r * 1.1, 2, 2); lg.pop()
	end
end
function standardArchetypes.regenerator(e, x, y, r, _, alpha)
	lg.setColor(outR, outG, outB, alpha)
	lg.rectangle("fill", x - 2, y - r * 1.65, 4, r * 0.75)
	lg.rectangle("fill", x - r * 0.38, y - r * 1.42, r * 0.76, 4)
end

local bossArchetypes = {}
function bossArchetypes.summoner(e, x, y, r, animT, alpha)
	local orbit = animT * 1.4
	lg.setColor(0.78, 0.45, 1, 0.85 * alpha); lg.setLineWidth(3); lg.circle("line", x, y, r + 8)
	for n = 0, 2 do
		local angle = orbit + n * pi * 2 / 3
		local sx, sy = x + cos(angle) * (r + 8), y + sin(angle) * (r + 8)
		lg.polygon("fill", sx, sy - 4, sx + 4, sy, sx, sy + 4, sx - 4, sy)
	end
end
function bossArchetypes.displacement(e, x, y, r, _, alpha)
	lg.setColor(1, 0.66, 0.22, 0.8 * alpha); lg.setLineWidth(3)
	lg.line(x-r-9,y-5,x-r-3,y,x-r-9,y+5); lg.line(x+r+9,y-5,x+r+3,y,x+r+9,y+5)
end
function bossArchetypes.suppression(e, x, y, r, animT, alpha)
	lg.setColor(0.9, 0.25, 0.3, (0.55 + sin(animT * 2) * 0.15) * alpha); lg.setLineWidth(4)
	lg.arc("line", "open", x, y, r + 8, pi * 0.12, pi * 0.88)
end
function bossArchetypes.aegis(e, x, y, r, _, alpha)
	lg.setColor(0.3, 0.9, 1, (e.bossShieldActive and 0.95 or 0.38) * alpha)
	lg.setLineWidth(e.bossShieldActive and 5 or 2)
	for n=0,2 do local a=-HALF_PI+n*pi*2/3; lg.arc("line","open",x,y,r+8,a-0.62,a+0.62) end
end
function bossArchetypes.ravager(e, x, y, r, _, alpha)
	lg.setColor(1,0.28,0.18,(e.enraged and 0.95 or 0.5)*alpha); lg.setLineWidth(e.enraged and 4 or 2)
	local trail=e.enraged and 14 or 8
	lg.line(x-r-trail,y-7,x-r-3,y-7); lg.line(x-r-trail-4,y,x-r-3,y); lg.line(x-r-trail,y+7,x-r-3,y+7)
end

local function combine(archetype, trait, horns)
	return function(e, x, y, r, animT, alpha)
		if trait then trait(e, x, y, r, animT, alpha) end
		if archetype then archetype(e, x, y, r, animT, alpha) end
		if horns then bossHorns(e, x, y, r, animT, alpha) end
	end
end

local function statusHit(e, x, y, r, _, alpha)
	if e.hitFlash > 0 then lg.setColor(0.92,0.96,1,min(1,e.hitFlash/0.05)*0.55); lg.circle("fill",x,y,r) end
end
local function statusSlow(e,x,y,r,animT,alpha)
	if e.slowTimer > 0 then local pulse=0.6+sin(animT*3.5)*0.4
		lg.setColor(sr,sg,sb,(0.35+pulse*0.25)*alpha); lg.circle("line",x,y,r+3)
		lg.setColor(sr*0.7,sg*0.85,sb,0.1*alpha); lg.circle("fill",x,y,r-3) end
end
local function statusPoison(e,x,y,r,_,alpha)
	if e.poisonStacks and e.poisonStacks > 0 then local intensity=min(1,0.3+e.poisonStacks*0.12)
		lg.setColor(0.35,0.85,0.4,0.6*intensity*alpha); lg.circle("line",x,y,r-1) end
end
local function statusTraits(e,x,y,r,_,alpha)
	if e.regeneration and e.regenDelay <= 0 and e.hp < e.maxHp and e.poisonStacks <= 0 then
		lg.setColor(0.55,1,0.55,alpha); lg.setLineWidth(2); lg.line(x-6,y+r+5,x,y+r+1,x+6,y+r+5)
		if e.regenVisualPulse > 0 then local a=e.regenVisualPulse/0.28; lg.circle("line",x,y,r+4+(1-a)*8) end
	end
	if (e.supportBoost or 1) > 1 then lg.setColor(1,0.8,0.35,0.8*alpha); lg.setLineWidth(2)
		lg.line(x-r-8,y-4,x-r-2,y-4); lg.line(x-r-10,y+3,x-r-2,y+3) end
end
local statusDecorators = { statusHit, statusSlow, statusPoison, statusTraits }
local function drawStatuses(e,x,y,r,animT,alpha)
	for i=1,#statusDecorators do statusDecorators[i](e,x,y,r,animT,alpha) end
end

local function standardFace(e,x,y,r,animT,alpha)
	local eyeSep, eyeSize, eyeY = r*0.38, max(1.6,r*0.16), y-r*0.22
	lg.setColor(efR,efG,efB,alpha)
	if e.face == "shock" then
		local bigR,smallR=eyeSize+1,max(2,eyeSize-1); local p=1-(e.faceT/e.faceDur); local pop=1+(1-p*p)*0.15
		lg.push(); lg.translate(x,eyeY); lg.scale(pop,pop); lg.setLineWidth(2); lg.setColor(0.9,0.9,0.9,alpha)
		lg.circle("fill",-eyeSep,0,bigR+1); lg.setColor(efR,efG,efB,alpha); lg.circle("line",-eyeSep,0,bigR); lg.circle("fill",eyeSep,0,smallR); lg.pop()
	else
		local dx=e.eyeDX or (e.rx-(e.prevRX or e.rx)); local dy=e.eyeDY or (e.ry-(e.prevRY or e.ry)); local m=1.2
		if abs(dx)<EYE_DEADZONE then dx=0 end; if abs(dy)<EYE_DEADZONE then dy=0 end
		dx=(dx*m)/(abs(dx)+m); dy=(dy*m)/(abs(dy)+m)
		lg.circle("fill",x-eyeSep+dx,eyeY+dy,eyeSize); lg.circle("fill",x+eyeSep+dx,eyeY+dy,eyeSize)
	end
end
local function bossFace(e,x,y,r,animT,alpha)
	local eyeSep,eyeSize,eyeY=r*0.38,max(1.6,r*0.16),y-r*0.22
	if e.dying then local bigR,smallR=eyeSize+1,max(2,eyeSize-1); local p=1-(e.deathT/e.deathDur); local pop=1+(1-p*p)*0.15
		lg.push(); lg.translate(x,eyeY); lg.scale(pop,pop); lg.setLineWidth(3); lg.setColor(0.9,0.9,0.9,alpha); lg.circle("fill",-eyeSep,0,bigR+1)
		lg.setColor(efR,efG,efB,alpha); lg.circle("line",-eyeSep,0,bigR); lg.circle("fill",eyeSep,0,smallR); lg.pop(); return end
	lg.setColor(efR,efG,efB,alpha); if e.enraged then lg.setColor(1,0.18,0.12,alpha) end
	lg.circle("fill",x-eyeSep,eyeY,eyeSize); lg.circle("fill",x+eyeSep,eyeY,eyeSize); lg.setLineWidth(2)
	local len,drop,tension,lift,inside=eyeSize*2.5,eyeSize*0.85,sin(animT*1.6)*0.6,eyeSize*0.35,eyeSize*0.35
	lg.line(x-eyeSep-len*0.65+inside,eyeY-drop-lift,x-eyeSep+len*0.35+inside,eyeY-drop*0.15+tension-lift)
	lg.line(x+eyeSep-len*0.35-inside,eyeY-drop*0.15+tension-lift,x+eyeSep+len*0.65-inside,eyeY-drop-lift)
end

local profiles = {}
local function profile(identity, faceRenderer) return { identity=identity or none, face=faceRenderer or standardFace } end
profiles.grunt=profile(); profiles.tank=profile(); profiles.runner=profile()
profiles.bulwark=profile(standardArchetypes.bulwark); profiles.regenerator=profile(standardArchetypes.regenerator)
profiles.warcaller=profile(combine(nil,support)); profiles.summoner=profile(combine(nil,summon))
profiles.boss=profile(combine(nil,nil,true),bossFace)
profiles.boss_summoner=profile(combine(bossArchetypes.summoner,nil,true),bossFace)
profiles.boss_displacement=profile(combine(bossArchetypes.displacement,nil,true),bossFace)
profiles.boss_suppression=profile(combine(bossArchetypes.suppression,nil,true),bossFace)
profiles.boss_aegis=profile(combine(bossArchetypes.aegis,nil,true),bossFace)
profiles.boss_ravager=profile(combine(bossArchetypes.ravager,nil,true),bossFace)

return { profiles=profiles, drawStatuses=drawStatuses }

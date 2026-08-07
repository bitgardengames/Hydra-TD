local AbilityDefs = require("systems.ability_defs")
local CampaignUnlocks = require("systems.campaign_unlocks")
local Enemies = require("world.enemies")
local Towers = require("world.towers")
local Effects = require("world.effects")
local State = require("core.state")

local Abilities = {}
local active = {}
local clock = 0

function Abilities.getEquipped(abilityId)
	local id = abilityId or (State.equippedAbilities and State.equippedAbilities[1])
	if not id or not CampaignUnlocks.isAbilityUnlocked(id) then return nil end
	for slotIndex, equippedId in ipairs(State.equippedAbilities or {}) do
		if equippedId == id and CampaignUnlocks.isAbilitySlotUnlocked(slotIndex) then return AbilityDefs[id] end
	end
end
local function getEffect(def)
	return def.upgradeId and CampaignUnlocks.isAbilityUpgradeUnlocked(def.upgradeId) and (def.upgradedEffect or def.effect) or def.effect
end
function Abilities.getEffect(def) return getEffect(def) end
function Abilities.isReady(id) local d=Abilities.getEquipped(id); return d and (State.abilityCooldowns[d.id] or 0)<=0 or false end
function Abilities.beginTargeting(id)
	local d=Abilities.getEquipped(id)
	if not d or not Abilities.isReady(d.id) or State.mode~="game" or State.modulePicker.active then return false end
	State.abilityTargeting={abilityId=d.id,x=nil,y=nil,firstTower=nil}; State.placing=nil; State.selectedTower=nil; State.selectedEnemy=nil; return true
end
function Abilities.cancelTargeting() State.abilityTargeting=nil end
local function towerAt(x,y)
	local best,bd=nil,24*24
	for _,t in ipairs(Towers.towers) do local dx,dy=t.x-x,t.y-y; local d=dx*dx+dy*dy; if d<=bd then best,bd=t,d end end
	return best
end
local function buffTower(t,e,kind)
	-- Expiries and multipliers never rewrite the authored tower statistics.
	t.abilityBuffs=t.abilityBuffs or {}; t.abilityBuffs[#t.abilityBuffs+1]={kind=kind,expires=clock+e.duration,attackSpeed=e.attackSpeed or 1,range=e.range or 1}
end
local function addActive(a) active[#active+1]=a end
function Abilities.activate(x,y)
	local target=State.abilityTargeting; local def=target and Abilities.getEquipped(target.abilityId)
	if not def or not Abilities.isReady(def.id) then return false end
	local e=getEffect(def)
	if e.kind=="power_grid" then
		local t=towerAt(x,y); if not t then return false end
		if not target.firstTower then target.firstTower=t; target.x,target.y=t.x,t.y; return true end
		local first=target.firstTower; local dx,dy=t.x-first.x,t.y-first.y
		if t==first or dx*dx+dy*dy>e.maxDistance*e.maxDistance then return false end
		local linked={first,t}
		if e.chain then
			local best,score
			for _,candidate in ipairs(Towers.towers) do if candidate~=first and candidate~=t then
				local lineDx,lineDy=t.x-first.x,t.y-first.y; local u=((candidate.x-first.x)*lineDx+(candidate.y-first.y)*lineDy)/(lineDx*lineDx+lineDy*lineDy); u=math.max(0,math.min(1,u)); local px,py=first.x+lineDx*u,first.y+lineDy*u; local dd=(candidate.x-px)^2+(candidate.y-py)^2
				if dd<45^2 and (not score or dd<score) then best,score=candidate,dd end
			end end
			if best then linked[#linked+1]=best end
		end
		for _,tower in ipairs(linked) do buffTower(tower,e,"power_grid"); tower.powerGridPeers=linked end
		addActive({kind="power_grid",towers=linked,expires=clock+e.duration,assist=e.cooldownAssist})
	else
		local r2=e.radius*e.radius
		if e.kind=="tower_haste_area" or e.kind=="last_stand" then
			local affected={}; for _,t in ipairs(Towers.towers) do local dx,dy=t.x-x,t.y-y; if dx*dx+dy*dy<=r2 then buffTower(t,e,e.kind); affected[#affected+1]=t end end
			addActive({kind=e.kind,x=x,y=y,radius=e.radius,towers=affected,expires=clock+e.duration,volleys=e.volleys,lastVolley=-math.huge,inside={}})
		elseif e.kind=="gravity_well" then addActive({kind=e.kind,x=x,y=y,radius=e.radius,expires=clock+e.duration,damage=e.damage,pullSpeed=e.pullSpeed})
		else
			for _,enemy in ipairs(Enemies.enemies) do local ex,ey=enemy.rx or enemy.x,enemy.ry or enemy.y; local dx,dy=ex-x,ey-y; if enemy.hp>0 and dx*dx+dy*dy<=r2 then if e.kind=="damage_area" then Enemies.applyDamage(enemy,e.damage,{sourceKind="ability"}) else Enemies.applySlow(enemy,e.factor,e.duration) end end end
		end
	end
	if e.kind=="damage_area" then Effects.spawnCannonImpact(x,y,e.radius); Effects.trigger("ability_meteor",{intensity=3,shake=4,hitStop=.025}) elseif e.kind=="slow_area" then Effects.spawnFrostBurst(x,y); Effects.trigger("ability_frost",{intensity=2,shake=1}) else Effects.trigger("ability_cast",{intensity=2,shake=1}) end
	State.abilityCooldowns[def.id]=def.cooldown; State.abilityTargeting=nil; return true
end
local function triggerVolley(a, enemy)
	for _,t in ipairs(a.towers) do local dx,dy=enemy.x-t.x,enemy.y-t.y; local range=t.range*(t.abilityRangeMultiplier or 1); if enemy.hp>0 and dx*dx+dy*dy<=range*range then t.cooldown=0; t.windUp=0; t.target=enemy end end
	a.volleys=a.volleys-1; a.lastVolley=clock
end
function Abilities.update(dt)
	clock=clock+dt; State.abilityClock=clock
	for id,cd in pairs(State.abilityCooldowns) do State.abilityCooldowns[id]=math.max(0,cd-dt) end
	for i=#active,1,-1 do local a=active[i]
		if a.kind=="gravity_well" then
			local r2=a.radius*a.radius; for _,e in ipairs(Enemies.enemies) do local dx,dy=e.x-a.x,e.y-a.y; if e.hp>0 and dx*dx+dy*dy<=r2 then local resist=(e.def and (e.def.boss or e.def.heavy)) and .2 or 1; Enemies.setPathDistance(e, e.dist-a.pullSpeed*resist*dt) end end
		elseif a.kind=="last_stand" and a.volleys>0 then
			local r2=a.radius*a.radius; for _,e in ipairs(Enemies.enemies) do local dx,dy=e.x-a.x,e.y-a.y; local inside=dx*dx+dy*dy<=r2; if a.inside[e] and not inside and clock-a.lastVolley>=1.5 then triggerVolley(a,e) end; a.inside[e]=inside end
		end
		if clock>=a.expires then
			if a.kind=="gravity_well" then for _,e in ipairs(Enemies.enemies) do local dx,dy=e.x-a.x,e.y-a.y;if e.hp>0 and dx*dx+dy*dy<=a.radius*a.radius then Enemies.applyDamage(e,a.damage,{sourceKind="ability"}) end end; Effects.spawnCannonImpact(a.x,a.y,a.radius) end
			if a.kind=="power_grid" then for _,t in ipairs(a.towers) do t.powerGridPeers=nil end end
			table.remove(active,i)
		end
	end
end
function Abilities.getActive() return active,clock end
function Abilities.reset() active={}; clock=0; State.abilityClock=0 end
return Abilities

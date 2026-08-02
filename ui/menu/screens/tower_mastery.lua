local Constants = require("core.constants")
local TowerDefs = require("world.tower_defs")
local Mastery = require("systems.tower_mastery")
local Codex = require("ui.tower_codex")
local Save = require("core.save")
local Theme = require("core.theme")
local Fonts = require("core.fonts")
local Text = require("ui.text")
local L = require("core.localization")
local Sound = require("systems.sound")
local Backdrop = require("scenes.backdrop")

local Screen = {}
local lg = love.graphics
local selected, scroll, detailOpen = 1, 0, false
local cards, detailViewport = {}, nil

local function history(kind)
	local meta = Save.data and Save.data.meta or {}
	return type(meta.towerHistory) == "table" and type(meta.towerHistory[kind]) == "table" and meta.towerHistory[kind] or {}
end
local function n(h, key) return math.max(0, tonumber(h[key]) or 0) end
local function goBack() require("ui.menu.menu").set("menu"); Sound.play("uiBack") end

function Screen.load() end
function Screen.enter() selected, scroll, detailOpen = 1, 0, false; Backdrop.start() end
function Screen.update(dt) Backdrop.update(dt) end

local function drawCard(kind, x, y, w, h, active)
	local def, hist = TowerDefs[kind], history(kind)
	local mastery = Mastery.calculate(hist)
	lg.setColor(active and Theme.ui.buttonSelected or Theme.ui.panel)
	lg.rectangle("fill", x, y, w, h, 8)
	lg.setLineWidth(active and 3 or 1); lg.setColor(def.color); lg.rectangle("line", x, y, w, h, 8)
	Fonts.set("ui"); Text.printShadow(L(def.nameKey), x + 10, y + 8)
	Fonts.set("tooltip"); lg.setColor(Theme.ui.text)
	Text.printShadow(L(mastery.rankKey), x + 10, y + 31)
	Text.printfShadow(L("towerMastery.cardStats", n(hist,"kills"), n(hist,"damage"), n(hist,"placements"), n(hist,"upgrades"), n(hist,"bestRunDamage")), x + 10, y + 51, w - 20, "left")
	local bx, by, bw = x + 10, y + h - 27, w - 20
	lg.setColor(Theme.ui.panel2); lg.rectangle("fill", bx, by, bw, 8, 4)
	lg.setColor(def.color); lg.rectangle("fill", bx, by, bw * mastery.progress, 8, 4)
	lg.setColor(Theme.ui.text)
	local xpText = mastery.mastered and L("towerMastery.progressMastered", mastery.xp) or L("towerMastery.progress", mastery.xp, mastery.nextXP)
	Text.printfShadow(xpText, bx, by + 9, bw, "center")
end

function Screen.draw()
	local sw, sh = lg.getDimensions(); Backdrop.draw()
	lg.setColor(0.03,0.04,0.05,0.58); lg.rectangle("fill",0,0,sw,sh)
	local margin, top = math.max(12, math.min(28, sw * .025)), 68
	Fonts.set("title"); lg.setColor(Theme.ui.text); Text.printShadow(L("towerMastery.title"), margin, 14)
	local hasHistory = false
	for _, kind in ipairs(Constants.TOWER_LIST) do if Mastery.xp(history(kind)) > 0 then hasHistory = true; break end end
	Fonts.set("tooltip"); Text.printfShadow(L(hasHistory and "towerMastery.instructions" or "towerMastery.empty"), margin, 50, sw-margin*2, "left")
	local wide = sw >= 850
	local gridW = wide and math.floor(sw * .46) or sw - margin*2
	local gap = math.max(6, math.min(12, gridW * .02)); local cardW = (gridW-gap)/2
	local available = sh-top-margin; local cardH = wide and math.max(112, math.min(148,(available-gap*2)/3)) or math.max(100, math.min(125,(available-gap*2)/3))
	cards = {}
	for i, kind in ipairs(Constants.TOWER_LIST) do
		local col,row=(i-1)%2,math.floor((i-1)/2); local x=margin+col*(cardW+gap); local y=top+row*(cardH+gap)
		cards[i]={x=x,y=y,w=cardW,h=cardH}; drawCard(kind,x,y,cardW,cardH,i==selected)
	end
	if not wide and detailOpen then
		local x,y,w,h=margin,top,sw-margin*2,sh-top-margin
		detailViewport={x=x,y=y,w=w,h=h}
		lg.setColor(Theme.ui.panel2); lg.rectangle("fill",x,y,w,h,8)
		lg.setScissor(x,y,w,h); lg.push(); lg.translate(0,-scroll)
		local kind=Constants.TOWER_LIST[selected]; Codex.drawEntry(kind,TowerDefs[kind],x+16,y+14,w-32)
		lg.setColor(Theme.ui.selected); Fonts.set("tooltip"); Text.printShadow(L("towerMastery.rewardsTitle"),x+16,y+Codex.ENTRY_HEIGHT-70)
		local yy=y+Codex.ENTRY_HEIGHT-48
		for _, reward in ipairs(Mastery.unlockedRewards(history(kind))) do Text.printfShadow("• "..L(reward.rewardKey),x+16,yy,w-32,"left"); yy=yy+20 end
		lg.pop(); lg.setScissor()
	elseif wide then
		local x=margin+gridW+margin; local y=top; local w=sw-x-margin; local h=sh-y-margin
		detailViewport={x=x,y=y,w=w,h=h}
		lg.setColor(Theme.ui.panel2); lg.rectangle("fill",x,y,w,h,8)
		lg.setScissor(x,y,w,h); lg.push(); lg.translate(0,-scroll)
		local kind=Constants.TOWER_LIST[selected]; Codex.drawEntry(kind,TowerDefs[kind],x+16,y+14,w-32)
		lg.setColor(Theme.ui.selected); Fonts.set("tooltip"); Text.printShadow(L("towerMastery.rewardsTitle"),x+16,y+Codex.ENTRY_HEIGHT-70)
		local yy=y+Codex.ENTRY_HEIGHT-48
		for _, reward in ipairs(Mastery.unlockedRewards(history(kind))) do Text.printfShadow("• "..L(reward.rewardKey),x+16,yy,w-32,"left"); yy=yy+20 end
		lg.pop(); lg.setScissor()
	else
		detailViewport=nil
	end
	Fonts.set("tooltip"); lg.setColor(Theme.ui.text); Text.printfShadow(L("towerMastery.backHint"),margin,sh-22,sw-margin*2,"right")
end

local function move(dx,dy)
	local nextIndex=selected+dx+dy*2
	if nextIndex>=1 and nextIndex<=#Constants.TOWER_LIST then selected=nextIndex; scroll=0; Sound.play("uiMove") end
end
function Screen.keypressed(key)
	if key=="escape" or key=="backspace" then
		if detailOpen then detailOpen=false; scroll=0 else goBack() end
	elseif key=="return" or key=="space" then detailOpen=true; scroll=0
	elseif key=="left" or key=="a" then move(-1,0)
	elseif key=="right" or key=="d" then move(1,0)
	elseif key=="up" or key=="w" then move(0,-1)
	elseif key=="down" or key=="s" then move(0,1)
	elseif key=="pageup" then Screen.wheelmoved(0,4)
	elseif key=="pagedown" then Screen.wheelmoved(0,-4) end
end
function Screen.gamepadpressed(_,button)
	local map={dpleft={-1,0},dpright={1,0},dpup={0,-1},dpdown={0,1}}
	if map[button] then move(map[button][1],map[button][2])
	elseif button=="a" then detailOpen=true; scroll=0
	elseif button=="b" or button=="back" then if detailOpen then detailOpen=false; scroll=0 else goBack() end end
end
function Screen.mousepressed(x,y,button)
	if button~=1 then return end
	for i,r in ipairs(cards) do if x>=r.x and x<=r.x+r.w and y>=r.y and y<=r.y+r.h then if selected==i and not detailViewport then detailOpen=true else selected=i end; scroll=0; Sound.play("uiMove"); return true end end
end
function Screen.wheelmoved(_,y)
	if detailViewport then scroll=math.max(0,math.min(Codex.ENTRY_HEIGHT-detailViewport.h+80,scroll-y*28)) end
end
return Screen

local Save = require("core.save")
local State = require("core.state")
local Messages = require("ui.messages")
local L = require("core.localization")

local Onboarding = {}

local queue, queued, demonstrated = {}, {}, {}
local tutorial = {active = false, phase = nil, gx = 12, gy = 6, tower = nil}

local eventTips = {
	map_entered = "tower_placement", attempting_placement = "tower_placement",
	tower_selected = "inspection_upgrade", affordable_upgrade = "inspection_upgrade",
	enemy_leaked = "enemy_intel",
}
local actionTips = {
	tower_placed = "tower_placement", wave_started = "wave_start",
	tower_upgraded = "inspection_upgrade", enemy_selected = "enemy_intel",
}

local function enabled()
	return Save.data and Save.data.contextualTipsEnabled == true and not tutorial.active
end

local function dismissed(id)
	return Save.data.dismissedTipIds and Save.data.dismissedTipIds[id] == true
end

local function remember(id)
	demonstrated[id] = true
	if tutorial.active then Save.data.tutorialDemonstratedIds[id] = true end
	queued[id] = nil
	Messages.clearTip(id)
end

local function enqueue(id)
	if enabled() and not demonstrated[id] and not dismissed(id) and not queued[id] then
		queue[#queue + 1] = id
		queued[id] = true
	end
end

local function routeToCampaign()
	tutorial.active, tutorial.phase, tutorial.tower = false, nil, nil
	State.ignoreStats = false
	State.mode = "campaign"
	require("systems.sound").playMusic("menu")
	require("scenes.backdrop").start()
end

function Onboarding.offerIfNeeded()
	if Save.data.tutorialOffered then return end
	Save.data.tutorialOffered = true
	Save.flush()
	require("ui.overlay").show(require("ui.overlays.tutorial_offer"))
end

function Onboarding.startTutorial()
	Save.data.tutorialOffered = true
	Save.data.tutorialSkipped = false
	Save.flush()
	tutorial.active, tutorial.phase, tutorial.tower = true, "place", nil
	State.ignoreStats = true
	State.worldMapIndex, State.mapIndex = 1, 1
	State.mode = "game"
	require("scenes.backdrop").stop()
	require("systems.difficulty").set("easy")
	resetGame()
	State.money, State.moneyLerp = 150, 150
	State.placing = "lancer"
	require("systems.sound").playMusic("gameplay")
end

function Onboarding.replay()
	require("ui.overlay").hide()
	Onboarding.startTutorial()
end

function Onboarding.skip()
	Save.data.tutorialOffered = true
	Save.data.tutorialSkipped = true
	Save.flush()
	routeToCampaign()
end

function Onboarding.complete()
	if not tutorial.active then return end
	Save.data.tutorialCompleted = true
	Save.data.tutorialSkipped = false
	Save.flush()
	routeToCampaign()
	require("ui.overlay").show(require("ui.overlays.tutorial_complete"))
end

function Onboarding.isTutorialActive() return tutorial.active end

function Onboarding.validatePlacement(kind, gx, gy)
	if tutorial.active and tutorial.phase == "place" and (kind ~= "lancer" or gx ~= tutorial.gx or gy ~= tutorial.gy) then
		return false, "tutorial_tile"
	end
	return true
end

function Onboarding.isTutorialWave()
	return tutorial.active and tutorial.phase == "wave"
end

function Onboarding.canStartWave()
	return not tutorial.active or tutorial.phase == "wave"
end

function Onboarding.event(name, payload)
	local action = actionTips[name]
	if action then remember(action) end

	if tutorial.active then
		if name == "tower_placed" and tutorial.phase == "place" then
			tutorial.tower = payload
			tutorial.phase = "wave"
		elseif name == "wave_started" and tutorial.phase == "wave" then
			tutorial.phase = "combat"
		elseif name == "tower_selected" and tutorial.phase == "inspect" and payload == tutorial.tower then
			tutorial.phase = "upgrade"
			State.money = math.max(State.money, 500)
		elseif name == "tower_upgraded" and tutorial.phase == "upgrade" and payload == tutorial.tower then
			Onboarding.complete()
		end
		return
	end

	local tip = eventTips[name]
	if tip then enqueue(tip) end
	if name == "tower_placed" then enqueue("wave_start") end
	if name == "wave_started" then enqueue("enemy_intel") end
end

function Onboarding.update()
	if tutorial.active then
		if tutorial.phase == "combat" and require("systems.waves").allEnemiesCleared() then
			tutorial.phase = "inspect"
			State.inPrep = true
		end
		return
	end
	if not enabled() then Messages.clearTip(); return end
	if Messages.hasTip() then return end
	while #queue > 0 do
		local id = table.remove(queue, 1); queued[id] = nil
		if not demonstrated[id] and not dismissed(id) then
			Messages.showTip(id, L("onboarding." .. id), L("onboarding.dismiss"), function()
				Save.data.dismissedTipIds[id] = true; Save.flush()
			end)
			return
		end
	end
end

function Onboarding.drawWorld()
	if not tutorial.active or tutorial.phase ~= "place" then return end
	local Constants = require("core.constants")
	local x, y = (tutorial.gx - 1) * Constants.TILE, (tutorial.gy - 1) * Constants.TILE
	local pulse = 0.35 + 0.2 * math.sin(love.timer.getTime() * 5)
	love.graphics.setColor(0.35, 1, 0.45, pulse)
	love.graphics.rectangle("fill", x + 2, y + 2, Constants.TILE - 4, Constants.TILE - 4, 5)
	love.graphics.setColor(0.65, 1, 0.7, 1)
	love.graphics.setLineWidth(3); love.graphics.rectangle("line", x + 2, y + 2, Constants.TILE - 4, Constants.TILE - 4, 5)
end

function Onboarding.draw()
	if not tutorial.active then return end
	local textByPhase = {place = "place", wave = "wave", combat = "combat", inspect = "inspect", upgrade = "upgrade"}
	local lg, phase = love.graphics, textByPhase[tutorial.phase]
	if phase then
		lg.setColor(0.08, 0.09, 0.12, 0.94); lg.rectangle("fill", 24, 22, 530, 42, 8)
		lg.setColor(1, 1, 1, 1); require("ui.text").printfShadow(L("tutorial." .. phase), 38, 33, 500, "left")
	end
	lg.setColor(0.12, 0.13, 0.17, 0.96); lg.rectangle("fill", lg.getWidth() - 134, 22, 110, 36, 8)
	lg.setColor(1, 1, 1, 1); require("ui.text").printfShadow(L("tutorial.skipShort"), lg.getWidth() - 134, 31, 110, "center")
end

function Onboarding.mousepressed(x, y, button)
	if tutorial.active and button == 1 and x >= love.graphics.getWidth() - 134 and x <= love.graphics.getWidth() - 24 and y >= 22 and y <= 58 then
		Onboarding.skip(); return true
	end
	return false
end

function Onboarding.reset()
	queue, queued, demonstrated = {}, {}, {}
	Messages.clearTip()
	Save.data.dismissedTipIds = {}
	Save.data.tutorialDemonstratedIds = {}
	Save.flush()
end

function Onboarding.load()
	demonstrated = {}
	for id, value in pairs(Save.data.tutorialDemonstratedIds or {}) do demonstrated[id] = value end
end

return Onboarding

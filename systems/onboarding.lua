local Save = require("core.save")
local Messages = require("ui.messages")
local L = require("core.localization")

local Onboarding = {}

local queue = {}
local queued = {}
local demonstrated = {}

local eventTips = {
	map_entered = "tower_placement",
	attempting_placement = "tower_placement",
	tower_selected = "inspection_upgrade",
	affordable_upgrade = "inspection_upgrade",
	enemy_leaked = "enemy_intel",
}

local actionTips = {
	tower_placed = "tower_placement",
	wave_started = "wave_start",
	tower_upgraded = "inspection_upgrade",
	enemy_selected = "enemy_intel",
}

local function enabled()
	return Save.data and Save.data.contextualTipsEnabled == true
end

local function dismissed(id)
	return Save.data.dismissedTipIds and Save.data.dismissedTipIds[id] == true
end

local function completeIfReady()
	for _, id in pairs(actionTips) do
		if not demonstrated[id] then return end
	end
	Save.data.tutorialCompleted = true
	Save.flush()
end

local function demonstrate(id)
	demonstrated[id] = true
	queued[id] = nil
	Messages.clearTip(id)
	completeIfReady()
end

local function enqueue(id)
	if enabled() and not demonstrated[id] and not dismissed(id) and not queued[id] then
		queue[#queue + 1] = id
		queued[id] = true
	end
end

function Onboarding.event(name)
	local action = actionTips[name]
	if action then demonstrate(action) end

	local tip = eventTips[name]
	if tip then enqueue(tip) end

	if name == "tower_placed" then enqueue("wave_start") end
	if name == "wave_started" then enqueue("enemy_intel") end
end

function Onboarding.update()
	if not enabled() then
		Messages.clearTip()
		return
	end
	if Messages.hasTip() then return end

	while #queue > 0 do
		local id = table.remove(queue, 1)
		queued[id] = nil
		if not demonstrated[id] and not dismissed(id) then
			Messages.showTip(id, L("onboarding." .. id), L("onboarding.dismiss"), function()
				Save.data.dismissedTipIds[id] = true
				Save.flush()
			end)
			return
		end
	end
end

function Onboarding.reset()
	queue = {}
	queued = {}
	demonstrated = {}
	Messages.clearTip()
	Save.data.tutorialCompleted = false
	Save.data.dismissedTipIds = {}
	Save.flush()
end

return Onboarding

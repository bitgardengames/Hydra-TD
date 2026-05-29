local Save = require("core.save")
local State = require("core.state")
local L = require("core.localization")
local Constants = require("core.constants")
local TutorialTip = require("ui.overlays.tutorial_tip")

local Onboarding = {}

local MAX_FIRST_RUN_TIPS = 4
local TUTORIAL_MAP_INDEX = 1
local TUTORIAL_START_MONEY = 165

local function settings()
	Save.data.settings = Save.data.settings or {}
	return Save.data.settings
end

local function meta()
	Save.data.meta = Save.data.meta or {}
	Save.data.meta.tipsSeen = Save.data.meta.tipsSeen or {}
	return Save.data.meta
end

local function onboardingState()
	State.onboarding = State.onboarding or {active = false, step = nil, tipsShown = 0}
	return State.onboarding
end

local function clearPlacementTarget(state)
	state.targetGX = nil
	state.targetGY = nil
end

local function targetScore(gx, gy, bendIndex, path)
	local score = 0

	for i = math.max(1, bendIndex - 4), math.min(#path, bendIndex + 4) do
		local p = path[i]
		local dx = gx - p[1]
		local dy = gy - p[2]
		local dist2 = dx * dx + dy * dy

		if dist2 <= 16 then
			score = score + (18 - dist2)
		end
	end

	-- Prefer tiles below the opening bend on Riverbend so the first lesson is readable.
	if gy > path[bendIndex][2] then
		score = score + 3
	end

	return score
end

local function choosePlacementTarget()
	local MapMod = require("world.map")
	local path = MapMod.map and MapMod.map.path

	if not path or #path < 3 then
		return nil, nil
	end

	local bestGX, bestGY, bestScore

	for i = 2, #path - 1 do
		local prev = path[i - 1]
		local cur = path[i]
		local next = path[i + 1]
		local dx1 = cur[1] - prev[1]
		local dy1 = cur[2] - prev[2]
		local dx2 = next[1] - cur[1]
		local dy2 = next[2] - cur[2]

		if dx1 ~= dx2 or dy1 ~= dy2 then
			for ox = -1, 1 do
				for oy = -1, 1 do
					if ox ~= 0 or oy ~= 0 then
						local gx = cur[1] + ox
						local gy = cur[2] + oy
						local ok = gx >= 1 and gx <= Constants.GRID_W and gy >= 1 and gy <= Constants.GRID_H and MapMod.canPlaceAt(gx, gy)

						if ok then
							local score = targetScore(gx, gy, i, path)

							if not bestScore or score > bestScore then
								bestGX, bestGY, bestScore = gx, gy, score
							end
						end
					end
				end
			end

			if bestGX then
				return bestGX, bestGY
			end
		end
	end

	return nil, nil
end

local function setPlacementTarget(state)
	local gx, gy = choosePlacementTarget()

	state.targetGX = gx
	state.targetGY = gy
end

local function tipsAllowed()
	local s = settings()
	local m = meta()

	return s.tips_enabled ~= false and m.expert_mode ~= true
end

local function markTipSeen(id)
	local m = meta()

	if not m.tipsSeen[id] then
		m.tipsSeen[id] = true
		m.tipsShown = (m.tipsShown or 0) + 1
		Save.flush()
	end
end

local function dismissCurrent(id)
	if id then
		markTipSeen(id)
	end

	TutorialTip.hide()
end

local function disableTips()
	settings().tips_enabled = false
	Save.flush()
	TutorialTip.hide()
end

local function applyForgivingTutorialStart()
	State.money = math.max(State.money or 0, TUTORIAL_START_MONEY)
	State.moneyLerp = State.money
	State.inPrep = true
	State.speed = 1
	State.wave = 1
	State.waveLeaks = 0
	State.totalLeaks = State.totalLeaks or 0
end

local function launchTutorialRunIfPossible()
	State.mapIndex = TUTORIAL_MAP_INDEX
	State.worldMapIndex = State.resolveMapIndex(TUTORIAL_MAP_INDEX)
	State.mode = "game"

	local Difficulty = require("systems.difficulty")
	local Backdrop = require("scenes.backdrop")
	local Sound = require("systems.sound")

	Difficulty.set(settings().difficulty)
	Backdrop.stop()

	if type(_G.resetGame) == "function" then
		_G.resetGame()
		applyForgivingTutorialStart()
		setPlacementTarget(onboardingState())
		Sound.playMusic("gameplay")
	end
end

function Onboarding.showTip(id, titleKey, bodyKey, options)
	if not Save.data or not tipsAllowed() or TutorialTip.isActive() then
		return false
	end

	local m = meta()
	local seen = m.tipsSeen or {}
	local state = onboardingState()
	local count = state.tipsShown or 0

	if seen[id] then
		return false
	end

	if not (options and options.force) and count >= MAX_FIRST_RUN_TIPS then
		return false
	end

	state.tipsShown = count + 1
	state.active = true
	state.step = id

	TutorialTip.show({
		id = id,
		title = L(titleKey),
		body = L(bodyKey),
		anchor = options and options.anchor,
		dismissLabel = L("tutorial.dismiss"),
		dontShowLabel = L("tutorial.dontShowAgain"),
		onDismiss = function()
			dismissCurrent(id)
		end,
		onDontShow = disableTips,
	})

	return true
end

function Onboarding.showWelcomeIfNeeded()
	if not Save.data or TutorialTip.isActive() then
		return false
	end

	local m = meta()
	local state = onboardingState()

	if m.tutorial_completed == true or m.expert_mode == true or state.welcomeOffered then
		return false
	end

	state.active = true
	state.step = "offering_tutorial"
	state.welcomeOffered = true

	TutorialTip.show({
		id = "welcome",
		title = L("tutorial.welcomeTitle"),
		body = L("tutorial.welcomeBody"),
		modal = true,
		buttons = {
			{
				label = L("tutorial.startButton"),
				onClick = function()
					Onboarding.startTutorial()
				end,
			},
			{
				label = L("tutorial.skipButton"),
				onClick = function()
					Onboarding.skipTutorial()
				end,
			},
		},
	})

	return true
end

function Onboarding.startTutorial()
	local s = settings()
	local m = meta()
	local state = onboardingState()

	s.tips_enabled = true
	m.expert_mode = false
	m.tutorial_completed = false
	state.active = true
	state.step = "micro_tutorial_place_tower"
	state.tipsShown = 0
	clearPlacementTarget(state)
	Save.flush()
	launchTutorialRunIfPossible()

	TutorialTip.show({
		id = "micro_tutorial_place_tower",
		title = L("tutorial.placeTitle"),
		body = L("tutorial.placeBody"),
		dismissLabel = L("tutorial.skipTutorial"),
		onDismiss = function()
			Onboarding.skipTutorial()
		end,
	})
end

function Onboarding.skipTutorial()
	local m = meta()
	local state = onboardingState()

	m.tutorial_completed = true
	state.active = false
	state.step = "complete"
	clearPlacementTarget(state)
	Save.flush()
	TutorialTip.hide()
end

function Onboarding.completeTutorial()
	local m = meta()
	local state = onboardingState()

	m.tutorial_completed = true
	state.active = false
	state.step = "complete"
	clearPlacementTarget(state)
	Save.flush()

	TutorialTip.show({
		id = "tutorial_complete",
		title = L("tutorial.readyTitle"),
		body = L("tutorial.readyBody"),
		dismissLabel = L("tutorial.dismiss"),
		onDismiss = function()
			TutorialTip.hide()
		end,
	})
end

function Onboarding.replayTutorial()
	local m = meta()
	local s = settings()
	local state = onboardingState()

	s.tips_enabled = true
	m.expert_mode = false
	m.tutorial_completed = false
	m.tipsSeen = {}
	state.welcomeOffered = false
	Save.flush()
	Onboarding.startTutorial()
end

function Onboarding.onGameStarted()
	local state = onboardingState()

	if state.step == "micro_tutorial_place_tower" then
		state.active = true
		applyForgivingTutorialStart()
		setPlacementTarget(state)
	elseif not meta().tutorial_completed then
		Onboarding.startTutorial()
	end
end

function Onboarding.onTowerPlaced()
	local state = onboardingState()

	if state.step == "micro_tutorial_place_tower" then
		state.step = "micro_tutorial_start_wave"
		clearPlacementTarget(state)
		TutorialTip.show({
			id = "micro_tutorial_start_wave",
			title = L("tutorial.waveTitle"),
			body = L("tutorial.waveBody"),
			dismissLabel = L("tutorial.skipTutorial"),
			onDismiss = function()
				Onboarding.skipTutorial()
			end,
		})
		return
	end

	Onboarding.showTip("first_tower", "tips.firstTowerTitle", "tips.firstTowerBody")
end

function Onboarding.onWaveStarted()
	local state = onboardingState()

	if state.step == "micro_tutorial_start_wave" then
		Onboarding.completeTutorial()
		return
	end

	Onboarding.showTip("first_wave", "tips.firstWaveTitle", "tips.firstWaveBody")
end

function Onboarding.onUpgradePromptAvailable()
	Onboarding.showTip("first_upgrade", "tips.firstUpgradeTitle", "tips.firstUpgradeBody")
end

function Onboarding.isPlacementLessonActive()
	local state = onboardingState()

	return state.active == true and state.step == "micro_tutorial_place_tower" and meta().tutorial_completed ~= true
end

function Onboarding.getPlacementTarget()
	if not Onboarding.isPlacementLessonActive() then
		return nil, nil
	end

	local state = onboardingState()

	if not state.targetGX or not state.targetGY then
		setPlacementTarget(state)
	end

	return state.targetGX, state.targetGY
end

function Onboarding.update(dt)
	TutorialTip.update(dt)
end

function Onboarding.draw()
	TutorialTip.draw()
end

function Onboarding.mousepressed(x, y, button)
	return TutorialTip.mousepressed(x, y, button)
end

function Onboarding.mousereleased(x, y, button)
	return TutorialTip.mousereleased(x, y, button)
end

function Onboarding.keypressed(key)
	if key == "escape" and TutorialTip.isActive() then
		local state = onboardingState()

		if state.step == "micro_tutorial_place_tower" or state.step == "micro_tutorial_start_wave" or state.step == "offering_tutorial" then
			Onboarding.skipTutorial()
		else
			TutorialTip.hide()
		end

		return true
	end

	return false
end

return Onboarding

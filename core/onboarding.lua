local Save = require("core.save")
local State = require("core.state")
local L = require("core.localization")
local TutorialTip = require("ui.overlays.tutorial_tip")

local Onboarding = {}

local MAX_FIRST_RUN_TIPS = 4

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
	Save.flush()

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
	Save.flush()
	TutorialTip.hide()
end

function Onboarding.completeTutorial()
	local m = meta()
	local state = onboardingState()

	m.tutorial_completed = true
	state.active = false
	state.step = "complete"
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
		Onboarding.startTutorial()
	elseif not meta().tutorial_completed then
		Onboarding.startTutorial()
	end
end

function Onboarding.onTowerPlaced()
	local state = onboardingState()

	if state.step == "micro_tutorial_place_tower" then
		state.step = "micro_tutorial_start_wave"
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
		TutorialTip.hide()
		return true
	end

	return false
end

return Onboarding

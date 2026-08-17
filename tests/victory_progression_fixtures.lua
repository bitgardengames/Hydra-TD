-- Dependency-free victory progression fixtures. Run from the repository root with Lua/LuaJIT.

love = {
	graphics = {getDimensions = function() return 1280, 720 end},
	math = {random = function(a) return a or 0.5 end},
	mouse = {},
}

local state = {
	worldMapIndex = 1,
	resolveMapIndex = function(index) return index end,
}
local maps = {{id = "first"}, {id = "highridge"}, {id = "twinloop"}}
local campaignComplete = false
local currentDifficulty = "normal"
local campaignUnlocks = {
	isChallengeModeUnlocked = function() return campaignComplete end,
	isEndlessUnlocked = function() return campaignComplete end,
}

local function module(name, value)
	package.loaded[name] = value
end

module("core.theme", {
	ui = {good = {}, text = {}, backdrop = {}, screenDim = {}, selected = {}, wave = {}, money = {}},
	outline = {color = {}, width = 1},
	medal = {gold = {}, silver = {}},
})
module("core.constants", {IS_DEMO = false})
module("ui.button", {})
module("core.state", state)
module("systems.sound", {play = function() end})
module("systems.difficulty", {key = function() return currentDifficulty end})
module("ui.text", {})
module("core.fonts", {})
module("world.map_defs", maps)
module("ui.medals", {
	getClusterSize = function() return 10, 10 end,
	getCount = function(difficulty) return ({easy = 1, normal = 2, hard = 3})[difficulty] or 0 end,
	resetAnimations = function() end,
	beginReveal = function() end,
})
module("scenes.backdrop", {})
module("core.steam", {})
local save = {data = {meta = {clearedMaps = {}}, mapStats = {}}}
function save.flush() end
module("core.save", save)
module("core.localization", setmetatable({}, {__call = function(_, key) return key end}))
module("world.tower_defs", {})
module("systems.ability_defs", {})
module("systems.campaign_unlocks", campaignUnlocks)
module("render.draw_entities", {})
module("ui.run_recap", {})
module("ui.scroll_view", {
	new = function() return {offset = 0, update = function() end, reset = function(self) self.offset = 0 end} end,
})
module("ui.ability_icons", {})
module("ui.tooltip", {})
module("ui.overlay", {})
module("ui.overlays.demo_complete", {})

resetGame = function() end

local Victory = require("ui.menu.screens.victory")

local function findButton(id)
	local buttons
	for index = 1, math.huge do
		local name, value = debug.getupvalue(Victory.load, index)
		if not name then break end
		if name == "buttons" then
			buttons = value
			break
		end
	end
	assert(buttons, "victory buttons should be available after loading")
	for _, button in ipairs(buttons) do
		if button.id == id then return button end
	end
end

state.worldMapIndex = #maps - 1
Victory.load()
local nextButton = assert(findButton("next"), "penultimate victory should present Next Map")
assert(nextButton.label == "menu.nextMap", "progression action should retain the Next Map label")
assert(not campaignUnlocks.isChallengeModeUnlocked(), "Challenge should remain locked after High Ridge")
assert(not campaignUnlocks.isEndlessUnlocked(), "Endless should remain locked after High Ridge")
assert(not findButton("endless").enabled, "Endless should remain locked after High Ridge")
nextButton.onClick()
assert(state.worldMapIndex == #maps, "penultimate victory should advance exactly one map")

state.worldMapIndex = #maps
campaignComplete = true
Victory.load()
assert(not findButton("next"), "final victory must not present a same-map Next Map restart")
assert(campaignUnlocks.isChallengeModeUnlocked(), "Challenge should unlock after Twin Loop")
assert(campaignUnlocks.isEndlessUnlocked(), "Endless should unlock after Twin Loop")
assert(findButton("endless").enabled, "Endless should unlock after Twin Loop")
assert(findButton("menu"), "final victory should retain a non-progression menu action")

local function getUpvalue(fn, wanted)
	for index = 1, math.huge do
		local name, value = debug.getupvalue(fn, index)
		if not name then break end
		if name == wanted then return value end
	end
end

local buildRewardCards = assert(getUpvalue(Victory.enter, "buildRewardCards"))
local function getRewardCards()
	return assert(getUpvalue(buildRewardCards, "rewardCards"))
end

local function enterTwinLoop(difficulty, alreadyCleared)
	currentDifficulty = difficulty
	state.worldMapIndex = #maps
	state.mapIndex = #maps
	state.previousCompletionDifficulty = nil
	state.unlockedTowersThisVictory = {}
	state.unlockedAbilitiesThisVictory = {}
	state.unlockedRewardsThisVictory = alreadyCleared and {}
		or {{type = "campaign_complete", id = "challenge_endless"}}
	save.data.meta.clearedMaps = alreadyCleared and {twinloop = true} or {}
	Victory.enter()
	return getRewardCards()
end

for _, difficulty in ipairs({"easy", "normal", "hard"}) do
	local cards = enterTwinLoop(difficulty, false)
	assert(#cards == 2, "first Twin Loop clear should append completion after ordinary unlocks on " .. difficulty)
	assert(cards[1].type == "campaign_complete", "ordinary unlock must remain first on " .. difficulty)
	assert(cards[2].type == "full_game_completion", "full-game completion card missing on " .. difficulty)
	assert(state.wasFirstClear, "first completion should be recorded on " .. difficulty)
end

local repeatCards = enterTwinLoop("hard", true)
assert(#repeatCards == 0, "repeat completion should retain the normal compact victory flow")
assert(not state.wasFirstClear, "repeat Twin Loop clear must not be treated as first completion")

print("victory progression fixtures passed")

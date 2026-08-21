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
local selectedMenu

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
module("systems.difficulty", {})
module("ui.text", {})
module("core.fonts", {})
module("world.map_defs", maps)
module("ui.medals", {getClusterSize = function() return 10, 10 end})
module("scenes.backdrop", {start = function() end})
module("core.steam", {setRichPresence = function() end})
module("core.save", {flush = function() end})
module("core.localization", setmetatable({}, {__call = function(_, key) return key end}))
module("world.tower_defs", {})
module("systems.ability_defs", {})
module("render.draw_entities", {})
module("ui.run_recap", {})
module("ui.scroll_view", {
	new = function() return {update = function() end} end,
})
module("ui.ability_icons", {})
module("ui.tooltip", {})
module("ui.overlay", {})
module("ui.overlays.demo_complete", {})
module("ui.menu.menu", {set = function(mode) selectedMenu = mode end})

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
nextButton.onClick()
assert(state.worldMapIndex == #maps, "penultimate victory should advance exactly one map")

state.worldMapIndex = #maps
state.unlockedRewardsThisVictory = {}
Victory.load()
assert(not findButton("next"), "final victory must not present a same-map Next Map restart")
local mapSelectButton = assert(findButton("map_select"),
	"final victory should retain a map selection action")
assert(mapSelectButton.label == "menu.mapSelect",
	"victory navigation should be labeled Map Select")
mapSelectButton.onClick()
assert(selectedMenu == "campaign",
	"victory Map Select should open campaign map selection")

print("victory progression fixtures passed")

local Button = require("ui.button")
local Fonts = require("core.fonts")
local Theme = require("core.theme")
local Text = require("ui.text")
local State = require("core.state")
local Save = require("core.save")
local Sound = require("systems.sound")
local Difficulty = require("systems.difficulty")
local Contracts = require("systems.contracts")
local Backdrop = require("scenes.backdrop")

local Screen = {}
local buttons, contract

local function refresh()
	contract = Contracts.generate(os.time(), Contracts.DEFAULT_CADENCE, Contracts.RULESET_VERSION)
end

local function startContract()
	-- Keep the generated record on State; resetGame consumes its map, difficulty,
	-- seed and modifiers rather than generating anything a second time.
	State.activeContract = contract
	State.challenge = true
	State.ignoreStats = true
	State.mapIndex = contract.map.index
	State.worldMapIndex = contract.map.index
	Difficulty.set(contract.difficulty)
	Save.recordContractAttempt(contract.id)
	Save.flush()
	State.mode = "game"
	Backdrop.stop()
	resetGame()
	Sound.playMusic("gameplay")
end

function Screen.load()
	buttons = {
		{id = "start", label = "Start Contract", w = 240, h = 42, onClick = startContract},
		{id = "back", label = "Back", w = 240, h = 42, onClick = function()
			require("ui.menu.menu").set("menu"); Sound.play("uiBack")
		end},
	}
end

function Screen.enter() refresh() end

function Screen.update(dt)
	refresh() -- Changes only when the UTC rotation boundary is crossed.
	local sw, sh = love.graphics.getDimensions()
	for i, button in ipairs(buttons) do
		button.x, button.y = sw * 0.5 - button.w * 0.5, sh * 0.67 + (i - 1) * 58
	end
	Button.updateList(buttons, dt)
	Backdrop.update(dt)
end

local function duration(seconds)
	seconds = math.floor(seconds)
	local hours = math.floor(seconds / 3600)
	local minutes = math.floor((seconds % 3600) / 60)
	return string.format("%dh %02dm", hours, minutes)
end

function Screen.draw()
	Backdrop.draw()
	local sw, sh = love.graphics.getDimensions()
	local x, y, w, h = sw * 0.5 - 280, sh * 0.18, 560, 330
	love.graphics.setColor(Theme.outline.color)
	love.graphics.rectangle("fill", x - 3, y - 3, w + 6, h + 6, 18)
	love.graphics.setColor(Theme.ui.backdrop)
	love.graphics.rectangle("fill", x, y, w, h, 16)
	Fonts.set("menu")
	love.graphics.setColor(Theme.ui.text)
	Text.printfShadow("Daily Contract", x + 24, y + 22, w - 48, "center")
	Fonts.set("ui")
	local history = Save.data.contracts
	local best = history.personalBests[contract.id]
	local rewardState = history.completed[contract.id] and "Earned" or "Available"
	local lines = {
		"Map: " .. contract.map.id .. "  •  Baseline: " .. contract.difficulty,
		"Mutator: " .. contract.mutator.label,
		"Restriction: " .. contract.restriction.label,
		"Objective: " .. contract.objective.label,
		"Reward: " .. contract.reward.label .. " (" .. rewardState .. ")",
		"Personal best: " .. (best and tostring(best.value) or "No completed run"),
		"Rotates in: " .. duration(Contracts.secondsUntilRotation(os.time(), contract.cadence)),
	}
	for i, line in ipairs(lines) do Text.printfShadow(line, x + 32, y + 78 + (i - 1) * 30, w - 64, "left") end
	Button.drawList(buttons)
end

function Screen.mousepressed(x, y, button) return Button.mousepressedList(buttons, x, y, button) end
function Screen.mousereleased(x, y, button) return Button.mousereleasedList(buttons, x, y, button) end
function Screen.keypressed(key) if key == "escape" then require("ui.menu.menu").set("menu") end end

return Screen

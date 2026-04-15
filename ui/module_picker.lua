local Theme = require("core.theme")
local Fonts = require("core.fonts")
local State = require("core.state")
local Modules = require("systems.modules")
local L = require("core.localization")

local lg = love.graphics

local ModulePicker = {}

local cards = {}

local function prettyTowerName(kind)
	return L("tower." .. kind)
end

local function getModuleName(mod)
	if mod and mod.nameKey then
		return L(mod.nameKey)
	end

	return "Unknown Module"
end

local function getModuleDesc(mod)
	if mod and mod.descKey then
		return L(mod.descKey)
	end

	return ""
end

local function rebuildLayout()
	cards = {}

	if not State.modulePicker.choices then
		return
	end

	local sw, sh = lg.getDimensions()
	local count = #State.modulePicker.choices

	local cardW = 260
	local cardH = 190
	local gap = 22
	local totalW = count * cardW + (count - 1) * gap
	local startX = (sw - totalW) * 0.5
	local y = sh * 0.5 - cardH * 0.35

	for i = 1, count do
		local x = startX + (i - 1) * (cardW + gap)

		cards[i] = {
			x = x,
			y = y,
			w = cardW,
			h = cardH,
		}
	end
end

function ModulePicker.open(choices)
	State.modulePicker.active = true
	State.modulePicker.choices = choices
	rebuildLayout()
end

function ModulePicker.close()
	State.modulePicker.active = false
	State.modulePicker.choices = nil
	cards = {}
end

function ModulePicker.isActive()
	return State.modulePicker.active == true
end

function ModulePicker.choose(index)
	local picker = State.modulePicker
	local choice = picker.choices and picker.choices[index]

	if not choice then
		return false
	end

	Modules.add(choice.moduleId, choice.target)
	ModulePicker.close()

	return true
end

local function pointInCard(mx, my, c)
	return mx >= c.x and mx <= c.x + c.w and my >= c.y and my <= c.y + c.h
end

function ModulePicker.mousepressed(x, y, button)
	if not ModulePicker.isActive() or button ~= 1 then
		return false
	end

	for i = 1, #cards do
		if pointInCard(x, y, cards[i]) then
			return ModulePicker.choose(i)
		end
	end

	return true
end

function ModulePicker.keypressed(key)
	if not ModulePicker.isActive() then
		return false
	end

	if key == "1" then
		return ModulePicker.choose(1)
	elseif key == "2" then
		return ModulePicker.choose(2)
	elseif key == "3" then
		return ModulePicker.choose(3)
	end

	return true
end

function ModulePicker.draw()
	if not ModulePicker.isActive() then
		return
	end

	local sw, sh = lg.getDimensions()
	local text = Theme.ui.text
	local dim = Theme.ui.screenDim
	local outline = Theme.outline.color

	lg.setColor(dim[1], dim[2], dim[3], 0.82)
	lg.rectangle("fill", 0, 0, sw, sh)

	Fonts.set("menu")
	lg.setColor(text)
	lg.printf("Choose a Module", 0, sh * 0.18, sw, "center")

	Fonts.set("ui")
	lg.setColor(1, 1, 1, 0.7)
	lg.printf("Press 1, 2, or 3", 0, sh * 0.18 + 34, sw, "center")

	local choices = State.modulePicker.choices or {}

	for i = 1, #choices do
		local choice = choices[i]
		local mod = Modules.getDef(choice.moduleId)
		local c = cards[i]

		local towerColor = Theme.tower[choice.target] or text

		lg.setColor(outline)
		lg.rectangle("fill", c.x, c.y, c.w, c.h, 14, 14)

		lg.setColor(0.10, 0.10, 0.12, 1)
		lg.rectangle("fill", c.x + 2, c.y + 2, c.w - 4, c.h - 4, 12, 12)

		lg.setColor(1, 1, 1, 0.04)
		lg.rectangle("line", c.x + 2, c.y + 2, c.w - 4, c.h - 4, 12, 12)

		lg.setColor(towerColor)
		lg.rectangle("fill", c.x + 12, c.y + 12, c.w - 24, 36, 12, 12)

		lg.setColor(0, 0, 0, 0.25)
		lg.rectangle("fill", c.x + 12, c.y + 30, c.w - 24, 18, 0, 0)

		lg.setColor(0, 0, 0, 0.25)
		lg.rectangle("fill", c.x + 14, c.y + 14, c.w - 28, 32, 10, 10)

		lg.setColor(1, 1, 1)
		lg.print(prettyTowerName(choice.target), c.x + 22, c.y + 20)

		Fonts.set("menu") -- bigger
		lg.setColor(1, 1, 1)
		lg.printf(getModuleName(mod), c.x + 18, c.y + 58, c.w - 36, "left")

		Fonts.set("ui")
		lg.setColor(1, 1, 1, 0.75)
		lg.printf(getModuleDesc(mod), c.x + 18, c.y + 92, c.w - 36, "left")
	end
end

return ModulePicker
local Theme = require("core.theme")
local Fonts = require("core.fonts")
local Text = require("ui.text")

local AnimatedRunStats = {}
AnimatedRunStats.__index = AnimatedRunStats

local ROW_H = 42
local ROW_GAP = 8
local ROW_DURATION = 0.7
local BAR_MAX_WIDTH = 380

local function clamp(value)
	return math.max(0, math.min(1, value))
end

local function formatNumber(value)
	local text = tostring(math.max(0, math.floor((value or 0) + 0.5)))
	local changed
	repeat
		text, changed = text:gsub("^(%-?%d+)(%d%d%d)", "%1,%2")
	until changed == 0
	return text
end

function AnimatedRunStats.new(fillColor)
	return setmetatable({rows = {}, elapsed = 0, rowDuration = ROW_DURATION,
		fillColor = fillColor or Theme.ui.good, complete = true}, AnimatedRunStats)
end

function AnimatedRunStats:setRows(rows)
	self.rows = rows or {}
	self:reset()
end

function AnimatedRunStats:reset()
	self.elapsed = 0
	self.complete = #self.rows == 0
	for _, row in ipairs(self.rows) do
		row.displayedValue = 0
		row.fill = 0
	end
end

function AnimatedRunStats:update(dt)
	if self.complete then return end
	self.elapsed = self.elapsed + math.max(0, dt or 0)
	for index, row in ipairs(self.rows) do
		-- Give each result its own moment instead of overlapping every fill.
		local progress = clamp((self.elapsed - (index - 1) * self.rowDuration) / self.rowDuration)
		local eased = 1 - (1 - progress) ^ 3
		row.displayedValue = (row.value or 0) * eased
		row.fill = row.denominator and row.denominator > 0
			and clamp((row.value or 0) / row.denominator) * eased or nil
	end
	local lastStart = math.max(0, (#self.rows - 1) * self.rowDuration)
	if self.elapsed >= lastStart + self.rowDuration then self:finish() end
end

function AnimatedRunStats:finish()
	for _, row in ipairs(self.rows) do
		row.displayedValue = row.value or 0
		row.fill = row.denominator and row.denominator > 0
			and clamp((row.value or 0) / row.denominator) or nil
	end
	self.complete = true
end

function AnimatedRunStats:isComplete() return self.complete end
function AnimatedRunStats:getHeight()
	return #self.rows > 0 and #self.rows * ROW_H + (#self.rows - 1) * ROW_GAP + 18 or 0
end

function AnimatedRunStats:draw(x, y, width, alpha)
	local lg = love.graphics
	alpha = alpha or 1
	for index, row in ipairs(self.rows) do
		local rowY = y + (index - 1) * (ROW_H + ROW_GAP)
		local barWidth = math.min(width, BAR_MAX_WIDTH)
		local barX = x + (width - barWidth) * 0.5
		Fonts.set("ui")
		lg.setColor(Theme.ui.text[1], Theme.ui.text[2], Theme.ui.text[3], 0.78 * alpha)
		Text.printfShadow(row.label, barX, rowY, barWidth * 0.68, "left")
		local value = formatNumber(row.displayedValue)
		if row.denominator then value = value .. " / " .. formatNumber(row.denominator) end
		Text.printfShadow(value, barX, rowY, barWidth, "right")
		local barY = rowY + 25
		if row.denominator and row.denominator > 0 then
			lg.setColor(Theme.ui.screenDim[1], Theme.ui.screenDim[2], Theme.ui.screenDim[3], 0.6 * alpha)
			lg.rectangle("fill", barX, barY, barWidth, 8, 4, 4)
			lg.setColor(self.fillColor[1], self.fillColor[2], self.fillColor[3], 0.9 * alpha)
			lg.rectangle("fill", barX, barY, barWidth * clamp(row.fill or 0), 8, 4, 4)
		end
	end
	if not self.complete then
		local L = require("core.localization")
		lg.setColor(Theme.ui.text[1], Theme.ui.text[2], Theme.ui.text[3], 0.48 * alpha)
		Text.printfShadow(L("runRecap.skipHint"), x, y + self:getHeight() - 14, width, "center")
	end
end

AnimatedRunStats.formatNumber = formatNumber
return AnimatedRunStats

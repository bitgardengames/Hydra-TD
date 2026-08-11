-- Dependency-free fixtures for wrapped notifications and contextual tips.
package.path = "./?.lua;" .. package.path

local Layout = require("ui.message_layout")

local function font(size, characterW)
	return {
		getHeight = function() return size end,
		getWidth = function(_, text) return #text * characterW end,
		getWrap = function(self, text, limit)
			local perLine = math.max(1, math.floor(limit / characterW))
			local lines = {}
			for start = 1, #text, perLine do
				lines[#lines + 1] = text:sub(start, start + perLine - 1)
			end
			return math.min(self:getWidth(text), limit), lines
		end,
	}
end

local longText = ("A long notification must remain readable at the minimum supported viewport. "):rep(3)
local cases = {
	{name = "minimum viewport", viewportW = 1280, font = font(16, 8)},
	{name = "large font", viewportW = 1280, font = font(36, 20)},
}

for _, case in ipairs(cases) do
	local notification = Layout.notification(case.font, longText, case.viewportW, 36, 8, 4)
	assert(notification.w <= case.viewportW - 36 + 8, case.name .. " notification exceeds viewport")
	assert(notification.lineCount > 1, case.name .. " notification did not wrap")

	local tip = Layout.tip(case.font, longText, "Dismiss", case.viewportW, 24, 12, 8, 10, 10, 4)
	assert(tip.w <= case.viewportW - 48, case.name .. " tip exceeds viewport")
	assert(tip.messageH > case.font:getHeight(), case.name .. " tip did not grow for wrapped text")
	assert(tip.messageW + tip.dismissW + 10 + 24 <= tip.w, case.name .. " dismiss space overlaps message")
end

local heights = {24, 56, 40, 88, 32}
local offsets = Layout.stackOffsets(heights, 4)
for i = #heights, 1, -1 do
	if i < #heights then
		assert(offsets[i] - offsets[i + 1] == heights[i + 1] + 4,
			"differently sized stack items collide")
	end
end

print("message layout fixtures passed")

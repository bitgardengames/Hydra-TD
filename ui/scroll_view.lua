local Util = require("core.util")

local ScrollView = {}
ScrollView.__index = ScrollView

function ScrollView.new()
	return setmetatable({offset = 0, contentSize = 0, viewportSize = 0, maxOffset = 0}, ScrollView)
end

function ScrollView:update(contentSize, viewportSize)
	self.contentSize = math.max(0, contentSize or 0)
	self.viewportSize = math.max(0, viewportSize or 0)
	self.maxOffset = math.max(0, self.contentSize - self.viewportSize)
	self.offset = Util.clamp(self.offset, 0, self.maxOffset)

	return self.offset
end

function ScrollView:move(distance)
	self.offset = Util.clamp(self.offset + distance, 0, self.maxOffset)
	return self.offset
end

function ScrollView:reset()
	self.offset = 0
end

function ScrollView:canScroll()
	return self.maxOffset > 0
end

function ScrollView:getThumb(trackStart, trackSize, minimumSize)
	if not self:canScroll() or trackSize <= 0 then
		return trackStart, trackSize
	end

	local thumbSize = math.max(minimumSize or 0, trackSize * self.viewportSize / self.contentSize)
	thumbSize = math.min(trackSize, thumbSize)
	local progress = self.offset / self.maxOffset

	return trackStart + (trackSize - thumbSize) * progress, thumbSize
end

return ScrollView

local Layout = {}

local max = math.max
local min = math.min

function Layout.stackOffsets(heights, gap)
	local offsets = {}
	local offset = 0
	for i = #heights, 1, -1 do
		offsets[i] = offset
		offset = offset + heights[i] + gap
	end
	return offsets, offset
end

function Layout.notification(font, text, viewportW, x, paddingX, paddingY)
	local textLimit = max(1, viewportW - x - paddingX)
	local wrappedW, lines = font:getWrap(text, textLimit)
	local lineCount = max(1, #lines)
	local textW = min(textLimit, wrappedW)
	local textH = lineCount * font:getHeight()

	return {
		textW = textW,
		textH = textH,
		lineCount = lineCount,
		w = textW + paddingX * 2,
		h = textH + paddingY * 2,
	}
end

function Layout.tip(font, message, dismissText, viewportW, margin, paddingX, paddingY,
		gap, dismissPaddingX, dismissPaddingY)
	local availableW = max(1, viewportW - margin * 2)
	local dismissW = min(availableW, font:getWidth(dismissText) + dismissPaddingX * 2)
	local innerW = max(1, availableW - paddingX * 2)
	local messageLimit = max(1, innerW - dismissW - gap)
	local wrappedW, lines = font:getWrap(message, messageLimit)
	local messageW = min(messageLimit, wrappedW)
	local messageH = max(1, #lines) * font:getHeight()
	local dismissH = font:getHeight() + dismissPaddingY * 2
	local contentH = max(messageH, dismissH)
	local w = min(availableW, messageW + gap + dismissW + paddingX * 2)

	return {
		messageW = max(1, w - paddingX * 2 - dismissW - gap),
		messageH = messageH,
		dismissW = dismissW,
		dismissH = dismissH,
		w = w,
		h = contentH + paddingY * 2,
	}
end

return Layout

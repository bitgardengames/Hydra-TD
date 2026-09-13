-- Dependency-free tooltip layout and scissor regression fixtures. Run from the
-- repository root with Lua/LuaJIT.
package.path = "./?.lua;" .. package.path

local screenW, screenH = 400, 300
local scissor
local scissorCalls = {}
local drawn = {}

local function pack(...)
	return {n = select("#", ...), ...}
end

local function setScissor(...)
	local args = pack(...)
	scissorCalls[#scissorCalls + 1] = args
	if args.n == 0 then
		scissor = nil
	else
		scissor = {args[1], args[2], args[3], args[4]}
	end
end

local graphics = {
	getWidth = function() return screenW end,
	getDimensions = function() return screenW, screenH end,
	getScissor = function()
		if scissor then
			return scissor[1], scissor[2], scissor[3], scissor[4]
		end
	end,
	setScissor = setScissor,
	setColor = function() end,
	rectangle = function() end,
}

love = {
	graphics = graphics,
	mouse = {getX = function() return 0 end, getY = function() return 0 end},
}

local function wrap(text, limit)
	local maxChars = math.max(1, math.floor(limit / 10))
	local lines = {}
	if text == "" then
		lines[1] = ""
	else
		for start = 1, #text, maxChars do
			lines[#lines + 1] = text:sub(start, start + maxChars - 1)
		end
	end
	local widest = 0
	for _, line in ipairs(lines) do
		widest = math.max(widest, #line * 10)
	end
	return widest, lines
end

local font = {
	getWidth = function(_, text) return #text * 10 end,
	getWrap = function(_, text, limit) return wrap(text, limit) end,
}

package.loaded["core.fonts"] = {
	tooltip = font,
	ui = font,
	set = function() end,
}
package.loaded["ui.text"] = {
	printShadow = function(text) drawn[#drawn + 1] = text end,
}

local Tooltip = require("ui.tooltip")

local function resetDrawState(existingScissor)
	scissor = existingScissor
	scissorCalls = {}
	drawn = {}
end

local function assertDrawn(text)
	for _, actual in ipairs(drawn) do
		if actual == text then return end
	end
	error("tooltip did not draw expected content: " .. text)
end

Tooltip.active = {
	title = "Tower title",
	rows = {
		{kind = "text", text = "Description row"},
		{label = "Damage", value = 12, delta = "+3"},
	},
	x = 10,
	y = 20,
}
Tooltip.recalculate()

assert(#Tooltip.active.titleLines > 0, "title lines were not established")
assert(#Tooltip.active.rowLayouts[1].lines > 0, "text row lines were not established")
assert(#Tooltip.active.rowLayouts[2].labelLines > 0, "key/value label lines were not established")
assert(not Tooltip.active.stackStats, "wide tooltip unexpectedly stacked key/value rows")

-- Drawing with no prior scissor must disable the tooltip scissor afterward.
resetDrawState(nil)
Tooltip.draw()
assert(scissor == nil, "draw did not restore the absence of a scissor")
assert(scissorCalls[#scissorCalls].n == 0, "draw did not clear its scissor")
assertDrawn("Tower title")
assertDrawn("Description row")
assertDrawn("Damage")
assertDrawn("12")
assertDrawn("(+3)")

-- Drawing inside another clipped component must restore all four values.
resetDrawState({3, 4, 50, 60})
Tooltip.draw()
local restored = scissorCalls[#scissorCalls]
assert(restored.n == 4, "draw did not restore a four-value scissor")
assert(restored[1] == 3 and restored[2] == 4 and restored[3] == 50 and restored[4] == 60,
	"draw changed the enclosing scissor")

-- A narrow viewport wraps both halves and stacks stats below their labels.
screenW = 70
Tooltip.recalculate()
assert(Tooltip.active.stackStats, "narrow tooltip did not stack key/value rows")
assert(#Tooltip.active.rowLayouts[2].labelLines > 1, "narrow label was not wrapped")
assert(#Tooltip.active.rowLayouts[2].statsLines > 0, "narrow stats lines were not established")
resetDrawState(nil)
Tooltip.draw()
assertDrawn("12 (")
assertDrawn("+3)")

print("tooltip fixtures passed")

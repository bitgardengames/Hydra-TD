-- Dependency-free confirmation dialog state and presentation fixtures.
-- Run from the repository root with Lua/LuaJIT.
love = {
	graphics = { getDimensions = function() return 800, 600 end },
	mouse = { getPosition = function() return 0, 0 end },
}

package.loaded["ui.button"] = {
	updateList = function() end,
	drawList = function() end,
	mousepressedList = function() end,
	mousereleasedList = function() end,
}
package.loaded["core.fonts"] = { set = function() end }
package.loaded["core.theme"] = {
	outline = { width = 2, color = { 1, 1, 1, 1 } },
	ui = { backdrop = { 0, 0, 0, 1 }, text = { 1, 1, 1, 1 } },
}
package.loaded["ui.text"] = { printfShadow = function() end }

local Presentation = require("ui.confirmation_dialog_presentation")
local ConfirmationDialog = require("ui.confirmation_dialog")

local opening = Presentation.pose("opening", Presentation.OPEN_DURATION * 0.5, false)
assert(opening.panelAlpha > 0 and opening.panelAlpha < 1, "opening must fade the panel")
assert(opening.scale < 1 and opening.offsetY > 0, "opening must move the panel as one pose")
assert(not opening.pointerReady, "early opening must suppress pointer activation")
assert(Presentation.pose("opening", Presentation.OPEN_DURATION * 0.8, false).pointerReady,
	"late opening should permit pointer activation")

local cancelled = Presentation.pose("closing", Presentation.CANCEL_DURATION * 0.7, false, "cancel")
local confirmed = Presentation.pose("closing", Presentation.CONFIRM_DURATION * 0.3, false, "confirm")
assert(cancelled.panelAlpha < 1 and cancelled.offsetY > 0, "cancel must reverse the entrance")
assert(confirmed.scale < 1 and confirmed.offsetY < 0, "confirm must show an accepted response")

local calls = 0
local dialog = ConfirmationDialog.new()
dialog:show({ title = "Title", description = "Body", confirmLabel = "Yes", cancelLabel = "No",
	onConfirm = function() calls = calls + 1 end })
assert(dialog:isOpen() and dialog.state == "opening", "show must enter opening state")
assert(not dialog:confirm(), "confirm must not activate during early opening")
dialog:update(Presentation.OPEN_DURATION)
assert(dialog.state == "open", "opening must settle into open state")
assert(dialog:confirm() and dialog.state == "closing" and dialog.closeReason == "confirm",
	"confirm must enter accepted closing state")
assert(not dialog:confirm() and not dialog:cancel(), "closing must block all repeated input")
assert(calls == 0, "callback must wait until the accepted response completes")
dialog:update(Presentation.CONFIRM_DURATION)
assert(not dialog:isOpen() and calls == 1, "callback must run exactly once after close")
dialog:update(1)
assert(calls == 1, "closed dialog must never repeat its callback")

dialog:show({ title = "Title", description = "Body", confirmLabel = "Yes", cancelLabel = "No",
	onConfirm = function() calls = calls + 1 end })
assert(dialog:cancel() and dialog.state == "closing" and dialog.closeReason == "cancel",
	"cancel must enter cancelling close state")
dialog:update(Presentation.CANCEL_DURATION)
assert(not dialog:isOpen() and calls == 1 and dialog.title == nil, "cancel must clear content without callback")

local reduced = Presentation.pose("opening", Presentation.REDUCED_DURATION * 0.5, true)
assert(reduced.scale == 1 and reduced.offsetY == 0, "reduced motion must use opacity only")
assert(Presentation.REDUCED_DURATION < Presentation.OPEN_DURATION, "reduced motion must complete promptly")

print("confirmation dialog fixtures passed")

local Sound = require("systems.sound")
local Util = require("core.util")

local Controls = {}

local function commonActivate(row, _, ctx)
	if row.onClick then
		row.onClick()
	end
	return true
end

Controls.operations = {
	slider = {
		draw = function(row, view, hovered, ctx) ctx.drawSlider(row, view, hovered) end,
		adjust = function(row, direction, ctx)
			local previous = row.get()
			local value = Util.clamp(previous + direction * ctx.sliderKeyStep, 0, 1)
			if value == previous then
				return false
			end
			row.set(value)
			ctx.changed()
			Sound.play("uiMove")
			ctx.flush()
			return true
		end,
		setFromPointer = function(row, view, x, ctx)
			local rect = view and view.sliderBounds
			if not rect then
				return false
			end
			row.set(Util.clamp((x - rect.x) / rect.w, 0, 1))
			ctx.changed()
			ctx.beginDrag(view)
			return true
		end,
	},
	toggle = {
		draw = function(row, view, _, ctx) ctx.drawToggle(row, view.bounds.x, view.bounds.y) end,
		activate = function(row, _, ctx)
			row.set(not row.get())
			ctx.changed()
			Sound.play("uiConfirm")
			return true
		end,
	},
	keybind = {
		draw = function(row, view, _, ctx) ctx.drawKeybind(row, view.bounds.x, view.bounds.y) end,
		activate = function(row, _, ctx) ctx.capture:start(row); return true end,
	},
	action = {
		draw = function(row, view, _, ctx) ctx.drawAction(row, view.bounds.x, view.bounds.y) end,
		activate = commonActivate,
	},
	info = {
		draw = function(row, view, _, ctx) ctx.drawInfo(row, view.bounds.x, view.bounds.y) end,
		activate = function() Sound.play("uiMove"); return true end,
	},
}

function Controls.dispatch(row, operation, ...)
	local handlers = row and Controls.operations[row.type]
	local handler = handlers and handlers[operation]
	if handler then
		return handler(row, ...)
	end
	return false
end

return Controls

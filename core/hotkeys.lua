local State = require("core.state")

local Hotkeys = {}

-- Keyboard bindings
Hotkeys.kb = {
	shop = {
		slow = "1",
		lancer = "2",
		poison = "3",
		cannon = "4",
		shock = "5",
		plasma = "6",
	},

	actions = {
		escape = "escape",
		upgrade = "u",
		sell = "x",
		nextMap = "n",
		endless = "e",
		fastForward = "tab",
		skipPrep = "space",
		toggleMeter = "d",
		--toggleMeterInfo = "f",
		screenshot = "printscreen",
	},
}

-- Gamepad bindings (standardized LOVE names)
-- These names work across Xbox/PS/Switch/Steam Deck (input-wise).
Hotkeys.pad = {
	actions = {
		confirm = "a",
		cancel = "b",
		pause = "start",
		back = "back",

		fastForward = "rightshoulder",
		skipPrep = "leftshoulder",

		upgrade = "y",
		sell = "x",

		toggleMeter = "leftstick",
		--toggleMeterInfo = "leftstick",
	},

	-- I need a wheel or something, controllers don't handle this well
	shop = {
		dpleft = "slow",
		dpup = "lancer",
		dpdown = "poison",
		dpright = "cannon",
		rightstick = "shock",
	},
}

-- Text aliases for controller buttons (for UI display)
Hotkeys.padAliases = {
	a = "A",
	b = "B",
	x = "X",
	y = "Y",

	leftshoulder  = "LB",
	rightshoulder = "RB",

	leftstick  = "L3",
	rightstick = "R3",

	start = "Start",
	back  = "Back",
}

function Hotkeys.getShopKey(kind)
	return Hotkeys.kb.shop[kind]
end

function Hotkeys.getActionKey(action)
	return Hotkeys.kb.actions[action]
end

-- Returns a readable label based on input mode (keyboard vs controller)
function Hotkeys.getDisplay(action)
	local usingController = State.inputSource == "controller"

	-- Controller display
	if usingController then
		local btn = Hotkeys.pad.actions[action]

		if btn then
			return Hotkeys.padAliases[btn] or btn:upper()
		end

		-- Shop actions (d-pad)
		for dpad, kind in pairs(Hotkeys.pad.shop) do
			if kind == action then
				return Hotkeys.padAliases[dpad] or dpad
			end
		end

		return nil
	end

	-- Keyboard display
	local key = Hotkeys.kb.actions[action] or Hotkeys.kb.shop[action]

	if not key then
		return nil
	end

	-- Normalize common keys
	if key == "escape" then return "Esc" end
	if key == "space" then return "Space" end
	if key == "tab" then return "Tab" end

	return key:upper()
end

function Hotkeys.padActionFromButton(button)
	for action, btn in pairs(Hotkeys.pad.actions) do
		if btn == button then
			return action
		end
	end

	return nil
end

function Hotkeys.padShopKindFromButton(joystick, button)
	--[[ Modifier layer
	if joystick:isGamepadDown(Hotkeys.pad.shop.modifier) then
		return Hotkeys.pad.shop.mod and Hotkeys.pad.shop.mod[button]
	end]]

	-- Base layer
	return Hotkeys.pad.shop[button]
end

function Hotkeys.getGlyph(action)
	-- Only show glyphs when using a controller
	if State.inputSource ~= "controller" then
		return nil
	end

	-- Direct action bindings (confirm, upgrade, sell, etc.)
	local btn = Hotkeys.pad.actions[action]
	if btn then
		-- Face buttons
		if btn == "a" then return "confirm" end
		if btn == "b" then return "cancel" end
		if btn == "x" then return "x" end
		if btn == "y" then return "y" end

		-- Shoulders
		if btn == "leftshoulder" then return "pad_lb" end
		if btn == "rightshoulder" then return "pad_rb" end

		-- Stick buttons
		if btn == "leftstick" then return "pad_l3" end
		if btn == "rightstick" then return "pad_r3" end

		-- D-pad used as actions
		if btn == "dpup" then return "dpad_up" end
		if btn == "dpdown" then return "dpad_down" end
		if btn == "dpleft" then return "dpad_left" end
		if btn == "dpright" then return "dpad_right" end
	end

	-- Shop bindings (tower kinds mapped to d-pad / stick)
	for dpad, kind in pairs(Hotkeys.pad.shop) do
		if kind == action then
			if dpad == "dpup" then return "dpad_up" end
			if dpad == "dpdown" then return "dpad_down" end
			if dpad == "dpleft" then return "dpad_left" end
			if dpad == "dpright" then return "dpad_right" end
			if dpad == "rightstick" then return "pad_r3" end
		end
	end

	return nil
end

return Hotkeys
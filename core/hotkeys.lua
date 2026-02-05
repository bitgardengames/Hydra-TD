local State = require("core.state")

local Hotkeys = {}

-- Keyboard bindings
Hotkeys.kb = {
	shop = {
		lancer = "1",
		slow = "2",
		poison = "3",
		shock = "4",
		cannon = "5",
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
		toggleMeterInfo = "f",
		screenshot = "printscreen",
	},
}

-- Gamepad bindings (standardized LÖVE names)
-- These names work across Xbox/PS/Switch/Steam Deck (input-wise).
Hotkeys.pad = {
	actions = {
		confirm = "a", -- A / Cross
		cancel = "b", -- B / Circle
		pause = "start", -- Menu / Options
		back = "back", -- View / Share

		-- Tempo
		fastForward = "rightshoulder", -- RB / R1
		skipPrep = "leftshoulder", -- LB / L1

		-- Tower actions
		upgrade = "y", -- Y / Triangle
		sell = "x", -- X / Square

		-- Info
		toggleMeter = "rightstick", -- R3
		toggleMeterInfo = "leftstick", -- L3
	},

	shop = {
		dpup = "lancer",
		dpleft = "slow",
		dpdown = "poison",
		dpright = "cannon",

		-- Optional special tower
		--y = "shock", -- RT / R2
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

	dpup    = "^",
	dpdown  = "v",
	dpleft  = "<",
	dpright = ">",
}


function Hotkeys.getShopKey(kind)
	return Hotkeys.kb.shop[kind]
end

function Hotkeys.getActionKey(action)
	return Hotkeys.kb.actions[action]
end

-- Returns a human-readable label for an action or shop kind,
-- based on input mode (keyboard vs controller)
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
	if key == "space"  then return "Space" end
	if key == "tab"    then return "Tab" end

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

function Hotkeys.padShopKindFromButton(button)
	-- button is dpup/dpleft/... or y/x etc
	return Hotkeys.pad.shop[button]
end

return Hotkeys
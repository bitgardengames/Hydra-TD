local Hotkeys = {}

Hotkeys.defaultKb = {
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
		screenshot = "printscreen",
	},
}

local function cloneBindings(src)
	local out = { shop = {}, actions = {} }
	for section, values in pairs(src) do
		for id, key in pairs(values) do
			out[section][id] = key
		end
	end
	return out
end

function Hotkeys.getDefaultKeyboardBindings()
	return cloneBindings(Hotkeys.defaultKb)
end

function Hotkeys.getDefaultBindings()
	return Hotkeys.getDefaultKeyboardBindings()
end

function Hotkeys.applyKeyboardBindings(bindings)
	local applied = Hotkeys.getDefaultKeyboardBindings()
	if bindings and type(bindings) == "table" then
		for section, values in pairs(applied) do
			local incoming = bindings[section]
			if type(incoming) == "table" then
				for id, defaultKey in pairs(values) do
					local key = incoming[id]
					if key == "none" then values[id] = nil
					elseif type(key) == "string" and key ~= "" then values[id] = key
					else values[id] = defaultKey end
				end
			end
		end
	end
	Hotkeys.kb = applied
end

function Hotkeys.refreshFromSave()
	local Save = require("core.save")
	local settings = Save.data and Save.data.settings
	local bindings = settings and settings.keybinds
	if bindings and bindings.keyboard then bindings = bindings.keyboard end
	Hotkeys.applyKeyboardBindings(bindings)
end

Hotkeys.applyKeyboardBindings(nil)

function Hotkeys.getShopKey(kind) return Hotkeys.kb.shop[kind] end
function Hotkeys.getActionKey(action) return Hotkeys.kb.actions[action] end

function Hotkeys.getDisplay(action)
	local key = Hotkeys.kb.actions[action] or Hotkeys.kb.shop[action]
	if not key then return nil end
	if key == "escape" then return "Esc" end
	if key == "space" then return "Space" end
	if key == "tab" then return "Tab" end
	return key:upper()
end


return Hotkeys

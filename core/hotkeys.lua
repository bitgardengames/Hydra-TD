local Hotkeys = {}

local bindingByKey = {}

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
		restartRun = "r",
		returnToMenu = "escape",
		fastForward = "tab",
		skipPrep = "space",
		toggleMeter = "d",
	},
}

local function cloneBindings(src)
	local out = {shop = {}, actions = {}}

	for section, values in pairs(src) do
		for id, key in pairs(values) do
			out[section][id] = key
		end
	end

	return out
end

local function rebuildBindingIndex()
	bindingByKey = {}

	-- Shop bindings take precedence, matching gameplay's original lookup order.
	-- Keybind capture normally prevents conflicts, but save files can be edited.
	for kind, key in pairs(Hotkeys.kb.shop) do
		bindingByKey[key] = {kind = "shop", id = kind}
	end

	for action, key in pairs(Hotkeys.kb.actions) do
		if not bindingByKey[key] then
			bindingByKey[key] = {kind = "action", id = action}
		end
	end
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

					if key == "none" then
						values[id] = nil
					elseif type(key) == "string" and key ~= "" then
						values[id] = key
					else
						values[id] = defaultKey
					end
				end
			end
		end
	end

	Hotkeys.kb = applied
	rebuildBindingIndex()
end

function Hotkeys.refreshFromSave()
	local Save = require("core.save")
	local settings = Save.data and Save.data.settings
	local bindings = settings and settings.keybinds

	Hotkeys.applyKeyboardBindings(bindings)
end

Hotkeys.applyKeyboardBindings(nil)

function Hotkeys.getShopKey(kind) return Hotkeys.kb.shop[kind] end
function Hotkeys.getActionKey(action) return Hotkeys.kb.actions[action] end

-- Input routers should not need to know how bindings are stored or repeatedly
-- scan every action and tower. Return the logical binding for a physical key.
function Hotkeys.getBinding(key)
	local binding = bindingByKey[key]

	if binding then
		return binding.kind, binding.id
	end
end

function Hotkeys.getDisplay(action)
	local key = Hotkeys.kb.actions[action] or Hotkeys.kb.shop[action]

	if not key then return nil end

	if key == "escape" then return "Esc" end
	if key == "space" then return "Space" end
	if key == "tab" then return "Tab" end

	return key:upper()
end


return Hotkeys

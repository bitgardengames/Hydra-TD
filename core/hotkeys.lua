local Hotkeys = {}

Hotkeys.shop = {
	lancer = "1",
	slow = "2",
	poison = "3",
	shock = "4",
	cannon = "5",
}

Hotkeys.actions = {
	deselect = "escape",
	pause = "p",
	upgrade = "u",
	sell = "x",
	nextMap = "n",
	endless = "e",
	fastForward = "tab",
	skipPrep = "space",
	toggleMeter = "d",
	toggleMeterInfo = "f",
	screenshot = "printscreen",
}

function Hotkeys.getShopKey(kind)
	return Hotkeys.shop[kind]
end

function Hotkeys.getActionKey(action)
	return Hotkeys.actions[action]
end

return Hotkeys
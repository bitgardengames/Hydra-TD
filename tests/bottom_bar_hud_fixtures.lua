-- Bottom-bar status layout fixtures. Run from the repository root with Lua/LuaJIT.
package.path = "./?.lua;" .. package.path

local state = {money = 100, moneyLerp = 100, lives = 20, livesAnim = 0, speed = 2}
local labels = {}
local font = {
	getHeight = function() return 10 end,
	getWidth = function(_, text) return #text * 6 end,
}

love = {
	graphics = {
		getFont = function() return font end,
		setColor = function() end,
	},
}
package.loaded["core.state"] = state
package.loaded["core.theme"] = {ui = {text = {1, 1, 1}, money = {1, 1, 1}, lives = {1, 1, 1}}}
package.loaded["core.util"] = {formatInt = tostring}
package.loaded["core.save"] = {data = {settings = {cameraMotion = true}}}
package.loaded["ui.text"] = {
	printShadow = function(text, x, y)
		labels[#labels + 1] = {text = text, x = x, y = y}
	end,
}
package.loaded["core.localization"] = function(key, value)
	if key == "hud.lives" then return ("Lives %d"):format(value) end
	if key == "hud.speed" then return ("Speed: %g"):format(value) end
	return key
end

local Hud = require("ui.bottom_bar_hud")
Hud.draw(10, 20, 300, 28)

assert(#labels == 3, "HUD should draw exactly three status labels")
assert(labels[1].text == "$100", "money label changed unexpectedly")
assert(labels[2].text == "Lives 20", "lives label changed unexpectedly")
assert(labels[3].text == "Speed: 2", "speed label should be descriptive and omit its hotkey")

local centers = {}
for i, label in ipairs(labels) do
	centers[i] = label.x + font:getWidth(label.text) * 0.5
end
assert(centers[1] == 60 and centers[2] == 160 and centers[3] == 260,
	"status labels should be centered in three evenly spaced columns")

print("bottom bar HUD fixtures: ok")

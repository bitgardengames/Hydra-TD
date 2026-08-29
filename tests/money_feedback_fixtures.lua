-- Dependency-free money feedback fixtures. Run from the repository root with Lua/LuaJIT.
package.path = "./?.lua;" .. package.path

local state = {money = 100, moneyLerp = 100}
love = {graphics = {}}
package.loaded["core.state"] = state
package.loaded["core.theme"] = {ui = {text = {1, 1, 1}, money = {0.9, 0.85, 0.2}, lives = {1, 1, 1}}}
package.loaded["core.util"] = {formatInt = tostring}
package.loaded["core.hotkeys"] = {}
package.loaded["core.save"] = {data = {settings = {cameraMotion = true}}}
package.loaded["ui.text"] = {}
package.loaded["core.localization"] = function() return "" end

local Hud = require("ui.bottom_bar_hud")
local function pulse() local value, time, pose = Hud._moneyFeedbackState(false); return value, time, pose end

Hud._resetMoneyFeedback(100)
state.money = 125
Hud.update(0)
local gain, gainTime = pulse()
assert(gain > 0 and gainTime > 0, "gain did not start an upward pulse")
Hud.update(0.17)
local _, _, gainPose = pulse()
assert(gainPose.y < 0 and gainPose.g > 0.85, "gain did not nudge upward and turn green")

Hud._resetMoneyFeedback(100)
state.money = 75
Hud.update(0)
Hud.update(0.17)
local spending, _, spendPose = pulse()
assert(spending < 0 and spendPose.y > 0 and spendPose.scaleY < 1, "spending did not compress downward")

Hud._resetMoneyFeedback(100)
state.money = 101; Hud.update(0)
local _, firstTime = pulse()
state.money = 102; Hud.update(0.01)
local rapid, rapidTime = pulse()
assert(rapid <= 1 and rapidTime <= firstTime, "rapid changes restarted or exceeded the bounded pulse")

Hud._resetMoneyFeedback(100)
Hud.update(0)
local zero, zeroTime = pulse()
assert(zero == 0 and zeroTime == 0, "zero delta started feedback")

Hud._resetMoneyFeedback(100)
state.money = 100000000; Hud.update(0)
local clamped = pulse()
assert(clamped == 1, "large reward intensity was not clamped")

Hud.update(0.17)
local _, _, moving = pulse()
local _, _, reduced = Hud._moneyFeedbackState(true)
assert(moving.y ~= 0 and moving.scaleY ~= 1, "fixture did not sample active motion")
assert(reduced.y == 0 and reduced.scaleY == 1, "reduced motion retained positional or scale motion")
assert(reduced.r ~= 0.9 or reduced.g ~= 0.85 or reduced.b ~= 0.2,
	"reduced motion removed the color transition")

print("money feedback fixtures passed")

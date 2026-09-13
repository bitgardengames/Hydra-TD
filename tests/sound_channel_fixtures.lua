-- Dependency-free channel mixer fixtures. Run from the repository root with Lua/LuaJIT.
package.path = "./?.lua;" .. package.path

local function source()
	return {
		volume = -1,
		setVolume = function(self, value) self.volume = value end,
	}
end

love = {audio = {}, math = {random = math.random}}
local settings = {
	musicVolume = 0.5,
	uiVolume = 0.2,
	gameplaySfxVolume = 0.6,
	muteWhenUnfocused = true,
}
package.loaded["core.save"] = {data = {settings = settings}}
package.loaded["core.game_speed"] = {getSoundCooldownScale = function() return 1 end}

local Sound = require("systems.sound")
local ui, repetitive, important = source(), source(), source()
Sound.sfx = {
	interface = {source = ui, category = "ui"},
	combat = {source = repetitive, category = "repetitive", bias = 0.5},
	placementOrOutcome = {source = important, category = "important"},
}

package.loaded["core.theme"] = {tower = {shock = {}, cannon = {}, lancer = {}}}
package.loaded["core.util"] = {clamp = function(value, low, high)
	return math.max(low, math.min(high, value))
end}
package.loaded["core.localization"] = function(key) return key end
local SettingsModel = require("ui.menu.settings_model")
local model = SettingsModel.build({
	restoreDefaults = function() end,
	text = function() return "" end,
})
local rows = {}
for _, row in ipairs(model[1].rows) do rows[row.id] = row end
assert(rows.gameplay_sfx and rows.ui_sfx, "settings did not expose both sound sliders")

Sound.setSFXVolume()
local master = Sound.masterVolume
assert(ui.volume == 0.2 * master, "UI entry did not use the interface channel")
assert(repetitive.volume == 0.6 * 0.5 * master, "repetitive entry did not use the gameplay channel and bias")
assert(important.volume == 0.6 * master, "important entry did not use the gameplay channel")

local repetitiveBefore, importantBefore = repetitive.volume, important.volume
rows.ui_sfx.set(0.8)
assert(ui.volume == 0.8 * master, "interface slider did not affect UI entries")
assert(repetitive.volume == repetitiveBefore and important.volume == importantBefore,
	"interface slider affected gameplay entries")

local uiBefore = ui.volume
rows.gameplay_sfx.set(0.1)
assert(ui.volume == uiBefore, "gameplay slider affected UI entries")
assert(repetitive.volume == 0.1 * 0.5 * master and important.volume == 0.1 * master,
	"gameplay slider did not affect both gameplay categories")

print("sound channel fixtures passed")

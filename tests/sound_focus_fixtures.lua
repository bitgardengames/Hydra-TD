-- Dependency-free focus-mixer fixtures. Run from the repository root with Lua/LuaJIT.
package.path = "./?.lua;" .. package.path

local function source()
	return {
		volume = -1,
		setVolume = function(self, value) self.volume = value end,
	}
end

love = {audio = {}, math = {random = math.random}}
package.loaded["core.save"] = {data = {settings = {
	musicVolume = 0.5,
	uiVolume = 0.4,
	gameplaySfxVolume = 0.25,
	muteWhenUnfocused = true,
}}}
package.loaded["core.game_speed"] = {getSoundCooldownScale = function() return 1 end}

local Sound = require("systems.sound")
local effect, pooledA, pooledB, music = source(), source(), source(), source()
Sound.sfx = {
	single = {source = effect, category = "important"},
	pooled = {sources = {pooledA, pooledB}, bias = 0.5, category = "repetitive"},
}
Sound.music = {menu = music}

Sound.setFocused(true)
local original = {effect.volume, pooledA.volume, pooledB.volume, music.volume}
assert(original[1] == 0.25 * Sound.masterVolume, "SFX did not receive its saved level")
assert(original[2] == 0.25 * 0.5 * Sound.masterVolume, "biased SFX did not receive its saved level")
assert(original[4] == 0.5 * Sound.masterVolume, "music did not receive its saved level")

Sound.setFocused(false)
assert(effect.volume == 0 and pooledA.volume == 0 and pooledB.volume == 0 and music.volume == 0,
	"focus loss did not silence every audio channel")

Sound.setFocused(true)
assert(effect.volume == original[1] and pooledA.volume == original[2]
	and pooledB.volume == original[3] and music.volume == original[4],
	"focus restoration did not reapply the exact saved mix")

Sound.setMuteWhenUnfocused(false)
Sound.setFocused(false)
assert(effect.volume == original[1] and pooledA.volume == original[2]
	and pooledB.volume == original[3] and music.volume == original[4],
	"disabled focus muting changed the mix")

print("sound focus fixtures passed")

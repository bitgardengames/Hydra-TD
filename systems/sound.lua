local State = require("core.state")
local Save = require("core.save")

local Sound = {
	masterVolume = 0.16,
	currentMusic = nil,
	suppressed = false,
	musicFadeT = 0,
	musicFadeDur = 0.25,
	musicFadeDir = 0,
	musicDuckAmount = 0.2,

	sfx = {},
	music = {},
}

local lastPlayTime = {}

local la = love.audio
local lmr = love.math.random
local max = math.max
local min = math.min

local function scaleVolume(v)
	return v * Sound.masterVolume
end

-- Play a sound effect
function Sound.play(name, opts)
	if Sound.suppressed then
		return
	end

	local entry = Sound.sfx[name]
	opts = opts or {}

	if not entry then
		return
	end

	-- Cooldown throttle per sound
	if entry.cooldown then
		local now = love.timer.getTime()
		local last = lastPlayTime[name] or 0

		-- Scale with game speed
		--local speedMult = (State and State.speed == 4) and 1.6 or 1.0
		local speedMult = (State and State.speed == 4) and 1.0 or 0.5

		if now - last < entry.cooldown * speedMult then
			return
		end

		lastPlayTime[name] = now
	end

	local sound

	if entry.sources then
		sound = entry.sources[lmr(#entry.sources)]
	else
		sound = entry.source
	end

	if not entry.cooldown then
		sound:stop()
	end

	if entry.jitter then
		sound:setPitch((opts.pitch or 1) + lmr(-8, 8) * 0.02)
	else
		sound:setPitch(opts.pitch or 1)
	end

	sound:play()
end

function Sound.setSFXVolume(v)
	local baseVol = scaleVolume(v)

	for _, entry in pairs(Sound.sfx) do
		local bias = entry.bias or 1.0
		local vol = baseVol * bias

		if entry.source then
			entry.source:setVolume(vol)
		elseif entry.sources then
			for _, s in ipairs(entry.sources) do
				s:setVolume(vol)
			end
		end
	end
end

-- Music controls
function Sound.playMusic(name)
	local newTrack = nil

	if name == "gameplay" then
		if not Sound.gameplayTracks or #Sound.gameplayTracks == 0 then
			return
		end

		newTrack = Sound.gameplayTracks[lmr(#Sound.gameplayTracks)]
	else
		newTrack = Sound.music[name]
	end

	if not newTrack then
		return
	end

	-- If already playing this track, do nothing
	if Sound.currentMusic == newTrack then
		return
	end

	-- Stop previous music
	if Sound.currentMusic then
		Sound.currentMusic:stop()
	end

	Sound.currentMusic = newTrack
	Sound.currentMusic:play()
end

function Sound.stopAllMusic()
	if Sound.currentMusic then
		Sound.currentMusic:stop()
		Sound.currentMusic = nil
	end
end

function Sound.setMusicVolume(v)
	local vol = scaleVolume(v)

	for _, music in pairs(Sound.music) do
		music:setVolume(vol)
	end
end

function Sound.load()
	local sfx = Sound.sfx
	local music = Sound.music

	-- Sounds
	sfx.uiMove = {
		source = la.newSource("assets/sounds/uiMove.ogg", "static"),
	}

	sfx.uiConfirm = {
		source = la.newSource("assets/sounds/uiConfirm.ogg", "static"),
	}

	sfx.uiBack = {
		source = la.newSource("assets/sounds/uiBack.ogg", "static"),
	}

	sfx.uiError = {
		source = la.newSource("assets/sounds/uiError.ogg", "static"),
	}

	sfx.victory = {
		source = la.newSource("assets/sounds/victory.ogg", "static"),
	}

	sfx.gameOver = {
		source = la.newSource("assets/sounds/gameOver.ogg", "static"),
	}

	sfx.towerPlaced = {
		sources = {
			la.newSource("assets/sounds/towerPlaced1.ogg", "static"),
			la.newSource("assets/sounds/towerPlaced2.ogg", "static"),
		},
		jitter = true,
	}

	sfx.towerUpgraded = {
		source = la.newSource("assets/sounds/upgrade.ogg", "static"),
	}

	sfx.message = {
		source = la.newSource("assets/sounds/message.ogg", "static"),
		jitter = true,
		bias = 0.8,
	}

	sfx.medal = {
		source = la.newSource("assets/sounds/medal.mp3", "static"),
		jitter = true,
		bias = 0.9,
	}

	sfx.towerSold = {
		sources = {
			la.newSource("assets/sounds/towerSold1.ogg", "static"),
			la.newSource("assets/sounds/towerSold2.ogg", "static"),
			la.newSource("assets/sounds/towerSold3.ogg", "static"),
		},
	}

	sfx.lancer = {
		source = la.newSource("assets/sounds/lancer.ogg", "static"),
		jitter = true,
		bias = 0.7,
		--cooldown = 0.08,
	}

	sfx.slow = {
		source = la.newSource("assets/sounds/slow.ogg", "static"),
		jitter = true,
		bias = 0.2,
		--cooldown = 0.10,
	}

	sfx.cannon = {
		source = la.newSource("assets/sounds/cannon.ogg", "static"),
		jitter = true,
		bias = 0.82,
		--cooldown = 0.14,
	}

	sfx.poison = {
		sources = {
			la.newSource("assets/sounds/poison1.ogg", "static"),
			la.newSource("assets/sounds/poison2.ogg", "static"),
		},
		jitter = true,
		bias = 0.7,
		--cooldown = 0.12,
	}

	sfx.shock = {
		sources = {
			la.newSource("assets/sounds/shock1.ogg", "static"),
			la.newSource("assets/sounds/shock2.ogg", "static"),
			la.newSource("assets/sounds/shock3.ogg", "static"),
		},
		jitter = true,
		bias = 0.9,
		--cooldown = 0.09,
	}

	--[[sfx.plasma = {
		source = la.newSource("assets/sounds/plasma.ogg", "static"),
		jitter = true,
		bias = 0.62,
		--cooldown = 0.08,
	}]]

	sfx.plasma = {
		source = la.newSource("assets/sounds/plasma2.ogg", "static"),
		jitter = true,
		bias = 0.82,
		--cooldown = 0.08,
	}

	-- Music
	music.menu = la.newSource("assets/music/Menu4.ogg", "stream")
	music.menu:setLooping(true)

	music.pause = la.newSource("assets/music/Pause.ogg", "stream")
	music.pause:setLooping(true)

	music.gameOver = la.newSource("assets/music/GameOver.ogg", "stream")
	music.gameOver:setLooping(true)

	music.track1 = la.newSource("assets/music/Track1.ogg", "stream")
	music.track1:setLooping(true)

	music.track2 = la.newSource("assets/music/Track2.ogg", "stream")
	music.track2:setLooping(true)

	music.track3 = la.newSource("assets/music/Track3.ogg", "stream")
	music.track3:setLooping(true)

	music.track4 = la.newSource("assets/music/Track4.ogg", "stream")
	music.track4:setLooping(true)

	music.track5 = la.newSource("assets/music/Track5.ogg", "stream")
	music.track5:setLooping(true)

	music.track6 = la.newSource("assets/music/Track6.ogg", "stream")
	music.track6:setLooping(true)

	Sound.gameplayTracks = {
		music.track1,
		music.track2,
		music.track3,
		music.track4,
		music.track5,
		music.track6,
	}

	Sound.setMusicVolume(Save.data.settings.musicVolume)
	Sound.setSFXVolume(Save.data.settings.sfxVolume)
end

function Sound.update(dt)
	if not Sound.currentMusic then
		return
	end

	if Sound.musicFadeDir == 0 then
		return
	end

	local t = Sound.musicFadeT
	local dur = Sound.musicFadeDur

	t = t + (dt / dur) * Sound.musicFadeDir
	t = max(0, min(1, t))

	Sound.musicFadeT = t

	-- Stop when finished
	if t == 0 or t == 1 then
		Sound.musicFadeDir = 0
	end

	local base = Save.data.settings.musicVolume or 1
	local duck = Sound.musicDuckAmount

	local eased = t * t
	local fadeFactor = 1 - (eased * (1 - duck))
	local finalVol = base * fadeFactor * Sound.masterVolume

	Sound.currentMusic:setVolume(finalVol)
end

function Sound.enterPause()
	if not Sound.currentMusic then
		return
	end

	Sound.musicFadeDir = 1
end

function Sound.exitPause()
	if not Sound.currentMusic then
		return
	end

	Sound.musicFadeDir = -1
end

return Sound

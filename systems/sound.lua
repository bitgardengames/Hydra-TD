local Save = require("core.save")
local GameSpeed = require("core.game_speed")

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

local pitchJitterByCategory = {
	ui = 0,
	important = 0.035,
	repetitive = 0.08,
}

local function scaleVolume(v)
	return v * Sound.masterVolume
end

local function buildSfxEntry(def)
	local entry = {
		jitter = def.jitter,
		bias = def.bias,
		cooldown = def.cooldown,
		category = def.category or "important",
	}

	if def.files or def.pool then
		entry.sources = {}
		local files = def.files or {def.file}
		local poolSize = def.pool or #files

		for i = 1, poolSize do
			local file = files[((i - 1) % #files) + 1]
			entry.sources[i] = la.newSource(file, "static")
		end
	else
		entry.source = la.newSource(def.file, "static")
	end

	return entry
end

local function buildMusicTrack(file)
	local track = la.newSource(file, "stream")
	track:setLooping(true)
	return track
end

-- Play a sound effect
function Sound.play(name, opts)
	if Sound.suppressed then
		return
	end

	local entry = Sound.sfx[name]

	if not entry then
		return
	end

	-- Cooldown throttle per sound
	if entry.cooldown then
		local now = love.timer.getTime()
		local last = lastPlayTime[name] or 0

		local speedMult = GameSpeed.getSoundCooldownScale(entry.category)

		if now - last < entry.cooldown * speedMult then
			return
		end

		lastPlayTime[name] = now
	end

	local sound

	if entry.sources then
		-- Prefer an idle voice so an overlapping impact is never swallowed or
		-- restarted. If the small pool is saturated, preserve existing cues.
		local start = lmr(#entry.sources)
		for offset = 0, #entry.sources - 1 do
			local candidate = entry.sources[((start + offset - 1) % #entry.sources) + 1]
			if not candidate:isPlaying() then
				sound = candidate
				break
			end
		end
		if not sound then return end
	else
		sound = entry.source
	end

	if not entry.cooldown then
		sound:stop()
	end

	if entry.jitter then
		local basePitch = opts and opts.pitch or 1
		local range = pitchJitterByCategory[entry.category] or 0
		sound:setPitch(max(0.5, min(2.0, basePitch + (lmr() * 2 - 1) * range)))
	else
		sound:setPitch(opts and opts.pitch or 1)
	end

	sound:play()
end

-- Readiness cues have their own entry and throttle so simultaneous cooldowns
-- cannot turn into a burst of UI sounds. Callers may also suppress a cue for
-- contextual transitions such as restoring a run.
function Sound.playAbilityReady(opts)
	if opts and opts.suppress then
		return
	end
	Sound.play("abilityReady", opts)
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

	local sfxDefs = {
		uiMove = { file = "assets/sounds/uiMove.ogg", category = "ui" },
		uiConfirm = { file = "assets/sounds/uiConfirm.ogg", category = "ui" },
		uiBack = { file = "assets/sounds/uiBack.ogg", category = "ui" },
		uiError = { file = "assets/sounds/uiError.ogg", category = "ui" },
		abilityReady = { file = "assets/sounds/uiConfirm.ogg", cooldown = 0.35, bias = 0.7, category = "ui", pool = 2 },
		victory = { file = "assets/sounds/victory.ogg" },
		gameOver = { file = "assets/sounds/gameOver.ogg" },
		towerPlaced = { files = { "assets/sounds/towerPlaced1.ogg", "assets/sounds/towerPlaced2.ogg" }, jitter = true },
		towerUpgraded = { file = "assets/sounds/upgrade.ogg" },
		message = { file = "assets/sounds/message.ogg", jitter = true, bias = 0.8 },
		medal = { file = "assets/sounds/medal.mp3", jitter = true, bias = 0.9 },
		towerSold = { files = { "assets/sounds/towerSold1.ogg", "assets/sounds/towerSold2.ogg", "assets/sounds/towerSold3.ogg" } },
		lancer = { file = "assets/sounds/lancer.ogg", jitter = true, bias = 0.7, cooldown = 0.06, category = "repetitive", pool = 3 },
		slow = { file = "assets/sounds/slow.ogg", jitter = true, bias = 0.2, cooldown = 0.08, category = "repetitive", pool = 2 },
		cannon = { file = "assets/sounds/cannon.ogg", jitter = true, bias = 0.82, cooldown = 0.06, category = "repetitive", pool = 3 },
		poison = { files = { "assets/sounds/poison1.ogg", "assets/sounds/poison2.ogg" }, jitter = true, bias = 0.7, cooldown = 0.07, category = "repetitive", pool = 4 },
		shock = { files = { "assets/sounds/shock1.ogg", "assets/sounds/shock2.ogg", "assets/sounds/shock3.ogg" }, jitter = true, bias = 0.9, cooldown = 0.05, category = "important", pool = 4 },
		plasma = { file = "assets/sounds/plasma2.ogg", jitter = true, bias = 0.82, cooldown = 0.05, category = "repetitive", pool = 3 },
	}

	for name, def in pairs(sfxDefs) do
		sfx[name] = buildSfxEntry(def)
	end

	local musicDefs = {
		menu = "assets/music/Menu4.ogg",
		pause = "assets/music/Pause.ogg",
		gameOver = "assets/music/GameOver.ogg",
		track1 = "assets/music/Track1.ogg",
		track2 = "assets/music/Track2.ogg",
		track3 = "assets/music/Track3.ogg",
		track4 = "assets/music/Track4.ogg",
		track5 = "assets/music/Track5.ogg",
		track6 = "assets/music/Track6.ogg",
	}

	for name, file in pairs(musicDefs) do
		music[name] = buildMusicTrack(file)
	end

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

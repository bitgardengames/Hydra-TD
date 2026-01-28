local State = require("core.state")
local Save = require("core.save")

local Sound = {}

Sound.sfx = {}
Sound.music = {}

Sound.supressed = false

local lastPlayTime = {}

local la = love.audio
local lmr = love.math.random

local function clampHalf(v)
	return v * 0.25
end

-- Play a sound effect
function Sound.play(name)
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

        -- Scale with game speed
        local speedMult = (State and State.speed == 4) and 1.6 or 1.0

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
        sound:setPitch(1 + lmr(-8, 8) * 0.01)
    else
        sound:setPitch(1)
    end

    sound:play()
end

function Sound.setSFXVolume(v)
    local vol = clampHalf(v)

    for _, entry in pairs(Sound.sfx) do
        if entry.source then
            entry.source:setVolume(vol)
        elseif entry.sources then
            for _, s in ipairs(entry.sources) do
                s:setVolume(vol)
            end
        end
    end
end

-- Play music
function Sound.playMusic(name)
    local music = Sound.music[name]

    if music then
        music:play()
    end
end

-- Stop music
function Sound.stopMusic(name)
    local music = Sound.music[name]

    if music then
        music:stop()
    end
end

function Sound.setMusicVolume(v)
    if Sound.music.bg then
        Sound.music.bg:setVolume(clampHalf(v))
    end
end

function Sound.load()
	-- Sounds
    Sound.sfx.uiMove = {
		source = la.newSource("assets/sounds/Pop sounds 10.ogg", "static"),
	}

    Sound.sfx.uiConfirm = {
		source = la.newSource("assets/sounds/Click.ogg", "static"),
	}

    Sound.sfx.uiBack = {
		source = la.newSource("assets/sounds/select.ogg", "static"),
	}

    Sound.sfx.uiError = {
		source = la.newSource("assets/sounds/Bonus 2.ogg", "static"),
	}

	Sound.sfx.victory = {
		source = la.newSource("assets/sounds/Buff 3.ogg", "static"),
	}

	Sound.sfx.gameOver = {
		source = la.newSource("assets/sounds/Bonus 2.ogg", "static"),
	}

    Sound.sfx.towerPlaced = {
		sources = {
			la.newSource("assets/sounds/Shadow Punch 1.ogg", "static"),
			la.newSource("assets/sounds/Shadow Punch 2.ogg", "static"),
		},
		jitter = true,
	}

	-- NYI
    Sound.sfx.towerUpgraded = {
		source = la.newSource("assets/sounds/sell.wav", "static"),
	}

    Sound.sfx.towerSold = {
		source = la.newSource("assets/sounds/sell.wav", "static"),
	}

    Sound.sfx.lancer = {
		source = la.newSource("assets/sounds/Arrow Impact wood 1.ogg", "static"),
		jitter = true,
		cooldown = 0.08,
	}

    Sound.sfx.slow = {
		source = la.newSource("assets/sounds/Mud footsteps 7.ogg", "static"),
		jitter = true,
		cooldown = 0.10,
	}

    Sound.sfx.cannon = {
		source = la.newSource("assets/sounds/Cannon shots 1.ogg", "static"),
		jitter = true,
		cooldown = 0.14,
	}

    Sound.sfx.poison = {
		sources = {
			la.newSource("assets/sounds/Bloody punches 7.ogg", "static"),
			la.newSource("assets/sounds/Bloody punches 10.ogg", "static"),
		},
		jitter = true,
		cooldown = 0.12,
	}

    Sound.sfx.shock = {
		sources = {
			la.newSource("assets/sounds/Spark 1.ogg", "static"),
			la.newSource("assets/sounds/Spark 2.ogg", "static"),
			la.newSource("assets/sounds/Spark 3.ogg", "static"),
		},
		jitter = true,
		cooldown = 0.09,
	}

    -- Music
    Sound.music.bg = la.newSource("assets/music/Menu4.ogg", "stream")
    Sound.music.bg:setLooping(true)

	Sound.setMusicVolume(Save.data.settings.musicVolume)
	Sound.setSFXVolume(Save.data.settings.sfxVolume)
end

return Sound
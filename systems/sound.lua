local Sound = {}

Sound.sfx = {}
Sound.music = {}

local lastPlayTime = {}

local la = love.audio
local lmr = love.math.random

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

	local SFXVolume = 0 --0.16
	local UIVolume = 0.12 --0.12

	-- If any sounds need specific tuning
	Sound.sfx.uiMove.source:setVolume(UIVolume)
	Sound.sfx.uiConfirm.source:setVolume(UIVolume)
	Sound.sfx.uiBack.source:setVolume(UIVolume)
	Sound.sfx.uiError.source:setVolume(UIVolume)
	Sound.sfx.victory.source:setVolume(UIVolume)
	Sound.sfx.gameOver.source:setVolume(UIVolume)

	Sound.sfx.towerPlaced.sources[1]:setVolume(0.08)
	Sound.sfx.towerPlaced.sources[2]:setVolume(0.08)

	Sound.sfx.lancer.source:setVolume(SFXVolume)
	Sound.sfx.slow.source:setVolume(SFXVolume)
	Sound.sfx.cannon.source:setVolume(SFXVolume)
	Sound.sfx.poison.sources[1]:setVolume(SFXVolume)
	Sound.sfx.poison.sources[2]:setVolume(SFXVolume)
	Sound.sfx.shock.sources[1]:setVolume(SFXVolume)
	Sound.sfx.shock.sources[2]:setVolume(SFXVolume)
	Sound.sfx.shock.sources[3]:setVolume(SFXVolume)

    -- Music
    Sound.music.bg = la.newSource("assets/music/Menu4.ogg", "stream")
    Sound.music.bg:setLooping(true)
    Sound.music.bg:setVolume(0.0) -- 0.3
end

-- Play a sound effect
function Sound.play(name)
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

return Sound
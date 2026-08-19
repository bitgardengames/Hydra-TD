local sin = math.sin
local cos = math.cos
local pi = math.pi

local Dance = {}

local function smoothstep(t)
	t = math.max(0, math.min(1, t))
	return t * t * (3 - 2 * t)
end

-- Spend most of each cycle on the tower's regular dance, then complete one
-- rotation as an occasional extra move. Zero and one full turn render at the
-- same angle, so the tower can cleanly return to its usual choreography.
local function spinMove(localTime, phase)
	local cycleLength = 7.2
	local moveStart = 6.05
	local moveLength = 0.9
	local phaseDelay = phase / (pi * 2) * cycleLength
	local cycleTime = (localTime + phaseDelay) % cycleLength
	if cycleTime < moveStart or cycleTime >= moveStart + moveLength then
		return 0
	end
	return smoothstep((cycleTime - moveStart) / moveLength) * pi * 2
end

-- Give every tower a short signature flourish between its regular beats. The
-- squared sine envelope starts and ends at rest, so these little hops and
-- shimmies can be layered onto the looping dances without a visible snap.
local function signatureMove(localTime, kind, phase)
	local cycleLength = 4.8
	local moveStart = 2.75
	local moveLength = 1.2
	local phaseDelay = phase / (pi * 2) * cycleLength
	local cycleTime = (localTime + phaseDelay) % cycleLength
	if cycleTime < moveStart or cycleTime >= moveStart + moveLength then
		return 0, 0, 0
	end

	local progress = (cycleTime - moveStart) / moveLength
	local envelope = sin(progress * pi) ^ 2
	local wiggle = sin(progress * pi * 2)

	if kind == "lancer" then
		-- An eager heel-click: spring upward and kick the lance side to side.
		return wiggle * envelope * 1.7, -envelope * 2.4, wiggle * envelope * 0.32
	elseif kind == "slow" then
		-- A bashful curtsy, complete with a small look in either direction.
		return wiggle * envelope * 1.1, envelope * 1.5, -wiggle * envelope * 0.45
	elseif kind == "cannon" then
		-- Two stout little stomps make the heavy turret feel cheerfully weighty.
		local stomp = sin(progress * pi * 2) ^ 2
		return -wiggle * envelope * 0.8, stomp * envelope * 1.8, wiggle * envelope * 0.24
	elseif kind == "shock" then
		-- A quick three-beat electric shimmy.
		local buzz = sin(progress * pi * 6)
		return buzz * envelope * 1.5, -math.abs(buzz) * envelope * 0.8,
			buzz * envelope * 0.36
	elseif kind == "poison" then
		-- A gooey shoulder wiggle that droops in the middle.
		local wobble = sin(progress * pi * 4)
		return wobble * envelope * 1.3, envelope * 1.2, -wobble * envelope * 0.3
	elseif kind == "plasma" then
		-- A buoyant zero-gravity hop with a happy half-twirl.
		return wiggle * envelope * 0.8, -envelope * 2.8, envelope * pi
	end

	-- Modded towers get a modest hop rather than borrowing a named tower's move.
	return wiggle * envelope, -envelope * 1.4, wiggle * envelope * 0.25
end

-- Return a render-only offset and turn for a tower's turret. The curves use
-- paired sine waves rather than sharp, one-sided hops so direction changes ease
-- naturally. Index-based delays and phases keep groups from moving in lockstep.
function Dance.pose(clock, kind, index)
	clock = math.max(0, clock or 0)
	kind = kind or "lancer"
	index = index or 1

	-- Let the cheer travel across the board when the victory screen opens.
	local localTime = math.max(0, clock - (index - 1) * 0.045)
	local entrance = smoothstep(localTime / 0.4)
	local phase = ((index - 1) % 4) * pi * 0.32
	local sway, bob, turn

	if kind == "lancer" then
		-- A broad side-to-side salute with a gentle floating bounce.
		local beat = localTime * pi * 1.8 + phase
		sway, bob, turn = sin(beat) * 3.4, -cos(beat * 2) * 2.2, sin(beat) * 0.48
	elseif kind == "slow" then
		-- Slow traces a relaxed circle while following the orbit with its barrel.
		local orbit = localTime * pi * 1.05 + phase
		sway, bob, turn = cos(orbit) * 3.8, sin(orbit) * 3.8, sin(orbit) * 0.5
	elseif kind == "cannon" then
		-- The heavy cannon rocks through a wide, weighty pendulum.
		local swing = localTime * pi * 1.35 + phase
		sway, bob, turn = sin(swing) * 2.2, -cos(swing * 2) * 1.5, sin(swing) * 0.62
	elseif kind == "shock" then
		-- Shock buzzes around a tight circle, occasionally throwing in a spin.
		local orbit = localTime * pi * 2.5 + phase
		sway, bob, turn = cos(orbit) * 2.7, sin(orbit) * 2.7, sin(orbit) * 0.22
	elseif kind == "poison" then
		-- A languid figure-eight gives poison its lopsided wobble.
		local drift = localTime * pi * 1.15 + phase
		sway, bob, turn = sin(drift) * 3.2, sin(drift * 2) * 2, sin(drift + pi / 3) * 0.42
	elseif kind == "plasma" then
		-- Plasma floats in a broad orbit and mixes in a leisurely full rotation.
		local orbit = localTime * pi * 1.5 + phase
		sway, bob, turn = cos(orbit) * 4.2, sin(orbit) * 4.2, sin(orbit) * 0.3
	else
		-- Custom/modded towers still get a restrained, smooth circular cheer.
		local orbit = localTime * pi * 1.4 + phase
		sway, bob, turn = cos(orbit) * 2.5, sin(orbit) * 2.5, sin(orbit) * 0.35
	end

	local flourishX, flourishY, flourishTurn = signatureMove(localTime, kind, phase)
	sway = sway + flourishX
	bob = bob + flourishY
	turn = turn + flourishTurn

	return sway * entrance, bob * entrance,
		(turn + spinMove(localTime, phase)) * entrance
end

return Dance

local State = require("core.state")
local Floaters = require("ui.floaters")

local bossAddTimer = 0

local wavePlan = {
	{count = 10, gap = 0.65, mix = {{type = "grunt", w = 1.0}}},
	{count = 14, gap = 0.55, mix = {{type = "grunt", w = 0.75}, {type = "runner", w = 0.25}}},
	{count = 16, gap = 0.55, mix = {{type = "grunt", w = 0.6}, {type = "runner", w = 0.4}}},
	{count = 14, gap = 0.65, mix = {{type = "grunt", w = 0.55}, {type = "tank", w = 0.45}}},
	{count = 14, gap = 0.6, mix = {{type = "grunt", w = 0.5}, {type = "splitter", w = 0.3}, {type = "runner", w = 0.2}}},
	{count = 20, gap = 0.48, mix = {{type = "grunt", w = 0.5}, {type = "runner", w = 0.35}, {type = "tank", w = 0.15}}},
	{count = 20, gap = 0.45, mix = {{type = "tank", w = 0.4}, {type = "splitter", w = 0.4}, {type = "runner", w = 0.2}}},
}

local spawner = {
	active = false,
	remaining = 0,
	gap = 0.6,
	timer = 0,
	hpMult = 1.0,
	spdMult = 1.0,
	mix = nil,
}

local function pickEnemyType(mix)
	local total = 0

	for _, m in ipairs(mix) do
		total = total + m.w
	end

	local r = love.math.random() * total
	local acc = 0

	for _, m in ipairs(mix) do
		acc = acc + m.w

		if r <= acc then
			return m.type
		end
	end

	return mix[#mix].type
end

local function startWave()
	local Enemies = require("world.enemies")

	State.wave = State.wave + 1

	local waveAnim = State.waveAnim or 0
	State.waveAnim = waveAnim + (1 - waveAnim) * 0.6

	-- Boss waves
	if State.wave % 10 == 0 then
		local bossIndex = State.wave / 10

		spawner.active = true
		spawner.remaining = 1
		spawner.gap = 0
		spawner.mix = {{type = "boss", w = 1.0}}

		if bossIndex == 1 then
			-- Wave 10
			spawner.hpMult = 1.35
		else
			-- Wave 20+ ramp hard
			spawner.hpMult = 1.35 * (3.0 ^ (bossIndex - 1)) -- 1.35 * (1.7 ^ (bossIndex - 1))
		end

		spawner.spdMult = 1.0 + (bossIndex - 1) * 0.08
		State.inPrep = false
		return
	end

	local plan = wavePlan[math.min(State.wave, #wavePlan)]
	spawner.active = true
	spawner.remaining = plan.count + math.max(0, State.wave - #wavePlan) * 3
	spawner.gap = plan.gap * math.max(0.75, 1.0 - (State.wave - 1) * 0.02)
	spawner.timer = 0
	spawner.mix = plan.mix

	spawner.hpMult = (plan.hpMult or 1.0) * (1.0 + (State.wave - 1) * 0.22) -- 0.18
	spawner.spdMult = (plan.spdMult or 1.0) * (1.0 + (State.wave - 1) * 0.06) -- 0.03

	State.inPrep = false
end

local function updateSpawner(dt)
	local Enemies = require("world.enemies")

	-- Normal wave spawning
	if spawner.active then
		spawner.timer = spawner.timer - dt

		if spawner.timer <= 0 and spawner.remaining > 0 then
			local kind = pickEnemyType(spawner.mix)
			Enemies.spawnEnemy(kind, spawner.hpMult, spawner.spdMult)
			spawner.remaining = spawner.remaining - 1
			spawner.timer = spawner.gap
		end

		if spawner.remaining <= 0 then
			spawner.active = false
		end
	end

	-- Boss add trickle
	if State.wave == 10 or State.wave == 20 then
		-- check if a boss is alive
		local bossAlive = false
		for _, e in ipairs(Enemies.enemies) do
			if e.boss then
				bossAlive = true
				break
			end
		end

		if bossAlive then
			bossAddTimer = bossAddTimer - dt
			if bossAddTimer <= 0 then
				-- reset timer
				bossAddTimer = (State.wave == 10) and 2.0 or 1.0

				-- spawn a small number of normal enemies
				if State.wave == 10 then
					-- light pressure
					Enemies.spawnEnemy("runner", 1.0, 1.0)
				else
					-- heavier mix
					Enemies.spawnEnemy("runner", 1.0, 1.0)
					Enemies.spawnEnemy("grunt", 1.0, 1.0)
				end
			end
		else
			-- boss dead, stop spawning adds
			bossAddTimer = 0
		end
	end
end

local function allEnemiesCleared()
	local Enemies = require("world.enemies")
	return #Enemies.enemies == 0 and not spawner.active
end

local function updatePrep(dt)
	if not State.inPrep then
		return
	end

	State.prepTimer = State.prepTimer - dt

	if State.prepTimer <= 0 then
		State.prepTimer = 0
		startWave()
	end
end

local function resetSpawner()
	spawner.active = false
	spawner.remaining = 0
	spawner.timer = 0
	spawner.hpMult = 1.0
	spawner.spdMult = 1.0
	spawner.mix = nil
end

return {
	wavePlan = wavePlan,
	spawner = spawner,
	startWave = startWave,
	updateSpawner = updateSpawner,
	updatePrep = updatePrep,
	allEnemiesCleared = allEnemiesCleared,
	resetSpawner = resetSpawner,
}
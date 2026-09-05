-- Pure phase-cycle state transitions, kept independent of LÖVE for fixtures and tools.
local Phase = {}

function Phase.initialize(enemy, config)
	enemy.phase = config
	enemy.phaseActive = false
	enemy.phaseTimer = config and (config.initialDelay or config.period) or 0
	enemy.hasPhase = config ~= nil
end

function Phase.update(enemy, dt)
	if not enemy.hasPhase then return end
	enemy.phaseTimer = enemy.phaseTimer - dt
	if enemy.phaseActive and enemy.phaseTimer <= 0 then
		enemy.phaseActive = false
		enemy.phaseTimer = math.max(0.000001, enemy.phase.period - enemy.phase.duration)
	elseif not enemy.phaseActive and enemy.phaseTimer <= 0 then
		enemy.phaseActive = true
		enemy.phaseTimer = enemy.phase.duration
	end
end

function Phase.movementMultiplier(enemy)
	return enemy.phaseActive and enemy.phase.speedMultiplier or 1
end

function Phase.canDirectHit(enemy)
	return enemy ~= nil and not enemy.phaseActive
end

return Phase

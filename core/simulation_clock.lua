-- Gameplay advances on this clock; rendering and UI continue to use frame time.
-- Sixteen ticks cover 4x speed at 30 FPS with roughly 20% headroom. Development
-- counters expose discardedSimulationTime, catchUpSteps, fixedStepFrames,
-- maxCatchUpStepsInFrame,
-- framesAtCatchUpLimit, and spawnBackpressureEvents; tune this budget from those
-- observations rather than increasing it in response to an isolated slow frame.
return {
	step = 0.01,
	maxCatchUpSteps = 16,
}

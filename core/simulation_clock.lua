-- Gameplay advances on this clock; rendering and UI continue to use frame time.
-- Sixteen ticks cover 4x speed at 30 FPS. If a frame supplies more work than
-- this budget, the excess is deliberately discarded rather than carried forward.
return {
	step = 0.01,
	maxCatchUpSteps = 16,
}

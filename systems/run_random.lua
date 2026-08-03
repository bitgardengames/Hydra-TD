-- The sole random stream for decisions which can affect a run.  Presentation
-- code must use its own RandomGenerator instead of consuming this stream.
local RunRandom = {}

local rng = love.math.newRandomGenerator(1)
local seed = 1

function RunRandom.seed(value)
	seed = math.max(1, math.floor(tonumber(value) or 1))
	rng:setSeed(seed)
end

function RunRandom.getSeed()
	return seed
end

function RunRandom.random(a, b)
	if a == nil then return rng:random() end
	if b == nil then return rng:random(a) end
	return rng:random(a, b)
end

return RunRandom

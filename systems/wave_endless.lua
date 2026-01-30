local Endless = {}

function Endless.apply(wave, depth)
	-- counts
	wave.enemies.tank = wave.enemies.tank + math.floor(depth / 2)
	wave.enemies.splitter = wave.enemies.splitter + math.floor(depth / 3)
	wave.enemies.runner = wave.enemies.runner + math.floor(depth / 4)
	wave.enemies.grunt = wave.enemies.grunt + math.floor(depth / 5)

	-- ramps
	wave.ramps.hp = wave.ramps.hp * (1.06 ^ depth)
	wave.ramps.speed = wave.ramps.speed * (1.01 ^ depth)

	-- gap clamp
	wave.gap = math.max(0.38, wave.gap * (0.985 ^ depth))
end

return Endless
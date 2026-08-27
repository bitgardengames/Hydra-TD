-- Dependency-free checks for the victory screen's celebratory confetti mix.
local file = assert(io.open("ui/menu/screens/victory.lua", "r"))
local source = file:read("*a")
file:close()

assert(source:find('local confettiShapes = {"paper", "diamond", "ribbon", "dot"}', 1, true),
	"victory confetti should mix several silhouettes")
assert(source:find("local burst = not reducedMotion and i <= 36", 1, true),
	"victory should open with a two-sided confetti burst")
assert(source:find("p.vy = p.vy + p.gravity * dt", 1, true),
	"burst pieces should arc back down under gravity")
assert(source:find("local count = reducedMotion and 36 or 84", 1, true),
	"reduced motion should use a calmer particle count")
assert(source:find('p.shape == "ribbon"', 1, true) and source:find('p.shape == "dot"', 1, true),
	"the renderer should draw the authored confetti silhouettes")

print("victory confetti fixtures passed")

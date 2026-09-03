-- Dependency-free checks for the victory screen's celebratory confetti mix.
local file = assert(io.open("ui/menu/screens/victory.lua", "r"))
local source = file:read("*a")
file:close()

assert(source:find('local confettiShapes = {"paper", "diamond", "dot"}', 1, true),
	"victory confetti should mix several non-arrow silhouettes")
assert(not source:find('p.shape == "ribbon"', 1, true),
	"victory confetti should not draw the arrow-like ribbon silhouette")
assert(source:find("local burst = not reducedMotion and i <= 36", 1, true),
	"victory should open with a two-sided confetti burst")
assert(source:find("p.vy = p.vy + p.gravity * dt", 1, true),
	"burst pieces should arc back down under gravity")
assert(source:find("local drag = 1 / (1 + p.drag * dt)", 1, true),
	"confetti velocity should gradually slow under air resistance")
assert(source:find("random(210, 400)", 1, true) and source:find("random(-400, -210)", 1, true),
	"the opening volley should travel farther across the screen")
assert(source:find("random(-600, -350)", 1, true),
	"the opening volley should launch with extra upward velocity")
assert(source:find("local count = reducedMotion and 36 or 84", 1, true),
	"reduced motion should use a calmer particle count")
assert(source:find('p.shape == "diamond"', 1, true) and source:find('p.shape == "dot"', 1, true),
	"the renderer should draw the authored confetti silhouettes")

print("victory confetti fixtures passed")

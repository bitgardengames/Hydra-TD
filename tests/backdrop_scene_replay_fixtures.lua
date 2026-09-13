-- Regression coverage for backdrop scenes captured from live gameplay.
local source = assert(io.open("scenes/backdrop.lua", "r")):read("*a")

assert(source:find('local SimulationClock = require("core.simulation_clock")', 1, true),
	"backdrop replay must use the gameplay simulation clock")
assert(source:find("State.wave = shot.wave or 1", 1, true),
	"backdrop replay must preserve the captured campaign wave number")
assert(not source:find("% 10", 1, true),
	"backdrop replay must not wrap captured campaign waves to waves 1-10")
assert(source:find("Sim.update(step)", 1, true),
	"backdrop warmup must advance using the gameplay fixed step")
assert(source:find("Backdrop.fadeT = Backdrop.fadeT + dt * Backdrop.fadeDir", 1, true),
	"backdrop fades must advance in wall-clock time rather than per rendered frame")

print("backdrop scene replay fixtures passed")

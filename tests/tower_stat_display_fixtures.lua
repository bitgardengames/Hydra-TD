-- Dependency-free tower stat display fixtures. Run from the repository root
-- with Lua/LuaJIT.
package.path = "./?.lua;" .. package.path

package.loaded["core.constants"] = {TILE = 56}

local TowerStatDisplay = require("core.tower_stat_display")

assert(TowerStatDisplay.range(4.25 * 56) == 85,
	"range should use twenty whole-number display units per tile")
assert(TowerStatDisplay.range(4.25 * 56 + 0.16 * 56) == 88,
	"fractional world-space range upgrades should produce a readable whole number")
assert(TowerStatDisplay.range(1.77 * 56 / 20) == 2,
	"fractional display-unit gains should round to the nearest whole number")
assert(TowerStatDisplay.range(nil) == 0, "missing range should display as zero")

print("tower stat display fixtures: ok")

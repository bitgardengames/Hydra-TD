-- Health-bar policy and lightweight render counters live outside the renderer so
-- dependency-free fixtures can exercise the rules without booting LÖVE.
local HealthVisibility = {}

HealthVisibility.RECENT_HIT_DURATION = 1.0

local counters = {
	visibleBars = 0,
	drawSubmissions = 0,
}

function HealthVisibility.isVisible(e, selectedEnemy)
	if not e or not e.hp or e.hp <= 0 then return false end
	return e.hp < (e.maxHp or e.hp)
		or e.boss == true
		or e == selectedEnemy
		or (e.healthBarHitTimer or 0) > 0
end

function HealthVisibility.beginFrame()
	counters.visibleBars = 0
	counters.drawSubmissions = 0
end

function HealthVisibility.recordBar(drawSubmissions)
	counters.visibleBars = counters.visibleBars + 1
	counters.drawSubmissions = counters.drawSubmissions + drawSubmissions
end

function HealthVisibility.getCounters()
	return counters
end

return HealthVisibility

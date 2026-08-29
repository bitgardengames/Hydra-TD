-- Dependency-free health-bar visibility and submission fixtures.
package.path = "./?.lua;" .. package.path

local Visibility = require("render.enemy_health_visibility")

local function renderFixture(enemies, selected)
	Visibility.beginFrame()
	for _, enemy in ipairs(enemies) do
		if Visibility.isVisible(enemy, selected) then
			-- A non-empty bar submits its background, base fill, and highlight.
			Visibility.recordBar(3)
		end
	end
	local counters = Visibility.getCounters()
	return counters.visibleBars, counters.drawSubmissions
end

local wave = {}
for i = 1, 180 do wave[i] = {hp = 100, maxHp = 100} end
local bars, submissions = renderFixture(wave)
assert(bars == 0, "a large full-health wave has no visible health bars")
assert(submissions == 0, "a large full-health wave has no health-bar draw submissions")

local damaged = {hp = 99, maxHp = 100}
bars, submissions = renderFixture({damaged})
assert(bars == 1 and submissions == 3, "a damaged enemy draws one complete bar")

local boss = {hp = 100, maxHp = 100, boss = true}
bars, submissions = renderFixture({boss})
assert(bars == 1 and submissions == 3, "a full-health boss keeps its bar")

local selected = {hp = 100, maxHp = 100}
bars, submissions = renderFixture({selected}, selected)
assert(bars == 1 and submissions == 3, "a selected full-health enemy keeps its bar")

local recentlyHit = {hp = 100, maxHp = 100, healthBarHitTimer = 0.25}
bars, submissions = renderFixture({recentlyHit})
assert(bars == 1 and submissions == 3, "a recently hit full-health enemy keeps its bar")
recentlyHit.healthBarHitTimer = 0
assert(not Visibility.isVisible(recentlyHit), "the recent-hit rule expires")

print("enemy health visibility fixtures passed")

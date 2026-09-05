-- Gatecrasher threshold queue and path-distance regression fixtures.
package.path = "./?.lua;./?/init.lua;" .. package.path

love = {math = {random = function() return 0.5 end}}
local map = {
	path = {{0, 0}, {1, 0}},
	pathWorld = {{0, 0}, {100, 0}, {100, 100}, {200, 100}},
	pathSegLen = {100, 100, 100}, totalWorldLength = 300, lastSecondThreshold = 290,
}
local spatialUpdates = 0
package.loaded["core.theme"] = {ui = {money={1,1,1}, good={0,1,0}, bad={1,0,0}, warn={1,.5,0}}, tower={slow={0,1,1}, poison={0,1,0}}}
package.loaded["core.util"] = {clearTable=function(t) for k in pairs(t) do t[k]=nil end end}
package.loaded["core.state"] = {money=0,score=0,lives=10,waveLeaks=0,totalLeaks=0,addDamage=function() end}
package.loaded["world.effects"] = {shake=function() end,spawnGatecrasherLunge=function() end,spawnBossDeathExplosion=function() end,spawnEnemyDeath=function() end}
package.loaded["world.map"] = {map=map,gridToCenter=function() return 0,0 end}
package.loaded["world.spatial_grid"] = {
	newQueryContext=function() return {results={}} end, radiusOptions={living={}},
	setEnemyLifecycleHooks=function() end, updateEnemy=function(e)
		spatialUpdates=spatialUpdates+1; e.cellX=math.floor(e.x/64); e.cellY=math.floor(e.y/64)
	end, removeEnemy=function() end, querySquareCandidatesLocal=function() return {},0 end, visitRadius=function() end,
}
package.loaded["world.enemy_support"] = {onEnemyCellChanged=function() end,onEnemyRemoved=function() end,register=function() end,update=function() end,clear=function() end,detachDead=function() end,markSourceDirty=function() end}
package.loaded["ui.floaters"] = {add=function() end}
package.loaded["systems.achievements"] = {increment=function() end,unlock=function() end}
package.loaded["core.localization"] = function(key) return key end
package.loaded["core.save"] = {markEnemyEncountered=function() end,recordEnemyResult=function() end}
package.loaded["systems.run_stats"] = {recordDamage=function() end,recordKill=function() end}
package.loaded["systems.difficulty"] = {}
local defeatReason
package.loaded["systems.gameplay_outcome"] = {defeat=function(reason) defeatReason=reason end}
package.loaded["world.enemy_phase"] = {initialize=function() end,update=function() end,movementMultiplier=function() return 1 end}

local Enemies = require("world.enemies")
local def = assert(Enemies.EnemyDefs.boss_gatecrasher)
assert(def.healthThresholds[1] > def.healthThresholds[2] and def.healthThresholds[2] > def.healthThresholds[3],
	"health thresholds must be ordered high to low")

local exact = Enemies.spawnEnemy("boss_gatecrasher", 1, 1)
Enemies.applyDamage(exact, exact.maxHp * 0.25, {})
assert(exact.nextHealthThreshold == 2 and exact.lungesPending == 1 and exact.lungeWindup,
	"damage landing exactly on a threshold must activate it")
local hpBeforeMitigatedHit = exact.hp
local dealt = Enemies.applyDamage(exact, 10, {})
assert(dealt == 10 * def.lunge.windupDamageMultiplier
	and exact.hp == hpBeforeMitigatedHit - dealt,
	"the authored mitigation must apply only while the lunge is winding up")

local multi = Enemies.spawnEnemy("boss_gatecrasher", 1, 1)
Enemies.applyDamage(multi, multi.maxHp * 0.8, {})
assert(multi.nextHealthThreshold == 4 and multi.lungesPending == 3,
	"one large hit must queue one lunge for every crossed threshold")
Enemies.applyDamage(multi, 1, {})
assert(multi.lungesPending == 3, "damage below consumed thresholds must not duplicate lunges")

local pathEnemy = {x=90,y=0,dist=90,pathSeg=1,pathT=.9,radius=10,id=99}
local beforeUpdates = spatialUpdates
local moved, exited = Enemies.advanceEnemyByDistance(pathEnemy, 35, map.pathWorld, map.pathSegLen, map.totalWorldLength)
assert(moved and not exited and pathEnemy.pathSeg == 2 and pathEnemy.pathT == .25,
	"distance advance must traverse a segment boundary and preserve interpolation")
assert(pathEnemy.x == 100 and pathEnemy.y == 25 and pathEnemy.dist == 125,
	"distance advance must update world and total path positions")
assert(spatialUpdates == beforeUpdates + 1 and pathEnemy.cellX == 1,
	"distance advance must refresh spatial-grid membership")

-- The documented queue rule is sequential: three simultaneous crossings yield
-- three completed lunges, never duplicate or coalesce into one.
multi.baseSpeed, multi.speed = 0, 0
multi.lunge = {distance=30, windupDuration=def.lunge.windupDuration,
	windupDamageMultiplier=def.lunge.windupDamageMultiplier}
for _ = 1, 3 do Enemies.updateEnemies(def.lunge.windupDuration) end
assert(multi.lungesCompleted == 3 and multi.lungesPending == 0 and not multi.lungeWindup,
	"queued threshold lunges must execute exactly once each")

local exitBoss = Enemies.spawnEnemy("boss_gatecrasher", 1, 1)
Enemies.setPathDistance(exitBoss, 260)
exitBoss.lungesPending, exitBoss.lungeWindup, exitBoss.lungeActiveThreshold = 1, def.lunge.windupDuration, 1
exitBoss.baseSpeed = 0
Enemies.updateEnemies(def.lunge.windupDuration)
assert(defeatReason == "game.bossBreach",
	"a lunge reaching the path exit must immediately enter boss breach handling")

print("gatecrasher fixtures passed")

-- A tiny, isolated host for the normal combat modules.  The gameplay modules
-- still own entity construction, targeting, firing, projectile behavior and FX;
-- this object only installs a different set of collections/map for one tick.
local State = require("core.state")
local Map = require("world.map")
local Enemies = require("world.enemies")
local Towers = require("world.towers")
local Projectiles = require("world.projectiles")
local Effects = require("world.effects")
local Spatial = require("world.spatial_grid")
local Modules = require("systems.modules")
local BranchTierResolver = require("systems.branch_tier_resolver")
local EnemyRenderState = require("render.enemy_render_state")

local Sandbox = {}
Sandbox.__index = Sandbox

local effectNames = {
	"presentation", "towerTransformations", "splashes", "explosions", "zaps",
	"zapLines", "frost", "poison", "lancer", "gatecrasher", "plasmaParticles",
	"placePuffs", "sellSmoke", "death",
}

local function exchange(a, b)
	local temporary = {}
	for i = 1, #a do temporary[i] = a[i]; a[i] = nil end
	for i = 1, #b do a[i] = b[i]; b[i] = nil end
	for i = 1, #temporary do b[i] = temporary[i] end
end

local function buildPath(points)
	local path = {blocked={}, isPath={}, path={}, pathWorld=points, pathSegLen={}, samples={}, sampleStep=1}
	local total = 0
	for i = 1, #points - 1 do
		local a, b = points[i], points[i + 1]
		local dx, dy = b[1] - a[1], b[2] - a[2]
		local length = math.sqrt(dx * dx + dy * dy)
		path.pathSegLen[i] = length
		for d = 0, math.max(0, math.ceil(length) - 1) do
			local t = length > 0 and d / length or 0
			path.samples[#path.samples + 1] = {a[1] + dx*t, a[2] + dy*t}
		end
		total = total + length
	end
	path.samples[#path.samples + 1] = {points[#points][1], points[#points][2]}
	path.sampleCount, path.totalWorldLength = #path.samples, total
	path.lastSecondThreshold = math.max(0, total - 100)
	return path
end

local function makeTower(kind, specialization, x, y)
	local def = assert(Towers.TowerDefs[kind])
	local t = {
		kind=kind, def=def, gx=1, gy=1, x=x, y=y, renderY=y, level=2,
		specialization=specialization, height=4, prevHeight=4, renderHeight=4,
		placementAnim=0, range=0, range2=0, fireRate=0, fireInterval=0,
		damage=0, projSpeed=def.projSpeed, cooldown=0.2, damageDealt=0, kills=0,
		charge=0, windUp=0, fireAnim=0, recoil=0,
		recoilStrength=def.recoilStrength or 0, recoilDecay=def.recoilDecay or 18,
		angle=0, levelUpAnim=0, retargetT=0, _retargetSeed=17, _retargetCycle=0,
		turnSpeed=def.turnSpeed or 12, canRotate=def.canRotate ~= false,
		color=def.color, appliedModules={}, _cache={}, abilityRangeMultiplier=1,
		abilityAttackSpeed=1,
	}
	local resolved = BranchTierResolver.resolve(t, {modifiers={}})
	for key, value in pairs(resolved.stats) do t[key] = value end
	t.fireInterval = 1 / math.max(0.001, t.fireRate)
	t.range2 = t.range * t.range
	t.targetingPolicy = resolved.targetingPolicy
	t._fireProfile = Modules.getFireProfile(t)
	return t
end

function Sandbox.new(config)
	local self = setmetatable({
		map=buildPath(config.path), enemies={}, towers={}, projectiles={}, effects={},
		time=0, duration=config.duration or 5, config=config,
	}, Sandbox)
	for _, name in ipairs(effectNames) do self.effects[name] = {} end
	self.towers[1] = makeTower(config.tower.kind, config.branchId, config.tower.x, config.tower.y)
	self:withWorld(function()
		for i, spawn in ipairs(config.enemies) do
			local e = Enemies.spawnEnemy(spawn.kind, spawn.hpScale or 3, spawn.speedScale or 0.42,
				config.path[1][1], config.path[1][2], 1, nil, spawn.distance or ((i-1)*24), 0)
			Enemies.setPathDistance(e, spawn.distance or ((i-1)*24))
		end
	end)
	return self
end

function Sandbox:withWorld(fn)
	local map, savedMap = Map.map, {}
	for key, value in pairs(map) do savedMap[key] = value; map[key] = nil end
	for key, value in pairs(self.map) do map[key] = value end
	exchange(Enemies.enemies, self.enemies)
	exchange(Towers.towers, self.towers)
	exchange(Projectiles.projectiles, self.projectiles)
	for _, name in ipairs(effectNames) do exchange(Effects[name], self.effects[name]) end
	local oldPreview, oldFrame = State.previewSandbox, State.frameId
	local randomState = love.math.getRandomState and love.math.getRandomState()
	State.previewSandbox = true
	Spatial.clear()
	for i=1,#Enemies.enemies do Spatial.updateEnemy(Enemies.enemies[i]) end
	local ok, err = pcall(fn)
	Spatial.clear()
	exchange(Enemies.enemies, self.enemies)
	exchange(Towers.towers, self.towers)
	exchange(Projectiles.projectiles, self.projectiles)
	for _, name in ipairs(effectNames) do exchange(Effects[name], self.effects[name]) end
	for key in pairs(map) do map[key] = nil end
	for key, value in pairs(savedMap) do map[key] = value end
	for i=1,#Enemies.enemies do Spatial.updateEnemy(Enemies.enemies[i]) end
	State.previewSandbox, State.frameId = oldPreview, oldFrame
	if randomState and love.math.setRandomState then love.math.setRandomState(randomState) end
	if not ok then error(err, 0) end
end

function Sandbox:update(dt)
	self:withWorld(function()
		State.frameId = (State.frameId or 0) + 1
		Enemies.updateEnemies(dt)
		Towers.updateTowers(dt)
		Projectiles.update(dt)
		Effects.update(dt)
	end)
	self.time = self.time + dt
	EnemyRenderState.prepare(self.enemies, 1, dt, self.time)
end

function Sandbox:reset()
	local config = self.config
	local fresh = Sandbox.new(config)
	for key in pairs(self) do self[key] = nil end
	for key, value in pairs(fresh) do self[key] = value end
	setmetatable(self, Sandbox)
end

function Sandbox:draw(drawPath)
	local EnemyRenderer = require("render.enemy_renderer")
	local TowerRenderer = require("render.tower_renderer")
	drawPath(self.map.pathWorld)
	local tower = self.towers[1]
	TowerRenderer.drawTowerVisual(tower.kind, tower.x, tower.renderY, tower.angle, tower.recoil, tower.level)
	TowerRenderer.drawTowerFX(tower)
	for i=1,#self.enemies do EnemyRenderer.drawEnemy(self.enemies[i]) end
	self:withWorld(function() Projectiles.draw(); Effects.draw() end)
end

return Sandbox

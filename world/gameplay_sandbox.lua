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
local Targeting = require("world.targeting")
local EnemyDefs = require("world.enemy_defs")

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

local function buildPath(points, biome)
	-- Preview paths are ordinary grid paths. Map owns tile-to-world conversion,
	-- segment lengths, centerline samples, path width assumptions and biome.
	return Map.createRenderContext({path=points, biome=biome or "default"}).map
end

local function makeTower(kind, specialization, gx, gy)
	local def = assert(Towers.TowerDefs[kind])
	local x, y = Map.gridToCenter(gx, gy)
	local t = {
		kind=kind, def=def, gx=gx, gy=gy, x=x, y=y, renderY=y, level=2,
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
		map=buildPath(config.path, config.biome), enemies={}, towers={}, projectiles={}, effects={},
		pendingEnemies={}, time=0, duration=config.duration or 5, config=config,
	}, Sandbox)
	for _, name in ipairs(effectNames) do self.effects[name] = {} end
	self.towers[1] = makeTower(config.tower.kind, config.branchId, config.tower.x, config.tower.y)
	for _, authored in ipairs(config.enemies) do
		local count = authored.count or 1
		local spacing = authored.spacing or 0
		local initialDistance = authored.distance or authored.initialDistance or authored.spawnDistance or 0
		for i=1,count do
			local spawn={}
			for key,value in pairs(authored) do spawn[key]=value end
			spawn.distance=initialDistance+(i-1)*spacing
			spawn.spawnTime=(authored.spawnTime or 0)+(i-1)*(authored.spawnInterval or 0)
			self.pendingEnemies[#self.pendingEnemies+1]=spawn
		end
	end
	table.sort(self.pendingEnemies, function(a,b) return (a.spawnTime or 0) < (b.spawnTime or 0) end)
	self:spawnDueEnemies(0)
	return self
end

function Sandbox:spawnDueEnemies(now)
	self:withWorld(function()
		while self.pendingEnemies[1] and (self.pendingEnemies[1].spawnTime or 0) <= now do
			local spawn = table.remove(self.pendingEnemies, 1)
			local distance = math.max(0, spawn.distance or 0)
			local start = self.map.pathWorld[1]
			local speedScale=spawn.speedScale or 1
			if spawn.speedOverride then speedScale=spawn.speedOverride/assert(EnemyDefs[spawn.kind]).speed end
			local e = Enemies.spawnEnemy(spawn.kind, spawn.hpScale or 1, speedScale,
				start[1], start[2], 1, nil, distance, 0)
			Enemies.setPathDistance(e, distance)
			local health=spawn.healthOverride or spawn.health
			if health then e.hp=health; e.maxHp=health end
		end
	end)
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
	-- The live targeting cache is keyed by State.frameId. Preview sandboxes all
	-- restore that value after ticking, so sharing the cache could leave a card
	-- targeting another card's enemies (or no enemy at all). Give every sandbox
	-- tick a clean gameplay query without retaining preview entities afterward.
	Targeting.clearFrameCache()
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
	Targeting.clearFrameCache()
	State.previewSandbox, State.frameId = oldPreview, oldFrame
	if randomState and love.math.setRandomState then love.math.setRandomState(randomState) end
	if not ok then error(err, 0) end
end

function Sandbox:update(dt)
	self:spawnDueEnemies(self.time + dt)
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

function Sandbox:draw(drawWorld)
	local EnemyRenderer = require("render.enemy_renderer")
	local TowerRenderer = require("render.tower_renderer")
	drawWorld(self.map)
	local tower = self.towers[1]
	TowerRenderer.drawTowerVisual(tower.kind, tower.x, tower.renderY, tower.angle, tower.recoil, tower.level)
	TowerRenderer.drawTowerFX(tower)
	for i=1,#self.enemies do EnemyRenderer.drawEnemy(self.enemies[i]) end
	self:withWorld(function() Projectiles.draw(); Effects.draw() end)
end

return Sandbox

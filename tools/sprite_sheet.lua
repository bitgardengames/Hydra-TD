local DrawEntities = require("render.draw_entities")
local TowersDefs = require("world.tower_defs")
local EnemyDefs = require("world.enemy_defs")

local Export = {}

local lg = love.graphics

local EXPORT_DIR = "export"
local EXPORT_FILE = EXPORT_DIR .. "/hydra_spritesheet"

local SIZE = 256
local REF_ICON_SIZE = 64


local function ensureDir()
	love.filesystem.createDirectory(EXPORT_DIR)
end


local function renderTower(kind, angle)

	local canvas = lg.newCanvas(SIZE, SIZE, {msaa = 8})
	local scale = SIZE / REF_ICON_SIZE

	lg.setCanvas(canvas)
	lg.clear(0,0,0,0)

	lg.push()
	lg.translate(SIZE * 0.5, SIZE * 0.5)
	lg.scale(scale, scale)

	DrawEntities.drawTowerBase(kind, 0,0,1,1,1,1,0)
	DrawEntities.drawTowerCore(kind, 0,0,angle,0,1,1,1,1,0)

	lg.pop()
	lg.setCanvas()

	return canvas
end


local function renderEnemy(kind, def, dead)

	local canvas = lg.newCanvas(SIZE, SIZE, {msaa = 8})
	local scale = SIZE / REF_ICON_SIZE

	lg.setCanvas(canvas)
	lg.clear(0,0,0,0)

	lg.push()
	lg.translate(SIZE * 0.5, SIZE * 0.5)
	lg.scale(scale, scale)

	local enemy = {

		kind = kind,
		def = def,

		x = 0, y = 0,
		prevX = 0, prevY = 0,

		rx = 0,
		ry = 0,
		rAnimT = 0,

		alpha = 1,

		animT = 0,
		prevAnimT = 0,

		hp = 0,
		maxHp = def.hp,

		speed = def.speed,
		baseSpeed = def.speed,

		reward = def.reward,
		score = def.score,

		radius = def.radius,
		split = def.split,

		boss = def.boss or false,

		hitFlash = 0,
		shadow = true,

		dying = dead,
		deathDur = 0.3,
		deathT = dead and 0.3 or 0,

		spawnFade = 0,
		exitFade = nil,

		slowFactor = 1,
		slowTimer = 0,

		poisonStacks = 0,
		poisonTimer = 0,
		poisonDPS = 0
	}

	DrawEntities.drawEnemy(enemy)

	lg.pop()
	lg.setCanvas()

	return canvas
end


local function renderFX(kind)

	local canvas = lg.newCanvas(SIZE, SIZE)

	lg.setCanvas(canvas)
	lg.clear(0,0,0,0)

	lg.push()
	lg.translate(SIZE/2, SIZE/2)

	if kind == "lancer" then
		lg.setColor(1,1,1)
		lg.circle("fill",0,0,4)

	elseif kind == "cannon" then
		lg.setColor(0.9,0.9,0.9)
		lg.circle("fill",0,0,12)

	elseif kind == "slow" then
		lg.setColor(0.7,0.85,1)
		lg.setLineWidth(4)
		lg.circle("line",0,0,20)

	elseif kind == "shock" then
		lg.setColor(0.5,0.8,1)
		lg.circle("line",0,0,18)

	elseif kind == "poison" then
		lg.setColor(0.5,1,0.5)
		lg.circle("fill",0,0,10)
	end

	lg.pop()
	lg.setCanvas()

	return canvas
end


function Export.run()

	ensureDir()

	local sprites = {}

	-- Towers
	for kind in pairs(TowersDefs) do

		table.insert(sprites, renderTower(kind, -math.pi/2))
		table.insert(sprites, renderTower(kind, -math.pi/4))

	end


	-- Enemies
	for kind, def in pairs(EnemyDefs) do

		table.insert(sprites, renderEnemy(kind, def, false))
		table.insert(sprites, renderEnemy(kind, def, true))

	end


	-- FX
	local fx = {"lancer","cannon","slow","shock","poison"}

	for _,kind in ipairs(fx) do
		table.insert(sprites, renderFX(kind))
	end


	-- Sprite sheet layout
	local cols = 8
	local rows = math.ceil(#sprites / cols)

	local sheetW = cols * SIZE
	local sheetH = rows * SIZE

	local sheet = lg.newCanvas(sheetW, sheetH)

	lg.setCanvas(sheet)
	lg.clear(0,0,0,0)

	lg.setColor(1,1,1,1)

	for i, sprite in ipairs(sprites) do

		local col = (i-1) % cols
		local row = math.floor((i-1) / cols)

		local x = col * SIZE
		local y = row * SIZE

		lg.draw(sprite, x, y)
	end

	lg.setCanvas()

	local img = sheet:newImageData()
	img:encode("png", EXPORT_FILE .. ".png")

	print("Sprite sheet exported:", EXPORT_FILE)

	love.event.quit()

end


return Export
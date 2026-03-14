local DrawWorld = require("render.draw_world")
local DrawEntities = require("render.draw_entities")
local TowersDefs = require("world.tower_defs")
local EnemyDefs = require("world.enemy_defs")
local Title = require("ui.title")

local lg = love.graphics

local Export = {}

local EXPORT_DIR = "export"
local CAPSULE_DIR = EXPORT_DIR .. "/capsules"

-- Reuse banner sizes from art_export
local SIZES = {
	main_capsule   = {w = 1232, h = 706},
	header_capsule = {w = 920,  h = 430},
	small_capsule  = {w = 462,  h = 174},
	vertical_capsule = {w = 748, h = 896},
}

-- Composition definition
local Composition = {
	background = true,

	objects = {

		-- Giant boss threat (top center)
		{
			type = "enemy",
			kind = "boss",
			x = 0.58,
			y = 0.34,
			scale = 28.0,
		},

		-- Enemy wave approaching
		{
			type = "enemy",
			kind = "grunt",
			x = 0.46,
			y = 0.48,
			scale = 2.0,
		},
		{
			type = "enemy",
			kind = "grunt",
			x = 0.52,
			y = 0.50,
			scale = 2.0,
		},
		{
			type = "enemy",
			kind = "grunt",
			x = 0.58,
			y = 0.52,
			scale = 2.0,
		},
		{
			type = "enemy",
			kind = "grunt",
			x = 0.64,
			y = 0.54,
			scale = 2.0,
		},

		-- Hero tower (bottom-right firing upward)
		{
			type = "tower",
			kind = "lancer",
			x = 0.78,
			y = 0.74,
			scale = 2.4,
			angle = -math.pi * 0.72,
		},

		-- Secondary tower to give battlefield feel
		{
			type = "tower",
			kind = "cannon",
			x = 0.60,
			y = 0.76,
			scale = 2.0,
			angle = -math.pi * 0.70,
		},
	},

	logo = {
		enabled = true,
		drop = 0.08,
	},
}

local function ensureDirs()
	love.filesystem.createDirectory(EXPORT_DIR)
	love.filesystem.createDirectory(CAPSULE_DIR)
end

local function exportCanvas(canvas, path)
	local data = canvas:newImageData()
	data:encode("png", path .. ".png")
end

local REF_W = 1232
local REF_H = 706

local function drawObject(obj, w, h)

	local x = w * obj.x
	local y = h * obj.y

	local baseScale = math.min(w / REF_W, h / REF_H)

	lg.push()
	lg.translate(x, y)

	lg.scale(obj.scale * baseScale, obj.scale * baseScale)

	if obj.type == "tower" then
		DrawEntities.drawTowerBase(obj.kind, 0, 0, 1,1,1,1,0)

		DrawEntities.drawTowerCore(
			obj.kind,
			0,
			0,
			obj.angle or 0,
			0,
			1,1,1,1,
			0
		)

	elseif obj.type == "enemy" then
		local def = EnemyDefs[obj.kind]

		local enemy = {
			kind = obj.kind,
			def = def,
			x = 0,
			y = 0,
			prevX = 0,
			prevY = 0,
			boss = def.boss or false,

			hp = 0,
			maxHp = def.hp or 1,
			baseSpeed = def.speed,
			speed = def.speed,
			reward = def.reward,
			score = def.score,

			radius = def.radius,
			split = def.split,

			alpha = 1,
			animT = 0,
			prevAnimT = 0,
			dist = 0,
			prevDist = 0,
			seg = 1,
			prevSeg = 1,

			hitFlash = 0,
			dying = false,
			deathDur = 0.3,
			deathT = 0,

			spawnFade = 0,
			exitFade = nil,
			modifiers = def.modifiers,

			slowFactor = 1,
			slowTimer = 0,
			poisonStacks = 0,
			poisonTimer = 0,
			poisonDPS = 0,
		}

		DrawEntities.drawEnemy(enemy)
	end

	lg.pop()
end

local function renderCapsule(name, size)
	local w = size.w
	local h = size.h

	local canvas = lg.newCanvas(w, h, {msaa=8})
	lg.setCanvas(canvas)
	lg.clear(0,0,0,0)

	if Composition.background then
		DrawWorld.drawGrass()
	end

	for _, obj in ipairs(Composition.objects) do
		drawObject(obj, w, h)
	end

	if Composition.logo.enabled then
		Title.invalidateCache()
		Title.drawBannerStyle(w, h, -math.pi/6, 1, h * Composition.logo.drop)
	end

	lg.setCanvas()

	exportCanvas(canvas, CAPSULE_DIR .. "/" .. name)
end

function Export.exportCapsules()
	for name, size in pairs(SIZES) do
		renderCapsule(name, size)
	end
end

function Export.run()
	ensureDirs()
	Export.exportCapsules()
	love.event.quit()
end

return Export
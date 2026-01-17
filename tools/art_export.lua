local Towers = require("world.towers")
local Theme = require("core.theme")
local Enemies = require("world.enemies")
local Draw = require("ui.draw")
local Title = require("ui.title")

local Export = {}

local lg = love.graphics

local SIZES = {64, 128, 256, 512, 1024}
local REF_ICON_SIZE = 64
local ICON_FILL = 2.00

local EXPORT_DIR = "export"
local TOWER_DIR = EXPORT_DIR .. "/towers"
local ENEMY_DIR = EXPORT_DIR .. "/enemies"
local BANNER_DIR = EXPORT_DIR .. "/banners"
local ICON_DIR = EXPORT_DIR .. "/icons"

-- Canonical banner reference
local REF_W = 920
local REF_H = 430
local REF_TITLE_FONT = 78

local BANNERS = {
	-- Steam banner sizes
	main_capsule = {w = 1232, h = 706},
	header_capsule = {w = 920, h = 430},
	small_capsule = {w = 462, h = 174},
	vertical_capsule = {w = 748, h = 896},

	library_hero = {w = 3840, h = 1240},
	library_logo = {w = 1280, h = 720},
	library_header = {w = 920, h = 430},
	library_capsule = {w = 600, h = 900},

	-- Social banners
	youtube_banner = {w = 2048, h = 1152},

	-- Desktop
	desktop = {w = 1920, h = 1080},
}

local TRANSPARENT_BANNERS = {
	store_main = true,
	store_header = true,
	store_small = true,
	desktop  = true,
}

-- Helpers
local function ensureDirs()
	love.filesystem.createDirectory(EXPORT_DIR)
	love.filesystem.createDirectory(TOWER_DIR)
	love.filesystem.createDirectory(ENEMY_DIR)
	love.filesystem.createDirectory(BANNER_DIR)
	love.filesystem.createDirectory(ICON_DIR)
end

local function exportCanvas(canvas, path)
	local imageData = canvas:newImageData()
	imageData:encode("png", path .. ".png")
end

-- Tower export
function Export.exportTowers()
	local REF_ICON_SIZE = 64

	local POSES = {
		idle = -math.pi / 2, -- straight up
		action = -math.pi / 4, -- acrtion
	}

	for kind in pairs(Towers.towerDefs) do
		for poseName, angle in pairs(POSES) do
			for _, size in ipairs(SIZES) do
				local canvas = lg.newCanvas(size, size, {msaa = 8})
				local scale = size / REF_ICON_SIZE

				lg.setCanvas(canvas)
				lg.clear(0, 0, 0, 0)

				lg.push()
				lg.translate(size * 0.5, size * 0.5)
				lg.scale(scale, scale)

				Draw.drawTowerCore(kind, 0, 0, {angle = angle, alpha = 1, shadow = false})

				lg.pop()
				lg.setCanvas()

				exportCanvas(canvas, string.format( "%s/tower_%s_%s_%d", TOWER_DIR, kind, poseName, size))
			end
		end
	end
end

-- Enemy export (alive + dead)
function Export.exportEnemies()
	for kind, def in pairs(Enemies.enemyDefs) do
		for _, size in ipairs(SIZES) do
			for _, isDead in ipairs({false, true}) do
				local canvas = lg.newCanvas(size, size, {msaa = 8})
				local scale = size / REF_ICON_SIZE

				lg.setCanvas(canvas)
				lg.clear(0, 0, 0, 0)

				lg.push()
				lg.translate(size * 0.5, size * 0.5)
				lg.scale(scale, scale)

				local enemy = {
					kind = kind,
					def = def,
					x = 0,
					y = 0,
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

					hitFlash = 0,
					dying = isDead,
					deathDur = 0.3,
					deathT = isDead and 0.3 or 0,

					spawnFade = 0,
					exitFade = nil,
					pathIndex = 1,
					modifiers = def.modifiers,

					slowFactor = 1,
					slowTimer = 0,
					poisonStacks = 0,
					poisonTimer = 0,
					poisonDPS = 0,
				}

				Draw.drawEnemy(enemy)

				lg.pop()
				lg.setCanvas()

				exportCanvas(canvas, string.format("%s/enemy_%s%s_%d", ENEMY_DIR, kind, isDead and "_dead" or "", size))
			end
		end
	end
end

-- Banner helpers
local function isVerticalBanner(w, h)
	return h / w > 1.15
end

local function drawOutlinedText(text, x, y, font, opts)
	opts = opts or {}

	local outline = opts.outline or 2
	local or_, og, ob, oa = unpack(opts.outlineColor or {0, 0, 0, 0.6})
	local tr, tg, tb, ta = unpack(opts.textColor or {1, 1, 1, 1})

	lg.setFont(font)

	lg.setColor(or_, og, ob, oa)

	for ox = -outline, outline do
		for oy = -outline, outline do
			if ox ~= 0 or oy ~= 0 then
				lg.print(text, x + ox, y + oy)
			end
		end
	end

	lg.setColor(tr, tg, tb, ta)
	lg.print(text, x, y)
end

local function drawBannerBackground(w, h)
	lg.setColor(0.31, 0.57, 0.76) -- soft arcade
	lg.rectangle("fill", 0, 0, w, h)

	lg.setBlendMode("alpha")

	local steps = 14
	local maxInset = math.min(w, h) * 0.06

	for i = 1, steps do
		local t = i / steps
		local inset = t * maxInset
		local alpha = 0.02 * (1 - t) ^ 2 -- quadratic falloff

		lg.setColor(0, 0, 0, alpha)

		lg.rectangle("fill", 0, 0, w, inset) -- Top
		lg.rectangle("fill", 0, h - inset, w, inset) -- Bottom
		lg.rectangle("fill", 0, inset, inset, h - inset * 2) -- Left
		lg.rectangle("fill", w - inset, inset, inset, h - inset * 2) -- Right
	end
end

-- Banner group
local function drawBannerGroup(w, h)
	Title.drawBannerStyle(w, h, { angle = -math.pi / 6 })
end

-- Banner export
function Export.exportBanners()
	for name, b in pairs(BANNERS) do
		local canvas = lg.newCanvas(b.w, b.h, {msaa = 8})

		lg.setCanvas(canvas)
		lg.clear(0, 0, 0, 0)

		drawBannerBackground(b.w, b.h)

		if name ~= "library_hero" then
			drawBannerGroup(b.w, b.h)
		end

		lg.setCanvas()

		exportCanvas(canvas, string.format("%s/%s_%dx%d", BANNER_DIR, name, b.w, b.h))

		if TRANSPARENT_BANNERS[name] then
			local canvas = lg.newCanvas(b.w, b.h, {msaa = 8})

			lg.setCanvas(canvas)
			lg.clear(0, 0, 0, 0)

			drawBannerGroup(b.w, b.h)

			lg.setCanvas()

			exportCanvas(canvas, string.format("%s/%s_%dx%d_transparent", BANNER_DIR, name, b.w, b.h))
		end
	end
end

function Export.exportAppIcons()
	local size = 256
	local canvas = lg.newCanvas(size, size, { msaa = 8 })
	local scale = (size / REF_ICON_SIZE) * ICON_FILL

	for towerId, _ in pairs(Towers.towerDefs) do
		lg.setCanvas(canvas)
		lg.clear(0, 0, 0, 0)

		lg.push()
		lg.translate(size * 0.5, size * 0.5)
		lg.scale(scale, scale)

		Draw.drawTowerCore(towerId, 0, 0, {angle  = -math.pi / 4, alpha  = 1, shadow = false})

		lg.pop()
		lg.setCanvas()

		exportCanvas(canvas, string.format("%s/appicon_%s_%d", ICON_DIR, towerId, size))
	end
end

function Export.run()
	ensureDirs()
	Export.exportTowers()
	Export.exportEnemies()
	Export.exportBanners()
	Export.exportAppIcons()
	love.event.quit()
end

return Export
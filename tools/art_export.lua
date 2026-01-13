-- tools/art_export.lua
-- Dev-only artwork export utility for Hydra TD

local Towers  = require("world.towers")
local Theme  = require("core.theme")
local Enemies = require("world.enemies")
local Draw    = require("ui.draw")

local Export = {}

local lg = love.graphics

-- =========================================================
-- Configuration
-- =========================================================

local SIZES = {64, 128, 256, 512}

local EXPORT_DIR = "export"
local TOWER_DIR  = EXPORT_DIR .. "/towers"
local ENEMY_DIR  = EXPORT_DIR .. "/enemies"
local BANNER_DIR = EXPORT_DIR .. "/banners"

-- Steam-required banner sizes
local BANNERS = {
	store_header  = { w = 920,  h = 430 },
	store_small   = { w = 462,  h = 174 },
	store_main    = { w = 1232, h = 706 },
	store_vertical= { w = 748,  h = 896 },

	library_capsule = { w = 600,  h = 900 },
	library_header  = { w = 920,  h = 430 },
}

-- =========================================================
-- Helpers
-- =========================================================

local function ensureDirs()
	love.filesystem.createDirectory(EXPORT_DIR)
	love.filesystem.createDirectory(TOWER_DIR)
	love.filesystem.createDirectory(ENEMY_DIR)
	love.filesystem.createDirectory(BANNER_DIR)
end

local function exportCanvas(canvas, path)
	local imageData = canvas:newImageData()
	imageData:encode("png", path .. ".png")
end

-- =========================================================
-- Tower export
-- =========================================================

function Export.exportTowers()
	for kind in pairs(Towers.towerDefs) do
		for _, size in ipairs(SIZES) do
			local canvas = lg.newCanvas(size, size, { msaa = 8 })

			lg.setCanvas(canvas)
			lg.clear(0, 0, 0, 0)

			lg.push()
			lg.translate(size * 0.5, size * 0.5)
			Draw.drawTowerCore(kind, 0, 0, {
				angle  = -math.pi / 4,
				alpha  = 1,
				shadow = false,
			})
			lg.pop()

			lg.setCanvas()

			exportCanvas(canvas, string.format("%s/tower_%s_%d", TOWER_DIR, kind, size))
		end
	end
end

-- =========================================================
-- Enemy export
-- =========================================================

function Export.exportEnemies()
	for kind, def in pairs(Enemies.enemyDefs) do
		for _, size in ipairs(SIZES) do
			-- ============================
			-- NORMAL POSE
			-- ============================
			do
				local canvas = lg.newCanvas(size, size, { msaa = 8 })

				lg.setCanvas(canvas)
				lg.clear(0, 0, 0, 0)

				lg.push()
				lg.translate(size * 0.5, size * 0.5)

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
					dying = false,
					deathT = 0,
					deathDur = 0.3,

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

				exportCanvas(
					canvas,
					string.format("%s/enemy_%s_%d", ENEMY_DIR, kind, size)
				)
			end

			-- ============================
			-- DEAD POSE
			-- ============================
			do
				local canvas = lg.newCanvas(size, size, { msaa = 8 })

				lg.setCanvas(canvas)
				lg.clear(0, 0, 0, 0)

				lg.push()
				lg.translate(size * 0.5, size * 0.5)

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
					dying = true,
					deathDur = 0.3,
					deathT = 0.3, -- fully “dead” pose

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

				exportCanvas(
					canvas,
					string.format("%s/enemy_%s_dead_%d", ENEMY_DIR, kind, size)
				)
			end
		end
	end
end

-- =========================================================
-- Banner helpers
-- =========================================================

local function drawOutlinedText(text, x, y, font, opts)
	opts = opts or {}

	local outline = opts.outline or 2
	local r, g, b, a = unpack(opts.outlineColor or {0, 0, 0, 0.6})
	local tr, tg, tb, ta = unpack(opts.textColor or {0.92, 0.94, 0.96, 1})

	lg.setFont(font)

	-- Outline
	lg.setColor(r, g, b, a)
	for ox = -outline, outline do
		for oy = -outline, outline do
			if ox ~= 0 or oy ~= 0 then
				lg.print(text, x + ox, y + oy)
			end
		end
	end

	-- Main text
	lg.setColor(tr, tg, tb, ta)
	lg.print(text, x, y)
end

local function drawBannerBackground(w, h)
	lg.setColor(135/255, 195/255, 230/255)
	lg.rectangle("fill", 0, 0, w, h)

	-- subtle vignette frame
	lg.setColor(0, 0, 0, 0.35)
	lg.rectangle("line", 1, 1, w - 2, h - 2)
end

local function drawBannerGroup(w, h)
	-- --- Tunables ---
	local GAP = h * 0.06
	local TITLE_SCALE = 0.18
	local LANCER_SCALE_FACTOR = 0.0048
	local LANCER_Y_OFFSET = -7

	-- Font
	local fontSize = math.floor(h * TITLE_SCALE)
	local font = love.graphics.newFont("assets/fonts/PTSans.ttf", fontSize)
	lg.setFont(font)

	local text = "HYDRA TD"
	local textW = font:getWidth(text)
	local textH = font:getHeight()

	-- Lancer sizing
	local lancerScale = math.min(w, h) * LANCER_SCALE_FACTOR
	local lancerVisualW = lancerScale * 50 -- approx visual width of tower

	-- Total group width
	local groupW = lancerVisualW + GAP + textW

	-- Center group
	local baseX = (w - groupW) * 0.5
	local centerY = h * 0.52

	-- --- Draw lancer ---
	lg.push()
	lg.translate(baseX + lancerVisualW * 0.5, centerY + LANCER_Y_OFFSET)
	lg.scale(lancerScale, lancerScale)

	Draw.drawTowerCore("lancer", 0, 0, {
		angle  = -math.pi / 6,
		alpha  = 1,
		shadow = false,
	})

	lg.pop()

	-- --- Draw title ---
	drawOutlinedText(
		text,
		baseX + lancerVisualW + GAP,
		centerY - textH * 0.5,
		font,
		{
			outline = 5,
			outlineColor = {0, 0, 0, 0.55},
			textColor = {Theme.tower.lancer[1], Theme.tower.lancer[2], Theme.tower.lancer[3], 1},
		}
	)
end

-- =========================================================
-- Banner export
-- =========================================================

function Export.exportBanners()
	for name, b in pairs(BANNERS) do
		local canvas = lg.newCanvas(b.w, b.h, { msaa = 8 })

		lg.setCanvas(canvas)
		lg.clear(0, 0, 0, 0)

		drawBannerBackground(b.w, b.h)
		drawBannerGroup(b.w, b.h)

		lg.setCanvas()

		exportCanvas(
			canvas,
			string.format("%s/%s_%dx%d", BANNER_DIR, name, b.w, b.h)
		)
	end
end

-- =========================================================
-- Entry point
-- =========================================================

function Export.run()
	ensureDirs()

	Export.exportTowers()
	Export.exportEnemies()
	Export.exportBanners()

	love.event.quit()
end

return Export
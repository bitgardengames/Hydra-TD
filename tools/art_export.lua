local Towers = require("world.towers")
local TowersDefs = require("world.tower_defs")
local Theme = require("core.theme")
local Enemies = require("world.enemies")
local EnemyDefs = require("world.enemy_defs")
local Draw = require("render.draw")
local DrawWorld = require("render.draw_world")
local DrawEntities = require("render.draw_entities")
local Camera = require("core.camera")
local Constants = require("core.constants")
local Title = require("ui.title")

local Export = {}

local lg = love.graphics
local pi = math.pi

local SIZES = {64, 128, 256, 512, 1024}
local REF_ICON_SIZE = 64
local ICON_FILL = 2.00

local EXPORT_DIR = "export"
local TOWER_DIR = EXPORT_DIR .. "/towers"
local ENEMY_DIR = EXPORT_DIR .. "/enemies"
local BANNER_DIR = EXPORT_DIR .. "/banners"
local ICON_DIR = EXPORT_DIR .. "/icons"
local AVATAR_DIR = EXPORT_DIR .. "/avatars"
local ANIM_DIR = EXPORT_DIR .. "/anim"
local PATCH_DIR = EXPORT_DIR .. "/patch"

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

	page_background = {w = 1438, h = 810},

	-- Steam update / announcement images
	announcement_cover = {w = 800, h = 450},
	announcement_header = {w = 1920, h = 622},

	-- Social banners
	youtube_banner = {w = 2048, h = 1152},
	x_banner = {w = 1500, h = 500},

	-- Desktop
	desktop = {w = 1920, h = 1080},
}

-- Banners that should output without text
local TEXTLESS_BANNERS = {
	library_hero = true,
	page_background = true,
}

local TRANSPARENT_BANNERS = {
	library_logo = true, -- Actually required by steam to be transparent
	main_capsule = true,
	header_capsule = true,
	small_capsule = true,
	desktop  = true,
}

-- Steam announcement cover and header
local PATCH_BANNERS = {
	update = {w = 800, h = 450},
	update_header = {w = 1920, h = 622},
}

-- Helpers
local function ensureDirs()
	love.filesystem.createDirectory(EXPORT_DIR)
	love.filesystem.createDirectory(TOWER_DIR)
	love.filesystem.createDirectory(ENEMY_DIR)
	love.filesystem.createDirectory(BANNER_DIR)
	love.filesystem.createDirectory(PATCH_DIR)
	love.filesystem.createDirectory(ICON_DIR)
	love.filesystem.createDirectory(AVATAR_DIR)
	love.filesystem.createDirectory(ANIM_DIR)
end

local function exportCanvas(canvas, path)
	local imageData = canvas:newImageData()
	imageData:encode("png", path .. ".png")
end

local function drawCog(x, y, r, teeth, toothDepth, rotation)
	lg.push()
	lg.translate(x, y)
	lg.rotate(rotation or 0)

	-- core
	lg.circle("fill", 0, 0, r)

	local toothW = (2 * pi * r) / teeth * 0.54

	for i = 1, teeth do
		local a = (i / teeth) * (2 * pi)

		lg.push()
		lg.rotate(a)

		lg.rectangle(
			"fill",
			r - toothDepth * 0.45,
			-toothW * 0.5,
			toothDepth,
			toothW,
			toothW * 0.35,
			toothW * 0.35
		)

		lg.pop()
	end

	lg.pop()
end

-- Tower export
function Export.exportTowers()
	local REF_ICON_SIZE = 64

	local POSES = {
		idle = -math.pi / 2,
		action = -math.pi / 4,
	}

	for kind in pairs(TowersDefs) do
		for poseName, angle in pairs(POSES) do
			for _, size in ipairs(SIZES) do
				local canvas = lg.newCanvas(size, size, {msaa = 8})
				local scale = size / REF_ICON_SIZE

				lg.setCanvas(canvas)
				lg.clear(0, 0, 0, 0)

				lg.push()
				lg.translate(size * 0.5, size * 0.5)
				lg.scale(scale, scale)

				-- Single source of truth
				DrawEntities.drawTowerVisual(kind, 0, 0, angle, 0, 1)

				lg.pop()
				lg.setCanvas()

				exportCanvas(canvas, string.format("%s/tower_%s_%s_%d", TOWER_DIR, kind, poseName, size))
			end
		end
	end
end

-- Enemy export (alive + dead)
function Export.exportEnemies()
	for kind, def in pairs(EnemyDefs) do
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

				DrawEntities.drawEnemy(enemy)

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
	local or_, og, ob, oa = unpack(opts.outlineColor or Theme.outline.color)
	local tr, tg, tb, ta = unpack(opts.textColor or Theme.tower.lancer)

	local maxWidth = opts.maxWidth
	local align = opts.align or "left"

	lg.setFont(font)

	lg.setColor(or_, og, ob, oa)

	for ox = -outline, outline do
		for oy = -outline, outline do
			if ox ~= 0 or oy ~= 0 then
				if maxWidth then
					lg.printf(text, x + ox - maxWidth * 0.5, y + oy, maxWidth, align)
				else
					lg.print(text, x + ox, y + oy)
				end
			end
		end
	end

	lg.setColor(tr, tg, tb, ta)

	if maxWidth then
		lg.printf(text, x - maxWidth * 0.5, y, maxWidth, align)
	else
		lg.print(text, x, y)
	end
end

local function drawBannerBackground(w, h)
	--lg.setColor(Theme.menu) -- soft arcade
	--lg.rectangle("fill", 0, 0, w, h)

	--Camera.begin()
	DrawWorld.drawGrass()
	--Camera.finish()
	--Camera.present()

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
local lancerAngle = -math.pi / 6

local function drawBannerGroup(w, h)
	Title.invalidateCache()
	Title.drawBannerStyle(w, h, lancerAngle, 1, 0)
end

-- Banner export
function Export.exportBanners()
	for name, b in pairs(BANNERS) do
		local canvas = lg.newCanvas(b.w, b.h, {msaa = 8})

		lg.setCanvas(canvas)
		lg.clear(0, 0, 0, 0)

		drawBannerBackground(b.w, b.h)

		if not TEXTLESS_BANNERS[name] then
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
	local sizes = {16, 32, 48, 256}

	for _, size in ipairs(sizes) do
		local samples = size > 32 and 8 or 0
		local canvas = lg.newCanvas(size, size, { msaa = samples })
		local scale = (size / REF_ICON_SIZE) * ICON_FILL

		for towerId, _ in pairs(TowersDefs) do
			lg.setCanvas(canvas)
			lg.clear(0, 0, 0, 0)
			lg.setColor(1, 1, 1, 1)
			lg.push()
			lg.translate(size * 0.5, size * 0.5)
			lg.scale(scale, scale)

			DrawEntities.drawTowerBase(towerId, 0, 0, {alpha  = 1, shadow = false})

			DrawEntities.drawTowerCore(towerId, 0, 0, {angle  = -math.pi / 4, alpha  = 1, shadow = false})

			lg.pop()
			lg.setCanvas()

			exportCanvas(canvas, string.format("%s/appicon_%s_%d", ICON_DIR, towerId, size))
		end
	end
end

--[[
	Animation idea, keep a glitchy tone but smooth animation

	animate the x eyes so they spin around,
	scale out
	boss shocked eyes scale/pop in
	flicker one eye
	vertical rounded rectangle (1 larger, 1 smaller) can "drip" from the eye, then fade out
	schocked eyes pop out
	x eyes come back
	x eyes flicke, one at a time, or just one

	normal eyes could come in, and look around, or wink or something.
--]]

function Export.exportSocialAvatar()
	local sizes = {98, 256, 512, 1024, 2048} -- 98 is YouTube avatar size
	local Constants = require("core.constants")

	local lg = love.graphics
	local max = math.max
	local pi = math.pi

	local ENEMY_RADIUS_REF = Constants.TILE * 0.42
	local OUTLINE_RATIO = 3 / ENEMY_RADIUS_REF

	for kind, data in pairs(TowersDefs) do
		for _, size in ipairs(sizes) do
			local canvas = lg.newCanvas(size, size, {msaa = 8})
			lg.setCanvas({canvas, stencil = true})
			lg.clear(0, 0, 0, 0)

			local cx = size * 0.5
			local cy = size * 0.5
			local radius = size * 0.34

			-- Outline)
			local outlinePad = radius * OUTLINE_RATIO * 1.28

			--local outlineColor = Theme.enemy.body -- assertive, but nice
			local outlineColor = data.color
			local bodyColor = {0.05, 0.05, 0.05, 1}

			-- Outline
			lg.setColor(outlineColor)
			lg.circle("fill", cx, cy, radius + outlinePad)

			-- Body
			lg.setColor(bodyColor)
			lg.circle("fill", cx, cy, radius)

			-- Eyes
			local eyeSep = radius * 0.38
			local eyeSize = max(1.6, radius * 0.16)
			local eyeY = cy - radius * 0.24

			lg.setColor(outlineColor)

			-- X eyes
			local armLen = eyeSize * 2.1
			local armThick = eyeSize * 1

			local function drawX(x, y)
				lg.push()
				lg.translate(x, y)
				lg.rotate(pi / 4)
				lg.rectangle("fill", -armLen, -armThick * 0.5, armLen * 2, armThick, armThick * 0.45)
				lg.pop()

				lg.push()
				lg.translate(x, y)
				lg.rotate(-pi / 4)
				lg.rectangle("fill", -armLen, -armThick * 0.5, armLen * 2, armThick, armThick * 0.45)
				lg.pop()
			end

			drawX(cx - eyeSep, eyeY)
			drawX(cx + eyeSep, eyeY)

			-- Mouth
			local mouthY = cy + radius * 0.32
			local outerR = radius * 0.56
			local innerR = outerR * 0.60
			local lipOffset = radius * 0.07

			local startAngle = -pi * 0.02
			local endAngle =  pi * 1.02

			local stretchX = 1.28

			-- Mouth silhouette
			local function drawMouthStencil()
				lg.push()
				lg.translate(cx, mouthY - lipOffset)
				lg.scale(stretchX, 1.0)
				lg.arc("fill", 0, 0, outerR, startAngle, endAngle)
				lg.pop()
			end

			-- Draw mouth base
			drawMouthStencil()

			-- Vertical bars
			lg.stencil(function()
				drawMouthStencil()
			end, "replace", 1)

			lg.setStencilTest("greater", 0)

			-- Bar configuration
			local barCount   = 5      -- try 4 or 5
			local barWidth   = radius * 0.078
			local barHeight  = radius * 1.15
			local barSpacing = barWidth * 3.4

			-- Center bars around mouth
			local totalWidth = (barCount - 1) * barSpacing
			local startX = cx - totalWidth * 0.5

			lg.setColor(bodyColor)

			for i = 0, barCount - 1 do
				local x = startX + i * barSpacing
				lg.rectangle("fill", x - barWidth * 0.5, mouthY - barHeight * 0.5, barWidth, barHeight, barWidth * 0.4, barWidth * 0.4)
			end

			lg.setStencilTest()

			lg.setCanvas()
			exportCanvas(canvas, string.format("%s/social_avatar_%s_%d", AVATAR_DIR, kind, size))
		end
	end
end

function Export.exportCogSocialAvatar()
	local sizes = {256, 512, 1024, 2048}
	local Constants = require("core.constants")

	local lg  = love.graphics
	local max = math.max

	local ENEMY_RADIUS_REF = Constants.TILE * 0.42
	local OUTLINE_RATIO    = 3 / ENEMY_RADIUS_REF

	for kind, data in pairs(TowersDefs) do
		for _, size in ipairs(sizes) do
			local canvas = lg.newCanvas(size, size, { msaa = 8, format = "rgba8"})
			lg.setCanvas({ canvas, stencil = true })
			lg.clear(0, 0, 0, 0)

			local cx = size * 0.5
			local cy = size * 0.5
			local radius = size * 0.34

			-- Outline + body
			local outlinePad = radius * OUTLINE_RATIO * 1.28
			local outlineColor = data.color
			local bodyColor = { 0.05, 0.05, 0.05, 1 }

			lg.setColor(outlineColor)
			lg.circle("fill", cx, cy, radius + outlinePad)

			lg.setColor(bodyColor)
			lg.circle("fill", cx, cy, radius)

			-- Cog eyes
			local eyeSep = radius * 0.30
			local eyeR   = radius * 0.25
			local hubR = eyeR * 0.44
			local eyeY   = cy - radius * 0.28

			local eyeOffset = radius * 0.06
			local leftY  = eyeY - eyeOffset
			local rightY = eyeY + eyeOffset

			local teeth = 8
			local toothDepth = eyeR * 0.64

			lg.setColor(outlineColor)

			drawCog(
				cx - eyeSep,
				leftY,
				eyeR,
				teeth,
				toothDepth,
				pi * 1.3
			)

			drawCog(
				cx + eyeSep,
				rightY,
				eyeR,
				teeth,
				toothDepth,
				(pi / teeth) * 1.55
			)

			-- Draw inner hubs (body color)
			lg.setColor(bodyColor)

			lg.circle("fill", cx - eyeSep, leftY,  hubR * 1.20)
			lg.circle("fill", cx + eyeSep, rightY, hubR * 0.80)

			lg.setColor(outlineColor)

			-- Mouth
			local mouthY    = cy + radius * 0.32
			local outerR    = radius * 0.56
			local lipOffset = radius * 0.07

			local startAngle = -pi * 0.02
			local endAngle   =  pi * 1.02
			local stretchX  = 1.28

			local function drawMouthStencil()
				lg.push()
				lg.translate(cx, mouthY - lipOffset)
				lg.scale(stretchX, 1.0)
				lg.arc("fill", 0, 0, outerR, startAngle, endAngle)
				lg.pop()
			end

			drawMouthStencil()

			-- Teeth bars (stenciled)
			lg.stencil(drawMouthStencil, "replace", 1)
			lg.setStencilTest("greater", 0)

			local barCount   = 5
			local barWidth   = radius * 0.078
			local barHeight  = radius * 1.15
			local barSpacing = barWidth * 3.4

			local totalWidth = (barCount - 1) * barSpacing
			local startX = cx - totalWidth * 0.5

			lg.setColor(bodyColor)

			for i = 0, barCount - 1 do
				local x = startX + i * barSpacing
				lg.rectangle(
					"fill",
					x - barWidth * 0.5,
					mouthY - barHeight * 0.5,
					barWidth,
					barHeight,
					barWidth * 0.4,
					barWidth * 0.4
				)
			end

			lg.setStencilTest()
			lg.setCanvas()

			exportCanvas(
				canvas,
				string.format("%s/cog_avatar_%s_%d", AVATAR_DIR, kind, size)
			)
		end
	end
end

function Export.exportCogSocialAvatarAnim()
	local sizes = {256}
	--local sizes = {256, 512, 1024}
	local Constants = require("core.constants")

	local lg  = love.graphics
	local max = math.max

	local ENEMY_RADIUS_REF = Constants.TILE * 0.42
	local OUTLINE_RATIO    = 3 / ENEMY_RADIUS_REF

	-- Animation settings
	local FRAMES = 24          -- number of slices
	local TEETH  = 8           -- must match cog teeth
	local LOOP_ANGLE = (2 * pi) / TEETH
	local MESH_OFFSET = LOOP_ANGLE
	-- one tooth step = perfect loop

	for kind, data in pairs(TowersDefs) do
		for _, size in ipairs(sizes) do
			for frame = 0, FRAMES - 1 do
				local t   = frame / FRAMES
				local rot = t * LOOP_ANGLE

				local canvas = lg.newCanvas(size, size, { msaa = 8 })
				lg.setCanvas({ canvas, stencil = true })
				lg.clear(0, 0, 0, 0)

				local cx = size * 0.5
				local cy = size * 0.5
				local radius = size * 0.34

				-- Outline + body
				local outlinePad   = radius * OUTLINE_RATIO * 1.28
				local outlineColor = data.color
				local bodyColor    = { 0.05, 0.05, 0.05, 1 }

				lg.setColor(outlineColor)
				lg.circle("fill", cx, cy, radius + outlinePad)

				lg.setColor(bodyColor)
				lg.circle("fill", cx, cy, radius)

				-- Cog eyes
				local eyeSep = radius * 0.30
				local eyeR   = radius * 0.25
				local hubR   = eyeR * 0.44
				local eyeY   = cy - radius * 0.28

				local eyeOffset = radius * 0.06
				local leftY  = eyeY - eyeOffset
				local rightY = eyeY + eyeOffset

				local toothDepth = eyeR * 0.64

				lg.setColor(outlineColor)

				-- Left cog
				drawCog(
					cx - eyeSep,
					leftY,
					eyeR,
					TEETH,
					toothDepth,
					rot
				)

				-- Right cog (meshed, opposite direction)
				drawCog(
					cx + eyeSep,
					rightY,
					eyeR,
					TEETH,
					toothDepth,
					-rot + MESH_OFFSET
				)

				-- Inner hubs
				lg.setColor(bodyColor)
				lg.circle("fill", cx - eyeSep, leftY,  hubR * 1.20)
				lg.circle("fill", cx + eyeSep, rightY, hubR * 0.80)

				lg.setColor(outlineColor)

				-- Mouth
				local mouthY    = cy + radius * 0.32
				local outerR    = radius * 0.56
				local lipOffset = radius * 0.07

				local startAngle = -pi * 0.02
				local endAngle   =  pi * 1.02
				local stretchX  = 1.28

				local function drawMouthStencil()
					lg.push()
					lg.translate(cx, mouthY - lipOffset)
					lg.scale(stretchX, 1.0)
					lg.arc("fill", 0, 0, outerR, startAngle, endAngle)
					lg.pop()
				end

				drawMouthStencil()

				-- Teeth bars (stenciled)
				lg.stencil(drawMouthStencil, "replace", 1)
				lg.setStencilTest("greater", 0)

				local barCount   = 5
				local barWidth   = radius * 0.078
				local barHeight  = radius * 1.15
				local barSpacing = barWidth * 3.4

				local totalWidth = (barCount - 1) * barSpacing
				local startX = cx - totalWidth * 0.5

				lg.setColor(bodyColor)

				for i = 0, barCount - 1 do
					local x = startX + i * barSpacing
					lg.rectangle(
						"fill",
						x - barWidth * 0.5,
						mouthY - barHeight * 0.5,
						barWidth,
						barHeight,
						barWidth * 0.4,
						barWidth * 0.4
					)
				end

				lg.setStencilTest()
				lg.setCanvas()

				exportCanvas(
					canvas,
					string.format(
						"%s/cog_avatar_%s_%d_f%02d",
						ANIM_DIR,
						kind,
						size,
						frame
					)
				)
			end
		end
	end
end

local _bannerLogoCache = {}

local function getBannerLogoCanvas(name)
	if _bannerLogoCache[name] then
		return _bannerLogoCache[name]
	end

	local b = BANNERS[name]
	assert(b, "Unknown banner type: " .. tostring(name))

	local canvas = lg.newCanvas(b.w, b.h, { msaa = 8 })

	lg.setCanvas(canvas)
	lg.clear(0, 0, 0, 0)

	-- EXACT same call as exportBanners transparent pass
	drawBannerGroup(b.w, b.h)

	lg.setCanvas()

	_bannerLogoCache[name] = canvas
	return canvas
end

function Export.composeHero(opts)
	assert(opts.canvas, "composeHero requires canvas")

	local srcCanvas = opts.canvas
	local w = opts.width
	local h = opts.height

	local out = lg.newCanvas(w, h, { msaa = 8 })
	lg.setCanvas(out)
	lg.clear(0, 0, 0, 0)

	-- 1. Draw hero render
	lg.setColor(1, 1, 1, 1)
	lg.draw(srcCanvas, 0, 0)

	-- 2. Subtle edge darkening (hero-friendly vignette)
	lg.setBlendMode("alpha")

	local steps = 12
	local maxInset = math.min(w, h) * 0.06

	for i = 1, steps do
		local t = i / steps
		local inset = t * maxInset
		local alpha = 0.025 * (1 - t) ^ 2

		lg.setColor(0, 0, 0, alpha)

		lg.rectangle("fill", 0, 0, w, inset)                 -- Top
		lg.rectangle("fill", 0, h - inset, w, inset)        -- Bottom
		lg.rectangle("fill", 0, inset, inset, h - inset*2)  -- Left
		lg.rectangle("fill", w - inset, inset, inset, h - inset*2) -- Right
	end

	-- 3. Draw Hydra TD logo (same logic as banner export)
	local logoCanvas = getBannerLogoCanvas("vertical_capsule")

	local lw = logoCanvas:getWidth()
	local lh = logoCanvas:getHeight()

	-- Center it EXACTLY like a banner
	local x = math.floor((w - lw) * 0.5)
	local y = math.floor((h - lh) * 0.5)

	lg.setColor(1, 1, 1, 1)
	lg.draw(logoCanvas, x, y)

	lg.setCanvas()

	-- 4. Save
	local stamp = os.date("%Y-%m-%d_%H-%M-%S")
	local fileName = ("hero_branded_%s.png"):format(stamp)

	local img = out:newImageData()
	img:encode("png", fileName)

	return out
end

local function drawBannerBackground(w, h)
	lg.push()

	-- Center scaling so grass grows outward from middle
	local scale = 3.0 -- try 2.0 → 4.0

	lg.translate(w * 0.5, h * 0.5)
	lg.scale(scale, scale)
	lg.translate(-w * 0.5, -h * 0.5)

	DrawWorld.drawGrass()

	lg.pop()

	lg.setBlendMode("alpha")

	local steps = 14
	local maxInset = math.min(w, h) * 0.06

	for i = 1, steps do
		local t = i / steps
		local inset = t * maxInset
		local alpha = 0.02 * (1 - t)^2

		lg.setColor(0,0,0,alpha)

		lg.rectangle("fill",0,0,w,inset)
		lg.rectangle("fill",0,h-inset,w,inset)
		lg.rectangle("fill",0,inset,inset,h-inset*2)
		lg.rectangle("fill",w-inset,inset,inset,h-inset*2)
	end
end

function Export.exportPatchHeader()
	local Title = require("ui.title")

	local w = 1920
	local h = 622

	local canvas = lg.newCanvas(w, h, {msaa = 8})

	lg.setCanvas(canvas)
	lg.clear(0,0,0,0)

	--[[ Checkered charcoal background
	local tile = 48
	local dark  = {0.10, 0.105, 0.11, 1}
	local light = {0.12, 0.125, 0.13, 1}

	for y = 0, math.ceil(h / tile) do
		for x = 0, math.ceil(w / tile) do
			local c = ((x + y) % 2 == 0) and light or dark
			lg.setColor(c)
			lg.rectangle("fill", x * tile, y * tile, tile, tile)
		end
	end]]

	drawBannerBackground(w, h)

	-- Hydra TD logo
	Title.invalidateCache()
	Title.drawBannerStyle(w, h, -math.pi / 6, 1, 14, 1.0)

	-- Subtle vignette
	local steps = 12
	local maxInset = math.min(w, h) * 0.06

	for i = 1, steps do
		local t = i / steps
		local inset = t * maxInset
		local alpha = 0.025 * (1 - t)^2

		lg.setColor(0,0,0,alpha)

		lg.rectangle("fill",0,0,w,inset)
		lg.rectangle("fill",0,h-inset,w,inset)
		lg.rectangle("fill",0,inset,inset,h-inset*2)
		lg.rectangle("fill",w-inset,inset,inset,h-inset*2)
	end

	lg.setCanvas()

	exportCanvas(canvas, string.format("%s/update_header_%dx%d", PATCH_DIR, w, h))
end

function Export.exportPatchCover(text, ver)
	local DrawWorld = require("render.draw_world")

	if not ver then
		ver = Constants.VERSION
	end

	local w = 800
	local h = 450

	local canvas = lg.newCanvas(w, h, {msaa = 8})

	lg.setCanvas(canvas)
	lg.clear(0,0,0,0)

	--[[local tile = 92
	local dark  = {0.16, 0.16, 0.16, 1}
	local light = {0.17, 0.17, 0.17, 1}

	local cols = math.ceil(w / tile) + 2
	local rows = math.ceil(h / tile) + 2

	local startX = math.floor((w - cols * tile) * 0.5)
	local startY = math.floor((h - rows * tile) * 0.5)

	for y = 0, rows - 1 do
		for x = 0, cols - 1 do
			local c = ((x + y) % 2 == 0) and light or dark
			lg.setColor(c)

			lg.rectangle(
				"fill",
				startX + x * tile,
				startY + y * tile,
				tile,
				tile
			)
		end
	end]]

	-- Render in-game grass
	drawBannerBackground(w, h)

	-- Subtle vignette
	local steps = 12
	local maxInset = math.min(w, h) * 0.06

	for i = 1, steps do
		local t = i / steps
		local inset = t * maxInset
		local alpha = 0.025 * (1 - t)^2

		lg.setColor(0,0,0,alpha)

		lg.rectangle("fill",0,0,w,inset)
		lg.rectangle("fill",0,h-inset,w,inset)
		lg.rectangle("fill",0,inset,inset,h-inset*2)
		lg.rectangle("fill",w-inset,inset,inset,h-inset*2)
	end

	-- Text
	local font = lg.newFont("assets/fonts/PTSans.ttf", 124)
	lg.setFont(font)

	local maxWidth = w * 0.85

	local _, wrappedLines = font:getWrap(text, maxWidth)

	local lineSpacing = 0.78 -- <--- adjust this
	local lineHeight = font:getHeight() * lineSpacing

	local textHeight = #wrappedLines * lineHeight
	local startY = math.floor((h - textHeight) * 0.5)

	for i, line in ipairs(wrappedLines) do
		drawOutlinedText(
			line,
			w * 0.5,
			startY + (i-1) * lineHeight,
			font,
			{
				align = "center",
				maxWidth = maxWidth,
				outline = 5,
			}
		)
	end

	lg.setCanvas()

	exportCanvas(canvas, string.format("%s/update_%s_%dx%d", PATCH_DIR, ver, w, h))
end

function Export.run()
	ensureDirs()
	--Export.exportTowers()
	--Export.exportEnemies()
	Export.exportBanners()
	--Export.exportAppIcons()
	--Export.exportSocialAvatar()
	--Export.exportCogSocialAvatar()
	--Export.exportCogSocialAvatarAnim()

	--require("ui.glyphs").exportSheet("glyphs.png", {cols = 6})

	-- Patching images
	--Export.exportPatchHeader()
	--Export.exportPatchCover("World Detail Update")

	love.event.quit()
end

return Export
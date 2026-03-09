local Theme = require("core.theme")
local Sound = require("systems.sound")

local pi = math.pi
local min = math.min
local max = math.max
local sin = math.sin
local abs = math.abs

local lg = love.graphics

local Medals = {}

local ranks = {
	easy = 1,
	normal = 2,
	hard = 3,
}

local bronze = Theme.medal.bronze
local silver = Theme.medal.silver
local gold = Theme.medal.gold

local COLORS = {
	{bronze[1], bronze[2], bronze[3]},
	{silver[1], silver[2], silver[3]},
	{gold[1], gold[2], gold[3]},
}

local radius = 9
local gap = 10

local revealBaseCount = 0
local revealTargetCount = 0

local revealDelay = 0.5
local revealDelayRemaining = 0

local queueDelayBase = 0.20
local queueTimer = 0

local queue = {}
local active = {}

function Medals.getCount(difficulty)
	return ranks[difficulty] or 0
end

function Medals.resetAnimations()
	revealBaseCount = 0
	revealTargetCount = 0
	revealDelayRemaining = 0
	queueTimer = 0
	queue = {}
	active = {}
end

function Medals.beginReveal(prev, current)
	Medals.resetAnimations()

	revealBaseCount = prev or 0
	revealTargetCount = current or 0

	if revealTargetCount <= revealBaseCount then
		return
	end

	for i = revealBaseCount + 1, revealTargetCount do
		queue[#queue + 1] = i
	end

	revealDelayRemaining = revealDelay
end

function Medals.update(dt)
	dt = min(dt, 0.05)

	if revealTargetCount <= revealBaseCount then
		return
	end

	if revealDelayRemaining > 0 then
		revealDelayRemaining = revealDelayRemaining - dt

		if revealDelayRemaining > 0 then
			return
		end
	end

	if #queue > 0 then
		queueTimer = queueTimer - dt

		if queueTimer <= 0 then
			local tier = table.remove(queue, 1)

			active[#active + 1] = {
				tier = tier,
				t = 0,
				scale = 0.55,
				yOffset = -22,
				glint = 0,
			}

			Sound.play("medal")

			-- Larger stagger per tier → more anticipation
			queueTimer = queueDelayBase + (tier - 1) * 0.16
		end
	end

	for i = #active, 1, -1 do
		local m = active[i]

		-- Gold settles slightly slower (weight)
		local speed = (m.tier == 3) and 3.2 or 3.6
		m.t = m.t + dt * speed

		-- Gold glint lingers slightly longer
		local glintSpeed = (m.tier == 3) and 1.5 or 1.9
		m.glint = min(1, m.glint + dt * glintSpeed)

		if m.t < 1 then
			local t = m.t

			-- Ease out
			local ease = 1 - (1 - t) ^ 3

			-- Tier based scale power
			local scalePower = 1
			if m.tier == 2 then
				scalePower = 1.05
			elseif m.tier == 3 then
				scalePower = 1.18
			end

			-- Premium overshoot
			local overshoot = sin(t * 3.8) * (1 - t) * 0.55 * scalePower
			m.scale = ease + overshoot

			-- Tier based drop weight
			local dropHeight = 18
			if m.tier == 2 then
				dropHeight = 20
			elseif m.tier == 3 then
				dropHeight = 26
			end

			local drop = -dropHeight * (1 - ease)

			-- Bounce amplitude
			local bouncePower = 6
			if m.tier == 2 then
				bouncePower = 7
			elseif m.tier == 3 then
				bouncePower = 9
			end

			local bounce = sin(t * 4.8) * (1 - t) * bouncePower

			m.yOffset = drop + bounce
		else
			revealBaseCount = max(revealBaseCount, m.tier)

			active[i] = active[#active]
			active[#active] = nil
		end
	end
end

local function drawMedal(x, y, tier, earned, scale, glint, yOffset)
	local c = COLORS[tier]

	scale = scale or 1
	yOffset = yOffset or 0

	lg.push()
	lg.translate(x, y + yOffset)
	lg.scale(scale, scale)
	lg.translate(-x, -(y + yOffset))

	if earned then
		-- Backplate
		lg.setColor(c[1] * 0.35, c[2] * 0.35, c[3] * 0.35)
		lg.circle("fill", x, y + yOffset, radius + 3)

		-- Medal
		lg.setColor(c)
		lg.circle("fill", x, y + yOffset, radius)

		-- Soft highlight
		lg.setColor(1, 1, 1, 0.10)
		lg.circle("fill", x - 2, y - 2 + yOffset, radius * 0.55)

		-- Highlight glint
		if glint and glint < 1 then
			local t = glint
			local flash = sin(t * pi)

			local idle = 0.10
			local peak = 0.50

			local a = flash * peak

			-- settle toward idle
			if t > 0.6 then
				local settle = (t - 0.6) / 0.4
				a = peak + (idle - peak) * settle
			end

			local r = radius * (0.28 + flash * 0.12)

			lg.setColor(1, 1, 1, a)
			lg.circle("fill", x - 3, y - 3 + yOffset, r)
		end
	else
		lg.setColor(0.1, 0.1, 0.1)
		lg.circle("fill", x, y, radius + 3)

		lg.setColor(c[1] * 0.3, c[2] * 0.3, c[3] * 0.3)
		lg.circle("fill", x, y, radius)
	end

	lg.pop()
end

function Medals.draw(x, y, earnedCount, r, g)
	radius = r or radius
	gap = g or gap

	local baseCount = min(earnedCount or 0, 3)

	local startX = x + radius
	local centerY = y + radius
	local step = radius * 2 + gap

	for i = 1, 3 do
		local mx = startX + (i - 1) * step
		local earned = i <= baseCount

		drawMedal(mx, centerY, i, earned, 1)
	end
end

function Medals.drawReveal(x, y, r, g)
	radius = r or radius
	gap = g or gap

	local staticCount = min(revealBaseCount, 3)

	local startX = x + radius
	local centerY = y + radius
	local step = radius * 2 + gap

	for i = 1, 3 do
		local mx = startX + (i - 1) * step
		local earned = i <= staticCount

		drawMedal(mx, centerY, i, earned, 1)
	end

	for i = 1, #active do
		local m = active[i]
		local mx = startX + (m.tier - 1) * step

		drawMedal(mx, centerY, m.tier, true, m.scale, m.glint, m.yOffset)
	end
end

function Medals.getClusterSize(r, g)
	r = r or radius
	g = g or gap

	return 3 * (r * 2) + 2 * g, r * 2
end

return Medals
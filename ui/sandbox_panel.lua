local State = require("core.state")
local Waves = require("systems.waves")
local Enemies = require("world.enemies")
local EnemyDefs = require("world.enemy_defs")
local AffixDefs = require("world.enemy_affix_defs")
local Fonts = require("core.fonts")
local Theme = require("core.theme")
local L = require("core.localization")

local Panel = {}
local rows = {}
local panel = {x = 16, y = 70, w = 286, h = 430}

local enemyKinds = {}
for kind in pairs(EnemyDefs) do enemyKinds[#enemyKinds + 1] = kind end
table.sort(enemyKinds)

-- Lua sequences cannot contain a false first element (# would become zero), so
-- an empty-string sentinel represents the localized "None" choice.
local affixKinds = {""}
for _, id in ipairs(AffixDefs.order or {}) do affixKinds[#affixKinds + 1] = id end

local function indexOf(list, value)
	for i, item in ipairs(list) do if item == value then return i end end
	return 1
end

local function cycle(list, value, direction)
	local i = indexOf(list, value) + direction
	if i < 1 then i = #list elseif i > #list then i = 1 end
	return list[i]
end

local function clamp(value, low, high)
	return math.max(low, math.min(high, value))
end

function Panel.enter()
	State.sandbox = State.sandbox or {
		gold = 1000, lives = 100, speed = 1, enemy = enemyKinds[1] or "grunt",
		count = 10, hpMultiplier = 1, affix = false,
	}
	State.money, State.moneyLerp = State.sandbox.gold, State.sandbox.gold
	State.lives = State.sandbox.lives
	State.speed = State.sandbox.speed
end

local function addRow(id, label, value, y, adjust)
	rows[#rows + 1] = {id = id, label = label, value = value, y = y, adjust = adjust}
end

function Panel.update()
	if not State.sandbox then Panel.enter() end
	local c = State.sandbox
	rows = {}
	local y = panel.y + 72
	addRow("gold", L("sandbox.gold"), tostring(c.gold), y, function(d)
		c.gold = clamp(c.gold + d * 100, 0, 999999); State.money = c.gold; State.moneyLerp = c.gold
	end); y = y + 36
	addRow("lives", L("sandbox.lives"), tostring(c.lives), y, function(d)
		c.lives = clamp(c.lives + d * 10, 0, 9999); State.lives = c.lives
	end); y = y + 36
	addRow("speed", L("sandbox.speed"), string.format("%.1fx", c.speed), y, function(d)
		c.speed = clamp(c.speed + d * 0.5, 0, 8); State.speed = c.speed
	end); y = y + 36
	addRow("enemy", L("sandbox.enemy"), L(EnemyDefs[c.enemy].nameKey), y, function(d)
		c.enemy = cycle(enemyKinds, c.enemy, d)
		if c.affix and not AffixDefs.isEligible(c.affix, EnemyDefs[c.enemy], {}) then c.affix = false end
	end); y = y + 36
	addRow("count", L("sandbox.count"), tostring(c.count), y, function(d) c.count = clamp(c.count + d, 1, 500) end); y = y + 36
	addRow("hp", L("sandbox.hpMultiplier"), string.format("%.2fx", c.hpMultiplier), y, function(d)
		c.hpMultiplier = clamp(c.hpMultiplier + d * 0.25, 0.05, 100)
	end); y = y + 36
	addRow("affix", L("sandbox.affix"), c.affix and L(AffixDefs[c.affix].nameKey) or L("sandbox.none"), y, function(d)
		local candidate = c.affix
		for _ = 1, #affixKinds do
			candidate = cycle(affixKinds, candidate, d)
			if candidate == "" or AffixDefs.isEligible(candidate, EnemyDefs[c.enemy], {}) then break end
		end
		c.affix = candidate ~= "" and candidate or false
	end)
end

local function hit(x, y, rx, ry, rw, rh)
	return x >= rx and x <= rx + rw and y >= ry and y <= ry + rh
end

local function actionRects()
	local y = panel.y + 330
	return {
		{label = L("sandbox.start"), x = panel.x + 12, y = y, w = 124, action = function() Waves.startSandboxWave(State.sandbox) end},
		{label = L("sandbox.stop"), x = panel.x + 146, y = y, w = 124, action = Waves.stopSandboxWave},
		{label = L("sandbox.clear"), x = panel.x + 12, y = y + 38, w = 124, action = function()
			Waves.stopSandboxWave(); Enemies.clear(); State.selectedEnemy = nil
		end},
		{label = L("sandbox.reset"), x = panel.x + 146, y = y + 38, w = 124, action = function() resetGame(); Panel.enter() end},
	}
end

function Panel.mousepressed(x, y, button)
	if button ~= 1 or not hit(x, y, panel.x, panel.y, panel.w, panel.h) then return false end
	for _, row in ipairs(rows) do
		if hit(x, y, panel.x + 194, row.y, 28, 26) then row.adjust(-1); return true end
		if hit(x, y, panel.x + 244, row.y, 28, 26) then row.adjust(1); return true end
	end
	for _, b in ipairs(actionRects()) do if hit(x, y, b.x, b.y, b.w, 30) then b.action(); return true end end
	return true
end

function Panel.wheelmoved(_, dy)
	local mx, my = love.mouse.getPosition()
	if not hit(mx, my, panel.x, panel.y, panel.w, panel.h) then return false end
	for _, row in ipairs(rows) do if hit(mx, my, panel.x + 8, row.y, panel.w - 16, 28) then row.adjust(dy > 0 and 1 or -1); break end end
	return true
end

function Panel.draw()
	local lg = love.graphics
	lg.setColor(Theme.outline.color); lg.rectangle("fill", panel.x - 2, panel.y - 2, panel.w + 4, panel.h + 4, 8)
	lg.setColor(Theme.ui.backdrop); lg.rectangle("fill", panel.x, panel.y, panel.w, panel.h, 7)
	Fonts.set("menu"); lg.setColor(Theme.ui.text); lg.printf(L("sandbox.title"), panel.x, panel.y + 12, panel.w, "center")
	Fonts.set("ui"); lg.setColor(0.75, 0.75, 0.75); lg.printf(L("sandbox.protected"), panel.x + 8, panel.y + 43, panel.w - 16, "center")
	for _, row in ipairs(rows) do
		lg.setColor(Theme.ui.text); lg.print(row.label, panel.x + 12, row.y + 5); lg.printf(row.value, panel.x + 120, row.y + 5, 70, "right")
		for _, control in ipairs({{x = panel.x + 194, text = "−"}, {x = panel.x + 244, text = "+"}}) do
			lg.setColor(Theme.ui.button); lg.rectangle("fill", control.x, row.y, 28, 26, 4); lg.setColor(Theme.ui.text); lg.printf(control.text, control.x, row.y + 4, 28, "center")
		end
	end
	for _, b in ipairs(actionRects()) do
		lg.setColor(Theme.ui.button); lg.rectangle("fill", b.x, b.y, b.w, 30, 4); lg.setColor(Theme.ui.text); lg.printf(b.label, b.x + 3, b.y + 7, b.w - 6, "center")
	end
end

return Panel

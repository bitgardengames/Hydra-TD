local Constants = require("core.constants")
local Fonts = require("core.fonts")
local L = require("core.localization")
local Save = require("core.save")
local Text = require("ui.text")
local Theme = require("core.theme")

local Codex = {}
local lg = love.graphics

local function line(text, x, y, w, color)
	lg.setColor(color or Theme.ui.text)
	Text.printfShadow(text, x, y, w, "left")
end

local function behaviorSummary(def)
	local tags = {}
	for _, behavior in ipairs(def.behaviors or {}) do
		local id = behavior.id or ""
		if id:find("slow") then tags.slow = true end
		if id:find("poison") then tags.poison = true end
		if id:find("chain") then tags.chain = true end
		if id:find("aoe") then tags.aoe = true end
		if id:find("tick") then tags.tick = true end
	end
	local out = {}
	for _, id in ipairs({"slow", "poison", "chain", "aoe", "tick"}) do
		if tags[id] then out[#out + 1] = L("towerCodex.counter." .. id) end
	end
	return #out > 0 and table.concat(out, " • ") or L("towerCodex.counter.direct")
end

function Codex.drawBaseStats(def, x, y, w)
	line(L("towerCodex.baseStats", def.damage, def.fireRate, def.range / Constants.TILE, def.cost), x, y, w)
end

function Codex.drawUpgradeDeltas(def, x, y, w)
	local u = def.upgrade or {}
	line(L("towerCodex.upgradeDeltas", (u.dmgMult or 1) * 100 - 100, (u.rangeAdd or 0) / Constants.TILE), x, y, w, Theme.ui.good)
end

function Codex.drawTargetingRules(def, x, y, w)
	line(L("towerCodex.targeting", def.canRotate == false and L("towerCodex.fixed") or L("towerCodex.progressTarget")), x, y, w)
end

function Codex.drawDamageInfo(def, x, y, w)
	line(L("towerCodex.damageInfo", behaviorSummary(def)), x, y, w, Theme.ui.warn)
end

function Codex.drawEntry(kind, def, x, y, w)
	local h = ((Save.data.meta.towerHistory or {})[kind] or {})
	Fonts.set("ui"); lg.setColor(def.color or Theme.ui.text); Text.printShadow(L(def.nameKey), x, y)
	Fonts.set("tooltip")
	line(L("towerCodex.history", h.placements or 0, h.upgrades or 0, h.kills or 0, h.damage or 0, h.bestRunDamage or 0), x, y + 25, w)
	Codex.drawBaseStats(def, x, y + 48, w)
	Codex.drawUpgradeDeltas(def, x, y + 68, w)
	Codex.drawTargetingRules(def, x, y + 88, w)
	Codex.drawDamageInfo(def, x, y + 108, w)
	line(L("towerCodex.nativeRole", L(def.descKey)), x, y + 132, w, Theme.ui.selected)
end

Codex.ENTRY_HEIGHT = 220
return Codex

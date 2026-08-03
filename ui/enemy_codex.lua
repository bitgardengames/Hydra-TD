local Affixes = require("world.enemy_affix_defs")
local Fonts = require("core.fonts")
local L = require("core.localization")
local Save = require("core.save")
local Text = require("ui.text")

local Codex = {}

-- Shared by codex screens: undiscovered elite mechanics stay silhouetted until
-- the player actually encounters one, just like enemy archetype discovery.
function Codex.drawAffixes(x, y, width)
	Fonts.set("tooltip")
	local known = Save.data and Save.data.meta and Save.data.meta.encounteredAffixes or {}
	for i, id in ipairs(Affixes.order) do
		local affix = Affixes[id]
		love.graphics.setColor(known[id] and affix.color or {0.45, 0.45, 0.48})
		local text = known[id]
			and (affix.icon .. " " .. L(affix.nameKey) .. " — " .. L(affix.descriptionKey))
			or L("enemyAffix.unknown")
		Text.printfShadow(text, x, y + (i - 1) * 24, width, "left")
	end
	return #Affixes.order * 24
end

return Codex

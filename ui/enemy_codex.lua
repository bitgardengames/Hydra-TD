local Affixes = require("world.enemy_affix_defs")
local Fonts = require("core.fonts")
local L = require("core.localization")
local Save = require("core.save")
local Text = require("ui.text")
local Traits = require("world.enemy_traits")

local Codex = {}

-- Enemy entries can use this alongside their authored description. Keeping the
-- same localized sentences as the wave preview makes counter advice consistent.
function Codex.drawCounters(def, x, y, width)
	local rows = 0
	for _, id in ipairs((def and def.traits) or {}) do
		if Traits.get(id) then
			love.graphics.setColor(1, 0.78, 0.3)
			Text.printfShadow(L("enemyTrait." .. id .. ".tag") .. " — "
				.. L("enemyTrait." .. id .. ".counter"), x, y + rows * 32, width, "left")
			rows = rows + 1
		end
	end
	return rows * 32
end

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

local AbilityDefs = require("systems.ability_defs")
local L = require("core.localization")
local Tooltip = require("ui.tooltip")

local AbilityTooltip = {}
local cachedTooltips = {}

function AbilityTooltip.show(abilityId)
	local def = AbilityDefs[abilityId]
	if not def then return end

	local title = L(def.nameKey)
	local description = L(def.descKey)
	local tooltip = cachedTooltips[abilityId]

	-- Rebuild when localization changes, but keep the rows stable during normal
	-- hovering so Tooltip does not recalculate its layout every frame.
	if not tooltip or tooltip.title ~= title or tooltip.rows[1].text ~= description then
		local rows = {
			{kind = "text", text = description, padAfter = 4},
			{label = L("ability.chargeLabel"), value = L("ability.chargeValue", def.chargeRequired)},
		}
		if def.effect and def.effect.duration then
			rows[#rows + 1] = {label = L("ability.durationLabel"), value = string.format("%gs", def.effect.duration)}
		end
		tooltip = {
			title = title,
			rows = rows,
		}
		cachedTooltips[abilityId] = tooltip
	end

	Tooltip.show(tooltip)
end

return AbilityTooltip

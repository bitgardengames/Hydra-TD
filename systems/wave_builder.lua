local Builder = {}

-- Wave templates define structure, not difficulty
local Templates = {
	standard = {
		enemy = "grunt",
		baseCount = 12 * 3,
		spacing = 0.65, -- 0.65
	},

	fast = {
		enemy = "runner",
		baseCount = 16 * 3,
		spacing = 0.65, -- 0.45
	},

	tanky = {
		enemy = "tank",
		baseCount = 10 * 3,
		spacing = 1.05, -- 1.05
	},
}

-- Simple deterministic template selection
local TemplateSelectionRules = {
	{ mod = 6, template = Templates.standard },
	{ mod = 7, template = Templates.fast },
	{ mod = 11, template = Templates.tanky },
}

local function pickTemplate(waveIndex)
	for _, rule in ipairs(TemplateSelectionRules) do
		if waveIndex % rule.mod == 0 then
			return rule.template
		end
	end

	return Templates.standard
end

function Builder.build(waveIndex)
	-- Boss every 10th wave, no exceptions
	if waveIndex % 10 == 0 then
		return {
			boss = true,
			enemy = "boss",
			count = 1,
			spacing = 0,
		}
	end

	local template = pickTemplate(waveIndex)

	return {
		boss = false,
		enemy = template.enemy,
		count = template.baseCount,
		spacing = template.spacing,
	}
end

return Builder

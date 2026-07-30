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

local unlocks = {
	{ wave = 4, kind = "bulwark", every = 7 },
	{ wave = 6, kind = "regenerator", every = 6 },
	{ wave = 8, kind = "shieldbearer", every = 7 },
	{ wave = 9, kind = "warcaller", every = 10 },
}

local function buildComposition(waveIndex, baseKind, count)
	local composition = {}
	for i = 1, count do
		local kind = baseKind
		-- Offset each cadence so mixed waves read as squads rather than a solid wall
		-- of specialists. Later unlocks take precedence when cadences overlap.
		for j = 1, #unlocks do
			local u = unlocks[j]
			if waveIndex >= u.wave and (i + j * 2) % u.every == 0 then kind = u.kind end
		end
		composition[i] = kind
	end
	return composition
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

	local count = template.baseCount
	return {
		boss = false,
		enemy = template.enemy,
		count = count,
		spacing = template.spacing,
		composition = buildComposition(waveIndex, template.enemy, count),
	}
end

return Builder

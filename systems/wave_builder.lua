local Builder = {}

-- Wave templates define structure, not difficulty
local Templates = {
	standard = {
		enemy = "grunt",
		baseCount = 24,
		spacing = 0.6, -- 0.65
	},

	fast = {
		enemy = "runner",
		baseCount = 32,
		spacing = 0.6, -- 0.45
	},

	tanky = {
		enemy = "tank",
		baseCount = 20,
		spacing = 1.0, -- 1.05
	},
}

-- Simple deterministic template selection
local function pickTemplate(waveIndex)
	if waveIndex % 6 == 0 then
		return Templates.standard
	end

	if waveIndex % 7 == 0 then
		return Templates.fast
	end

	if waveIndex % 11 == 0 then
		return Templates.tanky
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
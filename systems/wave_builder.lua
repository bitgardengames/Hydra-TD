local Builder = {}
local Difficulty = require("systems.difficulty")

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

local supportArchetypes = {"support_haste", "support_amp", "support_displacer"}

local function supportCountFor(waveIndex)
	if waveIndex < 4 then
		return 0
	end

	local tier = Difficulty.key()
	local isHardTier = tier == "hard" or tier == "elite"

	if waveIndex < 12 then
		return 1
	end

	if isHardTier then
		return (waveIndex >= 24) and 3 or 2
	end

	return 1
end

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
	local supportCount = supportCountFor(waveIndex)
	local supportKind = supportArchetypes[((waveIndex - 1) % #supportArchetypes) + 1]

	return {
		boss = false,
		enemy = template.enemy,
		count = template.baseCount,
		spacing = template.spacing,
		support = (supportCount > 0) and {
			kind = supportKind,
			count = supportCount,
			spawnEarly = true,
		} or nil,
	}
end

return Builder

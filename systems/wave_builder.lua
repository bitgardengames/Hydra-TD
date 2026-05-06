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

local function buildPattern(waveIndex, baseGap)
	if waveIndex <= 3 then
		return {
			spawnPattern = "distributed",
			burstCount = 1,
			burstGap = baseGap,
			laneWeights = {1.0, 0.0, 0.0},
		}
	end

	local mod = waveIndex % 8

	if mod == 1 or mod == 5 then
		return {
			spawnPattern = "distributed",
			burstCount = 1,
			burstGap = baseGap,
			laneWeights = {0.45, 0.35, 0.2},
		}
	end

	if mod == 2 then
		return {
			spawnPattern = "clustered",
			burstCount = 2,
			burstGap = baseGap * 0.35,
			laneWeights = {0.65, 0.25, 0.1},
		}
	end

	if mod == 3 or mod == 7 then
		return {
			spawnPattern = "lane_split",
			burstCount = 1,
			burstGap = baseGap * 0.8,
			laneWeights = {0.34, 0.33, 0.33},
		}
	end

	if mod == 4 then
		return {
			spawnPattern = "burst",
			burstCount = math.min(4, 1 + math.floor(waveIndex / 8)),
			burstGap = math.max(0.08, baseGap * 0.2),
			laneWeights = {0.55, 0.3, 0.15},
		}
	end

	return {
		spawnPattern = "clustered",
		burstCount = 2,
		burstGap = baseGap * 0.5,
		laneWeights = {0.4, 0.4, 0.2},
	}
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
	local pattern = buildPattern(waveIndex, template.spacing)

	return {
		boss = false,
		enemy = template.enemy,
		count = template.baseCount,
		spacing = template.spacing,
		spawnPattern = pattern.spawnPattern,
		burstCount = pattern.burstCount,
		burstGap = pattern.burstGap,
		laneWeights = pattern.laneWeights,
	}
end

return Builder

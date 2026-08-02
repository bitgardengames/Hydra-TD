local DifficultyCurve = require("systems.difficulty_curve")
local CampaignWaveDefs = require("systems.campaign_wave_defs")

local Builder = {}

-- Templates describe the campaign baseline. Endless tiers add bodies and mixed
-- pressure, but retain a hard wave budget so progression cannot grow forever.
local Templates = {
	standard = { enemy = "grunt", baseCount = 36, spacing = 0.65 },
	fast = { enemy = "runner", baseCount = 48, spacing = 0.65 },
	tanky = { enemy = "tank", baseCount = 30, spacing = 1.05 },
}

local TemplateSelectionRules = {
	{ mod = 6, template = Templates.standard },
	{ mod = 7, template = Templates.fast },
	{ mod = 11, template = Templates.tanky },
}

local function pickTemplate(waveIndex)
	for _, rule in ipairs(TemplateSelectionRules) do
		if waveIndex % rule.mod == 0 then return rule.template end
	end
	return Templates.standard
end

local unlocks = {
	{ wave = 4, kind = "bulwark", every = 7 },
	{ wave = 6, kind = "regenerator", every = 6 },
	{ wave = 8, kind = "shieldbearer", every = 7 },
	{ wave = 9, kind = "warcaller", every = 10 },
}

Builder.endlessTierWaves = 5
Builder.maxWaveEnemies = 120
Builder.minSpawnSpacing = 0.28
Builder.spawnSpacingMultiplier = 1.1

function Builder.adjustSpawnSpacing(spacing)
	return (spacing or 0) * Builder.spawnSpacingMultiplier
end

function Builder.getIntensityTier(waveIndex)
	local endlessWave = math.max(0, (tonumber(waveIndex) or 0) - DifficultyCurve.campaignEnd)
	if endlessWave == 0 then return 0 end
	return math.floor((endlessWave - 1) / Builder.endlessTierWaves) + 1
end

local function buildComposition(waveIndex, baseKind, count, tier)
	local composition = {}
	local pressureKinds = {"runner", "grunt", "tank"}
	for i = 1, count do
		local kind = baseKind
		for j = 1, #unlocks do
			local u = unlocks[j]
			if waveIndex >= u.wave and (i + j * 2) % u.every == 0 then kind = u.kind end
		end
		-- Each endless tier inserts a predictable flank group. Rotating the kind
		-- creates simultaneous mixed pressure without making every unit elite.
		if tier > 0 then
			local groupSize = math.min(3 + tier, 9)
			local groupCycle = math.max(10, 18 - math.min(tier, 8))
			if (i - 1) % groupCycle < groupSize then
				kind = pressureKinds[((tier + math.floor((i - 1) / groupCycle)) % #pressureKinds) + 1]
			end
		end
		composition[i] = kind
	end
	return composition
end

function Builder.build(waveIndex)
	waveIndex = math.max(1, math.floor(tonumber(waveIndex) or 1))
	local tier = Builder.getIntensityTier(waveIndex)
	local campaignGroups = CampaignWaveDefs[waveIndex]
	if campaignGroups then
		local count = 0
		local composition = {}
		local groups = {}
		for _, group in ipairs(campaignGroups) do
			count = count + group.count
			for _ = 1, group.count do composition[#composition + 1] = group.kind end
			groups[#groups + 1] = {
				kind = group.kind,
				count = group.count,
				spacing = Builder.adjustSpawnSpacing(group.spacing),
				delay = group.delay,
				role = group.role,
			}
		end
		return {
			boss = campaignGroups[1].kind == "boss",
			enemy = campaignGroups[1].kind,
			count = count,
			spacing = groups[1].spacing,
			groups = groups,
			composition = composition,
			intensityTier = 0,
		}
	end

	-- Everything below this point is the separate, deterministic endless mode.
	if waveIndex % 10 == 0 then
		return { boss = true, enemy = "boss", count = 1, spacing = 0, intensityTier = tier }
	end

	local template = pickTemplate(waveIndex)
	-- Six more enemies per tier is legible count growth; the cap is the ultimate
	-- simulation budget. Spacing tightens gently and never becomes a frame burst.
	local count = math.min(Builder.maxWaveEnemies, template.baseCount + tier * 6)
	local spacing = Builder.adjustSpawnSpacing(
		math.max(Builder.minSpawnSpacing, template.spacing * (0.94 ^ tier))
	)
	return {
		boss = false,
		enemy = template.enemy,
		count = count,
		spacing = spacing,
		composition = buildComposition(waveIndex, template.enemy, count, tier),
		intensityTier = tier,
	}
end

return Builder

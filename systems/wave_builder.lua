local DifficultyCurve = require("systems.difficulty_curve")
local CampaignWaveDefs = require("systems.campaign_wave_defs")

local Builder = {}

-- Endless is the Milestone Circuit: four waves under a named, rotating pressure
-- rule followed by a boss milestone. Rules only remix the shared campaign roster.
local Templates = {
	standard = { enemy = "grunt", baseCount = 36, spacing = 0.7 },
	fast = { enemy = "runner", baseCount = 48, spacing = 0.7 },
	tanky = { enemy = "tank", baseCount = 30, spacing = 1.1 },
}

local EndlessRules = {
	{
		id = "rapid_deployment", template = Templates.fast, countMultiplier = 1,
		spacingMultiplier = 0.82, nameKey = "endless.rules.rapidDeployment.name",
		descriptionKey = "endless.rules.rapidDeployment.description",
	},
	{
		id = "heavy_column", template = Templates.tanky, countMultiplier = 0.9,
		spacingMultiplier = 1, nameKey = "endless.rules.heavyColumn.name",
		descriptionKey = "endless.rules.heavyColumn.description",
	},
	{
		id = "mixed_front", template = Templates.standard, countMultiplier = 1.15,
		spacingMultiplier = 0.94, nameKey = "endless.rules.mixedFront.name",
		descriptionKey = "endless.rules.mixedFront.description",
	},
}

Builder.milestoneInterval = 5

function Builder.getEndlessRules(waveIndex)
	waveIndex = math.max(DifficultyCurve.campaignEnd + 1, math.floor(tonumber(waveIndex) or 1))
	local endlessWave = waveIndex - DifficultyCurve.campaignEnd
	local milestoneNumber = math.ceil(endlessWave / Builder.milestoneInterval)
	local isMilestone = endlessWave % Builder.milestoneInterval == 0
	local rule = EndlessRules[((milestoneNumber - 1) % #EndlessRules) + 1]
	return {
		id = isMilestone and "boss_milestone" or rule.id,
		nameKey = isMilestone and "endless.rules.bossMilestone.name" or rule.nameKey,
		descriptionKey = isMilestone and "endless.rules.bossMilestone.description" or rule.descriptionKey,
		milestone = isMilestone,
		milestoneNumber = milestoneNumber,
		endlessWave = endlessWave,
		nextMilestoneWave = DifficultyCurve.campaignEnd + milestoneNumber * Builder.milestoneInterval,
		countMultiplier = rule.countMultiplier,
		spacingMultiplier = rule.spacingMultiplier,
		template = rule.template,
	}
end

local unlocks = {
	{ wave = 4, kind = "bulwark", every = 7 },
	{ wave = 6, kind = "regenerator", every = 6 },
	{ wave = 9, kind = "warcaller", every = 10 },
	{ wave = 11, kind = "summoner", every = 13 },
}

Builder.endlessTierWaves = 5
Builder.maxWaveEnemies = 120
-- Never compress an endless wave into a near-continuous stack. This floor is
-- shared by every procedural template as tiers tighten their cadence.
Builder.minSpawnSpacing = 0.5

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
		-- creates simultaneous mixed pressure without changing enemy stats.
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

function Builder.build(waveIndex, mapDef, isEndless)
	waveIndex = math.max(1, math.floor(tonumber(waveIndex) or 1))
	local tier = Builder.getIntensityTier(waveIndex)
	local campaignGroups = not isEndless and CampaignWaveDefs.get(mapDef, waveIndex)
	if campaignGroups then
		local count = 0
		local composition = {}
		for _, group in ipairs(campaignGroups) do
			count = count + group.count
			for _ = 1, group.count do composition[#composition + 1] = group.kind end
		end
		return {
			boss = campaignGroups[1].kind == "boss",
			enemy = campaignGroups[1].kind,
			count = count,
			spacing = campaignGroups[1].spacing,
			groups = campaignGroups,
			composition = composition,
			intensityTier = 0,
			bossArchetype = campaignGroups.bossArchetype,
		}
	end

	-- Everything below this point is the separate, deterministic endless mode.
	-- A missing campaign definition must not silently fall through to procedural content.
	if not isEndless then return nil end

	local rules = Builder.getEndlessRules(waveIndex)
	if rules.milestone then
		return { boss = true, enemy = "boss", count = 1, spacing = 0, intensityTier = tier,
			endlessRules = rules }
	end

	local template = rules.template
	-- Six more enemies per tier is legible count growth; the cap is the ultimate
	-- simulation budget. Spacing tightens gently and never becomes a frame burst.
	local count = math.min(Builder.maxWaveEnemies,
		math.floor((template.baseCount + tier * 6) * rules.countMultiplier + 0.5))
	local spacing = math.max(Builder.minSpawnSpacing,
		template.spacing * rules.spacingMultiplier * (0.94 ^ tier))
	return {
		boss = false,
		enemy = template.enemy,
		count = count,
		spacing = spacing,
		composition = buildComposition(waveIndex, template.enemy, count, tier),
		intensityTier = tier,
		endlessRules = rules,
	}
end

return Builder

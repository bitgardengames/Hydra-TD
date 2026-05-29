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

	runnerFlankAfterGruntOpener = {
		groups = {
			{ enemy = "grunt", baseCount = 24, spacing = 0.45 },
			{ enemy = "runner", baseCount = 8, spacing = 0.8, delay = 3.0 },
		},
	},

	tankScreenWithRunnerTrickle = {
		groups = {
			{ enemy = "tank", baseCount = 10, spacing = 0.95 },
			{ enemy = "runner", baseCount = 18, spacing = 0.55, delay = 1.4 },
		},
	},

	largeSwarmWithLowSpacing = {
		groups = {
			{ enemy = "grunt", baseCount = 64, spacing = 0.32 },
		},
	},

	eliteSmallPack = {
		groups = {
			{ enemy = "tank", baseCount = 14, spacing = 0.72 },
		},
	},
}

-- Simple deterministic template selection
local TemplateSelectionRules = {
	{ mod = 17, template = Templates.eliteSmallPack },
	{ mod = 13, template = Templates.largeSwarmWithLowSpacing },
	{ mod = 11, template = Templates.tankScreenWithRunnerTrickle },
	{ mod = 7, template = Templates.runnerFlankAfterGruntOpener },
	{ mod = 6, template = Templates.standard },
	{ mod = 5, template = Templates.tanky },
	{ mod = 4, template = Templates.fast },
}

local function pickTemplate(waveIndex)
	for _, rule in ipairs(TemplateSelectionRules) do
		if waveIndex % rule.mod == 0 then
			return rule.template
		end
	end

	return Templates.standard
end

local function getEndlessWaveIndex(waveIndex)
	return math.max(0, waveIndex - 20)
end

local function getEndlessCountMultiplier(endlessWaveIndex)
	if endlessWaveIndex <= 0 then
		return 1.0
	end

	return 1.0 + (endlessWaveIndex * 0.08) + (math.floor(endlessWaveIndex / 5) * 0.12)
end

local function getEndlessSpacingMultiplier(endlessWaveIndex)
	if endlessWaveIndex <= 0 then
		return 1.0
	end

	return math.max(0.55, 1.0 - (endlessWaveIndex * 0.012))
end

local function scaleCount(baseCount, countMultiplier)
	return math.max(1, math.floor((baseCount * countMultiplier) + 0.5))
end

local function cloneGroup(group, endlessWaveIndex)
	local countMultiplier = getEndlessCountMultiplier(endlessWaveIndex)
	local spacingMultiplier = getEndlessSpacingMultiplier(endlessWaveIndex)
	local delayMultiplier = math.max(0.65, 1.0 - (endlessWaveIndex * 0.01))

	return {
		enemy = group.enemy,
		count = scaleCount(group.baseCount or group.count or 1, countMultiplier),
		spacing = (group.spacing or 1.0) * spacingMultiplier,
		delay = group.delay and (group.delay * delayMultiplier) or nil,
	}
end

local function addEndlessDensityGroups(groups, endlessWaveIndex)
	if endlessWaveIndex <= 0 then
		return
	end

	local extraGroupCount = math.min(3, math.floor((endlessWaveIndex + 5) / 6))
	local countMultiplier = getEndlessCountMultiplier(endlessWaveIndex)
	local spacingMultiplier = getEndlessSpacingMultiplier(endlessWaveIndex)
	local densityKinds = { "grunt", "runner", "tank" }

	for i = 1, extraGroupCount do
		local kind = densityKinds[((endlessWaveIndex + i - 1) % #densityKinds) + 1]
		local baseCount = kind == "tank" and 5 or (kind == "runner" and 10 or 16)
		groups[#groups + 1] = {
			enemy = kind,
			count = scaleCount(baseCount, countMultiplier * (0.75 + (i * 0.15))),
			spacing = math.max(0.22, (kind == "tank" and 0.9 or 0.48) * spacingMultiplier),
			delay = math.max(0.35, 1.2 - (i * 0.2)),
		}
	end
end

local function buildGroups(template, endlessWaveIndex)
	local groups = {}

	if template.groups then
		for _, group in ipairs(template.groups) do
			groups[#groups + 1] = cloneGroup(group, endlessWaveIndex)
		end
	else
		groups[#groups + 1] = cloneGroup({
			enemy = template.enemy,
			baseCount = template.baseCount,
			spacing = template.spacing,
		}, endlessWaveIndex)
	end

	addEndlessDensityGroups(groups, endlessWaveIndex)

	return groups
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
	local endlessWaveIndex = getEndlessWaveIndex(waveIndex)

	if template.groups or endlessWaveIndex > 0 then
		return {
			boss = false,
			groups = buildGroups(template, endlessWaveIndex),
		}
	end

	return {
		boss = false,
		enemy = template.enemy,
		count = template.baseCount,
		spacing = template.spacing,
	}
end

return Builder

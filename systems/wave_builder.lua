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

	regeneratorPair = {
		groups = {
			{ enemy = "grunt", baseCount = 18, spacing = 0.44 },
			{ enemy = "regenerator", baseCount = 3, spacing = 1.1, delay = 1.8 },
		},
	},

	shieldedColumn = {
		groups = {
			{ enemy = "shielder", baseCount = 3, spacing = 1.25 },
			{ enemy = "tank", baseCount = 8, spacing = 0.82, delay = 1.1 },
		},
	},

	mixedSpecialists = {
		groups = {
			{ enemy = "runner", baseCount = 16, spacing = 0.45 },
			{ enemy = "regenerator", baseCount = 2, spacing = 1.35, delay = 1.2 },
			{ enemy = "shielder", baseCount = 2, spacing = 1.35, delay = 2.4 },
		},
	},

	stitcherEscort = {
		groups = {
			{ enemy = "grunt", baseCount = 16, spacing = 0.42 },
			{ enemy = "stitcher", baseCount = 3, spacing = 1.25, delay = 1.5 },
		},
	},

	aegisRush = {
		groups = {
			{ enemy = "aegis_runner", baseCount = 9, spacing = 0.58 },
			{ enemy = "runner", baseCount = 12, spacing = 0.42, delay = 1.6 },
		},
	},

	bastionLine = {
		groups = {
			{ enemy = "bastion", baseCount = 3, spacing = 1.45 },
			{ enemy = "shielder", baseCount = 4, spacing = 1.05, delay = 1.0 },
		},
	},

	bulwarkMenders = {
		groups = {
			{ enemy = "bulwark_mender", baseCount = 2, spacing = 1.5 },
			{ enemy = "tank", baseCount = 6, spacing = 0.85, delay = 1.4 },
			{ enemy = "runner", baseCount = 10, spacing = 0.48, delay = 2.6 },
		},
	},
}

-- Endless event templates alter post-campaign wave shapes without requiring map-specific data.
local EndlessEventTemplates = {
	stampede = {
		nameKey = "waveEvents.stampede",
		groups = {
			{ enemy = "runner", baseCount = 44, spacing = 0.26 },
		},
	},

	siegeLine = {
		nameKey = "waveEvents.siegeLine",
		groups = {
			{ enemy = "tank", baseCount = 22, spacing = 1.18 },
		},
	},

	mixedColumn = {
		nameKey = "waveEvents.mixedColumn",
		groups = {
			{ enemy = "tank", baseCount = 13, spacing = 0.86 },
			{ enemy = "runner", baseCount = 30, spacing = 0.34, delay = 4.6 },
		},
	},

	bossEscort = {
		nameKey = "waveEvents.bossEscort",
		groups = {
			{ enemy = "grunt", baseCount = 18, spacing = 0.42, delay = 1.4 },
			{ enemy = "runner", baseCount = 12, spacing = 0.45, delay = 3.2 },
		},
	},
}

local EndlessEventOrder = {
	EndlessEventTemplates.stampede,
	EndlessEventTemplates.siegeLine,
	EndlessEventTemplates.mixedColumn,
}

-- Simple deterministic template selection
local TemplateSelectionRules = {
	{ mod = 22, template = Templates.bulwarkMenders },
	{ mod = 19, template = Templates.bastionLine },
	{ mod = 15, template = Templates.aegisRush },
	{ mod = 14, template = Templates.stitcherEscort },
	{ mod = 18, template = Templates.mixedSpecialists },
	{ mod = 16, template = Templates.shieldedColumn },
	{ mod = 9, template = Templates.regeneratorPair },
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

local function pickEndlessEvent(waveIndex)
	local endlessWaveIndex = getEndlessWaveIndex(waveIndex)

	if endlessWaveIndex <= 0 or endlessWaveIndex % 5 ~= 0 then
		return nil
	end

	if waveIndex % 10 == 0 then
		return "bossEscort", EndlessEventTemplates.bossEscort
	end

	local eventIndex = math.floor(endlessWaveIndex / 5)
	local template = EndlessEventOrder[((eventIndex - 1) % #EndlessEventOrder) + 1]

	if template == EndlessEventTemplates.stampede then
		return "stampede", template
	elseif template == EndlessEventTemplates.siegeLine then
		return "siegeLine", template
	end

	return "mixedColumn", template
end

local function withEvent(wave, eventKey, eventTemplate)
	if not eventTemplate then
		return wave
	end

	wave.eventKey = eventKey
	wave.eventNameKey = eventTemplate.nameKey

	return wave
end

function Builder.getEvent(waveIndex)
	local eventKey, eventTemplate = pickEndlessEvent(waveIndex)

	if not eventTemplate then
		return nil
	end

	return {
		key = eventKey,
		nameKey = eventTemplate.nameKey,
	}
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
	local densityKinds = {
		"grunt",
		"runner",
		"tank",
		"regenerator",
		"shielder",
		"stitcher",
		"aegis_runner",
		"bastion",
		"bulwark_mender",
	}

	for i = 1, extraGroupCount do
		local kind = densityKinds[((endlessWaveIndex + i - 1) % #densityKinds) + 1]
		local baseCount = kind == "tank" and 5
			or (kind == "runner" and 10)
			or (kind == "regenerator" and 3)
			or (kind == "shielder" and 3)
			or (kind == "stitcher" and 2)
			or (kind == "aegis_runner" and 7)
			or (kind == "bastion" and 2)
			or (kind == "bulwark_mender" and 2)
			or 16
		local specialistSpacing = kind == "regenerator"
			or kind == "shielder"
			or kind == "stitcher"
			or kind == "bastion"
			or kind == "bulwark_mender"
		groups[#groups + 1] = {
			enemy = kind,
			count = scaleCount(baseCount, countMultiplier * (0.75 + (i * 0.15))),
			spacing = math.max(
				0.22,
				(kind == "tank" and 0.9 or (specialistSpacing and 1.05 or 0.48)) * spacingMultiplier
			),
			delay = math.max(0.35, 1.2 - (i * 0.2)),
		}
	end
end

local function buildGroups(template, endlessWaveIndex, includeDensity)
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

	if includeDensity ~= false then
		addEndlessDensityGroups(groups, endlessWaveIndex)
	end

	return groups
end

function Builder.build(waveIndex)
	local endlessWaveIndex = getEndlessWaveIndex(waveIndex)
	local eventKey, eventTemplate = pickEndlessEvent(waveIndex)

	-- Boss every 10th wave, no exceptions
	if waveIndex % 10 == 0 then
		local wave = {
			boss = true,
			enemy = "boss",
			count = 1,
			spacing = 0,
		}

		if eventTemplate and eventTemplate.groups then
			wave.groups = buildGroups(eventTemplate, endlessWaveIndex, false)
		end

		return withEvent(wave, eventKey, eventTemplate)
	end

	local template = eventTemplate or pickTemplate(waveIndex)
	local isEvent = eventTemplate ~= nil

	if template.groups or endlessWaveIndex > 0 then
		return withEvent({
			boss = false,
			groups = buildGroups(template, endlessWaveIndex, not isEvent),
		}, eventKey, eventTemplate)
	end

	return {
		boss = false,
		enemy = template.enemy,
		count = template.baseCount,
		spacing = template.spacing,
	}
end

return Builder

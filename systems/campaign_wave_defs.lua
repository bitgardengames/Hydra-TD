-- The hand-authored campaign is intentionally a sequence, not a bag of
-- enemies.  `delay` is the pause before a group begins and `spacing` is the
-- interval between its members.
local CampaignWaveDefs = {}

local lateWaves = {
	[1] = {{ kind = "grunt", count = 12, spacing = 0.9, delay = 0 }},
	[2] = {
		{ kind = "grunt", count = 10, spacing = 0.8, delay = 0 },
		{ kind = "runner", count = 5, spacing = 0.6, delay = 2.0 },
	},
	[3] = {
		{ kind = "runner", count = 7, spacing = 0.67, delay = 0 },
		{ kind = "grunt", count = 14, spacing = 0.53, delay = 1.5 },
	},
	[4] = {
		{ kind = "grunt", count = 16, spacing = 0.43, delay = 0 },
		{ kind = "bulwark", count = 3, spacing = 1.2, delay = 0.4 },
	},
	[5] = {
		{ kind = "tank", count = 5, spacing = 1.15, delay = 0 },
		{ kind = "runner", count = 10, spacing = 0.47, delay = 1.0 },
	},
	[6] = {
		{ kind = "grunt", count = 12, spacing = 0.6, delay = 0 },
		{ kind = "regenerator", count = 6, spacing = 0.85, delay = 1.2 },
	},
	[7] = {
		{ kind = "bulwark", count = 4, spacing = 0.8, delay = 0 },
		{ kind = "warcaller", count = 5, spacing = 0.3, delay = 0.2 },
		{ kind = "grunt", count = 10, spacing = 0.47, delay = 0.5 },
	},
	[8] = {
		{ kind = "shieldbearer", count = 6, spacing = 0.75, delay = 0 },
		{ kind = "regenerator", count = 7, spacing = 0.67, delay = 1.0 },
	},
	[9] = {
		{ kind = "runner", count = 12, spacing = 0.41, delay = 0 },
		{ kind = "tank", count = 7, spacing = 0.95, delay = 0.8 },
		{ kind = "warcaller", count = 3, spacing = 0.45, delay = 0.1 },
	},
	[10] = {{ kind = "boss", count = 1, spacing = 0, delay = 0 }},
	[11] = {
		{ kind = "grunt", count = 22, spacing = 0.35, delay = 0 },
		{ kind = "bulwark", count = 6, spacing = 0.9, delay = 0.15 },
	},
	[12] = {
		{ kind = "tank", count = 8, spacing = 0.87, delay = 0 },
		{ kind = "runner", count = 16, spacing = 0.35, delay = 0.35 },
	},
	[13] = {
		{ kind = "shieldbearer", count = 8, spacing = 0.55, delay = 0 },
		{ kind = "warcaller", count = 5, spacing = 0.35, delay = 0.2 },
		{ kind = "grunt", count = 12, spacing = 0.43, delay = 0.3 },
	},
	[14] = {
		{ kind = "regenerator", count = 10, spacing = 0.53, delay = 0 },
		{ kind = "runner", count = 14, spacing = 0.33, delay = 0.5 },
	},
	[15] = {
		{ kind = "bulwark", count = 7, spacing = 0.67, delay = 0 },
		{ kind = "warcaller", count = 7, spacing = 0.27, delay = 0.1 },
		{ kind = "tank", count = 7, spacing = 0.75, delay = 0.4 },
	},
	[16] = {
		{ kind = "grunt", count = 26, spacing = 0.3, delay = 0 },
		{ kind = "shieldbearer", count = 9, spacing = 0.57, delay = 0.1 },
	},
	[17] = {
		{ kind = "shieldbearer", count = 9, spacing = 0.5, delay = 0 },
		{ kind = "regenerator", count = 11, spacing = 0.47, delay = 0.25 },
		{ kind = "runner", count = 12, spacing = 0.32, delay = 0.4 },
	},
	[18] = {
		{ kind = "runner", count = 18, spacing = 0.3, delay = 0 },
		{ kind = "tank", count = 10, spacing = 0.73, delay = 0.25 },
		{ kind = "runner", count = 12, spacing = 0.3, delay = 0.3 },
	},
	[19] = {
		{ kind = "bulwark", count = 8, spacing = 0.53, delay = 0 },
		{ kind = "warcaller", count = 6, spacing = 0.25, delay = 0.05 },
		{ kind = "shieldbearer", count = 8, spacing = 0.45, delay = 0.25 },
		{ kind = "regenerator", count = 8, spacing = 0.45, delay = 0.25 },
	},
	[20] = {{ kind = "boss", count = 1, spacing = 0, delay = 0 }},
}


local function cloneGroups(groups, kindMap)
	local cloned = {}
	for i, group in ipairs(groups) do
		local copy = {}
		for key, value in pairs(group) do copy[key] = value end
		copy.kind = kindMap[copy.kind] or copy.kind
		cloned[i] = copy
	end
	return cloned
end

local function deriveStage(baseWaves, kindMap)
	local waves = {}
	for waveIndex, groups in pairs(baseWaves) do
		waves[waveIndex] = cloneGroups(groups, kindMap)
	end
	return waves
end

-- Early maps focus on core movement and health profiles only. Mid maps add
-- durable support specialists while postponing the full specialist mix until
-- late campaign maps.
local stageWaves = {
	[1] = deriveStage(lateWaves, {
		bulwark = "tank",
		regenerator = "tank",
		shieldbearer = "tank",
		warcaller = "runner",
	}),
	[2] = deriveStage(lateWaves, {
		shieldbearer = "bulwark",
		warcaller = "regenerator",
	}),
	[3] = lateWaves,
}

function CampaignWaveDefs.get(stage, waveIndex)
	waveIndex = math.max(1, math.floor(tonumber(waveIndex) or 1))
	if waveIndex > 20 then return nil end

	stage = math.max(1, math.min(3, math.floor(tonumber(stage) or 3)))
	return stageWaves[stage][waveIndex]
end

CampaignWaveDefs.stageWaves = stageWaves

return CampaignWaveDefs

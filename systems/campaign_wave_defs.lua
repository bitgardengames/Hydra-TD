-- The hand-authored campaign is intentionally a sequence, not a bag of
-- enemies.  `delay` is the pause before a group begins and `spacing` is the
-- interval between its members.
local CampaignWaveDefs = {}

-- Campaign teaching order is deliberate: Grunt, Tank, Runner, Bulwark,
-- Regenerator, Warcaller, then Shieldbearer. Stage one establishes the first
-- two profiles; stage two adds the next three; stage three completes the
-- support roster. Boss slots are milestone exams and must not be used to
-- introduce an ordinary enemy ahead of that curriculum.

-- Every campaign stage follows the same readable dramatic arc:
--   1-3   give players room to learn where the layout creates long sightlines,
--   4-9   add a new source of pressure at a time,
--   10    is a deliberate mid-map boss spike,
--   11-19 layer the stage's threats together, and
--   20    closes the map with a boss backed by a final mixed formation.
-- Keeping those beats visible here makes it harder for later balance edits to
-- accidentally turn an orientation wave into a specialist check.
local lateWaves = {
	-- Layout lesson: a slow baseline, then two small probes that reveal where
	-- fast enemies enter and where a durable target remains in range longest.
	[1] = {{ kind = "grunt", count = 10, spacing = 0.95, delay = 0 }},
	[2] = {{ kind = "grunt", count = 16, spacing = 0.72, delay = 0 }},
	[3] = {
		{ kind = "grunt", count = 12, spacing = 0.68, delay = 0 },
		{ kind = "runner", count = 4, spacing = 0.7, delay = 2.2 },
	},
	-- Pressure: increasingly tight packs introduce one interaction at a time.
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
	-- Mid-map milestone exam: the escort prevents the boss from being a pure single-
	-- target damage check, without yet asking for the full specialist mix.
	[10] = {
		{ kind = "boss", count = 1, spacing = 0, delay = 0 },
		{ kind = "runner", count = 8, spacing = 0.42, delay = 2.5 },
	},
	-- Combined threats: every wave now asks for at least two answers.
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
	-- Final milestone exam: the boss arrives first so the formation catches up to it and
	-- forces target-priority decisions instead of becoming post-boss cleanup.
	[20] = {
		{ kind = "boss", count = 1, spacing = 0, delay = 0 },
		{ kind = "shieldbearer", count = 6, spacing = 0.5, delay = 1.8 },
		{ kind = "warcaller", count = 4, spacing = 0.32, delay = 0.2 },
		{ kind = "regenerator", count = 6, spacing = 0.48, delay = 0.4 },
		{ kind = "runner", count = 10, spacing = 0.3, delay = 0.5 },
	},
}

-- Stage 1 (especially High Pass / map 3) teaches Cannon splash by sending
-- dense grunt packs with only a few tanks mixed in as durable anchors. Tanks
-- should be noticeable, not the main population pressure, because Poison is not
-- available until after High Pass is cleared.
local stageOneWaves = {
	-- Layout lesson: forgiving, single-profile groups expose corners, overlaps,
	-- and travel time before compact packs demand splash coverage.
	[1] = {{ kind = "grunt", count = 10, spacing = 0.9, delay = 0 }},
	[2] = {{ kind = "grunt", count = 15, spacing = 0.7, delay = 0 }},
	[3] = {
		{ kind = "grunt", count = 12, spacing = 0.62, delay = 0 },
		{ kind = "grunt", count = 8, spacing = 0.58, delay = 2.0 },
	},
	-- Pressure: denser packs teach splash, with tanks added only as anchors.
	[4] = {
		{ kind = "grunt", count = 24, spacing = 0.35, delay = 0 },
		{ kind = "tank", count = 1, spacing = 0, delay = 1.8 },
	},
	[5] = {
		{ kind = "grunt", count = 28, spacing = 0.32, delay = 0 },
		{ kind = "tank", count = 2, spacing = 1.35, delay = 2.0 },
	},
	[6] = {
		{ kind = "grunt", count = 32, spacing = 0.3, delay = 0 },
		{ kind = "tank", count = 2, spacing = 1.25, delay = 1.6 },
	},
	[7] = {
		{ kind = "grunt", count = 22, spacing = 0.32, delay = 0 },
		{ kind = "grunt", count = 16, spacing = 0.28, delay = 1.0 },
		{ kind = "tank", count = 2, spacing = 1.2, delay = 1.4 },
	},
	[8] = {
		{ kind = "grunt", count = 38, spacing = 0.27, delay = 0 },
		{ kind = "tank", count = 3, spacing = 1.15, delay = 1.3 },
	},
	[9] = {
		{ kind = "grunt", count = 26, spacing = 0.29, delay = 0 },
		{ kind = "tank", count = 3, spacing = 1.1, delay = 0.8 },
		{ kind = "grunt", count = 18, spacing = 0.26, delay = 1.1 },
	},
	-- Mid-map milestone exam: a readable boss plus a compact splash check.
	[10] = {
		{ kind = "boss", count = 1, spacing = 0, delay = 0 },
		{ kind = "grunt", count = 18, spacing = 0.3, delay = 2.8 },
	},
	-- Combined threats: dense packs and durable anchors overlap from here on.
	[11] = {
		{ kind = "grunt", count = 42, spacing = 0.25, delay = 0 },
		{ kind = "tank", count = 3, spacing = 1.05, delay = 1.0 },
	},
	[12] = {
		{ kind = "grunt", count = 30, spacing = 0.26, delay = 0 },
		{ kind = "tank", count = 4, spacing = 1.0, delay = 0.8 },
		{ kind = "grunt", count = 20, spacing = 0.24, delay = 1.2 },
	},
	[13] = {
		{ kind = "grunt", count = 48, spacing = 0.23, delay = 0 },
		{ kind = "tank", count = 4, spacing = 0.95, delay = 1.0 },
	},
	[14] = {
		{ kind = "grunt", count = 34, spacing = 0.24, delay = 0 },
		{ kind = "grunt", count = 24, spacing = 0.22, delay = 0.9 },
		{ kind = "tank", count = 4, spacing = 0.95, delay = 1.1 },
	},
	[15] = {
		{ kind = "grunt", count = 52, spacing = 0.22, delay = 0 },
		{ kind = "tank", count = 5, spacing = 0.9, delay = 0.9 },
	},
	[16] = {
		{ kind = "grunt", count = 60, spacing = 0.2, delay = 0 },
		{ kind = "tank", count = 4, spacing = 0.9, delay = 1.0 },
	},
	[17] = {
		{ kind = "grunt", count = 42, spacing = 0.21, delay = 0 },
		{ kind = "tank", count = 5, spacing = 0.85, delay = 0.6 },
		{ kind = "grunt", count = 28, spacing = 0.2, delay = 1.1 },
	},
	[18] = {
		{ kind = "grunt", count = 64, spacing = 0.2, delay = 0 },
		{ kind = "tank", count = 5, spacing = 0.85, delay = 0.8 },
	},
	[19] = {
		{ kind = "grunt", count = 48, spacing = 0.2, delay = 0 },
		{ kind = "tank", count = 6, spacing = 0.8, delay = 0.6 },
		{ kind = "grunt", count = 32, spacing = 0.19, delay = 1.0 },
	},
	-- Final milestone exam: the campaign's foundational crowd and tank checks support the
	-- boss without introducing a specialist that the player has not learned.
	[20] = {
		{ kind = "boss", count = 1, spacing = 0, delay = 0 },
		{ kind = "grunt", count = 36, spacing = 0.22, delay = 2.0 },
		{ kind = "tank", count = 6, spacing = 0.82, delay = 0.7 },
		{ kind = "grunt", count = 20, spacing = 0.2, delay = 0.8 },
	},
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
local stageTwoWaves = deriveStage(lateWaves, {
	shieldbearer = "bulwark",
	warcaller = "regenerator",
})

-- Stage two's capstone uses each threat learned in that stage. Defining it
-- explicitly avoids the late-stage kind substitutions collapsing two support
-- groups into one repeated Regenerator test.
stageTwoWaves[20] = {
	{ kind = "boss", count = 1, spacing = 0, delay = 0 },
	{ kind = "bulwark", count = 7, spacing = 0.52, delay = 1.8 },
	{ kind = "regenerator", count = 7, spacing = 0.48, delay = 0.35 },
	{ kind = "tank", count = 5, spacing = 0.78, delay = 0.45 },
	{ kind = "runner", count = 10, spacing = 0.3, delay = 0.45 },
}

local stageWaves = {
	[1] = stageOneWaves,
	[2] = stageTwoWaves,
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

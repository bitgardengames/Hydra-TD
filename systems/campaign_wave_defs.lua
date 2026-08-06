-- Fixed campaign encounters are indexed by map ID. They deliberately contain only
-- enemy kinds, counts, and timing: procedural kinds and Endless affixes belong in
-- wave_builder.lua and must never become part of the campaign curriculum.
local CampaignWaveDefs = {}

local function g(kind, count, spacing, delay)
	return { kind = kind, count = count, spacing = spacing, delay = delay or 0 }
end

-- Every map uses the same five-part teaching arc:
--   1 orientation; 2-3 demonstration; 4-6 practice; 7-9 mixed check; 10 final exam.
-- Enemy availability below follows introducesEnemies in world/map_defs.lua.
local wavesByMapId = {
	riverbend = {
		-- orientation
		[1] = { g("grunt", 8, 0.90, 0.0) },
		-- demonstration
		[2] = { g("grunt", 12, 0.72, 0.0) },
		-- demonstration
		[3] = { g("grunt", 10, 0.62, 0.0), g("grunt", 8, 0.58, 1.4) },
		-- practice
		[4] = { g("grunt", 20, 0.48, 0.0) },
		-- practice
		[5] = { g("grunt", 24, 0.43, 0.0) },
		-- practice
		[6] = { g("grunt", 10, 0.52, 0.0) },
		-- mixed check
		[7] = { g("grunt", 5, 0.48, 0.0) },
		-- mixed check
		[8] = { g("grunt", 7, 0.43, 0.0) },
		-- mixed check
		[9] = { g("grunt", 6, 0.40, 0.0) },
		-- final exam
		[10] = { g("boss", 1, 0.00, 0.0), g("grunt", 5, 0.43, 1.8) },
	},
	switchback = {
		-- orientation
		[1] = { g("grunt", 10, 0.89, 0.0) },
		-- demonstration
		[2] = { g("grunt", 14, 0.72, 0.0) },
		-- demonstration
		[3] = { g("grunt", 12, 0.62, 0.0), g("grunt", 9, 0.58, 1.4) },
		-- practice
		[4] = { g("grunt", 22, 0.48, 0.0) },
		-- practice
		[5] = { g("grunt", 26, 0.43, 0.0) },
		-- practice
		[6] = { g("grunt", 11, 0.52, 0.0) },
		-- mixed check
		[7] = { g("grunt", 6, 0.48, 0.0) },
		-- mixed check
		[8] = { g("grunt", 8, 0.43, 0.0) },
		-- mixed check
		[9] = { g("grunt", 7, 0.40, 0.0) },
		-- final exam
		[10] = { g("boss", 1, 0.00, 0.0), g("grunt", 6, 0.43, 1.8) },
	},
	highpass = {
		-- orientation
		[1] = { g("grunt", 12, 0.87, 0.0) },
		-- demonstration
		[2] = { g("grunt", 16, 0.72, 0.0) },
		-- demonstration
		[3] = { g("grunt", 14, 0.62, 0.0), g("grunt", 10, 0.58, 1.4) },
		-- practice
		[4] = { g("grunt", 24, 0.48, 0.0) },
		-- practice
		[5] = { g("grunt", 28, 0.43, 0.0) },
		-- practice
		[6] = { g("grunt", 12, 0.52, 0.0) },
		-- mixed check
		[7] = { g("grunt", 6, 0.48, 0.0) },
		-- mixed check
		[8] = { g("grunt", 8, 0.43, 0.0) },
		-- mixed check
		[9] = { g("grunt", 7, 0.40, 0.0) },
		-- final exam
		[10] = { g("boss", 1, 0.00, 0.0), g("grunt", 6, 0.43, 1.8) },
	},
	roundabout = {
		-- orientation
		[1] = { g("grunt", 14, 0.85, 0.0) },
		-- demonstration
		[2] = { g("grunt", 18, 0.72, 0.0) },
		-- demonstration
		[3] = { g("grunt", 16, 0.62, 0.0), g("grunt", 11, 0.58, 1.4) },
		-- practice
		[4] = { g("grunt", 26, 0.48, 0.0) },
		-- practice
		[5] = { g("grunt", 30, 0.43, 0.0) },
		-- practice
		[6] = { g("grunt", 13, 0.52, 0.0) },
		-- mixed check
		[7] = { g("grunt", 7, 0.48, 0.0) },
		-- mixed check
		[8] = { g("grunt", 9, 0.43, 0.0) },
		-- mixed check
		[9] = { g("grunt", 8, 0.40, 0.0) },
		-- final exam
		[10] = { g("boss", 1, 0.00, 0.0), g("grunt", 7, 0.43, 1.8) },
	},
	gauntlet = {
		-- orientation
		[1] = { g("grunt", 16, 0.84, 0.0) },
		-- demonstration
		[2] = { g("grunt", 20, 0.72, 0.0) },
		-- demonstration
		[3] = { g("grunt", 18, 0.62, 0.0), g("grunt", 12, 0.58, 1.4) },
		-- practice
		[4] = { g("grunt", 28, 0.48, 0.0) },
		-- practice
		[5] = { g("grunt", 32, 0.43, 0.0) },
		-- practice
		[6] = { g("grunt", 14, 0.52, 0.0) },
		-- mixed check
		[7] = { g("grunt", 7, 0.48, 0.0) },
		-- mixed check
		[8] = { g("grunt", 9, 0.43, 0.0) },
		-- mixed check
		[9] = { g("grunt", 8, 0.40, 0.0) },
		-- final exam
		[10] = { g("boss", 1, 0.00, 0.0), g("grunt", 7, 0.43, 1.8) },
	},
	snaketrail = {
		-- orientation
		[1] = { g("grunt", 18, 0.83, 0.0) },
		-- demonstration
		[2] = { g("tank", 11, 0.82, 0.0) },
		-- demonstration
		[3] = { g("grunt", 16, 0.68, 0.0), g("tank", 6, 0.78, 1.5) },
		-- practice
		[4] = { g("tank", 13, 0.65, 0.0), g("grunt", 16, 0.54, 0.8) },
		-- practice
		[5] = { g("grunt", 12, 0.70, 0.0), g("tank", 9, 0.60, 0.7) },
		-- practice
		[6] = { g("tank", 11, 0.52, 0.0), g("grunt", 15, 0.60, 0.5) },
		-- mixed check
		[7] = { g("tank", 8, 0.48, 0.0), g("grunt", 9, 0.53, 0.3) },
		-- mixed check
		[8] = { g("grunt", 10, 0.43, 0.0), g("tank", 11, 0.47, 0.3) },
		-- mixed check
		[9] = { g("tank", 9, 0.40, 0.0), g("grunt", 10, 0.44, 0.2) },
		-- final exam
		[10] = { g("boss", 1, 0.00, 0.0), g("tank", 8, 0.43, 1.8), g("grunt", 9, 0.48, 2.0) },
	},
	backtrack = {
		-- orientation
		[1] = { g("grunt", 20, 0.81, 0.0) },
		-- demonstration
		[2] = { g("runner", 12, 0.82, 0.0) },
		-- demonstration
		[3] = { g("grunt", 17, 0.68, 0.0), g("runner", 6, 0.78, 1.5) },
		-- practice
		[4] = { g("runner", 14, 0.65, 0.0), g("grunt", 17, 0.54, 0.8) },
		-- practice
		[5] = { g("tank", 13, 0.70, 0.0), g("runner", 9, 0.60, 0.7) },
		-- practice
		[6] = { g("runner", 12, 0.52, 0.0), g("tank", 12, 0.60, 0.5), g("grunt", 16, 0.68, 1.0) },
		-- mixed check
		[7] = { g("runner", 8, 0.48, 0.0), g("tank", 9, 0.53, 0.3), g("grunt", 10, 0.58, 0.7) },
		-- mixed check
		[8] = { g("tank", 10, 0.43, 0.0), g("runner", 11, 0.47, 0.3), g("grunt", 12, 0.51, 0.6) },
		-- mixed check
		[9] = { g("runner", 9, 0.40, 0.0), g("tank", 10, 0.44, 0.2), g("grunt", 11, 0.48, 0.5) },
		-- final exam
		[10] = { g("boss", 1, 0.00, 0.0), g("runner", 8, 0.43, 1.8), g("tank", 9, 0.48, 2.0), g("grunt", 10, 0.53, 2.3) },
	},
	lowvalley = {
		-- orientation
		[1] = { g("grunt", 22, 0.80, 0.0) },
		-- demonstration
		[2] = { g("bulwark", 13, 0.82, 0.0) },
		-- demonstration
		[3] = { g("grunt", 18, 0.68, 0.0), g("bulwark", 6, 0.78, 1.5) },
		-- practice
		[4] = { g("bulwark", 15, 0.65, 0.0), g("grunt", 18, 0.54, 0.8) },
		-- practice
		[5] = { g("runner", 14, 0.70, 0.0), g("bulwark", 10, 0.60, 0.7) },
		-- practice
		[6] = { g("bulwark", 13, 0.52, 0.0), g("runner", 13, 0.60, 0.5), g("tank", 17, 0.68, 1.0) },
		-- mixed check
		[7] = { g("bulwark", 9, 0.48, 0.0), g("runner", 10, 0.53, 0.3), g("tank", 11, 0.58, 0.7), g("grunt", 12, 0.63, 1.0) },
		-- mixed check
		[8] = { g("grunt", 11, 0.43, 0.0), g("tank", 12, 0.47, 0.3), g("runner", 13, 0.51, 0.6), g("bulwark", 14, 0.55, 0.9) },
		-- mixed check
		[9] = { g("bulwark", 10, 0.40, 0.0), g("runner", 11, 0.44, 0.2), g("tank", 12, 0.48, 0.5), g("grunt", 13, 0.52, 0.8) },
		-- final exam
		[10] = { g("boss", 1, 0.00, 0.0), g("bulwark", 9, 0.43, 1.8), g("runner", 10, 0.48, 2.0), g("tank", 11, 0.53, 2.3), g("grunt", 12, 0.58, 2.5) },
	},
	circuit = {
		-- orientation
		[1] = { g("grunt", 24, 0.78, 0.0) },
		-- demonstration
		[2] = { g("regenerator", 14, 0.82, 0.0) },
		-- demonstration
		[3] = { g("grunt", 19, 0.68, 0.0), g("regenerator", 7, 0.78, 1.5) },
		-- practice
		[4] = { g("regenerator", 16, 0.65, 0.0), g("grunt", 19, 0.54, 0.8) },
		-- practice
		[5] = { g("bulwark", 15, 0.70, 0.0), g("regenerator", 10, 0.60, 0.7) },
		-- practice
		[6] = { g("regenerator", 14, 0.52, 0.0), g("bulwark", 14, 0.60, 0.5), g("runner", 18, 0.68, 1.0) },
		-- mixed check
		[7] = { g("regenerator", 9, 0.48, 0.0), g("bulwark", 10, 0.53, 0.3), g("runner", 11, 0.58, 0.7), g("tank", 12, 0.63, 1.0) },
		-- mixed check
		[8] = { g("regenerator", 11, 0.43, 0.0), g("grunt", 12, 0.47, 0.3), g("tank", 13, 0.51, 0.6), g("runner", 14, 0.55, 0.9) },
		-- mixed check
		[9] = { g("regenerator", 10, 0.40, 0.0), g("bulwark", 11, 0.44, 0.2), g("runner", 12, 0.48, 0.5), g("tank", 13, 0.52, 0.8), g("grunt", 14, 0.56, 1.0) },
		-- final exam
		[10] = { g("boss", 1, 0.00, 0.0), g("regenerator", 9, 0.43, 1.8), g("bulwark", 10, 0.48, 2.0), g("runner", 11, 0.53, 2.3), g("tank", 12, 0.58, 2.5) },
	},
	outerloop = {
		-- orientation
		[1] = { g("grunt", 26, 0.77, 0.0) },
		-- demonstration
		[2] = { g("regenerator", 15, 0.82, 0.0) },
		-- demonstration
		[3] = { g("grunt", 20, 0.68, 0.0), g("regenerator", 7, 0.78, 1.5) },
		-- practice
		[4] = { g("regenerator", 17, 0.65, 0.0), g("grunt", 20, 0.54, 0.8) },
		-- practice
		[5] = { g("bulwark", 16, 0.70, 0.0), g("regenerator", 11, 0.60, 0.7) },
		-- practice
		[6] = { g("regenerator", 15, 0.52, 0.0), g("bulwark", 15, 0.60, 0.5), g("runner", 19, 0.68, 1.0) },
		-- mixed check
		[7] = { g("regenerator", 10, 0.48, 0.0), g("bulwark", 11, 0.53, 0.3), g("runner", 12, 0.58, 0.7), g("tank", 13, 0.63, 1.0) },
		-- mixed check
		[8] = { g("grunt", 12, 0.43, 0.0), g("tank", 13, 0.47, 0.3), g("runner", 14, 0.51, 0.6), g("bulwark", 15, 0.55, 0.9) },
		-- mixed check
		[9] = { g("regenerator", 11, 0.40, 0.0), g("bulwark", 12, 0.44, 0.2), g("runner", 13, 0.48, 0.5), g("tank", 14, 0.52, 0.8), g("grunt", 15, 0.56, 1.0) },
		-- final exam
		[10] = { g("boss", 1, 0.00, 0.0), g("regenerator", 10, 0.43, 1.8), g("bulwark", 11, 0.48, 2.0), g("runner", 12, 0.53, 2.3), g("tank", 13, 0.58, 2.5) },
	},
	terrace = {
		-- orientation
		[1] = { g("grunt", 28, 0.75, 0.0) },
		-- demonstration
		[2] = { g("warcaller", 16, 0.82, 0.0) },
		-- demonstration
		[3] = { g("grunt", 21, 0.68, 0.0), g("warcaller", 7, 0.78, 1.5) },
		-- practice
		[4] = { g("warcaller", 18, 0.65, 0.0), g("grunt", 21, 0.54, 0.8) },
		-- practice
		[5] = { g("regenerator", 17, 0.70, 0.0), g("warcaller", 11, 0.60, 0.7) },
		-- practice
		[6] = { g("warcaller", 16, 0.52, 0.0), g("regenerator", 16, 0.60, 0.5), g("bulwark", 20, 0.68, 1.0) },
		-- mixed check
		[7] = { g("warcaller", 10, 0.48, 0.0), g("regenerator", 11, 0.53, 0.3), g("bulwark", 12, 0.58, 0.7), g("runner", 13, 0.63, 1.0) },
		-- mixed check
		[8] = { g("warcaller", 12, 0.43, 0.0), g("grunt", 13, 0.47, 0.3), g("tank", 14, 0.51, 0.6), g("runner", 15, 0.55, 0.9) },
		-- mixed check
		[9] = { g("warcaller", 11, 0.40, 0.0), g("regenerator", 12, 0.44, 0.2), g("bulwark", 13, 0.48, 0.5), g("runner", 14, 0.52, 0.8), g("tank", 15, 0.56, 1.0) },
		-- final exam
		[10] = { g("boss", 1, 0.00, 0.0), g("warcaller", 10, 0.43, 1.8), g("regenerator", 11, 0.48, 2.0), g("bulwark", 12, 0.53, 2.3), g("runner", 13, 0.58, 2.5) },
	},
	highridge = {
		-- orientation
		[1] = { g("grunt", 30, 0.74, 0.0) },
		-- demonstration
		[2] = { g("shieldbearer", 17, 0.82, 0.0) },
		-- demonstration
		[3] = { g("grunt", 22, 0.68, 0.0), g("shieldbearer", 8, 0.78, 1.5) },
		-- practice
		[4] = { g("shieldbearer", 19, 0.65, 0.0), g("grunt", 22, 0.54, 0.8) },
		-- practice
		[5] = { g("warcaller", 18, 0.70, 0.0), g("shieldbearer", 12, 0.60, 0.7) },
		-- practice
		[6] = { g("shieldbearer", 17, 0.52, 0.0), g("warcaller", 17, 0.60, 0.5), g("regenerator", 21, 0.68, 1.0) },
		-- mixed check
		[7] = { g("shieldbearer", 11, 0.48, 0.0), g("warcaller", 12, 0.53, 0.3), g("regenerator", 13, 0.58, 0.7), g("bulwark", 14, 0.63, 1.0) },
		-- mixed check
		[8] = { g("warcaller", 13, 0.43, 0.0), g("shieldbearer", 14, 0.47, 0.3), g("grunt", 15, 0.51, 0.6), g("tank", 16, 0.55, 0.9) },
		-- mixed check
		[9] = { g("shieldbearer", 12, 0.40, 0.0), g("warcaller", 13, 0.44, 0.2), g("regenerator", 14, 0.48, 0.5), g("bulwark", 15, 0.52, 0.8), g("runner", 16, 0.56, 1.0) },
		-- final exam
		[10] = { g("boss", 1, 0.00, 0.0), g("shieldbearer", 11, 0.43, 1.8), g("warcaller", 12, 0.48, 2.0), g("regenerator", 13, 0.53, 2.3), g("bulwark", 14, 0.58, 2.5) },
	},
	crossflow = {
		-- orientation
		[1] = { g("grunt", 32, 0.72, 0.0) },
		-- demonstration
		[2] = { g("shieldbearer", 18, 0.82, 0.0) },
		-- demonstration
		[3] = { g("grunt", 23, 0.68, 0.0), g("shieldbearer", 8, 0.78, 1.5) },
		-- practice
		[4] = { g("shieldbearer", 20, 0.65, 0.0), g("grunt", 23, 0.54, 0.8) },
		-- practice
		[5] = { g("warcaller", 19, 0.70, 0.0), g("shieldbearer", 12, 0.60, 0.7) },
		-- practice
		[6] = { g("shieldbearer", 18, 0.52, 0.0), g("warcaller", 18, 0.60, 0.5), g("regenerator", 22, 0.68, 1.0) },
		-- mixed check
		[7] = { g("shieldbearer", 11, 0.48, 0.0), g("warcaller", 12, 0.53, 0.3), g("regenerator", 13, 0.58, 0.7), g("bulwark", 14, 0.63, 1.0) },
		-- mixed check
		[8] = { g("shieldbearer", 13, 0.43, 0.0), g("grunt", 14, 0.47, 0.3), g("tank", 15, 0.51, 0.6), g("runner", 16, 0.55, 0.9) },
		-- mixed check
		[9] = { g("shieldbearer", 12, 0.40, 0.0), g("warcaller", 13, 0.44, 0.2), g("regenerator", 14, 0.48, 0.5), g("bulwark", 15, 0.52, 0.8), g("runner", 16, 0.56, 1.0) },
		-- final exam
		[10] = { g("boss", 1, 0.00, 0.0), g("shieldbearer", 11, 0.43, 1.8), g("warcaller", 12, 0.48, 2.0), g("regenerator", 13, 0.53, 2.3), g("bulwark", 14, 0.58, 2.5) },
	},
	steppingstones = {
		-- orientation
		[1] = { g("grunt", 34, 0.71, 0.0) },
		-- demonstration
		[2] = { g("shieldbearer", 19, 0.82, 0.0) },
		-- demonstration
		[3] = { g("grunt", 24, 0.68, 0.0), g("shieldbearer", 8, 0.78, 1.5) },
		-- practice
		[4] = { g("shieldbearer", 21, 0.65, 0.0), g("grunt", 24, 0.54, 0.8) },
		-- practice
		[5] = { g("warcaller", 20, 0.70, 0.0), g("shieldbearer", 13, 0.60, 0.7) },
		-- practice
		[6] = { g("shieldbearer", 19, 0.52, 0.0), g("warcaller", 19, 0.60, 0.5), g("regenerator", 23, 0.68, 1.0) },
		-- mixed check
		[7] = { g("shieldbearer", 12, 0.48, 0.0), g("warcaller", 13, 0.53, 0.3), g("regenerator", 14, 0.58, 0.7), g("bulwark", 15, 0.63, 1.0) },
		-- mixed check
		[8] = { g("grunt", 14, 0.43, 0.0), g("tank", 15, 0.47, 0.3), g("runner", 16, 0.51, 0.6), g("bulwark", 17, 0.55, 0.9) },
		-- mixed check
		[9] = { g("shieldbearer", 13, 0.40, 0.0), g("warcaller", 14, 0.44, 0.2), g("regenerator", 15, 0.48, 0.5), g("bulwark", 16, 0.52, 0.8), g("runner", 17, 0.56, 1.0) },
		-- final exam
		[10] = { g("boss", 1, 0.00, 0.0), g("shieldbearer", 12, 0.43, 1.8), g("warcaller", 13, 0.48, 2.0), g("regenerator", 14, 0.53, 2.3), g("bulwark", 15, 0.58, 2.5) },
	},
	twinloop = {
		-- orientation
		[1] = { g("grunt", 36, 0.69, 0.0) },
		-- demonstration
		[2] = { g("shieldbearer", 20, 0.82, 0.0) },
		-- demonstration
		[3] = { g("grunt", 25, 0.68, 0.0), g("shieldbearer", 9, 0.78, 1.5) },
		-- practice
		[4] = { g("shieldbearer", 22, 0.65, 0.0), g("grunt", 25, 0.54, 0.8) },
		-- practice
		[5] = { g("warcaller", 21, 0.70, 0.0), g("shieldbearer", 13, 0.60, 0.7) },
		-- practice
		[6] = { g("shieldbearer", 20, 0.52, 0.0), g("warcaller", 20, 0.60, 0.5), g("regenerator", 24, 0.68, 1.0) },
		-- mixed check
		[7] = { g("shieldbearer", 12, 0.48, 0.0), g("warcaller", 13, 0.53, 0.3), g("regenerator", 14, 0.58, 0.7), g("bulwark", 15, 0.63, 1.0) },
		-- mixed check
		[8] = { g("tank", 14, 0.43, 0.0), g("runner", 15, 0.47, 0.3), g("bulwark", 16, 0.51, 0.6), g("regenerator", 17, 0.55, 0.9) },
		-- mixed check
		[9] = { g("shieldbearer", 13, 0.40, 0.0), g("warcaller", 14, 0.44, 0.2), g("regenerator", 15, 0.48, 0.5), g("bulwark", 16, 0.52, 0.8), g("runner", 17, 0.56, 1.0) },
		-- final exam
		[10] = { g("boss", 1, 0.00, 0.0), g("shieldbearer", 12, 0.43, 1.8), g("warcaller", 13, 0.48, 2.0), g("regenerator", 14, 0.53, 2.3), g("bulwark", 15, 0.58, 2.5) },
	},
}

local function mapIdOf(mapOrId)
	if type(mapOrId) == "table" then return mapOrId.id end
	if type(mapOrId) == "string" then return mapOrId end
	return nil
end

function CampaignWaveDefs.get(mapOrId, waveIndex)
	local waves = wavesByMapId[mapIdOf(mapOrId)]
	if not waves then return nil end
	waveIndex = math.max(1, math.floor(tonumber(waveIndex) or 1))
	return waves[waveIndex]
end

function CampaignWaveDefs.getFinalWave(mapOrId)
	local waves = wavesByMapId[mapIdOf(mapOrId)]
	return waves and #waves or nil
end

CampaignWaveDefs.wavesByMapId = wavesByMapId

return CampaignWaveDefs

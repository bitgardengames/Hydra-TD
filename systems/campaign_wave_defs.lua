-- Fixed campaign encounters are indexed by map ID. They deliberately contain only
-- enemy kinds, counts, and timing.
local CampaignWaveDefs = {}

-- Pacing identities are expressed through the spawn schedule, not hidden stat or
-- enemy-count ramps.  The dependency-free report in tools/balance/ measures a
-- five-second engagement window and verifies these authored ceilings/ranges.
-- `openingPressure` and `peakSimultaneous` are enemy counts; duration/recovery
-- values are seconds. Riverbend is the untouched baseline for the curriculum.
local pacingIdentityByMapId = {
	riverbend = "baseline: an even stream that gradually learns pack overlap",
	switchback = "switchbacks: compact packs separated by readable resets",
	highpass = "long approach: sustained, widely spaced columns",
	roundabout = "convergence: offset groups fold into one another",
	gauntlet = "burst test: short rushes followed by full recovery windows",
	snaketrail = "armored cadence: tanks anchor alternating light columns",
	backtrack = "pincer cadence: runners arrive between slower anchors",
	lowvalley = "blockade: bulwark-led wedges with deliberate regrouping",
	circuit = "relay: regenerators hand pressure from group to group",
	outerloop = "long rotation: broad formations with generous recovery",
	terrace = "escalation: warcaller pulses inside steady escorts",
	highridge = "finale lesson one: staggered durable fronts expose runner leaks",
	crossflow = "finale lesson two: tighter crossings add overlapping pressure",
	steppingstones = "finale synthesis: separated platoons test target priority",
	twinloop = "campaign final exam: two dense cycles orbit summoner pressure",
}

local pacingTargetsByMapId = {
	riverbend = { openingPressure = 11, peakSimultaneous = 12, totalWaveDuration = { 6.30, 20.95 }, downtimeBetweenGroups = { 0.07, 1.40 } },
	switchback = { openingPressure = 11, peakSimultaneous = 12, totalWaveDuration = { 7.81, 20.30 }, downtimeBetweenGroups = { 0.09, 1.75 } },
	highpass = { openingPressure = 11, peakSimultaneous = 12, totalWaveDuration = { 9.27, 19.51 }, downtimeBetweenGroups = { 0.07, 1.47 } },
	roundabout = { openingPressure = 11, peakSimultaneous = 12, totalWaveDuration = { 7.50, 18.09 }, downtimeBetweenGroups = { 0.07, 0.69 } },
	gauntlet = { openingPressure = 11, peakSimultaneous = 11, totalWaveDuration = { 6.24, 21.47 }, downtimeBetweenGroups = { 0.44, 2.94 } },
	snaketrail = { openingPressure = 11, peakSimultaneous = 11, totalWaveDuration = { 7.63, 16.77 }, downtimeBetweenGroups = { 0.21, 2.50 } },
	backtrack = { openingPressure = 11, peakSimultaneous = 12, totalWaveDuration = { 6.39, 22.43 }, downtimeBetweenGroups = { 0.13, 1.72 } },
	lowvalley = { openingPressure = 11, peakSimultaneous = 11, totalWaveDuration = { 6.72, 30.81 }, downtimeBetweenGroups = { 0.25, 3.62 } },
	circuit = { openingPressure = 11, peakSimultaneous = 12, totalWaveDuration = { 5.92, 25.92 }, downtimeBetweenGroups = { 0.11, 1.62 } },
	outerloop = { openingPressure = 11, peakSimultaneous = 11, totalWaveDuration = { 7.52, 34.83 }, downtimeBetweenGroups = { 0.29, 4.25 } },
	terrace = { openingPressure = 11, peakSimultaneous = 12, totalWaveDuration = { 5.36, 23.23 }, downtimeBetweenGroups = { 0.12, 1.80 } },
	highridge = { openingPressure = 12, peakSimultaneous = 12, totalWaveDuration = { 8.15, 31.69 }, downtimeBetweenGroups = { 0.20, 3.00 } },
	crossflow = { openingPressure = 12, peakSimultaneous = 12, totalWaveDuration = { 6.05, 22.51 }, downtimeBetweenGroups = { 0.07, 1.04 } },
	steppingstones = { openingPressure = 11, peakSimultaneous = 11, totalWaveDuration = { 8.60, 41.81 }, downtimeBetweenGroups = { 0.26, 5.35 } },
	twinloop = { openingPressure = 12, peakSimultaneous = 12, totalWaveDuration = { 2.00, 23.07 }, downtimeBetweenGroups = { 0.10, 1.55 } },
}

-- A wave is written as a short list of spawn groups. Delay is the pause after
-- the previous group, so the common case (start immediately) can omit it.
local function g(kind, count, spacing, delay)
	return { kind = kind, count = count, spacing = spacing, delay = delay or 0 }
end

-- The authored table stays private; callers receive the small runtime wave shape
-- returned by get() rather than depending on its storage details.
local wavesByMapId = {
	riverbend = {
		-- orientation
		[1] = { g("grunt", 8, 0.90) },
		-- demonstration
		[2] = { g("grunt", 12, 0.72) },
		-- demonstration
		[3] = { g("grunt", 10, 0.62), g("grunt", 8, 0.58, 1.4) },
		-- practice
		[4] = { g("grunt", 20, 0.50) },
		-- practice
		[5] = { g("grunt", 24, 0.50) },
		-- practice: a sustained stream hands off to a trailing pack
		[6] = { g("grunt", 16, 0.50), g("grunt", 10, 0.50, 0.65) },
		-- mixed check: two packs compress the recovery window
		[7] = { g("grunt", 14, 0.50), g("grunt", 14, 0.50, 0.30) },
		-- mixed check: staggered packs overlap the player's engagement windows
		[8] = { g("grunt", 13, 0.50), g("grunt", 9, 0.50, 0.15), g("grunt", 8, 0.50, 0.12) },
		-- mixed check: a tight three-pack density exam
		[9] = { g("grunt", 13, 0.50), g("grunt", 10, 0.50, 0.08), g("grunt", 9, 0.50, 0.08) },
		-- final exam: boss with an authored vanguard, body, and rear escort
		[10] = { g("boss", 1, 0.00), g("grunt", 12, 0.50, 1.0), g("grunt", 13, 0.50, 0.35), g("grunt", 9, 0.50, 0.25) },
		[11] = { g("grunt", 15, 0.50), g("grunt", 15, 0.50, 0.33) },
		[12] = { g("grunt", 18, 0.50), g("grunt", 11, 0.50, 0.68) },
		[13] = { g("grunt", 14, 0.50), g("grunt", 10, 0.50, 0.15), g("grunt", 9, 0.50, 0.12) },
		[14] = { g("grunt", 16, 0.50), g("grunt", 16, 0.50, 0.28) },
		[15] = { g("grunt", 15, 0.50), g("grunt", 11, 0.50, 0.08), g("grunt", 10, 0.50, 0.08) },
		[16] = { g("grunt", 20, 0.50), g("grunt", 12, 0.50, 0.59) },
		[17] = { g("grunt", 16, 0.50), g("grunt", 11, 0.50, 0.14), g("grunt", 10, 0.50, 0.11) },
		[18] = { g("grunt", 18, 0.50), g("grunt", 18, 0.50, 0.26) },
		[19] = { g("grunt", 16, 0.50), g("grunt", 13, 0.50, 0.07), g("grunt", 11, 0.50, 0.07) },
		[20] = { g("boss", 1, 0.00), g("grunt", 15, 0.50, 0.90), g("grunt", 16, 0.50, 0.32), g("grunt", 11, 0.50, 0.23) },
	},
	switchback = {
		-- orientation
		[1] = { g("grunt", 10, 0.87) },
		-- demonstration
		[2] = { g("grunt", 12, 0.71) },
		-- demonstration
		[3] = { g("grunt", 11, 0.61), g("grunt", 8, 0.59, 1.75) },
		-- practice
		[4] = { g("grunt", 19, 0.50) },
		-- practice
		[5] = { g("grunt", 23, 0.50) },
		-- practice: a sustained stream hands off to a trailing pack
		[6] = { g("grunt", 16, 0.50), g("grunt", 10, 0.50, 0.81) },
		-- mixed check: two packs compress the recovery window
		[7] = { g("grunt", 13, 0.50), g("grunt", 14, 0.50, 0.38) },
		-- mixed check: staggered packs overlap the player's engagement windows
		[8] = { g("grunt", 13, 0.50), g("grunt", 8, 0.50, 0.19), g("grunt", 7, 0.50, 0.15) },
		-- mixed check: a tight three-pack density exam
		[9] = { g("grunt", 12, 0.50), g("grunt", 10, 0.50, 0.10), g("grunt", 9, 0.50, 0.10) },
		-- final exam: boss with an authored vanguard, body, and rear escort
		[10] = { g("boss", 1, 0.00), g("grunt", 11, 0.50, 1.25), g("grunt", 12, 0.50, 0.44), g("grunt", 9, 0.50, 0.31) },
		[11] = { g("grunt", 14, 0.50), g("grunt", 15, 0.50, 0.42) },
		[12] = { g("grunt", 18, 0.50), g("grunt", 11, 0.50, 0.85) },
		[13] = { g("grunt", 14, 0.50), g("grunt", 9, 0.50, 0.19), g("grunt", 8, 0.50, 0.15) },
		[14] = { g("grunt", 15, 0.50), g("grunt", 16, 0.50, 0.36) },
		[15] = { g("grunt", 13, 0.50), g("grunt", 11, 0.50, 0.11), g("grunt", 10, 0.50, 0.11) },
		[16] = { g("grunt", 20, 0.50), g("grunt", 12, 0.50, 0.73) },
		[17] = { g("grunt", 16, 0.50), g("grunt", 10, 0.50, 0.17), g("grunt", 8, 0.50, 0.14) },
		[18] = { g("grunt", 17, 0.50), g("grunt", 18, 0.50, 0.32) },
		[19] = { g("grunt", 15, 0.50), g("grunt", 13, 0.50, 0.09), g("grunt", 11, 0.50, 0.09) },
		[20] = { g("boss", 1, 0.00), g("grunt", 14, 0.50, 1.12), g("grunt", 15, 0.50, 0.40), g("grunt", 11, 0.50, 0.28) },
	},
	highpass = {
		-- orientation
		[1] = { g("grunt", 10, 1.03) },
		-- demonstration
		[2] = { g("grunt", 12, 0.85) },
		-- demonstration
		[3] = { g("grunt", 12, 0.73), g("grunt", 8, 0.71, 1.47) },
		-- practice
		[4] = { g("grunt", 18, 0.57) },
		-- practice
		[5] = { g("grunt", 22, 0.51) },
		-- practice: a sustained stream hands off to a trailing pack
		[6] = { g("grunt", 15, 0.52), g("grunt", 9, 0.50, 0.68) },
		-- mixed check: two packs compress the recovery window
		[7] = { g("grunt", 12, 0.50), g("grunt", 13, 0.50, 0.32) },
		-- mixed check: staggered packs overlap the player's engagement windows
		[8] = { g("grunt", 12, 0.50), g("grunt", 8, 0.50, 0.16), g("grunt", 6, 0.50, 0.13) },
		-- mixed check: a tight three-pack density exam
		[9] = { g("grunt", 11, 0.50), g("grunt", 10, 0.50, 0.08), g("grunt", 8, 0.50, 0.08) },
		-- final exam: boss with an authored vanguard, body, and rear escort
		[10] = { g("boss", 1, 0.00), g("grunt", 11, 0.50, 1.05), g("grunt", 12, 0.50, 0.37), g("grunt", 8, 0.50, 0.26) },
		[11] = { g("grunt", 13, 0.50), g("grunt", 14, 0.50, 0.35) },
		[12] = { g("grunt", 17, 0.52), g("grunt", 10, 0.50, 0.71) },
		[13] = { g("grunt", 13, 0.50), g("grunt", 9, 0.50, 0.16), g("grunt", 7, 0.50, 0.13) },
		[14] = { g("grunt", 14, 0.50), g("grunt", 15, 0.50, 0.30) },
		[15] = { g("grunt", 12, 0.50), g("grunt", 11, 0.50, 0.08), g("grunt", 9, 0.50, 0.08) },
		[16] = { g("grunt", 19, 0.52), g("grunt", 11, 0.50, 0.61) },
		[17] = { g("grunt", 14, 0.50), g("grunt", 10, 0.50, 0.14), g("grunt", 7, 0.50, 0.12) },
		[18] = { g("grunt", 16, 0.50), g("grunt", 17, 0.50, 0.27) },
		[19] = { g("grunt", 14, 0.50), g("grunt", 13, 0.50, 0.07), g("grunt", 10, 0.50, 0.07) },
		[20] = { g("boss", 1, 0.00), g("grunt", 14, 0.50, 0.95), g("grunt", 15, 0.50, 0.33), g("grunt", 10, 0.50, 0.23) },
	},
	roundabout = {
		-- orientation
		[1] = { g("grunt", 11, 0.75) },
		-- demonstration
		[2] = { g("grunt", 13, 0.63) },
		-- demonstration
		[3] = { g("grunt", 12, 0.55), g("grunt", 8, 0.53, 0.69) },
		-- practice
		[4] = { g("grunt", 18, 0.50) },
		-- practice
		[5] = { g("grunt", 22, 0.50) },
		-- practice: a sustained stream hands off to a trailing pack
		[6] = { g("grunt", 15, 0.50), g("grunt", 9, 0.50, 0.28) },
		-- mixed check: two packs compress the recovery window
		[7] = { g("grunt", 12, 0.50), g("grunt", 13, 0.50, 0.09) },
		-- mixed check: staggered packs overlap the player's engagement windows
		[8] = { g("grunt", 12, 0.50), g("grunt", 8, 0.50, 0.08), g("grunt", 7, 0.50, 0.08) },
		-- mixed check: a tight three-pack density exam
		[9] = { g("grunt", 10, 0.50), g("grunt", 9, 0.50, 0.08), g("grunt", 9, 0.50, 0.08) },
		-- final exam: boss with an authored vanguard, body, and rear escort
		[10] = { g("boss", 1, 0.00), g("grunt", 11, 0.50, 0.47), g("grunt", 11, 0.50, 0.11), g("grunt", 8, 0.50, 0.08) },
		[11] = { g("grunt", 13, 0.50), g("grunt", 14, 0.50, 0.10) },
		[12] = { g("grunt", 17, 0.50), g("grunt", 10, 0.50, 0.29) },
		[13] = { g("grunt", 13, 0.50), g("grunt", 9, 0.50, 0.08), g("grunt", 8, 0.50, 0.08) },
		[14] = { g("grunt", 14, 0.50), g("grunt", 15, 0.50, 0.09) },
		[15] = { g("grunt", 11, 0.50), g("grunt", 10, 0.50, 0.08), g("grunt", 10, 0.50, 0.08) },
		[16] = { g("grunt", 19, 0.50), g("grunt", 11, 0.50, 0.25) },
		[17] = { g("grunt", 14, 0.50), g("grunt", 10, 0.50, 0.07), g("grunt", 8, 0.50, 0.07) },
		[18] = { g("grunt", 16, 0.50), g("grunt", 17, 0.50, 0.08) },
		[19] = { g("grunt", 13, 0.50), g("grunt", 11, 0.50, 0.07), g("grunt", 11, 0.50, 0.07) },
		[20] = { g("boss", 1, 0.00), g("grunt", 14, 0.50, 0.42), g("grunt", 14, 0.50, 0.10), g("grunt", 10, 0.50, 0.07) },
	},
	gauntlet = {
		-- orientation
		[1] = { g("grunt", 12, 0.60) },
		-- demonstration
		[2] = { g("grunt", 13, 0.52) },
		-- demonstration
		[3] = { g("grunt", 13, 0.50), g("grunt", 8, 0.50, 2.94) },
		-- practice
		[4] = { g("grunt", 18, 0.50) },
		-- practice
		[5] = { g("grunt", 22, 0.50) },
		-- practice: a sustained stream hands off to a trailing pack
		[6] = { g("grunt", 15, 0.50), g("grunt", 9, 0.50, 1.37) },
		-- mixed check: two packs compress the recovery window
		[7] = { g("grunt", 12, 0.50), g("grunt", 13, 0.50, 0.98) },
		-- mixed check: staggered packs overlap the player's engagement windows
		[8] = { g("grunt", 12, 0.50), g("grunt", 8, 0.50, 0.67), g("grunt", 6, 0.50, 0.60) },
		-- mixed check: a tight three-pack density exam
		[9] = { g("grunt", 10, 0.50), g("grunt", 9, 0.50, 0.52), g("grunt", 8, 0.50, 0.52) },
		-- final exam: boss with an authored vanguard, body, and rear escort
		[10] = { g("boss", 1, 0.00), g("grunt", 10, 0.50, 2.45), g("grunt", 11, 0.50, 1.08), g("grunt", 9, 0.50, 0.88) },
		[11] = { g("grunt", 13, 0.50), g("grunt", 14, 0.50, 1.08) },
		[12] = { g("grunt", 17, 0.50), g("grunt", 10, 0.50, 1.44) },
		[13] = { g("grunt", 13, 0.50), g("grunt", 9, 0.50, 0.67), g("grunt", 7, 0.50, 0.60) },
		[14] = { g("grunt", 14, 0.50), g("grunt", 15, 0.50, 0.93) },
		[15] = { g("grunt", 11, 0.50), g("grunt", 10, 0.50, 0.55), g("grunt", 9, 0.50, 0.55) },
		[16] = { g("grunt", 19, 0.50), g("grunt", 11, 0.50, 1.23) },
		[17] = { g("grunt", 14, 0.50), g("grunt", 10, 0.50, 0.60), g("grunt", 7, 0.50, 0.54) },
		[18] = { g("grunt", 16, 0.50), g("grunt", 17, 0.50, 0.83) },
		[19] = { g("grunt", 13, 0.50), g("grunt", 11, 0.50, 0.44), g("grunt", 10, 0.50, 0.44) },
		[20] = { g("boss", 1, 0.00), g("grunt", 13, 0.50, 2.21), g("grunt", 14, 0.50, 0.97), g("grunt", 11, 0.50, 0.79) },
	},
	snaketrail = {
		-- orientation
		[1] = { g("grunt", 17, 0.90) },
		-- demonstration
		[2] = { g("tank", 10, 0.89) },
		-- demonstration
		[3] = { g("grunt", 15, 0.73), g("tank", 5, 0.87, 1.88) },
		-- practice
		[4] = { g("tank", 11, 0.70), g("grunt", 14, 0.60, 1.00) },
		-- practice
		[5] = { g("grunt", 11, 0.76), g("tank", 9, 0.67, 0.88) },
		-- practice
		[6] = { g("tank", 10, 0.56), g("grunt", 13, 0.67, 0.62) },
		-- mixed check
		[7] = { g("tank", 7, 0.52), g("grunt", 8, 0.59, 0.38) },
		-- mixed check
		[8] = { g("grunt", 9, 0.50), g("tank", 9, 0.53, 0.38) },
		-- mixed check
		[9] = { g("tank", 8, 0.50), g("grunt", 9, 0.50, 0.25) },
		-- final exam
		[10] = { g("boss", 1, 0.00), g("tank", 8, 0.50, 2.25), g("grunt", 8, 0.55, 2.50) },
		[11] = { g("tank", 8, 0.52), g("grunt", 9, 0.59, 0.42) },
		[12] = { g("tank", 11, 0.56), g("grunt", 15, 0.67, 0.65) },
		[13] = { g("grunt", 10, 0.50), g("tank", 10, 0.53, 0.38) },
		[14] = { g("tank", 8, 0.52), g("grunt", 9, 0.59, 0.36) },
		[15] = { g("tank", 9, 0.50), g("grunt", 10, 0.50, 0.26) },
		[16] = { g("tank", 12, 0.56), g("grunt", 16, 0.67, 0.56) },
		[17] = { g("grunt", 11, 0.50), g("tank", 11, 0.53, 0.34) },
		[18] = { g("tank", 9, 0.52), g("grunt", 10, 0.59, 0.32) },
		[19] = { g("tank", 10, 0.50), g("grunt", 11, 0.50, 0.21) },
		[20] = { g("boss", 1, 0.00), g("tank", 10, 0.50, 2.02), g("grunt", 10, 0.55, 2.25) },
	},
	backtrack = {
		-- orientation
		[1] = { g("grunt", 17, 0.70) },
		-- demonstration
		[2] = { g("runner", 10, 0.71) },
		-- demonstration
		[3] = { g("grunt", 14, 0.58), g("runner", 5, 0.69, 1.12) },
		-- practice
		[4] = { g("runner", 11, 0.56), g("grunt", 14, 0.50, 0.60) },
		-- practice
		[5] = { g("tank", 11, 0.60), g("runner", 8, 0.53, 0.52) },
		-- practice
		[6] = { g("runner", 10, 0.50), g("tank", 10, 0.53, 0.38), g("grunt", 14, 0.63, 0.75) },
		-- mixed check
		[7] = { g("runner", 6, 0.50), g("tank", 8, 0.50, 0.22), g("grunt", 8, 0.53, 0.52) },
		-- mixed check
		[8] = { g("tank", 8, 0.50), g("runner", 8, 0.50, 0.22), g("grunt", 10, 0.50, 0.45) },
		-- mixed check
		[9] = { g("runner", 7, 0.50), g("tank", 8, 0.50, 0.15), g("grunt", 10, 0.50, 0.38) },
		-- final exam
		[10] = { g("boss", 1, 0.00), g("runner", 7, 0.50, 1.35), g("tank", 7, 0.50, 1.50), g("grunt", 8, 0.50, 1.72) },
		[11] = { g("runner", 6, 0.50), g("tank", 9, 0.50, 0.24), g("grunt", 9, 0.53, 0.57) },
		[12] = { g("runner", 11, 0.50), g("tank", 11, 0.53, 0.40), g("grunt", 16, 0.63, 0.79) },
		[13] = { g("tank", 9, 0.50), g("runner", 9, 0.50, 0.22), g("grunt", 11, 0.50, 0.45) },
		[14] = { g("runner", 7, 0.50), g("tank", 9, 0.50, 0.21), g("grunt", 9, 0.53, 0.49) },
		[15] = { g("runner", 8, 0.50), g("tank", 9, 0.50, 0.16), g("grunt", 11, 0.50, 0.40) },
		[16] = { g("runner", 12, 0.50), g("tank", 12, 0.53, 0.34), g("grunt", 17, 0.63, 0.68) },
		[17] = { g("tank", 10, 0.50), g("runner", 10, 0.50, 0.20), g("grunt", 12, 0.50, 0.41) },
		[18] = { g("runner", 8, 0.50), g("tank", 10, 0.50, 0.19), g("grunt", 10, 0.53, 0.44) },
		[19] = { g("runner", 9, 0.50), g("tank", 10, 0.50, 0.13), g("grunt", 13, 0.50, 0.32) },
		[20] = { g("boss", 1, 0.00), g("runner", 9, 0.50, 1.22), g("tank", 9, 0.50, 1.35), g("grunt", 10, 0.50, 1.55) },
	},
	lowvalley = {
		-- orientation
		[1] = { g("grunt", 17, 0.82) },
		-- demonstration
		[2] = { g("bulwark", 9, 0.84) },
		-- demonstration
		[3] = { g("grunt", 13, 0.69), g("bulwark", 4, 0.82, 2.17) },
		-- practice
		[4] = { g("bulwark", 10, 0.66), g("grunt", 13, 0.57, 1.16) },
		-- practice
		[5] = { g("runner", 10, 0.71), g("bulwark", 8, 0.63, 1.01) },
		-- practice
		[6] = { g("bulwark", 10, 0.53), g("runner", 9, 0.63, 0.72), g("tank", 13, 0.74, 1.45) },
		-- mixed check
		[7] = { g("bulwark", 6, 0.50), g("runner", 7, 0.56, 0.43), g("tank", 7, 0.63, 1.01), g("grunt", 9, 0.71, 1.45) },
		-- mixed check
		[8] = { g("grunt", 8, 0.50), g("tank", 8, 0.50, 0.43), g("runner", 9, 0.56, 0.87), g("bulwark", 11, 0.62, 1.30) },
		-- mixed check
		[9] = { g("bulwark", 7, 0.50), g("runner", 8, 0.50, 0.29), g("tank", 9, 0.52, 0.72), g("grunt", 9, 0.59, 1.16) },
		-- final exam
		[10] = { g("boss", 1, 0.00), g("bulwark", 7, 0.50, 2.61), g("runner", 7, 0.52, 2.90), g("tank", 8, 0.60, 3.33), g("grunt", 8, 0.67, 3.62) },
		[11] = { g("bulwark", 6, 0.50), g("runner", 8, 0.56, 0.47), g("tank", 8, 0.63, 1.11), g("grunt", 10, 0.71, 1.59) },
		[12] = { g("bulwark", 11, 0.53), g("runner", 10, 0.63, 0.76), g("tank", 15, 0.74, 1.52) },
		[13] = { g("grunt", 9, 0.50), g("tank", 9, 0.50, 0.43), g("runner", 10, 0.56, 0.87), g("bulwark", 12, 0.62, 1.30) },
		[14] = { g("bulwark", 7, 0.50), g("runner", 8, 0.56, 0.41), g("tank", 8, 0.63, 0.96), g("grunt", 10, 0.71, 1.38) },
		[15] = { g("bulwark", 8, 0.50), g("runner", 9, 0.50, 0.30), g("tank", 10, 0.52, 0.76), g("grunt", 10, 0.59, 1.22) },
		[16] = { g("bulwark", 12, 0.53), g("runner", 11, 0.63, 0.65), g("tank", 16, 0.74, 1.30) },
		[17] = { g("grunt", 10, 0.50), g("tank", 10, 0.50, 0.39), g("runner", 11, 0.56, 0.78), g("bulwark", 13, 0.62, 1.17) },
		[18] = { g("bulwark", 8, 0.50), g("runner", 9, 0.56, 0.37), g("tank", 9, 0.63, 0.86), g("grunt", 12, 0.71, 1.23) },
		[19] = { g("bulwark", 9, 0.50), g("runner", 10, 0.50, 0.25), g("tank", 11, 0.52, 0.61), g("grunt", 11, 0.59, 0.99) },
		[20] = { g("boss", 1, 0.00), g("bulwark", 9, 0.50, 2.35), g("runner", 9, 0.52, 2.61), g("tank", 10, 0.60, 3.00), g("grunt", 10, 0.67, 3.26) },
	},
	circuit = {
		-- orientation
		[1] = { g("grunt", 17, 0.70) },
		-- demonstration
		[2] = { g("regenerator", 9, 0.74) },
		-- demonstration
		[3] = { g("grunt", 13, 0.61), g("regenerator", 4, 0.73, 0.98) },
		-- practice
		[4] = { g("regenerator", 10, 0.59), g("grunt", 13, 0.50, 0.52) },
		-- practice
		[5] = { g("bulwark", 10, 0.63), g("regenerator", 7, 0.56, 0.45) },
		-- practice
		[6] = { g("regenerator", 10, 0.50), g("bulwark", 9, 0.56, 0.33), g("runner", 13, 0.65, 0.65) },
		-- mixed check
		[7] = { g("regenerator", 6, 0.50), g("bulwark", 7, 0.50, 0.20), g("runner", 7, 0.56, 0.45), g("tank", 8, 0.63, 0.65) },
		-- mixed check
		[8] = { g("regenerator", 8, 0.50), g("grunt", 8, 0.50, 0.20), g("tank", 9, 0.50, 0.39), g("runner", 10, 0.55, 0.59) },
		-- mixed check
		[9] = { g("regenerator", 6, 0.50), g("bulwark", 7, 0.50, 0.13), g("runner", 9, 0.50, 0.33), g("tank", 9, 0.52, 0.52), g("grunt", 10, 0.57, 0.65) },
		-- final exam
		[10] = { g("boss", 1, 0.00), g("regenerator", 6, 0.50, 1.17), g("bulwark", 7, 0.50, 1.30), g("runner", 8, 0.53, 1.49), g("tank", 8, 0.60, 1.62) },
		[11] = { g("regenerator", 6, 0.50), g("bulwark", 8, 0.50, 0.22), g("runner", 8, 0.56, 0.50), g("tank", 9, 0.63, 0.72) },
		[12] = { g("regenerator", 11, 0.50), g("bulwark", 10, 0.56, 0.35), g("runner", 15, 0.65, 0.68) },
		[13] = { g("regenerator", 9, 0.50), g("grunt", 9, 0.50, 0.20), g("tank", 10, 0.50, 0.39), g("runner", 11, 0.55, 0.59) },
		[14] = { g("regenerator", 7, 0.50), g("bulwark", 8, 0.50, 0.19), g("runner", 8, 0.56, 0.43), g("tank", 9, 0.63, 0.62) },
		[15] = { g("regenerator", 7, 0.50), g("bulwark", 8, 0.50, 0.14), g("runner", 10, 0.50, 0.35), g("tank", 10, 0.52, 0.55), g("grunt", 11, 0.57, 0.68) },
		[16] = { g("regenerator", 12, 0.50), g("bulwark", 11, 0.56, 0.30), g("runner", 16, 0.65, 0.59) },
		[17] = { g("regenerator", 10, 0.50), g("grunt", 10, 0.50, 0.18), g("tank", 11, 0.50, 0.35), g("runner", 12, 0.55, 0.53) },
		[18] = { g("regenerator", 8, 0.50), g("bulwark", 9, 0.50, 0.17), g("runner", 9, 0.56, 0.38), g("tank", 10, 0.63, 0.55) },
		[19] = { g("regenerator", 8, 0.50), g("bulwark", 9, 0.50, 0.11), g("runner", 11, 0.50, 0.28), g("tank", 11, 0.52, 0.44), g("grunt", 13, 0.57, 0.55) },
		[20] = { g("boss", 1, 0.00), g("regenerator", 8, 0.50, 1.05), g("bulwark", 9, 0.50, 1.17), g("runner", 10, 0.53, 1.34), g("tank", 10, 0.60, 1.46) },
	},
	outerloop = {
		-- orientation
		[1] = { g("grunt", 17, 0.89) },
		-- demonstration
		[2] = { g("regenerator", 9, 0.94) },
		-- demonstration
		[3] = { g("grunt", 13, 0.78), g("regenerator", 4, 0.93, 2.55) },
		-- practice
		[4] = { g("regenerator", 10, 0.75), g("grunt", 13, 0.64, 1.36) },
		-- practice
		[5] = { g("bulwark", 10, 0.80), g("regenerator", 7, 0.71, 1.19) },
		-- practice
		[6] = { g("regenerator", 10, 0.60), g("bulwark", 9, 0.71, 0.85), g("runner", 13, 0.84, 1.70) },
		-- mixed check
		[7] = { g("regenerator", 6, 0.55), g("bulwark", 7, 0.63, 0.51), g("runner", 7, 0.71, 1.19), g("tank", 8, 0.80, 1.70) },
		-- mixed check
		[8] = { g("grunt", 8, 0.50), g("tank", 8, 0.56, 0.51), g("runner", 9, 0.63, 1.02), g("bulwark", 10, 0.70, 1.53) },
		-- mixed check
		[9] = { g("regenerator", 7, 0.50), g("bulwark", 8, 0.52, 0.34), g("runner", 9, 0.59, 0.85), g("tank", 9, 0.66, 1.36), g("grunt", 10, 0.73, 1.70) },
		-- final exam
		[10] = { g("boss", 1, 0.00), g("regenerator", 7, 0.51, 3.06), g("bulwark", 7, 0.59, 3.40), g("runner", 8, 0.67, 3.91), g("tank", 8, 0.76, 4.25) },
		[11] = { g("regenerator", 6, 0.55), g("bulwark", 8, 0.63, 0.56), g("runner", 8, 0.71, 1.31), g("tank", 9, 0.80, 1.87) },
		[12] = { g("regenerator", 11, 0.60), g("bulwark", 10, 0.71, 0.89), g("runner", 15, 0.84, 1.78) },
		[13] = { g("grunt", 9, 0.50), g("tank", 9, 0.56, 0.51), g("runner", 10, 0.63, 1.02), g("bulwark", 11, 0.70, 1.53) },
		[14] = { g("regenerator", 7, 0.55), g("bulwark", 8, 0.63, 0.48), g("runner", 8, 0.71, 1.13), g("tank", 9, 0.80, 1.61) },
		[15] = { g("regenerator", 8, 0.50), g("bulwark", 9, 0.52, 0.36), g("runner", 10, 0.59, 0.89), g("tank", 10, 0.66, 1.43), g("grunt", 11, 0.73, 1.78) },
		[16] = { g("regenerator", 12, 0.60), g("bulwark", 11, 0.71, 0.77), g("runner", 16, 0.84, 1.53) },
		[17] = { g("grunt", 10, 0.50), g("tank", 10, 0.56, 0.46), g("runner", 11, 0.63, 0.92), g("bulwark", 12, 0.70, 1.38) },
		[18] = { g("regenerator", 8, 0.55), g("bulwark", 9, 0.63, 0.43), g("runner", 9, 0.71, 1.01), g("tank", 10, 0.80, 1.44) },
		[19] = { g("regenerator", 9, 0.50), g("bulwark", 10, 0.52, 0.29), g("runner", 11, 0.59, 0.72), g("tank", 11, 0.66, 1.16), g("grunt", 13, 0.73, 1.44) },
		[20] = { g("boss", 1, 0.00), g("regenerator", 9, 0.51, 2.75), g("bulwark", 9, 0.59, 3.06), g("runner", 10, 0.67, 3.52), g("tank", 10, 0.76, 3.83) },
	},
	terrace = {
		-- orientation
		[1] = { g("grunt", 17, 0.61) },
		-- demonstration
		[2] = { g("warcaller", 9, 0.67) },
		-- demonstration
		[3] = { g("grunt", 13, 0.56), g("warcaller", 4, 0.66, 1.08) },
		-- practice
		[4] = { g("warcaller", 10, 0.53), g("grunt", 13, 0.50, 0.58) },
		-- practice
		[5] = { g("regenerator", 10, 0.57), g("warcaller", 7, 0.51, 0.50) },
		-- practice
		[6] = { g("warcaller", 10, 0.50), g("regenerator", 9, 0.51, 0.36), g("bulwark", 13, 0.60, 0.72) },
		-- mixed check
		[7] = { g("warcaller", 6, 0.50), g("regenerator", 7, 0.50, 0.22), g("bulwark", 7, 0.51, 0.50), g("runner", 8, 0.57, 0.72) },
		-- mixed check
		[8] = { g("warcaller", 8, 0.50), g("grunt", 7, 0.50, 0.22), g("tank", 9, 0.50, 0.43), g("runner", 10, 0.50, 0.65) },
		-- mixed check
		[9] = { g("warcaller", 6, 0.50), g("regenerator", 7, 0.50, 0.14), g("bulwark", 8, 0.50, 0.36), g("runner", 8, 0.50, 0.58), g("tank", 9, 0.52, 0.72) },
		-- final exam
		[10] = { g("boss", 1, 0.00), g("warcaller", 6, 0.50, 1.30), g("regenerator", 7, 0.50, 1.44), g("bulwark", 8, 0.50, 1.66), g("runner", 7, 0.54, 1.80) },
		[11] = { g("warcaller", 6, 0.50), g("regenerator", 8, 0.50, 0.24), g("bulwark", 8, 0.51, 0.55), g("runner", 9, 0.57, 0.79) },
		[12] = { g("warcaller", 11, 0.50), g("regenerator", 10, 0.51, 0.38), g("bulwark", 15, 0.60, 0.76) },
		[13] = { g("warcaller", 9, 0.50), g("grunt", 8, 0.50, 0.22), g("tank", 10, 0.50, 0.43), g("runner", 11, 0.50, 0.65) },
		[14] = { g("warcaller", 7, 0.50), g("regenerator", 8, 0.50, 0.21), g("bulwark", 8, 0.51, 0.47), g("runner", 9, 0.57, 0.68) },
		[15] = { g("warcaller", 7, 0.50), g("regenerator", 8, 0.50, 0.15), g("bulwark", 9, 0.50, 0.38), g("runner", 9, 0.50, 0.61), g("tank", 10, 0.52, 0.76) },
		[16] = { g("warcaller", 12, 0.50), g("regenerator", 11, 0.51, 0.32), g("bulwark", 16, 0.60, 0.65) },
		[17] = { g("warcaller", 10, 0.50), g("grunt", 8, 0.50, 0.20), g("tank", 11, 0.50, 0.39), g("runner", 12, 0.50, 0.59) },
		[18] = { g("warcaller", 8, 0.50), g("regenerator", 9, 0.50, 0.19), g("bulwark", 9, 0.51, 0.42), g("runner", 10, 0.57, 0.61) },
		[19] = { g("warcaller", 8, 0.50), g("regenerator", 9, 0.50, 0.12), g("bulwark", 10, 0.50, 0.31), g("runner", 10, 0.50, 0.49), g("tank", 11, 0.52, 0.61) },
		[20] = { g("boss", 1, 0.00), g("warcaller", 8, 0.50, 1.17), g("regenerator", 9, 0.50, 1.30), g("bulwark", 10, 0.50, 1.49), g("runner", 9, 0.54, 1.62) },
	},
	highridge = {
		-- orientation
		[1] = { g("grunt", 17, 0.78) },
		-- demonstration
		[2] = { g("bulwark", 6, 0.87), g("runner", 6, 0.70, 0.30) },
		-- demonstration
		[3] = { g("grunt", 13, 0.72), g("bulwark", 2, 0.86, 1.80), g("runner", 2, 0.69, 2.10) },
		-- practice
		[4] = { g("bulwark", 6, 0.69), g("runner", 6, 0.55, 0.30), g("grunt", 13, 0.59, 0.96) },
		-- practice
		[5] = { g("warcaller", 10, 0.74), g("bulwark", 4, 0.66, 0.84), g("runner", 4, 0.53, 1.14) },
		-- practice
		[6] = { g("bulwark", 6, 0.55), g("runner", 6, 0.50, 0.30), g("warcaller", 10, 0.66, 0.60), g("regenerator", 13, 0.77, 1.20) },
		-- mixed check
		[7] = { g("bulwark", 3, 0.51), g("runner", 4, 0.50, 0.30), g("warcaller", 7, 0.58, 0.36), g("regenerator", 7, 0.66, 0.84), g("bulwark", 8, 0.74, 1.20) },
		-- mixed check
		[8] = { g("warcaller", 8, 0.50), g("bulwark", 4, 0.52, 0.36), g("runner", 5, 0.50, 0.66), g("grunt", 9, 0.58, 0.72), g("tank", 10, 0.64, 1.08) },
		-- mixed check
		[9] = { g("bulwark", 4, 0.50), g("runner", 4, 0.50, 0.30), g("warcaller", 8, 0.50, 0.24), g("regenerator", 9, 0.54, 0.60), g("bulwark", 8, 0.61, 0.96), g("runner", 10, 0.68, 1.20) },
		-- final exam
		[10] = { g("boss", 1, 0.00), g("bulwark", 4, 0.50, 2.16), g("runner", 4, 0.50, 2.46), g("warcaller", 7, 0.54, 2.40), g("regenerator", 8, 0.62, 2.76), g("bulwark", 8, 0.70, 3.00) },
		[11] = { g("bulwark", 3, 0.51), g("runner", 4, 0.50, 0.33), g("warcaller", 8, 0.58, 0.40), g("regenerator", 8, 0.66, 0.92), g("bulwark", 9, 0.74, 1.32) },
		[12] = { g("bulwark", 7, 0.55), g("runner", 7, 0.50, 0.32), g("warcaller", 11, 0.66, 0.63), g("regenerator", 15, 0.77, 1.26) },
		[13] = { g("warcaller", 9, 0.50), g("bulwark", 4, 0.52, 0.36), g("runner", 6, 0.50, 0.66), g("grunt", 10, 0.58, 0.72), g("tank", 11, 0.64, 1.08) },
		[14] = { g("bulwark", 3, 0.51), g("runner", 5, 0.50, 0.28), g("warcaller", 8, 0.58, 0.34), g("regenerator", 8, 0.66, 0.80), g("bulwark", 9, 0.74, 1.14) },
		[15] = { g("bulwark", 4, 0.50), g("runner", 4, 0.50, 0.32), g("warcaller", 9, 0.50, 0.25), g("regenerator", 10, 0.54, 0.63), g("bulwark", 9, 0.61, 1.01), g("runner", 11, 0.68, 1.26) },
		[16] = { g("bulwark", 7, 0.55), g("runner", 7, 0.50, 0.27), g("warcaller", 12, 0.66, 0.54), g("regenerator", 16, 0.77, 1.08) },
		[17] = { g("warcaller", 10, 0.50), g("bulwark", 5, 0.52, 0.32), g("runner", 6, 0.50, 0.59), g("grunt", 11, 0.58, 0.65), g("tank", 12, 0.64, 0.97) },
		[18] = { g("bulwark", 4, 0.51), g("runner", 5, 0.50, 0.26), g("warcaller", 9, 0.58, 0.31), g("regenerator", 9, 0.66, 0.71), g("bulwark", 10, 0.74, 1.02) },
		[19] = { g("bulwark", 5, 0.50), g("runner", 5, 0.50, 0.26), g("warcaller", 10, 0.50, 0.20), g("regenerator", 11, 0.54, 0.51), g("bulwark", 10, 0.61, 0.82), g("runner", 13, 0.68, 1.02) },
		[20] = { g("boss", 1, 0.00), g("bulwark", 5, 0.50, 1.94), g("runner", 5, 0.50, 2.21), g("warcaller", 9, 0.54, 2.16), g("regenerator", 10, 0.62, 2.48), g("bulwark", 10, 0.70, 2.70) },
	},
	crossflow = {
		-- orientation
		[1] = { g("grunt", 19, 0.56) },
		-- demonstration
		[2] = { g("bulwark", 6, 0.64), g("runner", 6, 0.51, 0.30) },
		-- demonstration
		[3] = { g("grunt", 14, 0.53), g("bulwark", 2, 0.63, 0.60), g("runner", 2, 0.50, 0.90) },
		-- practice
		[4] = { g("bulwark", 6, 0.51), g("runner", 7, 0.50, 0.30), g("grunt", 13, 0.50, 0.28) },
		-- practice
		[5] = { g("warcaller", 11, 0.55), g("bulwark", 4, 0.50, 0.23), g("runner", 4, 0.50, 0.53) },
		-- practice
		[6] = { g("bulwark", 6, 0.50), g("runner", 7, 0.50, 0.30), g("warcaller", 10, 0.50, 0.15), g("regenerator", 13, 0.57, 0.37) },
		-- mixed check
		[7] = { g("bulwark", 3, 0.50), g("runner", 4, 0.50, 0.30), g("warcaller", 7, 0.50, 0.08), g("regenerator", 7, 0.50, 0.23), g("bulwark", 8, 0.54, 0.37) },
		-- mixed check
		[8] = { g("bulwark", 4, 0.50), g("runner", 5, 0.50, 0.30), g("grunt", 8, 0.50, 0.08), g("tank", 9, 0.50, 0.19), g("runner", 10, 0.50, 0.33) },
		-- mixed check
		[9] = { g("bulwark", 3, 0.50), g("runner", 4, 0.50, 0.30), g("warcaller", 7, 0.50, 0.08), g("regenerator", 8, 0.50, 0.15), g("bulwark", 8, 0.50, 0.28), g("runner", 9, 0.50, 0.37) },
		-- final exam
		[10] = { g("boss", 1, 0.00), g("bulwark", 4, 0.50, 0.73), g("runner", 4, 0.50, 1.03), g("warcaller", 7, 0.50, 0.82), g("regenerator", 8, 0.50, 0.95), g("bulwark", 8, 0.52, 1.04) },
		[11] = { g("bulwark", 3, 0.50), g("runner", 4, 0.50, 0.33), g("warcaller", 8, 0.50, 0.09), g("regenerator", 8, 0.50, 0.25), g("bulwark", 9, 0.54, 0.41) },
		[12] = { g("bulwark", 7, 0.50), g("runner", 8, 0.50, 0.32), g("warcaller", 11, 0.50, 0.16), g("regenerator", 15, 0.57, 0.39) },
		[13] = { g("bulwark", 4, 0.50), g("runner", 6, 0.50, 0.30), g("grunt", 9, 0.50, 0.08), g("tank", 10, 0.50, 0.19), g("runner", 11, 0.50, 0.33) },
		[14] = { g("bulwark", 3, 0.50), g("runner", 5, 0.50, 0.28), g("warcaller", 8, 0.50, 0.08), g("regenerator", 8, 0.50, 0.22), g("bulwark", 9, 0.54, 0.35) },
		[15] = { g("bulwark", 3, 0.50), g("runner", 4, 0.50, 0.32), g("warcaller", 8, 0.50, 0.08), g("regenerator", 9, 0.50, 0.16), g("bulwark", 9, 0.50, 0.29), g("runner", 10, 0.50, 0.39) },
		[16] = { g("bulwark", 7, 0.50), g("runner", 9, 0.50, 0.27), g("warcaller", 12, 0.50, 0.14), g("regenerator", 16, 0.57, 0.33) },
		[17] = { g("bulwark", 5, 0.50), g("runner", 6, 0.50, 0.27), g("grunt", 10, 0.50, 0.07), g("tank", 11, 0.50, 0.17), g("runner", 12, 0.50, 0.30) },
		[18] = { g("bulwark", 4, 0.50), g("runner", 5, 0.50, 0.26), g("warcaller", 9, 0.50, 0.07), g("regenerator", 9, 0.50, 0.20), g("bulwark", 10, 0.54, 0.31) },
		[19] = { g("bulwark", 4, 0.50), g("runner", 5, 0.50, 0.26), g("warcaller", 9, 0.50, 0.07), g("regenerator", 10, 0.50, 0.13), g("bulwark", 10, 0.50, 0.24), g("runner", 11, 0.50, 0.31) },
		[20] = { g("boss", 1, 0.00), g("bulwark", 5, 0.50, 0.66), g("runner", 5, 0.50, 0.93), g("warcaller", 9, 0.50, 0.74), g("regenerator", 10, 0.50, 0.85), g("bulwark", 10, 0.52, 0.94) },
	},
	steppingstones = {
		-- orientation
		[1] = { g("grunt", 20, 0.80) },
		-- demonstration
		[2] = { g("bulwark", 6, 0.92), g("runner", 6, 0.74, 0.30) },
		-- demonstration
		[3] = { g("grunt", 14, 0.76), g("bulwark", 2, 0.90, 3.00), g("runner", 2, 0.72, 3.30) },
		-- practice
		[4] = { g("bulwark", 6, 0.73), g("runner", 7, 0.58, 0.30), g("grunt", 13, 0.63, 1.60) },
		-- practice
		[5] = { g("warcaller", 11, 0.78), g("bulwark", 4, 0.70, 1.40), g("runner", 5, 0.56, 1.70) },
		-- practice
		[6] = { g("bulwark", 5, 0.58), g("runner", 7, 0.50, 0.30), g("warcaller", 10, 0.70, 1.00), g("regenerator", 13, 0.81, 2.00) },
		-- mixed check
		[7] = { g("bulwark", 3, 0.54), g("runner", 4, 0.50, 0.30), g("warcaller", 7, 0.61, 0.95), g("regenerator", 7, 0.70, 1.75), g("bulwark", 8, 0.78, 2.35) },
		-- mixed check
		[8] = { g("grunt", 8, 0.50), g("tank", 8, 0.54, 0.95), g("runner", 9, 0.61, 1.55), g("bulwark", 10, 0.68, 2.15) },
		-- mixed check
		[9] = { g("bulwark", 4, 0.50), g("runner", 4, 0.50, 0.30), g("warcaller", 8, 0.51, 0.75), g("regenerator", 9, 0.58, 1.35), g("bulwark", 9, 0.64, 1.95), g("runner", 10, 0.72, 2.35) },
		-- final exam
		[10] = { g("boss", 1, 0.00), g("bulwark", 4, 0.50, 3.95), g("runner", 4, 0.50, 4.25), g("warcaller", 7, 0.58, 4.35), g("regenerator", 8, 0.66, 4.95), g("bulwark", 8, 0.74, 5.35) },
		[11] = { g("bulwark", 3, 0.54), g("runner", 4, 0.50, 0.33), g("warcaller", 8, 0.61, 1.04), g("regenerator", 8, 0.70, 1.93), g("bulwark", 9, 0.78, 2.59) },
		[12] = { g("bulwark", 6, 0.58), g("runner", 8, 0.50, 0.32), g("warcaller", 11, 0.70, 1.05), g("regenerator", 15, 0.81, 2.10) },
		[13] = { g("grunt", 9, 0.50), g("tank", 9, 0.54, 0.95), g("runner", 10, 0.61, 1.55), g("bulwark", 11, 0.68, 2.15) },
		[14] = { g("bulwark", 3, 0.54), g("runner", 5, 0.50, 0.28), g("warcaller", 8, 0.61, 0.90), g("regenerator", 8, 0.70, 1.66), g("bulwark", 9, 0.78, 2.23) },
		[15] = { g("bulwark", 4, 0.50), g("runner", 4, 0.50, 0.32), g("warcaller", 9, 0.51, 0.79), g("regenerator", 10, 0.58, 1.42), g("bulwark", 10, 0.64, 2.05), g("runner", 11, 0.72, 2.47) },
		[16] = { g("bulwark", 6, 0.58), g("runner", 9, 0.50, 0.27), g("warcaller", 12, 0.70, 0.90), g("regenerator", 16, 0.81, 1.80) },
		[17] = { g("grunt", 10, 0.50), g("tank", 10, 0.54, 0.85), g("runner", 11, 0.61, 1.40), g("bulwark", 12, 0.68, 1.94) },
		[18] = { g("bulwark", 4, 0.54), g("runner", 5, 0.50, 0.26), g("warcaller", 9, 0.61, 0.81), g("regenerator", 9, 0.70, 1.49), g("bulwark", 10, 0.78, 2.00) },
		[19] = { g("bulwark", 5, 0.50), g("runner", 5, 0.50, 0.26), g("warcaller", 10, 0.51, 0.64), g("regenerator", 11, 0.58, 1.15), g("bulwark", 11, 0.64, 1.66), g("runner", 13, 0.72, 2.00) },
		[20] = { g("boss", 1, 0.00), g("bulwark", 5, 0.50, 3.56), g("runner", 5, 0.50, 3.83), g("warcaller", 9, 0.58, 3.91), g("regenerator", 10, 0.66, 4.46), g("bulwark", 10, 0.74, 4.81) },
	},
	twinloop = {
		-- orientation
		[1] = { g("grunt", 20, 0.51) },
		-- demonstration
		[2] = { g("summoner", 3, 1.00) },
		-- demonstration
		[3] = { g("grunt", 10, 0.50), g("summoner", 2, 0.84, 0.93) },
		-- practice
		[4] = { g("bulwark", 6, 0.50), g("runner", 7, 0.50, 0.30), g("grunt", 13, 0.50, 0.50) },
		-- practice
		[5] = { g("warcaller", 11, 0.52), g("bulwark", 4, 0.50, 0.43), g("runner", 4, 0.50, 0.73) },
		-- practice
		[6] = { g("bulwark", 6, 0.50), g("runner", 7, 0.50, 0.30), g("warcaller", 10, 0.50, 0.31), g("regenerator", 13, 0.54, 0.62) },
		-- mixed check
		[7] = { g("bulwark", 3, 0.50), g("runner", 4, 0.50, 0.30), g("warcaller", 7, 0.50, 0.19), g("regenerator", 7, 0.50, 0.43), g("bulwark", 8, 0.52, 0.62) },
		-- mixed check
		[8] = { g("tank", 8, 0.50), g("runner", 7, 0.50, 0.19), g("bulwark", 8, 0.50, 0.37), g("regenerator", 10, 0.50, 0.56) },
		-- mixed check
		[9] = { g("bulwark", 3, 0.50), g("runner", 4, 0.50, 0.30), g("warcaller", 7, 0.50, 0.12), g("regenerator", 8, 0.50, 0.31), g("bulwark", 8, 0.50, 0.50), g("runner", 9, 0.50, 0.62) },
		-- final exam
		[10] = { g("boss", 1, 0.00), g("bulwark", 4, 0.50, 1.12), g("runner", 4, 0.50, 1.42), g("warcaller", 7, 0.50, 1.24), g("regenerator", 8, 0.50, 1.43), g("bulwark", 7, 0.50, 1.55) },
		[11] = { g("bulwark", 3, 0.50), g("runner", 4, 0.50, 0.33), g("warcaller", 8, 0.50, 0.21), g("regenerator", 8, 0.50, 0.47), g("bulwark", 9, 0.52, 0.68) },
		[12] = { g("bulwark", 7, 0.50), g("runner", 8, 0.50, 0.32), g("warcaller", 11, 0.50, 0.33), g("regenerator", 15, 0.54, 0.65) },
		[13] = { g("tank", 9, 0.50), g("runner", 8, 0.50, 0.19), g("bulwark", 9, 0.50, 0.37), g("regenerator", 11, 0.50, 0.56) },
		[14] = { g("bulwark", 3, 0.50), g("runner", 5, 0.50, 0.28), g("warcaller", 8, 0.50, 0.18), g("regenerator", 8, 0.50, 0.41), g("bulwark", 9, 0.52, 0.59) },
		[15] = { g("bulwark", 3, 0.50), g("runner", 4, 0.50, 0.32), g("warcaller", 8, 0.50, 0.13), g("regenerator", 9, 0.50, 0.33), g("bulwark", 9, 0.50, 0.53), g("runner", 10, 0.50, 0.65) },
		[16] = { g("bulwark", 7, 0.50), g("runner", 9, 0.50, 0.27), g("warcaller", 12, 0.50, 0.28), g("regenerator", 16, 0.54, 0.56) },
		[17] = { g("tank", 10, 0.50), g("runner", 8, 0.50, 0.17), g("bulwark", 10, 0.50, 0.33), g("regenerator", 12, 0.50, 0.50) },
		[18] = { g("bulwark", 4, 0.50), g("runner", 5, 0.50, 0.26), g("warcaller", 9, 0.50, 0.16), g("regenerator", 9, 0.50, 0.37), g("bulwark", 10, 0.52, 0.53) },
		[19] = { g("bulwark", 4, 0.50), g("runner", 5, 0.50, 0.26), g("warcaller", 9, 0.50, 0.10), g("regenerator", 10, 0.50, 0.26), g("bulwark", 10, 0.50, 0.42), g("runner", 11, 0.50, 0.53) },
		[20] = { g("boss", 1, 0.00), g("bulwark", 5, 0.50, 1.01), g("runner", 5, 0.50, 1.28), g("warcaller", 9, 0.50, 1.12), g("regenerator", 10, 0.50, 1.29), g("bulwark", 9, 0.50, 1.40) },
	},
}


-- Boss selections remain explicit because they affect the spawned enemy type.
local bossArchetypeByMapId = {
	riverbend = "boss_summoner",
	switchback = "boss_summoner",
	highpass = "boss_summoner",
	roundabout = "boss_displacement",
	gauntlet = "boss_suppression",
	snaketrail = "boss_summoner",
	backtrack = "boss_displacement",
	lowvalley = "boss_suppression",
	circuit = "boss_aegis",
	outerloop = "boss_ravager",
	terrace = "boss_summoner",
	highridge = "boss_aegis",
	crossflow = "boss_ravager",
	steppingstones = "boss_displacement",
	twinloop = "boss_summoner",
}

for mapId, bossArchetype in pairs(bossArchetypeByMapId) do
	wavesByMapId[mapId][10].bossArchetype = bossArchetype
	wavesByMapId[mapId][20].bossArchetype = bossArchetype
end

local function mapIdOf(mapOrId)
	if type(mapOrId) == "table" then return mapOrId.id end
	if type(mapOrId) == "string" then return mapOrId end
	return nil
end

function CampaignWaveDefs.get(mapOrId, waveIndex)
	local waves = wavesByMapId[mapIdOf(mapOrId)]
	if not waves then return nil end
	waveIndex = math.max(1, math.floor(tonumber(waveIndex) or 1))
	local groups = waves[waveIndex]
	if not groups then return nil end

	local count = 0
	for _, group in ipairs(groups) do
		count = count + group.count
	end

	return {
		boss = groups[1].kind == "boss",
		bossArchetype = groups.bossArchetype,
		count = count,
		groups = groups,
	}
end

function CampaignWaveDefs.getFinalWave(mapOrId)
	local waves = wavesByMapId[mapIdOf(mapOrId)]
	return waves and #waves or nil
end

-- Authored groups are the honest campaign kill target: spawned adds and any
-- future procedural enemies are intentionally not folded into this summary.
function CampaignWaveDefs.getTotalEnemyCount(mapOrId)
	local waves = wavesByMapId[mapIdOf(mapOrId)]
	if not waves then return nil end
	local total = 0
	for _, wave in ipairs(waves) do
		for _, group in ipairs(wave) do
			total = total + math.max(0, tonumber(group.count) or 0)
		end
	end
	return total
end

CampaignWaveDefs.pacingIdentityByMapId = pacingIdentityByMapId
CampaignWaveDefs.pacingTargetsByMapId = pacingTargetsByMapId

return CampaignWaveDefs

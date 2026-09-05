-- Fixed campaign encounters are indexed by map ID. They deliberately contain only
-- enemy kinds, counts, and timing.
local CampaignWaveDefs = {}

-- A wave is written as a short list of spawn groups. Delay is the pause after
-- the previous group, so the common case (start immediately) can omit it.
local function g(kind, count, spacing, delay)
	return { kind = kind, count = count, spacing = spacing, delay = delay or 0 }
end

-- The authored table stays private; callers receive the small runtime wave shape
-- returned by get() rather than depending on its storage details.
local wavesByMapId = {
	riverbend = {
		-- 8 grunts.
		[1] = { g("grunt", 8, 0.90) },
		-- 12 grunts.
		[2] = { g("grunt", 12, 0.72) },
		-- 10 grunts followed by 8 grunts.
		[3] = { g("grunt", 10, 0.62), g("grunt", 8, 0.58, 1.4) },
		-- 20 grunts.
		[4] = { g("grunt", 20, 0.50) },
		-- 24 grunts.
		[5] = { g("grunt", 24, 0.50) },
		-- 16 grunts followed by 10 grunts.
		[6] = { g("grunt", 16, 0.50), g("grunt", 10, 0.50, 0.65) },
		-- 14 grunts followed by 14 grunts.
		[7] = { g("grunt", 14, 0.50), g("grunt", 14, 0.50, 0.30) },
		-- 13 grunts, then 9 grunts, and 8 grunts.
		[8] = { g("grunt", 13, 0.50), g("grunt", 9, 0.50, 0.15), g("grunt", 8, 0.50, 0.12) },
		-- 13 grunts, then 10 grunts, and 9 grunts.
		[9] = { g("grunt", 13, 0.50), g("grunt", 10, 0.50, 0.08), g("grunt", 9, 0.50, 0.08) },
		-- 1 boss, then 12 grunts, then 13 grunts, and 9 grunts.
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
		-- 10 grunts.
		[1] = { g("grunt", 10, 0.87) },
		-- 12 tanks.
		[2] = { g("tank", 12, 0.76) },
		-- 11 grunts followed by 8 tanks.
		[3] = { g("grunt", 11, 0.61), g("tank", 8, 0.64, 1.75) },
		-- 19 tanks.
		[4] = { g("tank", 19, 0.55) },
		-- 23 tanks.
		[5] = { g("tank", 23, 0.55) },
		-- 16 grunts followed by 10 tanks.
		[6] = { g("grunt", 16, 0.50), g("tank", 10, 0.55, 0.81) },
		-- 13 grunts followed by 14 tanks.
		[7] = { g("grunt", 13, 0.50), g("tank", 14, 0.55, 0.38) },
		-- 13 grunts, then 8 tanks, and 7 grunts.
		[8] = { g("grunt", 13, 0.50), g("tank", 8, 0.55, 0.19), g("grunt", 7, 0.50, 0.15) },
		-- 12 grunts, then 10 tanks, and 9 grunts.
		[9] = { g("grunt", 12, 0.50), g("tank", 10, 0.55, 0.10), g("grunt", 9, 0.50, 0.10) },
		-- 1 boss, then 11 grunts, then 12 tanks, and 9 grunts.
		[10] = { g("boss", 1, 0.00), g("grunt", 11, 0.50, 1.25), g("tank", 12, 0.55, 0.44), g("grunt", 9, 0.50, 0.31) },
		[11] = { g("grunt", 14, 0.50), g("tank", 15, 0.55, 0.42) },
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
		-- 10 grunts.
		[1] = { g("grunt", 10, 1.03) },
		-- 12 runners.
		[2] = { g("runner", 12, 0.85) },
		-- 12 grunts followed by 8 runners.
		[3] = { g("grunt", 12, 0.73), g("runner", 8, 0.71, 1.47) },
		-- 18 runners.
		[4] = { g("runner", 18, 0.57) },
		-- 22 runners.
		[5] = { g("runner", 22, 0.51) },
		-- 15 grunts followed by 9 runners.
		[6] = { g("grunt", 15, 0.52), g("runner", 9, 0.50, 0.68) },
		-- 12 grunts followed by 13 tanks.
		[7] = { g("grunt", 12, 0.50), g("tank", 13, 0.55, 0.32) },
		-- 12 grunts, then 8 runners, and 6 grunts.
		[8] = { g("grunt", 12, 0.50), g("runner", 8, 0.50, 0.16), g("grunt", 6, 0.50, 0.13) },
		-- 11 grunts, then 10 runners, and 8 grunts.
		[9] = { g("grunt", 11, 0.50), g("runner", 10, 0.50, 0.08), g("grunt", 8, 0.50, 0.08) },
		-- 1 boss, then 11 grunts, then 12 grunts, and 8 grunts.
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
		-- 11 grunts.
		[1] = { g("grunt", 11, 0.75) },
		-- 13 grunts.
		[2] = { g("grunt", 13, 0.63) },
		-- 12 grunts followed by 8 grunts.
		[3] = { g("grunt", 12, 0.55), g("grunt", 8, 0.53, 0.69) },
		-- 18 grunts.
		[4] = { g("grunt", 18, 0.50) },
		-- 22 grunts.
		[5] = { g("grunt", 22, 0.50) },
		-- 15 grunts followed by 9 grunts.
		[6] = { g("grunt", 15, 0.50), g("grunt", 9, 0.50, 0.28) },
		-- 12 grunts followed by 13 grunts.
		[7] = { g("grunt", 12, 0.50), g("grunt", 13, 0.50, 0.09) },
		-- 12 grunts, then 8 grunts, and 7 grunts.
		[8] = { g("grunt", 12, 0.50), g("grunt", 8, 0.50, 0.08), g("grunt", 7, 0.50, 0.08) },
		-- 10 grunts, then 9 grunts, and 9 grunts.
		[9] = { g("grunt", 10, 0.50), g("grunt", 9, 0.50, 0.08), g("grunt", 9, 0.50, 0.08) },
		-- 1 boss, then 11 grunts, then 11 grunts, and 8 grunts.
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
		-- 12 grunts.
		[1] = { g("grunt", 12, 0.60) },
		-- 13 grunts.
		[2] = { g("grunt", 13, 0.52) },
		-- 13 grunts followed by 8 grunts.
		[3] = { g("grunt", 13, 0.50), g("grunt", 8, 0.50, 2.94) },
		-- 18 grunts.
		[4] = { g("grunt", 18, 0.50) },
		-- 22 grunts.
		[5] = { g("grunt", 22, 0.50) },
		-- 15 grunts followed by 9 grunts.
		[6] = { g("grunt", 15, 0.50), g("grunt", 9, 0.50, 1.37) },
		-- 12 grunts followed by 13 grunts.
		[7] = { g("grunt", 12, 0.50), g("grunt", 13, 0.50, 0.98) },
		-- 12 grunts, then 8 grunts, and 6 grunts.
		[8] = { g("grunt", 12, 0.50), g("grunt", 8, 0.50, 0.67), g("grunt", 6, 0.50, 0.60) },
		-- 10 grunts, then 9 grunts, and 8 grunts.
		[9] = { g("grunt", 10, 0.50), g("grunt", 9, 0.50, 0.52), g("grunt", 8, 0.50, 0.52) },
		-- 1 boss, then 10 grunts, then 11 grunts, and 9 grunts.
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
		-- 17 grunts.
		[1] = { g("grunt", 17, 0.90) },
		-- 10 tanks.
		[2] = { g("tank", 10, 0.94) },
		-- 15 grunts followed by 5 tanks.
		[3] = { g("grunt", 15, 0.73), g("tank", 5, 0.92, 1.88) },
		-- 11 tanks followed by 14 grunts.
		[4] = { g("tank", 11, 0.75), g("grunt", 14, 0.60, 1.00) },
		-- 11 grunts followed by 9 tanks.
		[5] = { g("grunt", 11, 0.76), g("tank", 9, 0.72, 0.88) },
		-- 10 tanks followed by 13 grunts.
		[6] = { g("tank", 10, 0.61), g("grunt", 13, 0.67, 0.62) },
		-- 7 tanks followed by 8 grunts.
		[7] = { g("tank", 7, 0.57), g("grunt", 8, 0.59, 0.38) },
		-- 9 grunts followed by 9 tanks.
		[8] = { g("grunt", 9, 0.50), g("tank", 9, 0.58, 0.38) },
		-- 8 tanks followed by 9 grunts.
		[9] = { g("tank", 8, 0.55), g("grunt", 9, 0.50, 0.25) },
		-- 1 boss, then 8 tanks, and 8 grunts.
		[10] = { g("boss", 1, 0.00), g("tank", 8, 0.55, 2.25), g("grunt", 8, 0.55, 2.50) },
		[11] = { g("tank", 8, 0.57), g("grunt", 9, 0.59, 0.42) },
		[12] = { g("tank", 11, 0.61), g("grunt", 15, 0.67, 0.65) },
		[13] = { g("grunt", 10, 0.50), g("tank", 10, 0.58, 0.38) },
		[14] = { g("tank", 8, 0.57), g("grunt", 9, 0.59, 0.36) },
		[15] = { g("tank", 9, 0.55), g("grunt", 10, 0.50, 0.26) },
		[16] = { g("tank", 12, 0.61), g("grunt", 16, 0.67, 0.56) },
		[17] = { g("grunt", 11, 0.50), g("tank", 11, 0.58, 0.34) },
		[18] = { g("tank", 9, 0.57), g("grunt", 10, 0.59, 0.32) },
		[19] = { g("tank", 10, 0.55), g("grunt", 11, 0.50, 0.21) },
		[20] = { g("boss", 1, 0.00), g("tank", 10, 0.55, 2.02), g("grunt", 10, 0.55, 2.25) },
	},
	backtrack = {
		-- 17 grunts.
		[1] = { g("grunt", 17, 0.70) },
		-- 10 runners.
		[2] = { g("runner", 10, 0.71) },
		-- 14 grunts followed by 5 runners.
		[3] = { g("grunt", 14, 0.58), g("runner", 5, 0.69, 1.12) },
		-- 11 runners followed by 14 grunts.
		[4] = { g("runner", 11, 0.56), g("grunt", 14, 0.50, 0.60) },
		-- 11 tanks followed by 8 runners.
		[5] = { g("tank", 11, 0.65), g("runner", 8, 0.53, 0.52) },
		-- 10 runners, then 10 tanks, and 14 grunts.
		[6] = { g("runner", 10, 0.50), g("tank", 10, 0.58, 0.38), g("grunt", 14, 0.63, 0.75) },
		-- 6 runners, then 8 tanks, and 8 grunts.
		[7] = { g("runner", 6, 0.50), g("tank", 8, 0.55, 0.22), g("grunt", 8, 0.53, 0.52) },
		-- 8 tanks, then 8 runners, and 10 grunts.
		[8] = { g("tank", 8, 0.55), g("runner", 8, 0.50, 0.22), g("grunt", 10, 0.50, 0.45) },
		-- 7 runners, then 8 tanks, and 10 grunts.
		[9] = { g("runner", 7, 0.50), g("tank", 8, 0.55, 0.15), g("grunt", 10, 0.50, 0.38) },
		-- 1 boss, then 7 runners, then 7 tanks, and 8 grunts.
		[10] = { g("boss", 1, 0.00), g("runner", 7, 0.50, 1.35), g("tank", 7, 0.55, 1.50), g("grunt", 8, 0.50, 1.72) },
		[11] = { g("runner", 6, 0.50), g("tank", 9, 0.55, 0.24), g("grunt", 9, 0.53, 0.57) },
		[12] = { g("runner", 11, 0.50), g("tank", 11, 0.58, 0.40), g("grunt", 16, 0.63, 0.79) },
		[13] = { g("tank", 9, 0.55), g("runner", 9, 0.50, 0.22), g("grunt", 11, 0.50, 0.45) },
		[14] = { g("runner", 7, 0.50), g("tank", 9, 0.55, 0.21), g("grunt", 9, 0.53, 0.49) },
		[15] = { g("runner", 8, 0.50), g("tank", 9, 0.55, 0.16), g("grunt", 11, 0.50, 0.40) },
		[16] = { g("runner", 12, 0.50), g("tank", 12, 0.58, 0.34), g("grunt", 17, 0.63, 0.68) },
		[17] = { g("tank", 10, 0.55), g("runner", 10, 0.50, 0.20), g("grunt", 12, 0.50, 0.41) },
		[18] = { g("runner", 8, 0.50), g("tank", 10, 0.55, 0.19), g("grunt", 10, 0.53, 0.44) },
		[19] = { g("runner", 9, 0.50), g("tank", 10, 0.55, 0.13), g("grunt", 13, 0.50, 0.32) },
		[20] = { g("boss", 1, 0.00), g("runner", 9, 0.50, 1.22), g("tank", 9, 0.55, 1.35), g("grunt", 10, 0.50, 1.55) },
	},
	lowvalley = {
		-- 17 grunts.
		[1] = { g("grunt", 17, 0.82) },
		-- 9 bulwarks.
		[2] = { g("bulwark", 9, 0.94) },
		-- 13 grunts followed by 4 bulwarks.
		[3] = { g("grunt", 13, 0.69), g("bulwark", 4, 0.92, 2.17) },
		-- 10 bulwarks followed by 13 grunts.
		[4] = { g("bulwark", 10, 0.76), g("grunt", 13, 0.57, 1.16) },
		-- 10 runners followed by 8 bulwarks.
		[5] = { g("runner", 10, 0.71), g("bulwark", 8, 0.73, 1.01) },
		-- 10 bulwarks, then 9 runners, and 13 tanks.
		[6] = { g("bulwark", 10, 0.63), g("runner", 9, 0.63, 0.72), g("tank", 13, 0.79, 1.45) },
		-- 6 bulwarks, then 7 runners, then 7 tanks, and 9 grunts.
		[7] = { g("bulwark", 6, 0.60), g("runner", 7, 0.56, 0.43), g("tank", 7, 0.68, 1.01), g("grunt", 9, 0.71, 1.45) },
		-- 8 grunts, then 8 tanks, then 9 runners, and 11 bulwarks.
		[8] = { g("grunt", 8, 0.50), g("tank", 8, 0.55, 0.43), g("runner", 9, 0.56, 0.87), g("bulwark", 11, 0.72, 1.30) },
		-- 7 bulwarks, then 8 runners, then 9 tanks, and 9 grunts.
		[9] = { g("bulwark", 7, 0.60), g("runner", 8, 0.50, 0.29), g("tank", 9, 0.57, 0.72), g("grunt", 9, 0.59, 1.16) },
		-- 1 boss, then 7 bulwarks, then 7 runners, then 8 tanks, and 8 grunts.
		[10] = { g("boss", 1, 0.00), g("bulwark", 7, 0.60, 2.61), g("runner", 7, 0.52, 2.90), g("tank", 8, 0.65, 3.33), g("grunt", 8, 0.67, 3.62) },
		[11] = { g("bulwark", 6, 0.60), g("runner", 8, 0.56, 0.47), g("tank", 8, 0.68, 1.11), g("grunt", 10, 0.71, 1.59) },
		[12] = { g("bulwark", 11, 0.63), g("runner", 10, 0.63, 0.76), g("tank", 15, 0.79, 1.52) },
		[13] = { g("grunt", 9, 0.50), g("tank", 9, 0.55, 0.43), g("runner", 10, 0.56, 0.87), g("bulwark", 12, 0.72, 1.30) },
		[14] = { g("bulwark", 7, 0.60), g("runner", 8, 0.56, 0.41), g("tank", 8, 0.68, 0.96), g("grunt", 10, 0.71, 1.38) },
		[15] = { g("bulwark", 8, 0.60), g("runner", 9, 0.50, 0.30), g("tank", 10, 0.57, 0.76), g("grunt", 10, 0.59, 1.22) },
		[16] = { g("bulwark", 12, 0.63), g("runner", 11, 0.63, 0.65), g("tank", 16, 0.79, 1.30) },
		[17] = { g("grunt", 10, 0.50), g("tank", 10, 0.55, 0.39), g("runner", 11, 0.56, 0.78), g("bulwark", 13, 0.72, 1.17) },
		[18] = { g("bulwark", 8, 0.60), g("runner", 9, 0.56, 0.37), g("tank", 9, 0.68, 0.86), g("grunt", 12, 0.71, 1.23) },
		[19] = { g("bulwark", 9, 0.60), g("runner", 10, 0.50, 0.25), g("tank", 11, 0.57, 0.61), g("grunt", 11, 0.59, 0.99) },
		[20] = { g("boss", 1, 0.00), g("bulwark", 9, 0.60, 2.35), g("runner", 9, 0.52, 2.61), g("tank", 10, 0.65, 3.00), g("grunt", 10, 0.67, 3.26) },
	},
	circuit = {
		-- 17 grunts.
		[1] = { g("grunt", 17, 0.70) },
		-- 9 regenerators.
		[2] = { g("regenerator", 9, 0.84) },
		-- 13 grunts followed by 4 regenerators.
		[3] = { g("grunt", 13, 0.61), g("regenerator", 4, 0.83, 0.98) },
		-- 10 regenerators followed by 13 grunts.
		[4] = { g("regenerator", 10, 0.69), g("grunt", 13, 0.50, 0.52) },
		-- 10 bulwarks followed by 7 regenerators.
		[5] = { g("bulwark", 10, 0.73), g("regenerator", 7, 0.66, 0.45) },
		-- 10 regenerators, then 9 bulwarks, and 13 runners.
		[6] = { g("regenerator", 10, 0.60), g("bulwark", 9, 0.66, 0.33), g("runner", 13, 0.65, 0.65) },
		-- 6 regenerators, then 7 bulwarks, then 7 runners, and 8 tanks.
		[7] = { g("regenerator", 6, 0.60), g("bulwark", 7, 0.60, 0.20), g("runner", 7, 0.56, 0.45), g("tank", 8, 0.68, 0.65) },
		-- 8 regenerators, then 8 grunts, then 9 tanks, and 10 runners.
		[8] = { g("regenerator", 8, 0.60), g("grunt", 8, 0.50, 0.20), g("tank", 9, 0.55, 0.39), g("runner", 10, 0.55, 0.59) },
		-- 6 regenerators, then 7 bulwarks, then 9 runners, then 9 tanks, and 10 grunts.
		[9] = { g("regenerator", 6, 0.60), g("bulwark", 7, 0.60, 0.13), g("runner", 9, 0.50, 0.33), g("tank", 9, 0.57, 0.52), g("grunt", 10, 0.57, 0.65) },
		-- 1 boss, then 6 regenerators, then 7 bulwarks, then 8 runners, and 8 tanks.
		[10] = { g("boss", 1, 0.00), g("regenerator", 6, 0.60, 1.17), g("bulwark", 7, 0.60, 1.30), g("runner", 8, 0.53, 1.49), g("tank", 8, 0.65, 1.62) },
		[11] = { g("regenerator", 6, 0.60), g("bulwark", 8, 0.60, 0.22), g("runner", 8, 0.56, 0.50), g("tank", 9, 0.68, 0.72) },
		[12] = { g("regenerator", 11, 0.60), g("bulwark", 10, 0.66, 0.35), g("runner", 15, 0.65, 0.68) },
		[13] = { g("regenerator", 9, 0.60), g("grunt", 9, 0.50, 0.20), g("tank", 10, 0.55, 0.39), g("runner", 11, 0.55, 0.59) },
		[14] = { g("regenerator", 7, 0.60), g("bulwark", 8, 0.60, 0.19), g("runner", 8, 0.56, 0.43), g("tank", 9, 0.68, 0.62) },
		[15] = { g("regenerator", 7, 0.60), g("bulwark", 8, 0.60, 0.14), g("runner", 10, 0.50, 0.35), g("tank", 10, 0.57, 0.55), g("grunt", 11, 0.57, 0.68) },
		[16] = { g("regenerator", 12, 0.60), g("bulwark", 11, 0.66, 0.30), g("runner", 16, 0.65, 0.59) },
		[17] = { g("regenerator", 10, 0.60), g("grunt", 10, 0.50, 0.18), g("tank", 11, 0.55, 0.35), g("runner", 12, 0.55, 0.53) },
		[18] = { g("regenerator", 8, 0.60), g("bulwark", 9, 0.60, 0.17), g("runner", 9, 0.56, 0.38), g("tank", 10, 0.68, 0.55) },
		[19] = { g("regenerator", 8, 0.60), g("bulwark", 9, 0.60, 0.11), g("runner", 11, 0.50, 0.28), g("tank", 11, 0.57, 0.44), g("grunt", 13, 0.57, 0.55) },
		[20] = { g("boss", 1, 0.00), g("regenerator", 8, 0.60, 1.05), g("bulwark", 9, 0.60, 1.17), g("runner", 10, 0.53, 1.34), g("tank", 10, 0.65, 1.46) },
	},
	outerloop = {
		-- 17 grunts.
		[1] = { g("grunt", 17, 0.89) },
		-- 9 regenerators.
		[2] = { g("regenerator", 9, 1.04) },
		-- 13 grunts followed by 4 regenerators.
		[3] = { g("grunt", 13, 0.78), g("regenerator", 4, 1.03, 2.55) },
		-- 10 regenerators followed by 13 grunts.
		[4] = { g("regenerator", 10, 0.85), g("grunt", 13, 0.64, 1.36) },
		-- 10 bulwarks followed by 7 regenerators.
		[5] = { g("bulwark", 10, 0.90), g("regenerator", 7, 0.81, 1.19) },
		-- 10 regenerators, then 9 bulwarks, and 13 runners.
		[6] = { g("regenerator", 10, 0.70), g("bulwark", 9, 0.81, 0.85), g("runner", 13, 0.84, 1.70) },
		-- 6 regenerators, then 7 bulwarks, then 7 runners, and 8 tanks.
		[7] = { g("regenerator", 6, 0.65), g("bulwark", 7, 0.73, 0.51), g("runner", 7, 0.71, 1.19), g("tank", 8, 0.85, 1.70) },
		-- 8 grunts, then 8 tanks, then 9 runners, and 10 bulwarks.
		[8] = { g("grunt", 8, 0.50), g("tank", 8, 0.61, 0.51), g("runner", 9, 0.63, 1.02), g("bulwark", 10, 0.80, 1.53) },
		-- 7 regenerators, then 8 bulwarks, then 9 runners, then 9 tanks, and 10 grunts.
		[9] = { g("regenerator", 7, 0.60), g("bulwark", 8, 0.62, 0.34), g("runner", 9, 0.59, 0.85), g("tank", 9, 0.71, 1.36), g("grunt", 10, 0.73, 1.70) },
		-- 1 boss, then 7 regenerators, then 7 bulwarks, then 8 runners, and 8 tanks.
		[10] = { g("boss", 1, 0.00), g("regenerator", 7, 0.61, 3.06), g("bulwark", 7, 0.69, 3.40), g("runner", 8, 0.67, 3.91), g("tank", 8, 0.81, 4.25) },
		[11] = { g("regenerator", 6, 0.65), g("bulwark", 8, 0.73, 0.56), g("runner", 8, 0.71, 1.31), g("tank", 9, 0.85, 1.87) },
		[12] = { g("regenerator", 11, 0.70), g("bulwark", 10, 0.81, 0.89), g("runner", 15, 0.84, 1.78) },
		[13] = { g("grunt", 9, 0.50), g("tank", 9, 0.61, 0.51), g("runner", 10, 0.63, 1.02), g("bulwark", 11, 0.80, 1.53) },
		[14] = { g("regenerator", 7, 0.65), g("bulwark", 8, 0.73, 0.48), g("runner", 8, 0.71, 1.13), g("tank", 9, 0.85, 1.61) },
		[15] = { g("regenerator", 8, 0.60), g("bulwark", 9, 0.62, 0.36), g("runner", 10, 0.59, 0.89), g("tank", 10, 0.71, 1.43), g("grunt", 11, 0.73, 1.78) },
		[16] = { g("regenerator", 12, 0.70), g("bulwark", 11, 0.81, 0.77), g("runner", 16, 0.84, 1.53) },
		[17] = { g("grunt", 10, 0.50), g("tank", 10, 0.61, 0.46), g("runner", 11, 0.63, 0.92), g("bulwark", 12, 0.80, 1.38) },
		[18] = { g("regenerator", 8, 0.65), g("bulwark", 9, 0.73, 0.43), g("runner", 9, 0.71, 1.01), g("tank", 10, 0.85, 1.44) },
		[19] = { g("regenerator", 9, 0.60), g("bulwark", 10, 0.62, 0.29), g("runner", 11, 0.59, 0.72), g("tank", 11, 0.71, 1.16), g("grunt", 13, 0.73, 1.44) },
		[20] = { g("boss", 1, 0.00), g("regenerator", 9, 0.61, 2.75), g("bulwark", 9, 0.69, 3.06), g("runner", 10, 0.67, 3.52), g("tank", 10, 0.81, 3.83) },
	},
	terrace = {
		-- 17 grunts.
		[1] = { g("grunt", 17, 0.61) },
		-- 9 warcallers.
		[2] = { g("warcaller", 9, 0.67) },
		-- 13 grunts followed by 4 warcallers.
		[3] = { g("grunt", 13, 0.56), g("warcaller", 4, 0.66, 1.08) },
		-- 10 warcallers followed by 13 grunts.
		[4] = { g("warcaller", 10, 0.53), g("grunt", 13, 0.50, 0.58) },
		-- 10 regenerators followed by 7 warcallers.
		[5] = { g("regenerator", 10, 0.67), g("warcaller", 7, 0.51, 0.50) },
		-- 10 warcallers, then 9 regenerators, and 13 bulwarks.
		[6] = { g("warcaller", 10, 0.50), g("regenerator", 9, 0.61, 0.36), g("bulwark", 13, 0.70, 0.72) },
		-- 6 warcallers, then 7 regenerators, then 7 bulwarks, and 8 runners.
		[7] = { g("warcaller", 6, 0.50), g("regenerator", 7, 0.60, 0.22), g("bulwark", 7, 0.61, 0.50), g("runner", 8, 0.57, 0.72) },
		-- 8 warcallers, then 7 grunts, then 9 tanks, and 10 runners.
		[8] = { g("warcaller", 8, 0.50), g("grunt", 7, 0.50, 0.22), g("tank", 9, 0.55, 0.43), g("runner", 10, 0.50, 0.65) },
		-- 6 warcallers, then 7 regenerators, then 8 bulwarks, then 8 runners, and 9 tanks.
		[9] = { g("warcaller", 6, 0.50), g("regenerator", 7, 0.60, 0.14), g("bulwark", 8, 0.60, 0.36), g("runner", 8, 0.50, 0.58), g("tank", 9, 0.57, 0.72) },
		-- 1 boss, then 6 warcallers, then 7 regenerators, then 8 bulwarks, and 7 runners.
		[10] = { g("boss", 1, 0.00), g("warcaller", 6, 0.50, 1.30), g("regenerator", 7, 0.60, 1.44), g("bulwark", 8, 0.60, 1.66), g("runner", 7, 0.54, 1.80) },
		[11] = { g("warcaller", 6, 0.50), g("regenerator", 8, 0.60, 0.24), g("bulwark", 8, 0.61, 0.55), g("runner", 9, 0.57, 0.79) },
		[12] = { g("warcaller", 11, 0.50), g("regenerator", 10, 0.61, 0.38), g("bulwark", 15, 0.70, 0.76) },
		[13] = { g("warcaller", 9, 0.50), g("grunt", 8, 0.50, 0.22), g("tank", 10, 0.55, 0.43), g("runner", 11, 0.50, 0.65) },
		[14] = { g("warcaller", 7, 0.50), g("regenerator", 8, 0.60, 0.21), g("bulwark", 8, 0.61, 0.47), g("runner", 9, 0.57, 0.68) },
		[15] = { g("warcaller", 7, 0.50), g("regenerator", 8, 0.60, 0.15), g("bulwark", 9, 0.60, 0.38), g("runner", 9, 0.50, 0.61), g("tank", 10, 0.57, 0.76) },
		[16] = { g("warcaller", 12, 0.50), g("regenerator", 11, 0.61, 0.32), g("bulwark", 16, 0.70, 0.65) },
		[17] = { g("warcaller", 10, 0.50), g("grunt", 8, 0.50, 0.20), g("tank", 11, 0.55, 0.39), g("runner", 12, 0.50, 0.59) },
		[18] = { g("warcaller", 8, 0.50), g("regenerator", 9, 0.60, 0.19), g("bulwark", 9, 0.61, 0.42), g("runner", 10, 0.57, 0.61) },
		[19] = { g("warcaller", 8, 0.50), g("regenerator", 9, 0.60, 0.12), g("bulwark", 10, 0.60, 0.31), g("runner", 10, 0.50, 0.49), g("tank", 11, 0.57, 0.61) },
		[20] = { g("boss", 1, 0.00), g("warcaller", 8, 0.50, 1.17), g("regenerator", 9, 0.60, 1.30), g("bulwark", 10, 0.60, 1.49), g("runner", 9, 0.54, 1.62) },
	},
	highridge = {
		-- 17 grunts.
		[1] = { g("grunt", 17, 0.78) },
		-- 6 bulwarks followed by 6 runners.
		[2] = { g("bulwark", 6, 0.97), g("runner", 6, 0.70, 0.30) },
		-- 13 grunts, then 2 bulwarks, and 2 runners.
		[3] = { g("grunt", 13, 0.72), g("bulwark", 2, 0.96, 1.80), g("runner", 2, 0.69, 2.10) },
		-- 6 bulwarks, then 6 runners, and 13 grunts.
		[4] = { g("bulwark", 6, 0.79), g("runner", 6, 0.55, 0.30), g("grunt", 13, 0.59, 0.96) },
		-- 10 warcallers, then 4 bulwarks, and 4 runners.
		[5] = { g("warcaller", 10, 0.74), g("bulwark", 4, 0.76, 0.84), g("runner", 4, 0.53, 1.14) },
		-- 6 bulwarks, then 6 runners, then 10 warcallers, and 13 regenerators.
		[6] = { g("bulwark", 6, 0.65), g("runner", 6, 0.50, 0.30), g("warcaller", 10, 0.66, 0.60), g("regenerator", 13, 0.87, 1.20) },
		-- 3 bulwarks, then 4 runners, then 7 warcallers, then 7 regenerators, and 8 bulwarks.
		[7] = { g("bulwark", 3, 0.61), g("runner", 4, 0.50, 0.30), g("warcaller", 7, 0.58, 0.36), g("regenerator", 7, 0.76, 0.84), g("bulwark", 8, 0.84, 1.20) },
		-- 8 warcallers, then 4 bulwarks, then 5 runners, then 9 grunts, and 10 tanks.
		[8] = { g("warcaller", 8, 0.50), g("bulwark", 4, 0.62, 0.36), g("runner", 5, 0.50, 0.66), g("grunt", 9, 0.58, 0.72), g("tank", 10, 0.69, 1.08) },
		-- 4 bulwarks, then 4 runners, then 8 warcallers, then 9 regenerators, then 8 bulwarks, and 10 runners.
		[9] = { g("bulwark", 4, 0.60), g("runner", 4, 0.50, 0.30), g("warcaller", 8, 0.50, 0.24), g("regenerator", 9, 0.64, 0.60), g("bulwark", 8, 0.71, 0.96), g("runner", 10, 0.68, 1.20) },
		-- 1 boss, then 4 bulwarks, then 4 runners, then 7 warcallers, then 8 regenerators, and 8 bulwarks.
		[10] = { g("boss", 1, 0.00), g("bulwark", 4, 0.60, 2.16), g("runner", 4, 0.50, 2.46), g("warcaller", 7, 0.54, 2.40), g("regenerator", 8, 0.72, 2.76), g("bulwark", 8, 0.80, 3.00) },
		[11] = { g("bulwark", 3, 0.61), g("runner", 4, 0.50, 0.33), g("warcaller", 8, 0.58, 0.40), g("regenerator", 8, 0.76, 0.92), g("bulwark", 9, 0.84, 1.32) },
		[12] = { g("bulwark", 7, 0.65), g("runner", 7, 0.50, 0.32), g("warcaller", 11, 0.66, 0.63), g("regenerator", 15, 0.87, 1.26) },
		[13] = { g("warcaller", 9, 0.50), g("bulwark", 4, 0.62, 0.36), g("runner", 6, 0.50, 0.66), g("grunt", 10, 0.58, 0.72), g("tank", 11, 0.69, 1.08) },
		[14] = { g("bulwark", 3, 0.61), g("runner", 5, 0.50, 0.28), g("warcaller", 8, 0.58, 0.34), g("regenerator", 8, 0.76, 0.80), g("bulwark", 9, 0.84, 1.14) },
		[15] = { g("bulwark", 4, 0.60), g("runner", 4, 0.50, 0.32), g("warcaller", 9, 0.50, 0.25), g("regenerator", 10, 0.64, 0.63), g("bulwark", 9, 0.71, 1.01), g("runner", 11, 0.68, 1.26) },
		[16] = { g("bulwark", 7, 0.65), g("runner", 7, 0.50, 0.27), g("warcaller", 12, 0.66, 0.54), g("regenerator", 16, 0.87, 1.08) },
		[17] = { g("warcaller", 10, 0.50), g("bulwark", 5, 0.62, 0.32), g("runner", 6, 0.50, 0.59), g("grunt", 11, 0.58, 0.65), g("tank", 12, 0.69, 0.97) },
		[18] = { g("bulwark", 4, 0.61), g("runner", 5, 0.50, 0.26), g("warcaller", 9, 0.58, 0.31), g("regenerator", 9, 0.76, 0.71), g("bulwark", 10, 0.84, 1.02) },
		[19] = { g("bulwark", 5, 0.60), g("runner", 5, 0.50, 0.26), g("warcaller", 10, 0.50, 0.20), g("regenerator", 11, 0.64, 0.51), g("bulwark", 10, 0.71, 0.82), g("runner", 13, 0.68, 1.02) },
		[20] = { g("boss", 1, 0.00), g("bulwark", 5, 0.60, 1.94), g("runner", 5, 0.50, 2.21), g("warcaller", 9, 0.54, 2.16), g("regenerator", 10, 0.72, 2.48), g("bulwark", 10, 0.80, 2.70) },
	},
	crossflow = {
		-- 19 grunts.
		[1] = { g("grunt", 19, 0.56) },
		-- 6 bulwarks followed by 6 runners.
		[2] = { g("bulwark", 6, 0.74), g("runner", 6, 0.51, 0.30) },
		-- 14 grunts, then 2 bulwarks, and 2 runners.
		[3] = { g("grunt", 14, 0.53), g("bulwark", 2, 0.73, 0.60), g("runner", 2, 0.50, 0.90) },
		-- 6 bulwarks, then 7 runners, and 13 grunts.
		[4] = { g("bulwark", 6, 0.61), g("runner", 7, 0.50, 0.30), g("grunt", 13, 0.50, 0.28) },
		-- 11 warcallers, then 4 bulwarks, and 4 runners.
		[5] = { g("warcaller", 11, 0.55), g("bulwark", 4, 0.60, 0.23), g("runner", 4, 0.50, 0.53) },
		-- 6 bulwarks, then 7 runners, then 10 warcallers, and 13 regenerators.
		[6] = { g("bulwark", 6, 0.60), g("runner", 7, 0.50, 0.30), g("warcaller", 10, 0.50, 0.15), g("regenerator", 13, 0.67, 0.37) },
		-- 3 bulwarks, then 4 runners, then 7 warcallers, then 7 regenerators, and 8 bulwarks.
		[7] = { g("bulwark", 3, 0.60), g("runner", 4, 0.50, 0.30), g("warcaller", 7, 0.50, 0.08), g("regenerator", 7, 0.60, 0.23), g("bulwark", 8, 0.64, 0.37) },
		-- 4 bulwarks, then 5 runners, then 8 grunts, then 9 tanks, and 10 runners.
		[8] = { g("bulwark", 4, 0.60), g("runner", 5, 0.50, 0.30), g("grunt", 8, 0.50, 0.08), g("tank", 9, 0.55, 0.19), g("runner", 10, 0.50, 0.33) },
		-- 3 bulwarks, then 4 runners, then 7 warcallers, then 8 regenerators, then 8 bulwarks, and 9 runners.
		[9] = { g("bulwark", 3, 0.60), g("runner", 4, 0.50, 0.30), g("warcaller", 7, 0.50, 0.08), g("regenerator", 8, 0.60, 0.15), g("bulwark", 8, 0.60, 0.28), g("runner", 9, 0.50, 0.37) },
		-- 1 boss, then 4 bulwarks, then 4 runners, then 7 warcallers, then 8 regenerators, and 8 bulwarks.
		[10] = { g("boss", 1, 0.00), g("bulwark", 4, 0.60, 0.73), g("runner", 4, 0.50, 1.03), g("warcaller", 7, 0.50, 0.82), g("regenerator", 8, 0.60, 0.95), g("bulwark", 8, 0.62, 1.04) },
		[11] = { g("bulwark", 3, 0.60), g("runner", 4, 0.50, 0.33), g("warcaller", 8, 0.50, 0.09), g("regenerator", 8, 0.60, 0.25), g("bulwark", 9, 0.64, 0.41) },
		[12] = { g("bulwark", 7, 0.60), g("runner", 8, 0.50, 0.32), g("warcaller", 11, 0.50, 0.16), g("regenerator", 15, 0.67, 0.39) },
		[13] = { g("bulwark", 4, 0.60), g("runner", 6, 0.50, 0.30), g("grunt", 9, 0.50, 0.08), g("tank", 10, 0.55, 0.19), g("runner", 11, 0.50, 0.33) },
		[14] = { g("bulwark", 3, 0.60), g("runner", 5, 0.50, 0.28), g("warcaller", 8, 0.50, 0.08), g("regenerator", 8, 0.60, 0.22), g("bulwark", 9, 0.64, 0.35) },
		[15] = { g("bulwark", 3, 0.60), g("runner", 4, 0.50, 0.32), g("warcaller", 8, 0.50, 0.08), g("regenerator", 9, 0.60, 0.16), g("bulwark", 9, 0.60, 0.29), g("runner", 10, 0.50, 0.39) },
		[16] = { g("bulwark", 7, 0.60), g("runner", 9, 0.50, 0.27), g("warcaller", 12, 0.50, 0.14), g("regenerator", 16, 0.67, 0.33) },
		[17] = { g("bulwark", 5, 0.60), g("runner", 6, 0.50, 0.27), g("grunt", 10, 0.50, 0.07), g("tank", 11, 0.55, 0.17), g("runner", 12, 0.50, 0.30) },
		[18] = { g("bulwark", 4, 0.60), g("runner", 5, 0.50, 0.26), g("warcaller", 9, 0.50, 0.07), g("regenerator", 9, 0.60, 0.20), g("bulwark", 10, 0.64, 0.31) },
		[19] = { g("bulwark", 4, 0.60), g("runner", 5, 0.50, 0.26), g("warcaller", 9, 0.50, 0.07), g("regenerator", 10, 0.60, 0.13), g("bulwark", 10, 0.60, 0.24), g("runner", 11, 0.50, 0.31) },
		[20] = { g("boss", 1, 0.00), g("bulwark", 5, 0.60, 0.66), g("runner", 5, 0.50, 0.93), g("warcaller", 9, 0.50, 0.74), g("regenerator", 10, 0.60, 0.85), g("bulwark", 10, 0.62, 0.94) },
	},
	steppingstones = {
		-- 20 grunts.
		[1] = { g("grunt", 20, 0.80) },
		-- 6 bulwarks followed by 6 runners.
		[2] = { g("bulwark", 6, 1.02), g("runner", 6, 0.74, 0.30) },
		-- 14 grunts, then 2 bulwarks, and 2 runners.
		[3] = { g("grunt", 14, 0.76), g("bulwark", 2, 1.00, 3.00), g("runner", 2, 0.72, 3.30) },
		-- 6 bulwarks, then 7 runners, and 13 grunts.
		[4] = { g("bulwark", 6, 0.83), g("runner", 7, 0.58, 0.30), g("grunt", 13, 0.63, 1.60) },
		-- 11 warcallers, then 4 bulwarks, and 5 runners.
		[5] = { g("warcaller", 11, 0.78), g("bulwark", 4, 0.80, 1.40), g("runner", 5, 0.56, 1.70) },
		-- 5 bulwarks, then 7 runners, then 10 warcallers, and 13 regenerators.
		[6] = { g("bulwark", 5, 0.68), g("runner", 7, 0.50, 0.30), g("warcaller", 10, 0.70, 1.00), g("regenerator", 13, 0.91, 2.00) },
		-- 3 bulwarks, then 4 runners, then 7 warcallers, then 7 regenerators, and 8 bulwarks.
		[7] = { g("bulwark", 3, 0.64), g("runner", 4, 0.50, 0.30), g("warcaller", 7, 0.61, 0.95), g("regenerator", 7, 0.80, 1.75), g("bulwark", 8, 0.88, 2.35) },
		-- 8 grunts, then 8 tanks, then 9 runners, and 10 bulwarks.
		[8] = { g("grunt", 8, 0.50), g("tank", 8, 0.59, 0.95), g("runner", 9, 0.61, 1.55), g("bulwark", 10, 0.78, 2.15) },
		-- 4 bulwarks, then 4 runners, then 8 warcallers, then 9 regenerators, then 9 bulwarks, and 10 runners.
		[9] = { g("bulwark", 4, 0.60), g("runner", 4, 0.50, 0.30), g("warcaller", 8, 0.51, 0.75), g("regenerator", 9, 0.68, 1.35), g("bulwark", 9, 0.74, 1.95), g("runner", 10, 0.72, 2.35) },
		-- 1 boss, then 4 bulwarks, then 4 runners, then 7 warcallers, then 8 regenerators, and 8 bulwarks.
		[10] = { g("boss", 1, 0.00), g("bulwark", 4, 0.60, 3.95), g("runner", 4, 0.50, 4.25), g("warcaller", 7, 0.58, 4.35), g("regenerator", 8, 0.76, 4.95), g("bulwark", 8, 0.84, 5.35) },
		[11] = { g("bulwark", 3, 0.64), g("runner", 4, 0.50, 0.33), g("warcaller", 8, 0.61, 1.04), g("regenerator", 8, 0.80, 1.93), g("bulwark", 9, 0.88, 2.59) },
		[12] = { g("bulwark", 6, 0.68), g("runner", 8, 0.50, 0.32), g("warcaller", 11, 0.70, 1.05), g("regenerator", 15, 0.91, 2.10) },
		[13] = { g("grunt", 9, 0.50), g("tank", 9, 0.59, 0.95), g("runner", 10, 0.61, 1.55), g("bulwark", 11, 0.78, 2.15) },
		[14] = { g("bulwark", 3, 0.64), g("runner", 5, 0.50, 0.28), g("warcaller", 8, 0.61, 0.90), g("regenerator", 8, 0.80, 1.66), g("bulwark", 9, 0.88, 2.23) },
		[15] = { g("bulwark", 4, 0.60), g("runner", 4, 0.50, 0.32), g("warcaller", 9, 0.51, 0.79), g("regenerator", 10, 0.68, 1.42), g("bulwark", 10, 0.74, 2.05), g("runner", 11, 0.72, 2.47) },
		[16] = { g("bulwark", 6, 0.68), g("runner", 9, 0.50, 0.27), g("warcaller", 12, 0.70, 0.90), g("regenerator", 16, 0.91, 1.80) },
		[17] = { g("grunt", 10, 0.50), g("tank", 10, 0.59, 0.85), g("runner", 11, 0.61, 1.40), g("bulwark", 12, 0.78, 1.94) },
		[18] = { g("bulwark", 4, 0.64), g("runner", 5, 0.50, 0.26), g("warcaller", 9, 0.61, 0.81), g("regenerator", 9, 0.80, 1.49), g("bulwark", 10, 0.88, 2.00) },
		[19] = { g("bulwark", 5, 0.60), g("runner", 5, 0.50, 0.26), g("warcaller", 10, 0.51, 0.64), g("regenerator", 11, 0.68, 1.15), g("bulwark", 11, 0.74, 1.66), g("runner", 13, 0.72, 2.00) },
		[20] = { g("boss", 1, 0.00), g("bulwark", 5, 0.60, 3.56), g("runner", 5, 0.50, 3.83), g("warcaller", 9, 0.58, 3.91), g("regenerator", 10, 0.76, 4.46), g("bulwark", 10, 0.84, 4.81) },
	},
	twinloop = {
		-- 20 grunts.
		[1] = { g("grunt", 20, 0.51) },
		-- 3 summoners.
		[2] = { g("summoner", 3, 1.00) },
		-- 10 grunts followed by 2 summoners.
		[3] = { g("grunt", 10, 0.50), g("summoner", 2, 0.84, 0.93) },
		-- 6 bulwarks, then 7 runners, and 13 grunts.
		[4] = { g("bulwark", 6, 0.60), g("runner", 7, 0.50, 0.30), g("grunt", 13, 0.50, 0.50) },
		-- 1 summoner, then 10 warcallers, then 4 bulwarks, and 4 runners.
		[5] = { g("summoner", 1, 0.00), g("warcaller", 10, 0.52, 0.52), g("bulwark", 4, 0.60, 0.43), g("runner", 4, 0.50, 0.73) },
		-- 6 bulwarks, then 7 runners, then 10 warcallers, and 13 regenerators.
		[6] = { g("bulwark", 6, 0.60), g("runner", 7, 0.50, 0.30), g("warcaller", 10, 0.50, 0.31), g("regenerator", 13, 0.64, 0.62) },
		-- 3 bulwarks, then 4 runners, then 7 warcallers, then 7 regenerators, and 8 bulwarks.
		[7] = { g("bulwark", 3, 0.60), g("runner", 4, 0.50, 0.30), g("warcaller", 7, 0.50, 0.19), g("regenerator", 7, 0.60, 0.43), g("bulwark", 8, 0.62, 0.62) },
		-- 1 summoner, then 7 tanks, then 7 runners, then 8 bulwarks, and 10 regenerators.
		[8] = { g("summoner", 1, 0.00), g("tank", 7, 0.55, 0.50), g("runner", 7, 0.50, 0.19), g("bulwark", 8, 0.60, 0.37), g("regenerator", 10, 0.60, 0.56) },
		-- 3 bulwarks, then 4 runners, then 7 warcallers, then 8 regenerators, then 8 bulwarks, and 9 runners.
		[9] = { g("bulwark", 3, 0.60), g("runner", 4, 0.50, 0.30), g("warcaller", 7, 0.50, 0.12), g("regenerator", 8, 0.60, 0.31), g("bulwark", 8, 0.60, 0.50), g("runner", 9, 0.50, 0.62) },
		-- 1 boss, then 4 bulwarks, then 4 runners, then 7 warcallers, then 8 regenerators, and 7 bulwarks.
		[10] = { g("boss", 1, 0.00), g("bulwark", 4, 0.60, 1.12), g("runner", 4, 0.50, 1.42), g("warcaller", 7, 0.50, 1.24), g("regenerator", 8, 0.60, 1.43), g("bulwark", 7, 0.60, 1.55) },
		[11] = { g("summoner", 1, 0.00), g("bulwark", 2, 0.60, 0.50), g("runner", 4, 0.50, 0.33), g("warcaller", 8, 0.50, 0.21), g("regenerator", 8, 0.60, 0.47), g("bulwark", 9, 0.62, 0.68) },
		[12] = { g("bulwark", 7, 0.60), g("runner", 8, 0.50, 0.32), g("warcaller", 11, 0.50, 0.33), g("regenerator", 15, 0.64, 0.65) },
		[13] = { g("tank", 9, 0.55), g("runner", 8, 0.50, 0.19), g("bulwark", 9, 0.60, 0.37), g("regenerator", 11, 0.60, 0.56) },
		[14] = { g("summoner", 1, 0.00), g("bulwark", 2, 0.60, 0.50), g("runner", 5, 0.50, 0.28), g("warcaller", 8, 0.50, 0.18), g("regenerator", 8, 0.60, 0.41), g("bulwark", 9, 0.62, 0.59) },
		[15] = { g("bulwark", 3, 0.60), g("runner", 4, 0.50, 0.32), g("warcaller", 8, 0.50, 0.13), g("regenerator", 9, 0.60, 0.33), g("bulwark", 9, 0.60, 0.53), g("runner", 10, 0.50, 0.65) },
		[16] = { g("bulwark", 7, 0.60), g("runner", 9, 0.50, 0.27), g("warcaller", 12, 0.50, 0.28), g("regenerator", 16, 0.64, 0.56) },
		[17] = { g("summoner", 1, 0.00), g("tank", 9, 0.55, 0.50), g("runner", 8, 0.50, 0.17), g("bulwark", 10, 0.60, 0.33), g("regenerator", 12, 0.60, 0.50) },
		[18] = { g("bulwark", 4, 0.60), g("runner", 5, 0.50, 0.26), g("warcaller", 9, 0.50, 0.16), g("regenerator", 9, 0.60, 0.37), g("bulwark", 10, 0.62, 0.53) },
		[19] = { g("summoner", 1, 0.00), g("bulwark", 3, 0.60, 0.50), g("runner", 5, 0.50, 0.26), g("warcaller", 9, 0.50, 0.10), g("regenerator", 10, 0.60, 0.26), g("bulwark", 10, 0.60, 0.42), g("runner", 11, 0.50, 0.53) },
		[20] = { g("boss", 1, 0.00), g("summoner", 1, 0.00, 1.01), g("bulwark", 4, 0.60, 0.50), g("runner", 5, 0.50, 1.28), g("warcaller", 9, 0.50, 1.12), g("regenerator", 10, 0.60, 1.29), g("bulwark", 9, 0.60, 1.40) },
	},

	frostgate = {
		[1] = { g("tank", 12, 0.77) },
		[2] = { g("bulwark", 7, 0.92), g("grunt", 8, 0.62, 1.80) },
		[3] = { g("tank", 9, 0.73), g("regenerator", 6, 0.88, 1.55) },
		[4] = { g("bulwark", 8, 0.82), g("runner", 10, 0.55, 1.30) },
		[5] = { g("warcaller", 6, 0.76), g("tank", 12, 0.67, 1.60) },
		[6] = { g("regenerator", 8, 0.80), g("bulwark", 9, 0.76, 1.40), g("grunt", 10, 0.55, 1.05) },
		[7] = { g("tank", 10, 0.69), g("runner", 12, 0.50, 1.20), g("warcaller", 6, 0.72, 1.35) },
		[8] = { g("bulwark", 9, 0.78), g("regenerator", 9, 0.76, 1.25), g("tank", 11, 0.63, 1.10) },
		[9] = { g("warcaller", 7, 0.68), g("bulwark", 10, 0.72, 1.15), g("runner", 13, 0.50, 1.00) },
		[10] = { g("boss", 1, 0.00), g("tank", 11, 0.67, 2.40), g("regenerator", 9, 0.78, 1.65), g("bulwark", 9, 0.74, 1.45) },
		[11] = { g("tank", 12, 0.65), g("runner", 14, 0.50, 1.05), g("warcaller", 7, 0.66, 1.20) },
		[12] = { g("bulwark", 10, 0.74), g("regenerator", 10, 0.72, 1.15), g("grunt", 15, 0.50, 0.95) },
		[13] = { g("warcaller", 8, 0.64), g("tank", 13, 0.63, 1.05), g("runner", 15, 0.50, 0.90) },
		[14] = { g("regenerator", 11, 0.70), g("bulwark", 11, 0.70, 1.00), g("tank", 13, 0.61, 0.85) },
		[15] = { g("summoner", 2, 1.00), g("tank", 14, 0.61, 1.30), g("warcaller", 8, 0.62, 0.95) },
		[16] = { g("bulwark", 12, 0.68), g("runner", 17, 0.50, 0.80), g("regenerator", 11, 0.68, 0.90) },
		[17] = { g("tank", 15, 0.59), g("warcaller", 9, 0.60, 0.85), g("grunt", 18, 0.50, 0.70) },
		[18] = { g("regenerator", 12, 0.66), g("bulwark", 13, 0.66, 0.80), g("runner", 18, 0.50, 0.68) },
		[19] = { g("summoner", 2, 0.90), g("warcaller", 10, 0.58, 0.80), g("tank", 16, 0.57, 0.66), g("bulwark", 12, 0.64, 0.62) },
		[20] = { g("boss", 1, 0.00), g("bulwark", 13, 0.64, 2.10), g("regenerator", 12, 0.66, 1.15), g("tank", 16, 0.57, 0.90), g("runner", 18, 0.50, 0.72) },
	},
	tidelock = {
		[1] = { g("runner", 14, 0.58) },
		[2] = { g("warcaller", 5, 0.80), g("grunt", 10, 0.55, 0.65) },
		[3] = { g("regenerator", 6, 0.84), g("runner", 11, 0.52, 0.55) },
		[4] = { g("summoner", 2, 0.90), g("tank", 10, 0.63, 0.70) },
		[5] = { g("warcaller", 6, 0.70), g("bulwark", 8, 0.72, 0.50), g("runner", 12, 0.50, 0.45) },
		[6] = { g("regenerator", 8, 0.74), g("grunt", 13, 0.50, 0.42), g("tank", 9, 0.61, 0.50) },
		[7] = { g("summoner", 2, 0.84), g("runner", 14, 0.50, 0.52), g("bulwark", 8, 0.68, 0.44) },
		[8] = { g("warcaller", 7, 0.64), g("tank", 11, 0.59, 0.40), g("regenerator", 9, 0.70, 0.46) },
		[9] = { g("runner", 15, 0.50), g("summoner", 2, 0.80, 0.38), g("bulwark", 10, 0.66, 0.42) },
		[10] = { g("boss", 1, 0.00), g("warcaller", 8, 0.62, 1.30), g("runner", 15, 0.50, 0.66), g("regenerator", 9, 0.68, 0.58) },
		[11] = { g("summoner", 2, 0.78), g("tank", 12, 0.57, 0.38), g("runner", 16, 0.50, 0.36) },
		[12] = { g("regenerator", 10, 0.68), g("bulwark", 11, 0.64, 0.35), g("grunt", 16, 0.50, 0.34) },
		[13] = { g("warcaller", 9, 0.60), g("runner", 17, 0.50, 0.32), g("tank", 13, 0.57, 0.38) },
		[14] = { g("summoner", 3, 0.76), g("bulwark", 12, 0.62, 0.36), g("regenerator", 11, 0.66, 0.34) },
		[15] = { g("runner", 18, 0.50), g("warcaller", 10, 0.58, 0.30), g("tank", 14, 0.55, 0.32) },
		[16] = { g("regenerator", 12, 0.64), g("summoner", 3, 0.72, 0.32), g("bulwark", 13, 0.60, 0.30) },
		[17] = { g("warcaller", 11, 0.56), g("runner", 19, 0.50, 0.28), g("grunt", 18, 0.50, 0.26) },
		[18] = { g("summoner", 3, 0.68), g("tank", 15, 0.55, 0.28), g("regenerator", 13, 0.62, 0.26) },
		[19] = { g("runner", 20, 0.50), g("warcaller", 12, 0.54, 0.25), g("bulwark", 14, 0.60, 0.24), g("summoner", 3, 0.64, 0.24) },
		[20] = { g("boss", 1, 0.00), g("summoner", 3, 0.62, 1.10), g("runner", 20, 0.50, 0.52), g("warcaller", 12, 0.52, 0.46), g("bulwark", 14, 0.60, 0.42) },
	},
	ashspiral = {
		[1] = { g("grunt", 18, 0.52), g("runner", 8, 0.50, 0.30) },
		[2] = { g("tank", 10, 0.61), g("bulwark", 7, 0.68, 0.28) },
		[3] = { g("warcaller", 6, 0.62), g("regenerator", 7, 0.68, 0.26), g("runner", 10, 0.50, 0.24) },
		[4] = { g("summoner", 2, 0.76), g("grunt", 14, 0.50, 0.24), g("tank", 10, 0.57, 0.22) },
		[5] = { g("bulwark", 9, 0.64), g("runner", 13, 0.50, 0.22), g("warcaller", 7, 0.58, 0.20) },
		[6] = { g("regenerator", 9, 0.64), g("tank", 12, 0.55, 0.20), g("summoner", 2, 0.70, 0.20) },
		[7] = { g("runner", 15, 0.50), g("bulwark", 10, 0.62, 0.18), g("warcaller", 8, 0.56, 0.18) },
		[8] = { g("summoner", 3, 0.68), g("regenerator", 10, 0.62, 0.18), g("grunt", 17, 0.50, 0.16) },
		[9] = { g("tank", 13, 0.55), g("runner", 17, 0.50, 0.16), g("warcaller", 9, 0.54, 0.16) },
		[10] = { g("boss", 1, 0.00), g("summoner", 3, 0.64, 0.90), g("bulwark", 11, 0.60, 0.38), g("runner", 17, 0.50, 0.34), g("regenerator", 10, 0.60, 0.30) },
		[11] = { g("warcaller", 10, 0.52), g("tank", 14, 0.55, 0.15), g("runner", 18, 0.50, 0.15) },
		[12] = { g("summoner", 3, 0.62), g("regenerator", 11, 0.60, 0.15), g("bulwark", 12, 0.60, 0.14) },
		[13] = { g("runner", 19, 0.50), g("grunt", 20, 0.50, 0.14), g("warcaller", 11, 0.50, 0.14) },
		[14] = { g("tank", 15, 0.55), g("summoner", 4, 0.60, 0.14), g("regenerator", 12, 0.60, 0.13) },
		[15] = { g("bulwark", 13, 0.60), g("runner", 20, 0.50, 0.13), g("warcaller", 12, 0.50, 0.13) },
		[16] = { g("summoner", 4, 0.58), g("tank", 16, 0.55, 0.12), g("regenerator", 13, 0.60, 0.12) },
		[17] = { g("runner", 21, 0.50), g("bulwark", 14, 0.60, 0.12), g("warcaller", 13, 0.50, 0.11) },
		[18] = { g("regenerator", 14, 0.60), g("summoner", 4, 0.56, 0.11), g("tank", 17, 0.55, 0.11) },
		[19] = { g("warcaller", 14, 0.50), g("runner", 22, 0.50, 0.10), g("bulwark", 15, 0.60, 0.10), g("summoner", 4, 0.54, 0.10) },
		[20] = { g("boss", 1, 0.00), g("summoner", 4, 0.52, 0.72), g("warcaller", 14, 0.50, 0.28), g("regenerator", 14, 0.60, 0.25), g("bulwark", 15, 0.60, 0.22), g("runner", 22, 0.50, 0.20) },
	},
}


-- Boss selections remain explicit because they affect the spawned enemy type.
-- Each map uses a different boss for its second boss wave, and the pairings
-- vary across maps rather than following one rotation. Across the campaign,
-- every archetype appears five times (with Summoner appearing once more to fill
-- the 36 encounter slots) so no boss is crowded out by another.
local bossArchetypesByMapId = {
	riverbend = {[10] = "boss_summoner", [20] = "boss_ravager"},
	switchback = {[10] = "boss_summoner", [20] = "boss_vanguard"},
	highpass = {[10] = "boss_summoner", [20] = "boss_aegis"},
	roundabout = {[10] = "boss_vanguard", [20] = "boss_summoner"},
	gauntlet = {[10] = "boss_suppression", [20] = "boss_vanguard"},
	snaketrail = {[10] = "boss_summoner", [20] = "boss_phasewalker"},
	backtrack = {[10] = "boss_vanguard", [20] = "boss_ravager"},
	lowvalley = {[10] = "boss_suppression", [20] = "boss_aegis"},
	circuit = {[10] = "boss_aegis", [20] = "boss_gatecrasher"},
	outerloop = {[10] = "boss_ravager", [20] = "boss_summoner"},
	terrace = {[10] = "boss_suppression", [20] = "boss_phasewalker"},
	highridge = {[10] = "boss_aegis", [20] = "boss_gatecrasher"},
	crossflow = {[10] = "boss_ravager", [20] = "boss_vanguard"},
	steppingstones = {[10] = "boss_phasewalker", [20] = "boss_gatecrasher"},
	twinloop = {[10] = "boss_suppression", [20] = "boss_gatecrasher"},
	frostgate = {[10] = "boss_aegis", [20] = "boss_phasewalker"},
	tidelock = {[10] = "boss_suppression", [20] = "boss_gatecrasher"},
	ashspiral = {[10] = "boss_ravager", [20] = "boss_phasewalker"},
}

for mapId, bossArchetypes in pairs(bossArchetypesByMapId) do
	for waveIndex, bossArchetype in pairs(bossArchetypes) do
		wavesByMapId[mapId][waveIndex].bossArchetype = bossArchetype
	end
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

return CampaignWaveDefs

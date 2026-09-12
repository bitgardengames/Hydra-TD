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
		-- Grunt-only waves vary cadence and pack size.
		[1] = { g("grunt", 8, 0.90) },
		[2] = { g("grunt", 11, 0.75) },
		[3] = { g("grunt", 8, 0.70), g("grunt", 6, 0.70, 1.80) },
		[4] = { g("grunt", 15, 0.62) },
		[5] = { g("grunt", 18, 0.50) },
		[6] = { g("grunt", 10, 0.55), g("grunt", 8, 0.55, 1.20) },
		[7] = { g("grunt", 20, 0.50) },
		[8] = { g("grunt", 8, 0.52), g("grunt", 8, 0.52, 1.00) },
		[9] = { g("grunt", 22, 0.50) },
		[10] = { g("boss", 1, 0.00), g("grunt", 12, 0.55, 1.20), g("grunt", 10, 0.50, 0.80) },
		[11] = { g("grunt", 14, 0.52), g("grunt", 10, 0.52, 0.90) },
		[12] = { g("grunt", 24, 0.50) },
		[13] = { g("grunt", 10, 0.55), g("grunt", 10, 0.55, 0.75) },
		[14] = { g("grunt", 26, 0.50) },
		-- Later waves add small Grunt and Runner groups.
		[15] = { g("grunt", 6, 0.65), g("grunt", 16, 0.52, 1.60) },
		[16] = { g("grunt", 12, 0.50), g("grunt", 8, 0.61, 0.86) },
		[17] = { g("grunt", 8, 0.61), g("grunt", 18, 0.50, 1.30) },
		[18] = { g("grunt", 14, 0.55), g("runner", 5, 0.50, 0.75) },
		[19] = { g("grunt", 8, 0.61), g("grunt", 12, 0.52, 1.10), g("runner", 5, 0.50, 0.65) },
		[20] = { g("boss", 1, 0.00), g("grunt", 16, 0.52, 1.10), g("runner", 6, 0.50, 0.65) },
	},
	switchback = {
		-- Sparse durable fronts ask for focused damage; ordinary escorts punish tunnel vision.
		[1] = { g("grunt", 10, 0.87) },
		[2] = { g("grunt", 10, 0.83) },
		[3] = { g("grunt", 8, 0.76), g("grunt", 10, 0.58, 2.00) },
		[4] = { g("grunt", 14, 0.52), g("grunt", 10, 0.72, 1.35) },
		[5] = { g("grunt", 12, 0.72), g("grunt", 14, 0.52, 1.75) },
		[6] = { g("grunt", 18, 0.50), g("grunt", 10, 0.68, 1.19) },
		[7] = { g("grunt", 14, 0.68), g("grunt", 15, 0.50, 1.50) },
		[8] = { g("grunt", 10, 0.50), g("grunt", 12, 0.65, 0.97), g("grunt", 8, 0.50, 1.20) },
		[9] = { g("grunt", 14, 0.65), g("grunt", 18, 0.50, 1.30) },
		[10] = { g("boss", 1, 0.00), g("grunt", 12, 0.68, 1.51), g("grunt", 16, 0.50, 1.40) },
		[11] = { g("grunt", 20, 0.50), g("grunt", 12, 0.65, 1.08) },
		[12] = { g("grunt", 16, 0.65), g("grunt", 18, 0.50, 1.25) },
		[13] = { g("grunt", 12, 0.50), g("grunt", 14, 0.63, 0.86), g("grunt", 10, 0.50, 1.10) },
		[14] = { g("grunt", 16, 0.63), g("grunt", 20, 0.50, 1.15) },
		[15] = { g("grunt", 22, 0.50), g("grunt", 14, 0.62, 0.92) },
		[16] = { g("grunt", 18, 0.62), g("grunt", 20, 0.50, 1.05) },
		[17] = { g("grunt", 13, 0.50), g("grunt", 16, 0.60, 0.81), g("grunt", 11, 0.50, 1.00) },
		[18] = { g("grunt", 18, 0.60), g("grunt", 22, 0.50, 0.95) },
		[19] = { g("grunt", 24, 0.50), g("grunt", 16, 0.59, 0.76) },
		[20] = { g("boss", 1, 0.00), g("grunt", 18, 0.60, 1.40), g("grunt", 22, 0.50, 1.15) },
	},
	highpass = {
		-- Alternating dense and fast groups reward coverage over one fixed counter.
		[1] = { g("grunt", 10, 1.03) },
		[2] = { g("runner", 10, 0.78) },
		[3] = { g("grunt", 8, 0.72), g("runner", 8, 0.62, 1.60) },
		[4] = { g("runner", 14, 0.55), g("grunt", 10, 0.68, 1.51) },
		[5] = { g("grunt", 12, 0.68), g("runner", 14, 0.53, 1.25) },
		[6] = { g("runner", 16, 0.52), g("grunt", 12, 0.66, 1.19) },
		[7] = { g("grunt", 14, 0.66), g("runner", 15, 0.52, 1.00) },
		[8] = { g("runner", 10, 0.50), g("grunt", 12, 0.65, 0.86), g("grunt", 8, 0.52, 1.10) },
		[9] = { g("grunt", 14, 0.65), g("runner", 18, 0.50, 0.90) },
		[10] = { g("boss", 1, 0.00), g("runner", 14, 0.52, 1.20), g("grunt", 12, 0.66, 1.30) },
		[11] = { g("grunt", 16, 0.65), g("runner", 17, 0.50, 0.90) },
		[12] = { g("runner", 20, 0.50), g("grunt", 14, 0.63, 0.86) },
		[13] = { g("grunt", 16, 0.63), g("runner", 18, 0.50, 0.80) },
		[14] = { g("runner", 21, 0.50), g("grunt", 16, 0.62, 0.81) },
		[15] = { g("grunt", 18, 0.62), g("runner", 19, 0.50, 0.72) },
		[16] = { g("runner", 22, 0.50), g("grunt", 16, 0.60, 0.76) },
		[17] = { g("grunt", 18, 0.60), g("runner", 20, 0.50, 0.68) },
		[18] = { g("runner", 23, 0.50), g("grunt", 18, 0.59, 0.70) },
		[19] = { g("grunt", 20, 0.59), g("runner", 21, 0.50, 0.62) },
		[20] = { g("boss", 1, 0.00), g("runner", 22, 0.50, 1.10), g("grunt", 18, 0.60, 1.19) },
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
		-- Tight ordinary packs accompany Warcallers positioned behind escorts.
		[1] = { g("grunt", 12, 0.60) },
		[2] = { g("grunt", 16, 0.50) },
		[3] = { g("grunt", 18, 0.50) },
		[4] = { g("runner", 16, 0.50) },
		[5] = { g("grunt", 20, 0.50) },
		[6] = { g("bulwark", 3, 1.43), g("grunt", 16, 0.50, 1.30) },
		[7] = { g("grunt", 18, 0.50), g("warcaller", 2, 1.08, 0.70) },
		[8] = { g("runner", 18, 0.50), g("grunt", 12, 0.50, 0.70) },
		[9] = { g("grunt", 20, 0.50), g("warcaller", 3, 1.03, 0.60) },
		[10] = { g("boss", 1, 0.00), g("grunt", 18, 0.50, 1.20), g("warcaller", 3, 1.08, 0.80) },
		[11] = { g("bulwark", 4, 1.36), g("grunt", 18, 0.50, 0.90) },
		[12] = { g("grunt", 22, 0.50) },
		[13] = { g("runner", 20, 0.50), g("grunt", 12, 0.50, 0.65) },
		[14] = { g("grunt", 22, 0.50), g("warcaller", 4, 0.98, 0.55) },
		[15] = { g("bulwark", 5, 1.33), g("grunt", 20, 0.50, 0.75) },
		[16] = { g("grunt", 24, 0.50) },
		[17] = { g("runner", 22, 0.50), g("grunt", 12, 0.50, 0.60) },
		[18] = { g("grunt", 24, 0.50), g("warcaller", 4, 0.96, 0.50) },
		[19] = { g("bulwark", 5, 1.30), g("grunt", 20, 0.50, 0.65) },
		[20] = { g("boss", 1, 0.00), g("grunt", 22, 0.50, 1.10), g("warcaller", 4, 0.98, 0.70) },
	},
	snaketrail = {
		-- Long bends separate armored and fast blocks to force frequent retargeting.
		[1] = { g("grunt", 17, 0.90) },
		[2] = { g("bulwark", 4, 1.55) },
		[3] = { g("runner", 12, 0.58) },
		[4] = { g("bulwark", 4, 1.47), g("runner", 10, 0.52, 1.50) },
		[5] = { g("runner", 14, 0.52), g("bulwark", 4, 1.43, 1.40) },
		[6] = { g("bulwark", 5, 1.43), g("grunt", 14, 0.55, 1.20) },
		[7] = { g("runner", 16, 0.50), g("bulwark", 4, 1.40, 1.12) },
		[8] = { g("bulwark", 5, 1.40), g("runner", 15, 0.50, 0.90) },
		[9] = { g("runner", 17, 0.50), g("bulwark", 5, 1.36, 0.95) },
		[10] = { g("boss", 1, 0.00), g("bulwark", 5, 1.40, 1.51), g("runner", 16, 0.50, 1.20) },
		[11] = { g("runner", 18, 0.50), g("bulwark", 5, 1.33, 0.90) },
		[12] = { g("bulwark", 5, 1.33), g("grunt", 18, 0.52, 0.80) },
		[13] = { g("runner", 19, 0.50), g("bulwark", 5, 1.30, 0.84) },
		[14] = { g("bulwark", 6, 1.30), g("runner", 18, 0.50, 0.70) },
		[15] = { g("runner", 20, 0.50), g("bulwark", 5, 1.27, 0.76) },
		[16] = { g("bulwark", 6, 1.27), g("grunt", 20, 0.50, 0.65) },
		[17] = { g("runner", 21, 0.50), g("bulwark", 6, 1.24, 0.69) },
		[18] = { g("bulwark", 7, 1.24), g("runner", 20, 0.50, 0.60) },
		[19] = { g("runner", 22, 0.50), g("bulwark", 6, 1.21, 0.65) },
		[20] = { g("boss", 1, 0.00), g("bulwark", 7, 1.24, 1.34), g("runner", 21, 0.50, 1.05) },
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
		-- 11 bulwarks followed by 8 runners.
		[5] = { g("bulwark", 7, 1.01), g("runner", 8, 0.53, 0.52) },
		-- 10 runners, then 10 bulwarks, and 14 grunts.
		[6] = { g("runner", 10, 0.50), g("bulwark", 6, 0.90, 0.43), g("grunt", 14, 0.63, 0.75) },
		-- 6 runners, then 8 bulwarks, and 8 grunts.
		[7] = { g("runner", 6, 0.50), g("bulwark", 5, 0.85, 0.25), g("grunt", 8, 0.53, 0.52) },
		-- 8 bulwarks, then 8 runners, and 10 grunts.
		[8] = { g("bulwark", 5, 0.85), g("runner", 8, 0.50, 0.22), g("grunt", 10, 0.50, 0.45) },
		-- 7 runners, then 8 bulwarks, and 10 grunts.
		[9] = { g("runner", 7, 0.50), g("bulwark", 5, 0.85, 0.17), g("grunt", 10, 0.50, 0.38) },
		-- 1 boss, then 7 runners, then 7 bulwarks, and 8 grunts.
		[10] = { g("boss", 1, 0.00), g("runner", 7, 0.50, 1.35), g("bulwark", 4, 0.85, 1.68), g("grunt", 8, 0.50, 1.72) },
		[11] = { g("runner", 6, 0.50), g("bulwark", 5, 0.85, 0.27), g("grunt", 9, 0.53, 0.57) },
		[12] = { g("runner", 11, 0.50), g("bulwark", 7, 0.90, 0.45), g("grunt", 16, 0.63, 0.79) },
		[13] = { g("bulwark", 5, 0.85), g("runner", 9, 0.50, 0.22), g("grunt", 11, 0.50, 0.45) },
		[14] = { g("runner", 7, 0.50), g("bulwark", 5, 0.85, 0.24), g("grunt", 9, 0.53, 0.49) },
		[15] = { g("runner", 8, 0.50), g("bulwark", 5, 0.85, 0.18), g("grunt", 11, 0.50, 0.40) },
		[16] = { g("runner", 12, 0.50), g("bulwark", 7, 0.90, 0.38), g("grunt", 17, 0.63, 0.68) },
		[17] = { g("bulwark", 6, 0.85), g("runner", 10, 0.50, 0.20), g("grunt", 12, 0.50, 0.41) },
		[18] = { g("runner", 8, 0.50), g("bulwark", 6, 0.85, 0.21), g("grunt", 10, 0.53, 0.44) },
		[19] = { g("runner", 9, 0.50), g("bulwark", 6, 0.85, 0.15), g("grunt", 13, 0.50, 0.32) },
		[20] = { g("boss", 1, 0.00), g("runner", 9, 0.50, 1.22), g("bulwark", 5, 0.85, 1.51), g("grunt", 10, 0.50, 1.55) },
	},
	lowvalley = {
		-- 17 grunts.
		[1] = { g("grunt", 17, 0.82) },
		-- 9 bulwarks.
		[2] = { g("bulwark", 9, 1.78) },
		-- 13 grunts followed by 4 bulwarks.
		[3] = { g("grunt", 13, 0.69), g("bulwark", 4, 1.75, 2.17) },
		-- 10 bulwarks followed by 13 grunts.
		[4] = { g("bulwark", 10, 1.46), g("grunt", 13, 0.57, 1.16) },
		-- 10 runners followed by 8 bulwarks.
		[5] = { g("runner", 10, 0.71), g("bulwark", 8, 1.40, 1.01) },
		-- 10 bulwarks, then 9 runners, and 13 bulwarks.
		[6] = { g("bulwark", 10, 1.22), g("runner", 9, 0.63, 0.72), g("bulwark", 8, 1.22, 1.62) },
		-- 6 bulwarks, then 7 runners, then 7 bulwarks, and 9 grunts.
		[7] = { g("bulwark", 6, 1.17), g("runner", 7, 0.56, 0.43), g("bulwark", 4, 1.05, 1.13), g("grunt", 9, 0.71, 1.45) },
		-- 8 grunts, then 8 bulwarks, then 9 runners, and 11 bulwarks.
		[8] = { g("grunt", 8, 0.50), g("bulwark", 5, 0.85, 0.48), g("runner", 9, 0.56, 0.87), g("bulwark", 11, 1.39, 1.30) },
		-- 7 bulwarks, then 8 runners, then 9 bulwarks, and 9 grunts.
		[9] = { g("bulwark", 7, 1.17), g("runner", 8, 0.50, 0.29), g("bulwark", 5, 0.88, 0.81), g("grunt", 9, 0.59, 1.16) },
		-- 1 boss, then 7 bulwarks, then 7 runners, then 8 bulwarks, and 8 grunts.
		[10] = { g("boss", 1, 0.00), g("bulwark", 7, 1.17, 2.61), g("runner", 7, 0.52, 2.90), g("bulwark", 5, 1.01, 3.73), g("grunt", 8, 0.67, 3.62) },
		[11] = { g("bulwark", 6, 1.17), g("runner", 8, 0.56, 0.47), g("bulwark", 5, 1.05, 1.24), g("grunt", 10, 0.71, 1.59) },
		[12] = { g("bulwark", 11, 1.22), g("runner", 10, 0.63, 0.76), g("bulwark", 9, 1.22, 1.70) },
		[13] = { g("grunt", 9, 0.50), g("bulwark", 5, 0.85, 0.48), g("runner", 10, 0.56, 0.87), g("bulwark", 12, 1.39, 1.30) },
		[14] = { g("bulwark", 7, 1.17), g("runner", 8, 0.56, 0.41), g("bulwark", 5, 1.05, 1.08), g("grunt", 10, 0.71, 1.38) },
		[15] = { g("bulwark", 8, 1.17), g("runner", 9, 0.50, 0.30), g("bulwark", 6, 0.88, 0.85), g("grunt", 10, 0.59, 1.22) },
		[16] = { g("bulwark", 12, 1.22), g("runner", 11, 0.63, 0.65), g("bulwark", 9, 1.22, 1.46) },
		[17] = { g("grunt", 10, 0.50), g("bulwark", 6, 0.85, 0.44), g("runner", 11, 0.56, 0.78), g("bulwark", 13, 1.39, 1.17) },
		[18] = { g("bulwark", 8, 1.17), g("runner", 9, 0.56, 0.37), g("bulwark", 5, 1.05, 0.96), g("grunt", 12, 0.71, 1.23) },
		[19] = { g("bulwark", 9, 1.17), g("runner", 10, 0.50, 0.25), g("bulwark", 7, 0.88, 0.68), g("grunt", 11, 0.59, 0.99) },
		[20] = { g("boss", 1, 0.00), g("bulwark", 9, 1.17, 2.35), g("runner", 9, 0.52, 2.61), g("bulwark", 6, 1.01, 3.36), g("grunt", 10, 0.67, 3.26) },
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
		[5] = { g("bulwark", 10, 1.40), g("regenerator", 7, 0.66, 0.45) },
		-- 10 regenerators, then 9 bulwarks, and 13 runners.
		[6] = { g("regenerator", 10, 0.60), g("bulwark", 9, 1.28, 0.33), g("runner", 13, 0.65, 0.65) },
		-- 6 regenerators, then 7 bulwarks, then 7 runners, and 8 bulwarks.
		[7] = { g("regenerator", 6, 0.60), g("bulwark", 7, 1.17, 0.20), g("runner", 7, 0.56, 0.45), g("bulwark", 5, 1.05, 0.73) },
		-- 8 regenerators, then 8 grunts, then 9 bulwarks, and 10 runners.
		[8] = { g("regenerator", 8, 0.60), g("grunt", 8, 0.50, 0.20), g("bulwark", 5, 0.85, 0.44), g("runner", 10, 0.55, 0.59) },
		-- 6 regenerators, then 7 bulwarks, then 9 runners, then 9 bulwarks, and 10 grunts.
		[9] = { g("regenerator", 6, 0.60), g("bulwark", 7, 1.17, 0.13), g("runner", 9, 0.50, 0.33), g("bulwark", 5, 0.88, 0.58), g("grunt", 10, 0.57, 0.65) },
		-- 1 boss, then 6 regenerators, then 7 bulwarks, then 8 runners, and 8 bulwarks.
		[10] = { g("boss", 1, 0.00), g("regenerator", 6, 0.60, 1.17), g("bulwark", 7, 1.17, 1.30), g("runner", 8, 0.53, 1.49), g("bulwark", 5, 1.01, 1.81) },
		[11] = { g("regenerator", 6, 0.60), g("bulwark", 8, 1.17, 0.22), g("runner", 8, 0.56, 0.50), g("bulwark", 5, 1.05, 0.81) },
		[12] = { g("regenerator", 11, 0.60), g("bulwark", 10, 1.28, 0.35), g("runner", 15, 0.65, 0.68) },
		[13] = { g("regenerator", 9, 0.60), g("grunt", 9, 0.50, 0.20), g("bulwark", 6, 0.85, 0.44), g("runner", 11, 0.55, 0.59) },
		[14] = { g("regenerator", 7, 0.60), g("bulwark", 8, 1.17, 0.19), g("runner", 8, 0.56, 0.43), g("bulwark", 5, 1.05, 0.69) },
		[15] = { g("regenerator", 7, 0.60), g("bulwark", 8, 1.17, 0.14), g("runner", 10, 0.50, 0.35), g("bulwark", 6, 0.88, 0.62), g("grunt", 11, 0.57, 0.68) },
		[16] = { g("regenerator", 12, 0.60), g("bulwark", 11, 1.28, 0.30), g("runner", 16, 0.65, 0.59) },
		[17] = { g("regenerator", 10, 0.60), g("grunt", 10, 0.50, 0.18), g("bulwark", 7, 0.85, 0.39), g("runner", 12, 0.55, 0.53) },
		[18] = { g("regenerator", 8, 0.60), g("bulwark", 9, 1.17, 0.17), g("runner", 9, 0.56, 0.38), g("bulwark", 6, 1.05, 0.62) },
		[19] = { g("regenerator", 8, 0.60), g("bulwark", 9, 1.17, 0.11), g("runner", 11, 0.50, 0.28), g("bulwark", 7, 0.88, 0.49), g("grunt", 13, 0.57, 0.55) },
		[20] = { g("boss", 1, 0.00), g("regenerator", 8, 0.60, 1.05), g("bulwark", 9, 1.17, 1.17), g("runner", 10, 0.53, 1.34), g("bulwark", 6, 1.01, 1.64) },
	},
	outerloop = {
		-- Regenerators arrive in small escorted pockets, with a late Bulwark preview.
		[1] = { g("grunt", 14, 0.82) },
		[2] = { g("grunt", 8, 0.58), g("regenerator", 2, 1.00, 1.40) },
		[3] = { g("grunt", 12, 0.55), g("regenerator", 3, 0.95, 1.10) },
		[4] = { g("bulwark", 3, 1.47), g("grunt", 12, 0.52, 1.40) },
		[5] = { g("grunt", 14, 0.50), g("regenerator", 3, 0.90, 0.85) },
		[6] = { g("runner", 12, 0.52), g("grunt", 12, 0.52, 1.20) },
		[7] = { g("grunt", 10, 0.50), g("regenerator", 4, 0.88, 0.80), g("grunt", 8, 0.50, 1.00) },
		[8] = { g("bulwark", 4, 1.40), g("runner", 12, 0.50, 1.10) },
		[9] = { g("grunt", 14, 0.50), g("regenerator", 4, 0.86, 0.70), g("runner", 8, 0.50, 0.90) },
		[10] = { g("boss", 1, 0.00), g("grunt", 14, 0.52, 1.25), g("regenerator", 4, 0.90, 0.90) },
		[11] = { g("bulwark", 4, 1.36), g("grunt", 16, 0.50, 1.00) },
		[12] = { g("grunt", 16, 0.50), g("regenerator", 5, 0.84, 0.70) },
		[13] = { g("runner", 16, 0.50), g("bulwark", 4, 1.33, 0.95) },
		[14] = { g("grunt", 12, 0.50), g("regenerator", 5, 0.82, 0.65), g("grunt", 10, 0.50, 0.85) },
		[15] = { g("bulwark", 2, 1.98), g("grunt", 18, 0.50, 1.60) },
		[16] = { g("grunt", 16, 0.50), g("regenerator", 5, 0.80, 0.60), g("runner", 10, 0.50, 0.80) },
		[17] = { g("bulwark", 3, 1.89), g("runner", 16, 0.50, 1.40) },
		[18] = { g("bulwark", 5, 1.30), g("grunt", 18, 0.50, 0.75) },
		[19] = { g("grunt", 14, 0.50), g("regenerator", 6, 0.78, 0.55), g("runner", 10, 0.50, 0.75) },
		[20] = { g("boss", 1, 0.00), g("bulwark", 3, 1.80, 1.20), g("grunt", 18, 0.50, 1.30) },
	},
	terrace = {
		-- 17 grunts.
		[1] = { g("grunt", 17, 0.61) },
		-- 9 warcallers.
		[2] = { g("warcaller", 9, 0.80) },
		-- 13 grunts followed by 4 warcallers.
		[3] = { g("grunt", 13, 0.56), g("warcaller", 4, 0.79, 1.08) },
		-- 10 warcallers followed by 13 grunts.
		[4] = { g("warcaller", 10, 0.64), g("grunt", 13, 0.50, 0.58) },
		-- 10 regenerators followed by 7 warcallers.
		[5] = { g("regenerator", 10, 0.67), g("warcaller", 7, 0.61, 0.50) },
		-- 10 warcallers, then 9 regenerators, and 13 bulwarks.
		[6] = { g("warcaller", 10, 0.60), g("regenerator", 9, 0.61, 0.36), g("bulwark", 13, 1.35, 0.72) },
		-- 6 warcallers, then 7 regenerators, then 7 bulwarks, and 8 runners.
		[7] = { g("warcaller", 6, 0.60), g("regenerator", 7, 0.60, 0.22), g("bulwark", 7, 1.19, 0.50), g("runner", 8, 0.57, 0.72) },
		-- 8 warcallers, then 7 grunts, then 9 bulwarks, and 10 runners.
		[8] = { g("warcaller", 8, 0.60), g("grunt", 7, 0.50, 0.22), g("bulwark", 5, 0.85, 0.48), g("runner", 10, 0.50, 0.65) },
		-- 6 warcallers, then 7 regenerators, then 8 bulwarks, then 8 runners, and 9 bulwarks.
		[9] = { g("warcaller", 6, 0.60), g("regenerator", 7, 0.60, 0.14), g("bulwark", 8, 1.17, 0.36), g("runner", 8, 0.50, 0.58), g("bulwark", 5, 0.88, 0.81) },
		-- 1 boss, then 6 warcallers, then 7 regenerators, then 8 bulwarks, and 7 runners.
		[10] = { g("boss", 1, 0.00), g("warcaller", 6, 0.60, 1.30), g("regenerator", 7, 0.60, 1.44), g("bulwark", 8, 1.17, 1.66), g("runner", 7, 0.54, 1.80) },
		[11] = { g("warcaller", 6, 0.60), g("regenerator", 8, 0.60, 0.24), g("bulwark", 8, 1.19, 0.55), g("runner", 9, 0.57, 0.79) },
		[12] = { g("warcaller", 11, 0.60), g("regenerator", 10, 0.61, 0.38), g("bulwark", 15, 1.35, 0.76) },
		[13] = { g("warcaller", 9, 0.60), g("grunt", 8, 0.50, 0.22), g("bulwark", 6, 0.85, 0.48), g("runner", 11, 0.50, 0.65) },
		[14] = { g("warcaller", 7, 0.60), g("regenerator", 8, 0.60, 0.21), g("bulwark", 8, 1.19, 0.47), g("runner", 9, 0.57, 0.68) },
		[15] = { g("warcaller", 7, 0.60), g("regenerator", 8, 0.60, 0.15), g("bulwark", 9, 1.17, 0.38), g("runner", 9, 0.50, 0.61), g("bulwark", 6, 0.88, 0.85) },
		[16] = { g("warcaller", 12, 0.60), g("regenerator", 11, 0.61, 0.32), g("bulwark", 16, 1.35, 0.65) },
		[17] = { g("warcaller", 10, 0.60), g("grunt", 8, 0.50, 0.20), g("bulwark", 7, 0.85, 0.44), g("runner", 12, 0.50, 0.59) },
		[18] = { g("warcaller", 8, 0.60), g("regenerator", 9, 0.60, 0.19), g("bulwark", 9, 1.19, 0.42), g("runner", 10, 0.57, 0.61) },
		[19] = { g("warcaller", 8, 0.60), g("regenerator", 9, 0.60, 0.12), g("bulwark", 10, 1.17, 0.31), g("runner", 10, 0.50, 0.49), g("bulwark", 7, 0.88, 0.68) },
		[20] = { g("boss", 1, 0.00), g("warcaller", 8, 0.60, 1.17), g("regenerator", 9, 0.60, 1.30), g("bulwark", 10, 1.17, 1.49), g("runner", 9, 0.54, 1.62) },
	},
	highridge = {
		-- 17 grunts.
		[1] = { g("grunt", 17, 0.78) },
		-- 6 bulwarks followed by 6 runners.
		[2] = { g("bulwark", 6, 1.84), g("runner", 6, 0.70, 0.30) },
		-- 13 grunts, then 2 bulwarks, and 2 runners.
		[3] = { g("grunt", 13, 0.72), g("bulwark", 2, 1.82, 1.80), g("runner", 2, 0.69, 2.10) },
		-- 6 bulwarks, then 6 runners, and 13 grunts.
		[4] = { g("bulwark", 6, 1.51), g("runner", 6, 0.55, 0.30), g("grunt", 13, 0.59, 0.96) },
		-- 10 warcallers, then 4 bulwarks, and 4 runners.
		[5] = { g("warcaller", 10, 0.89), g("bulwark", 4, 1.46, 0.84), g("runner", 4, 0.53, 1.14) },
		-- 6 bulwarks, then 6 runners, then 10 warcallers, and 13 regenerators.
		[6] = { g("bulwark", 6, 1.26), g("runner", 6, 0.50, 0.30), g("warcaller", 10, 0.79, 0.60), g("regenerator", 13, 0.87, 1.20) },
		-- 3 bulwarks, then 4 runners, then 7 warcallers, then 7 regenerators, and 8 bulwarks.
		[7] = { g("bulwark", 3, 1.19), g("runner", 4, 0.50, 0.30), g("warcaller", 7, 0.70, 0.36), g("regenerator", 7, 0.76, 0.84), g("bulwark", 8, 1.60, 1.20) },
		-- 8 warcallers, then 4 bulwarks, then 5 runners, then 9 grunts, and 10 bulwarks.
		[8] = { g("warcaller", 8, 0.60), g("bulwark", 4, 1.21, 0.36), g("runner", 5, 0.50, 0.66), g("grunt", 9, 0.58, 0.72), g("bulwark", 6, 1.07, 1.21) },
		-- 4 bulwarks, then 4 runners, then 8 warcallers, then 9 regenerators, then 8 bulwarks, and 10 runners.
		[9] = { g("bulwark", 4, 1.17), g("runner", 4, 0.50, 0.30), g("warcaller", 8, 0.60, 0.24), g("regenerator", 9, 0.64, 0.60), g("bulwark", 8, 1.37, 0.96), g("runner", 10, 0.68, 1.20) },
		-- 1 boss, then 4 bulwarks, then 4 runners, then 7 warcallers, then 8 regenerators, and 8 bulwarks.
		[10] = { g("boss", 1, 0.00), g("bulwark", 4, 1.17, 2.16), g("runner", 4, 0.50, 2.46), g("warcaller", 7, 0.65, 2.40), g("regenerator", 8, 0.72, 2.76), g("bulwark", 8, 1.53, 3.00) },
		[11] = { g("bulwark", 3, 1.19), g("runner", 4, 0.50, 0.33), g("warcaller", 8, 0.70, 0.40), g("regenerator", 8, 0.76, 0.92), g("bulwark", 9, 1.60, 1.32) },
		[12] = { g("bulwark", 7, 1.26), g("runner", 7, 0.50, 0.32), g("warcaller", 11, 0.79, 0.63), g("regenerator", 15, 0.87, 1.26) },
		[13] = { g("warcaller", 9, 0.60), g("bulwark", 4, 1.21, 0.36), g("runner", 6, 0.50, 0.66), g("grunt", 10, 0.58, 0.72), g("bulwark", 7, 1.07, 1.21) },
		[14] = { g("bulwark", 3, 1.19), g("runner", 5, 0.50, 0.28), g("warcaller", 8, 0.70, 0.34), g("regenerator", 8, 0.76, 0.80), g("bulwark", 9, 1.60, 1.14) },
		[15] = { g("bulwark", 4, 1.17), g("runner", 4, 0.50, 0.32), g("warcaller", 9, 0.60, 0.25), g("regenerator", 10, 0.64, 0.63), g("bulwark", 9, 1.37, 1.01), g("runner", 11, 0.68, 1.26) },
		[16] = { g("bulwark", 7, 1.26), g("runner", 7, 0.50, 0.27), g("warcaller", 12, 0.79, 0.54), g("regenerator", 16, 0.87, 1.08) },
		[17] = { g("warcaller", 10, 0.60), g("bulwark", 5, 1.21, 0.32), g("runner", 6, 0.50, 0.59), g("grunt", 11, 0.58, 0.65), g("bulwark", 7, 1.07, 1.09) },
		[18] = { g("bulwark", 4, 1.19), g("runner", 5, 0.50, 0.26), g("warcaller", 9, 0.70, 0.31), g("regenerator", 9, 0.76, 0.71), g("bulwark", 10, 1.60, 1.02) },
		[19] = { g("bulwark", 5, 1.17), g("runner", 5, 0.50, 0.26), g("warcaller", 10, 0.60, 0.20), g("regenerator", 11, 0.64, 0.51), g("bulwark", 10, 1.37, 0.82), g("runner", 13, 0.68, 1.02) },
		[20] = { g("boss", 1, 0.00), g("bulwark", 5, 1.17, 1.94), g("runner", 5, 0.50, 2.21), g("warcaller", 9, 0.65, 2.16), g("regenerator", 10, 0.72, 2.48), g("bulwark", 10, 1.53, 2.70) },
	},
	crossflow = {
		-- 19 grunts.
		[1] = { g("grunt", 19, 0.56) },
		-- 6 bulwarks followed by 6 runners.
		[2] = { g("bulwark", 6, 1.42), g("runner", 6, 0.51, 0.30) },
		-- 14 grunts, then 2 bulwarks, and 2 runners.
		[3] = { g("grunt", 14, 0.53), g("bulwark", 2, 1.40, 0.60), g("runner", 2, 0.50, 0.90) },
		-- 6 bulwarks, then 7 runners, and 13 grunts.
		[4] = { g("bulwark", 6, 1.19), g("runner", 7, 0.50, 0.30), g("grunt", 13, 0.50, 0.28) },
		-- 11 warcallers, then 4 bulwarks, and 4 runners.
		[5] = { g("warcaller", 11, 0.66), g("bulwark", 4, 1.17, 0.23), g("runner", 4, 0.50, 0.53) },
		-- 6 bulwarks, then 7 runners, then 10 warcallers, and 13 regenerators.
		[6] = { g("bulwark", 6, 1.17), g("runner", 7, 0.50, 0.30), g("warcaller", 10, 0.60, 0.15), g("regenerator", 13, 0.67, 0.37) },
		-- 3 bulwarks, then 4 runners, then 7 warcallers, then 7 regenerators, and 8 bulwarks.
		[7] = { g("bulwark", 3, 1.17), g("runner", 4, 0.50, 0.30), g("warcaller", 7, 0.60, 0.08), g("regenerator", 7, 0.60, 0.23), g("bulwark", 8, 1.24, 0.37) },
		-- 4 bulwarks, then 5 runners, then 8 grunts, then 9 bulwarks, and 10 runners.
		[8] = { g("bulwark", 4, 1.17), g("runner", 5, 0.50, 0.30), g("grunt", 8, 0.50, 0.08), g("bulwark", 5, 0.85, 0.21), g("runner", 10, 0.50, 0.33) },
		-- 3 bulwarks, then 4 runners, then 7 warcallers, then 8 regenerators, then 8 bulwarks, and 9 runners.
		[9] = { g("bulwark", 3, 1.17), g("runner", 4, 0.50, 0.30), g("warcaller", 7, 0.60, 0.08), g("regenerator", 8, 0.60, 0.15), g("bulwark", 8, 1.17, 0.28), g("runner", 9, 0.50, 0.37) },
		-- 1 boss, then 4 bulwarks, then 4 runners, then 7 warcallers, then 8 regenerators, and 8 bulwarks.
		[10] = { g("boss", 1, 0.00), g("bulwark", 4, 1.17, 0.73), g("runner", 4, 0.50, 1.03), g("warcaller", 7, 0.60, 0.82), g("regenerator", 8, 0.60, 0.95), g("bulwark", 8, 1.21, 1.04) },
		[11] = { g("bulwark", 3, 1.17), g("runner", 4, 0.50, 0.33), g("warcaller", 8, 0.60, 0.09), g("regenerator", 8, 0.60, 0.25), g("bulwark", 9, 1.24, 0.41) },
		[12] = { g("bulwark", 7, 1.17), g("runner", 8, 0.50, 0.32), g("warcaller", 11, 0.60, 0.16), g("regenerator", 15, 0.67, 0.39) },
		[13] = { g("bulwark", 4, 1.17), g("runner", 6, 0.50, 0.30), g("grunt", 9, 0.50, 0.08), g("bulwark", 6, 0.85, 0.21), g("runner", 11, 0.50, 0.33) },
		[14] = { g("bulwark", 3, 1.17), g("runner", 5, 0.50, 0.28), g("warcaller", 8, 0.60, 0.08), g("regenerator", 8, 0.60, 0.22), g("bulwark", 9, 1.24, 0.35) },
		[15] = { g("bulwark", 3, 1.17), g("runner", 4, 0.50, 0.32), g("warcaller", 8, 0.60, 0.08), g("regenerator", 9, 0.60, 0.16), g("bulwark", 9, 1.17, 0.29), g("runner", 10, 0.50, 0.39) },
		[16] = { g("bulwark", 7, 1.17), g("runner", 9, 0.50, 0.27), g("warcaller", 12, 0.60, 0.14), g("regenerator", 16, 0.67, 0.33) },
		[17] = { g("bulwark", 5, 1.17), g("runner", 6, 0.50, 0.27), g("grunt", 10, 0.50, 0.07), g("bulwark", 7, 0.85, 0.19), g("runner", 12, 0.50, 0.30) },
		[18] = { g("bulwark", 4, 1.17), g("runner", 5, 0.50, 0.26), g("warcaller", 9, 0.60, 0.07), g("regenerator", 9, 0.60, 0.20), g("bulwark", 10, 1.24, 0.31) },
		[19] = { g("bulwark", 4, 1.17), g("runner", 5, 0.50, 0.26), g("warcaller", 9, 0.60, 0.07), g("regenerator", 10, 0.60, 0.13), g("bulwark", 10, 1.17, 0.24), g("runner", 11, 0.50, 0.31) },
		[20] = { g("boss", 1, 0.00), g("bulwark", 5, 1.17, 0.66), g("runner", 5, 0.50, 0.93), g("warcaller", 9, 0.60, 0.74), g("regenerator", 10, 0.60, 0.85), g("bulwark", 10, 1.21, 0.94) },
	},
	steppingstones = {
		-- 20 grunts.
		[1] = { g("grunt", 20, 0.80) },
		-- 6 bulwarks followed by 6 runners.
		[2] = { g("bulwark", 6, 1.93), g("runner", 6, 0.74, 0.30) },
		-- 14 grunts, then 2 bulwarks, and 2 runners.
		[3] = { g("grunt", 14, 0.76), g("bulwark", 2, 1.89, 3.00), g("runner", 2, 0.72, 3.30) },
		-- 6 bulwarks, then 7 runners, and 13 grunts.
		[4] = { g("bulwark", 6, 1.58), g("runner", 7, 0.58, 0.30), g("grunt", 13, 0.63, 1.60) },
		-- 11 warcallers, then 4 bulwarks, and 5 runners.
		[5] = { g("warcaller", 11, 0.94), g("bulwark", 4, 1.53, 1.40), g("runner", 5, 0.56, 1.70) },
		-- 5 bulwarks, then 7 runners, then 10 warcallers, and 13 regenerators.
		[6] = { g("bulwark", 5, 1.31), g("runner", 7, 0.50, 0.30), g("warcaller", 10, 0.84, 1.00), g("regenerator", 13, 0.91, 2.00) },
		-- 3 bulwarks, then 4 runners, then 7 warcallers, then 7 regenerators, and 8 bulwarks.
		[7] = { g("bulwark", 3, 1.24), g("runner", 4, 0.50, 0.30), g("warcaller", 7, 0.73, 0.95), g("regenerator", 7, 0.80, 1.75), g("bulwark", 8, 1.67, 2.35) },
		-- 8 grunts, then 8 bulwarks, then 9 runners, and 10 bulwarks.
		[8] = { g("grunt", 8, 0.50), g("bulwark", 5, 0.91, 1.06), g("runner", 9, 0.61, 1.55), g("bulwark", 10, 1.49, 2.15) },
		-- 4 bulwarks, then 4 runners, then 8 warcallers, then 9 regenerators, then 9 bulwarks, and 10 runners.
		[9] = { g("bulwark", 4, 1.17), g("runner", 4, 0.50, 0.30), g("warcaller", 8, 0.61, 0.75), g("regenerator", 9, 0.68, 1.35), g("bulwark", 9, 1.42, 1.95), g("runner", 10, 0.72, 2.35) },
		-- 1 boss, then 4 bulwarks, then 4 runners, then 7 warcallers, then 8 regenerators, and 8 bulwarks.
		[10] = { g("boss", 1, 0.00), g("bulwark", 4, 1.17, 3.95), g("runner", 4, 0.50, 4.25), g("warcaller", 7, 0.70, 4.35), g("regenerator", 8, 0.76, 4.95), g("bulwark", 8, 1.60, 5.35) },
		[11] = { g("bulwark", 3, 1.24), g("runner", 4, 0.50, 0.33), g("warcaller", 8, 0.73, 1.04), g("regenerator", 8, 0.80, 1.93), g("bulwark", 9, 1.67, 2.59) },
		[12] = { g("bulwark", 6, 1.31), g("runner", 8, 0.50, 0.32), g("warcaller", 11, 0.84, 1.05), g("regenerator", 15, 0.91, 2.10) },
		[13] = { g("grunt", 9, 0.50), g("bulwark", 5, 0.91, 1.06), g("runner", 10, 0.61, 1.55), g("bulwark", 11, 1.49, 2.15) },
		[14] = { g("bulwark", 3, 1.24), g("runner", 5, 0.50, 0.28), g("warcaller", 8, 0.73, 0.90), g("regenerator", 8, 0.80, 1.66), g("bulwark", 9, 1.67, 2.23) },
		[15] = { g("bulwark", 4, 1.17), g("runner", 4, 0.50, 0.32), g("warcaller", 9, 0.61, 0.79), g("regenerator", 10, 0.68, 1.42), g("bulwark", 10, 1.42, 2.05), g("runner", 11, 0.72, 2.47) },
		[16] = { g("bulwark", 6, 1.31), g("runner", 9, 0.50, 0.27), g("warcaller", 12, 0.84, 0.90), g("regenerator", 16, 0.91, 1.80) },
		[17] = { g("grunt", 10, 0.50), g("bulwark", 6, 0.91, 0.95), g("runner", 11, 0.61, 1.40), g("bulwark", 12, 1.49, 1.94) },
		[18] = { g("bulwark", 4, 1.24), g("runner", 5, 0.50, 0.26), g("warcaller", 9, 0.73, 0.81), g("regenerator", 9, 0.80, 1.49), g("bulwark", 10, 1.67, 2.00) },
		[19] = { g("bulwark", 5, 1.17), g("runner", 5, 0.50, 0.26), g("warcaller", 10, 0.61, 0.64), g("regenerator", 11, 0.68, 1.15), g("bulwark", 11, 1.42, 1.66), g("runner", 13, 0.72, 2.00) },
		[20] = { g("boss", 1, 0.00), g("bulwark", 5, 1.17, 3.56), g("runner", 5, 0.50, 3.83), g("warcaller", 9, 0.70, 3.91), g("regenerator", 10, 0.76, 4.46), g("bulwark", 10, 1.60, 4.81) },
	},
	twinloop = {
		-- 20 grunts.
		[1] = { g("grunt", 20, 0.51) },
		-- 3 summoners.
		[2] = { g("summoner", 3, 1.80) },
		-- 10 grunts followed by 2 summoners.
		[3] = { g("grunt", 10, 0.50), g("summoner", 2, 1.51, 0.93) },
		-- 6 bulwarks, then 7 runners, and 13 grunts.
		[4] = { g("bulwark", 6, 1.17), g("runner", 7, 0.50, 0.30), g("grunt", 13, 0.50, 0.50) },
		-- 1 summoner, then 10 warcallers, then 4 bulwarks, and 4 runners.
		[5] = { g("summoner", 1, 0.00), g("warcaller", 10, 0.62, 0.52), g("bulwark", 4, 1.17, 0.43), g("runner", 4, 0.50, 0.73) },
		-- 6 bulwarks, then 7 runners, then 10 warcallers, and 13 regenerators.
		[6] = { g("bulwark", 6, 1.17), g("runner", 7, 0.50, 0.30), g("warcaller", 10, 0.60, 0.31), g("regenerator", 13, 0.64, 0.62) },
		-- 3 bulwarks, then 4 runners, then 7 warcallers, then 7 regenerators, and 8 bulwarks.
		[7] = { g("bulwark", 3, 1.17), g("runner", 4, 0.50, 0.30), g("warcaller", 7, 0.60, 0.19), g("regenerator", 7, 0.60, 0.43), g("bulwark", 8, 1.21, 0.62) },
		-- 1 summoner, then 7 bulwarks, then 7 runners, then 8 bulwarks, and 10 regenerators.
		[8] = { g("summoner", 1, 0.00), g("bulwark", 4, 0.85, 0.56), g("runner", 7, 0.50, 0.19), g("bulwark", 8, 1.17, 0.37), g("regenerator", 10, 0.60, 0.56) },
		-- 3 bulwarks, then 4 runners, then 7 warcallers, then 8 regenerators, then 8 bulwarks, and 9 runners.
		[9] = { g("bulwark", 3, 1.17), g("runner", 4, 0.50, 0.30), g("warcaller", 7, 0.60, 0.12), g("regenerator", 8, 0.60, 0.31), g("bulwark", 8, 1.17, 0.50), g("runner", 9, 0.50, 0.62) },
		-- 1 boss, then 4 bulwarks, then 4 runners, then 7 warcallers, then 8 regenerators, and 7 bulwarks.
		[10] = { g("boss", 1, 0.00), g("bulwark", 4, 1.17, 1.12), g("runner", 4, 0.50, 1.42), g("warcaller", 7, 0.60, 1.24), g("regenerator", 8, 0.60, 1.43), g("bulwark", 7, 1.17, 1.55) },
		[11] = { g("summoner", 1, 0.00), g("bulwark", 2, 1.17, 0.50), g("runner", 4, 0.50, 0.33), g("warcaller", 8, 0.60, 0.21), g("regenerator", 8, 0.60, 0.47), g("bulwark", 9, 1.21, 0.68) },
		[12] = { g("bulwark", 7, 1.17), g("runner", 8, 0.50, 0.32), g("warcaller", 11, 0.60, 0.33), g("regenerator", 15, 0.64, 0.65) },
		[13] = { g("bulwark", 5, 0.85), g("runner", 8, 0.50, 0.19), g("bulwark", 9, 1.17, 0.37), g("regenerator", 11, 0.60, 0.56) },
		[14] = { g("summoner", 1, 0.00), g("bulwark", 2, 1.17, 0.50), g("runner", 5, 0.50, 0.28), g("warcaller", 8, 0.60, 0.18), g("regenerator", 8, 0.60, 0.41), g("bulwark", 9, 1.21, 0.59) },
		[15] = { g("bulwark", 3, 1.17), g("runner", 4, 0.50, 0.32), g("warcaller", 8, 0.60, 0.13), g("regenerator", 9, 0.60, 0.33), g("bulwark", 9, 1.17, 0.53), g("runner", 10, 0.50, 0.65) },
		[16] = { g("bulwark", 7, 1.17), g("runner", 9, 0.50, 0.27), g("warcaller", 12, 0.60, 0.28), g("regenerator", 16, 0.64, 0.56) },
		[17] = { g("summoner", 1, 0.00), g("bulwark", 5, 0.85, 0.56), g("runner", 8, 0.50, 0.17), g("bulwark", 10, 1.17, 0.33), g("regenerator", 12, 0.60, 0.50) },
		[18] = { g("bulwark", 4, 1.17), g("runner", 5, 0.50, 0.26), g("warcaller", 9, 0.60, 0.16), g("regenerator", 9, 0.60, 0.37), g("bulwark", 10, 1.21, 0.53) },
		[19] = { g("summoner", 1, 0.00), g("bulwark", 3, 1.17, 0.50), g("runner", 5, 0.50, 0.26), g("warcaller", 9, 0.60, 0.10), g("regenerator", 10, 0.60, 0.26), g("bulwark", 10, 1.17, 0.42), g("runner", 11, 0.50, 0.53) },
		[20] = { g("boss", 1, 0.00), g("summoner", 1, 0.00, 1.01), g("bulwark", 4, 1.17, 0.50), g("runner", 5, 0.50, 1.28), g("warcaller", 9, 0.60, 1.12), g("regenerator", 10, 0.60, 1.29), g("bulwark", 9, 1.17, 1.40) },
	},

}


-- Boss selections remain explicit because they affect the spawned enemy type.
-- Each map uses a different boss for its second boss wave, and the pairings
-- vary across maps rather than following one rotation. Across the campaign,
-- Summoners recur as the campaign's reinforcement boss, while the other
-- archetypes keep the surrounding encounters varied.
local bossArchetypesByMapId = {
	riverbend = {[10] = "boss_phasewalker", [20] = "boss_ravager"},
	switchback = {[10] = "boss_summoner", [20] = "boss_suppression"},
	highpass = {[10] = "boss_summoner", [20] = "boss_gatecrasher"},
	roundabout = {[10] = "boss_phasewalker", [20] = "boss_summoner"},
	gauntlet = {[10] = "boss_suppression", [20] = "boss_summoner"},
	snaketrail = {[10] = "boss_summoner", [20] = "boss_phasewalker"},
	backtrack = {[10] = "boss_summoner", [20] = "boss_ravager"},
	lowvalley = {[10] = "boss_suppression", [20] = "boss_phasewalker"},
	circuit = {[10] = "boss_suppression", [20] = "boss_gatecrasher"},
	outerloop = {[10] = "boss_ravager", [20] = "boss_summoner"},
	terrace = {[10] = "boss_suppression", [20] = "boss_phasewalker"},
	highridge = {[10] = "boss_ravager", [20] = "boss_gatecrasher"},
	crossflow = {[10] = "boss_ravager", [20] = "boss_summoner"},
	steppingstones = {[10] = "boss_phasewalker", [20] = "boss_gatecrasher"},
	twinloop = {[10] = "boss_suppression", [20] = "boss_gatecrasher"},
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

-- The hand-authored campaign is intentionally a sequence, not a bag of
-- enemies.  `delay` is the pause before a group begins and `spacing` is the
-- interval between its members.  Roles are short, player-facing explanations
-- of what each part of the encounter is doing.
local waves = {
	[1] = {{ kind = "grunt", count = 12, spacing = 0.85, delay = 0, role = "Opening line" }},
	[2] = {
		{ kind = "grunt", count = 10, spacing = 0.75, delay = 0, role = "Main line" },
		{ kind = "runner", count = 5, spacing = 0.55, delay = 2.0, role = "Late sprint" },
	},
	[3] = {
		{ kind = "runner", count = 7, spacing = 0.62, delay = 0, role = "Early pressure" },
		{ kind = "grunt", count = 14, spacing = 0.48, delay = 1.5, role = "Packed follow-up" },
	},
	[4] = {
		{ kind = "grunt", count = 16, spacing = 0.38, delay = 0, role = "Area-damage check" },
		{ kind = "bulwark", count = 3, spacing = 1.15, delay = 0.4, role = "Durable finish" },
	},
	[5] = {
		{ kind = "tank", count = 5, spacing = 1.1, delay = 0, role = "Heavy vanguard" },
		{ kind = "runner", count = 10, spacing = 0.42, delay = 1.0, role = "Overcommit punish" },
	},
	[6] = {
		{ kind = "grunt", count = 12, spacing = 0.55, delay = 0, role = "Screen" },
		{ kind = "regenerator", count = 6, spacing = 0.8, delay = 1.2, role = "Sustained-pressure check" },
	},
	[7] = {
		{ kind = "bulwark", count = 4, spacing = 0.75, delay = 0, role = "Armored screen" },
		{ kind = "warcaller", count = 5, spacing = 0.25, delay = 0.2, role = "Tight support cadre" },
		{ kind = "grunt", count = 10, spacing = 0.42, delay = 0.5, role = "Accelerated line" },
	},
	[8] = {
		{ kind = "shieldbearer", count = 6, spacing = 0.7, delay = 0, role = "Burst check" },
		{ kind = "regenerator", count = 7, spacing = 0.62, delay = 1.0, role = "Sustained follow-up" },
	},
	[9] = {
		{ kind = "runner", count = 12, spacing = 0.36, delay = 0, role = "Fast probe" },
		{ kind = "tank", count = 7, spacing = 0.9, delay = 0.8, role = "Heavy anchor" },
		{ kind = "warcaller", count = 3, spacing = 0.4, delay = 0.1, role = "Priority targets" },
	},
	[10] = {{ kind = "boss", count = 1, spacing = 0, delay = 0, role = "Boss encounter" }},
	[11] = {
		{ kind = "grunt", count = 22, spacing = 0.3, delay = 0, role = "Firing-cycle bait" },
		{ kind = "bulwark", count = 6, spacing = 0.85, delay = 0.15, role = "Durable threat" },
	},
	[12] = {
		{ kind = "tank", count = 8, spacing = 0.82, delay = 0, role = "Heavy commitment" },
		{ kind = "runner", count = 16, spacing = 0.3, delay = 0.35, role = "Breakthrough wave" },
	},
	[13] = {
		{ kind = "shieldbearer", count = 8, spacing = 0.5, delay = 0, role = "Shield wall" },
		{ kind = "warcaller", count = 5, spacing = 0.3, delay = 0.2, role = "Protected support" },
		{ kind = "grunt", count = 12, spacing = 0.38, delay = 0.3, role = "Buffed reserve" },
	},
	[14] = {
		{ kind = "regenerator", count = 10, spacing = 0.48, delay = 0, role = "Sustained-pressure line" },
		{ kind = "runner", count = 14, spacing = 0.28, delay = 0.5, role = "Target-switch check" },
	},
	[15] = {
		{ kind = "bulwark", count = 7, spacing = 0.62, delay = 0, role = "Armored screen" },
		{ kind = "warcaller", count = 7, spacing = 0.22, delay = 0.1, role = "Packed support core" },
		{ kind = "tank", count = 7, spacing = 0.7, delay = 0.4, role = "Heavy rear guard" },
	},
	[16] = {
		{ kind = "grunt", count = 26, spacing = 0.25, delay = 0, role = "Area-damage lure" },
		{ kind = "shieldbearer", count = 9, spacing = 0.52, delay = 0.1, role = "Burst finish" },
	},
	[17] = {
		{ kind = "shieldbearer", count = 9, spacing = 0.45, delay = 0, role = "Shield wall" },
		{ kind = "regenerator", count = 11, spacing = 0.42, delay = 0.25, role = "Recovery column" },
		{ kind = "runner", count = 12, spacing = 0.27, delay = 0.4, role = "Fast closer" },
	},
	[18] = {
		{ kind = "runner", count = 18, spacing = 0.25, delay = 0, role = "Opening rush" },
		{ kind = "tank", count = 10, spacing = 0.68, delay = 0.25, role = "Heavy reversal" },
		{ kind = "runner", count = 12, spacing = 0.25, delay = 0.3, role = "Second rush" },
	},
	[19] = {
		{ kind = "bulwark", count = 8, spacing = 0.48, delay = 0, role = "Armored escort" },
		{ kind = "warcaller", count = 6, spacing = 0.2, delay = 0.05, role = "Support cluster" },
		{ kind = "shieldbearer", count = 8, spacing = 0.4, delay = 0.25, role = "Shielded push" },
		{ kind = "regenerator", count = 8, spacing = 0.4, delay = 0.25, role = "Endurance finish" },
	},
	[20] = {{ kind = "boss", count = 1, spacing = 0, delay = 0, role = "Campaign finale" }},
}

return waves

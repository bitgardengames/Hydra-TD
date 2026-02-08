local DifficultyCurve = require("systems.difficulty_curve")

local Builder = {}

-- Wave templates define structure, not difficulty
local Templates = {
	standard = {
		enemy = "grunt",
		baseCount = 12,
		spacing = 0.65,
	},

	dense = {
		enemy = "splitter",
		baseCount = 12,
		spacing = 0.35,
	},

	fast = {
		enemy = "runner",
		baseCount = 20,
		spacing = 0.45,
	},

	tanky = {
		enemy = "tank",
		baseCount = 8,
		spacing = 0.85,
	},
}

-- Simple deterministic template selection
local function pickTemplate(waveIndex)
	if waveIndex % 5 == 0 then
		return Templates.dense
	end

	if waveIndex % 7 == 0 then
		return Templates.fast
	end

	if waveIndex % 9 == 0 then
		return Templates.tanky
	end

	return Templates.standard
end

local function jitter(value)
	return value * (0.9 + love.math.random() * 0.2)
end

function Builder.build(waveIndex)
	-- Boss invariant: every 10th wave, no exceptions
	if waveIndex % 10 == 0 then
		return {
			boss = true,
			enemy = "boss",
			count = 1,
			spacing = 0,
		}
	end

	local template = pickTemplate(waveIndex)
	local scalar = DifficultyCurve.getScalar(waveIndex)

	return {
		boss = false,
		enemy = template.enemy,
		count = math.max(1, math.floor(template.baseCount * scalar)),
		spacing = jitter(template.spacing),
	}
end

return Builder
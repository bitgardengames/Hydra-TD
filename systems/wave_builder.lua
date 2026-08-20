local CampaignWaveDefs = require("systems.campaign_wave_defs")

local Builder = {}

function Builder.build(waveIndex, mapDef)
	waveIndex = math.max(1, math.floor(tonumber(waveIndex) or 1))
	local campaignGroups = CampaignWaveDefs.get(mapDef, waveIndex)
	if campaignGroups then
		local count = 0
		local composition = {}
		for _, group in ipairs(campaignGroups) do
			count = count + group.count
			for _ = 1, group.count do composition[#composition + 1] = group.kind end
		end
		return {
			boss = campaignGroups[1].kind == "boss",
			enemy = campaignGroups[1].kind,
			count = count,
			spacing = campaignGroups[1].spacing,
			groups = campaignGroups,
			composition = composition,
			intensityTier = 0,
			bossArchetype = campaignGroups.bossArchetype,
		}
	end

	return nil
end

return Builder

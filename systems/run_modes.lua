local RunModes = {}

RunModes.CAMPAIGN = "campaign"
RunModes.ENDLESS = "endless"

local valid = {campaign = true, endless = true}

function RunModes.normalize(mode)
	return valid[mode] and mode or RunModes.CAMPAIGN
end

function RunModes.set(state, mode)
	state.runMode = RunModes.normalize(mode)
	return state.runMode
end

function RunModes.get(state)
	return RunModes.normalize(state and state.runMode)
end

-- Internal plumbing for the module playtest entry point in systems/modules.lua.
-- Run selection must never call this or infer the value from replay/endless mode.
function RunModes._setExperimentalModulesForPlaytest(state, enabled)
	state.runRules = state.runRules or {}
	state.runRules.experimentalModules = enabled == true
	return state.runRules.experimentalModules
end

function RunModes.experimentalModulesEnabled(state)
	return state ~= nil
		and state.runRules ~= nil
		and state.runRules.experimentalModules == true
end

function RunModes.isCampaign(state) return RunModes.get(state) == RunModes.CAMPAIGN end
function RunModes.isEndless(state) return RunModes.get(state) == RunModes.ENDLESS end
function RunModes.isReplay(state) return not RunModes.isCampaign(state) end
function RunModes.hasCampaignVictory(state) return RunModes.isCampaign(state) end
function RunModes.awardsCampaignProgress(state) return RunModes.isCampaign(state) end
function RunModes.lossCondition(state) return (tonumber(state and state.lives) or 0) <= 0 end

return RunModes

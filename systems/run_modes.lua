local RunModes = {}

RunModes.CAMPAIGN = "campaign"
RunModes.REPLAY = "replay"
RunModes.MODULE_PLAYTEST = "module_playtest"

local valid = {campaign = true, replay = true, module_playtest = true}

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
-- Run selection must never call this or infer the value from replay mode.
function RunModes._setExperimentalModulesForPlaytest(state, enabled)
	state.runRules = state.runRules or {}
	state.runRules.experimentalModules = enabled == true
	if enabled == true then
		state.runMode = RunModes.MODULE_PLAYTEST
	end
	return state.runRules.experimentalModules
end

function RunModes.experimentalModulesEnabled(state)
	return state ~= nil
		and RunModes.get(state) == RunModes.MODULE_PLAYTEST
		and state.runRules ~= nil
		and state.runRules.experimentalModules == true
end

function RunModes.isCampaign(state) return RunModes.get(state) == RunModes.CAMPAIGN end
function RunModes.isReplay(state) return RunModes.get(state) == RunModes.REPLAY end
function RunModes.hasCampaignVictory() return true end
function RunModes.awardsCampaignProgress() return true end
function RunModes.lossCondition(state) return (tonumber(state and state.lives) or 0) <= 0 end

return RunModes

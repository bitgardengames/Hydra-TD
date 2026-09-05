local RunModes = require("systems.run_modes")
local state = {lives = 1}

assert(RunModes.get(state) == RunModes.CAMPAIGN, "missing modes normalize to campaign")
assert(RunModes.set(state, "unsupported") == RunModes.CAMPAIGN,
	"unsupported modes must normalize to campaign")
assert(not RunModes.experimentalModulesEnabled(state),
	"campaign must not implicitly enable experimental modules")
RunModes._setExperimentalModulesForPlaytest(state, true)
assert(RunModes.experimentalModulesEnabled(state), "internal module experiments should be explicitly opt-in")
RunModes.set(state, RunModes.CAMPAIGN)
assert(RunModes.experimentalModulesEnabled(state), "changing modes must not silently change experiment rules")
RunModes._setExperimentalModulesForPlaytest(state, false)
assert(RunModes.awardsCampaignProgress(state), "campaign runs must award campaign progress")
assert(RunModes.hasCampaignVictory(state), "campaign runs must end in victory")
assert(not RunModes.lossCondition(state), "a living player must not lose")
state.lives = 0
assert(RunModes.lossCondition(state), "the loss condition must be explicit and life-based")

print("run mode fixtures passed")

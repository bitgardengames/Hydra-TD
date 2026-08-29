local RunModes = require("systems.run_modes")
local state = {lives = 1}

assert(RunModes.get(state) == RunModes.CAMPAIGN, "missing modes normalize to campaign")
RunModes.set(state, RunModes.ENDLESS)
assert(RunModes.isEndless(state), "endless selection was not retained")
assert(not RunModes.experimentalModulesEnabled(state), "endless must not implicitly enable experimental modules")
RunModes._setExperimentalModulesForPlaytest(state, true)
assert(RunModes.experimentalModulesEnabled(state), "internal module experiments should be explicitly opt-in")
RunModes.set(state, RunModes.CAMPAIGN)
assert(RunModes.experimentalModulesEnabled(state), "changing modes must not silently change experiment rules")
RunModes._setExperimentalModulesForPlaytest(state, false)
RunModes.set(state, RunModes.ENDLESS)
assert(not RunModes.awardsCampaignProgress(state), "endless must never award campaign progress")
assert(not RunModes.hasCampaignVictory(state), "wave 20 must transition rather than win in endless")
assert(not RunModes.lossCondition(state), "a living player must not lose endless")
state.lives = 0
assert(RunModes.lossCondition(state), "endless loss condition must be explicit and life-based")

print("run mode fixtures passed")

-- Dependency-free source checks for the Victory screen's persistent reward summary.
local file = assert(io.open("ui/menu/screens/victory.lua", "r"))
local source = file:read("*a")
file:close()

assert(source:find("local earnedRewardCards = {}", 1, true),
	"victory must retain earned rewards after the unlock overlay is dismissed")
assert(source:find("local mapRewardCards = {}", 1, true),
	"victory must retain the completed map's reward for its persistent summary")
assert(source:find("CampaignUnlocks.getRewardsForMap(map)", 1, true),
	"victory must show the reward associated with the completed map")
assert(source:find("drawRewardsPanel(rightX, rewardsY", 1, true),
	"victory must render its rewards panel")
assert(source:find("Text.printfShadow(reward.name", 1, true),
	"the rewards panel must name the map reward")
assert(source:find("reward.labelKey and L(reward.labelKey)", 1, true),
	"victory must localize authored ability reward labels")
assert(source:find('"victory.rewardNew" or "victory.rewardAlreadyUnlocked"', 1, true),
	"the rewards panel must distinguish a new reward from an existing unlock")
assert(source:find("DrawEntities.drawTowerCore(reward.id", 1, true),
	"tower rewards must use their actual tower sprite")
assert(not source:find('L("victory.coinsEarned")', 1, true),
	"remaining money must not be presented as coins earned")
assert(not source:find('L("runRecap.score"), "+"', 1, true),
	"score must not be presented as a reward")

print("victory reward fixtures passed")

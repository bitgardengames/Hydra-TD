-- Dependency-free source checks for the Victory screen's persistent reward summary.
local file = assert(io.open("ui/menu/screens/victory.lua", "r"))
local source = file:read("*a")
file:close()

assert(source:find("local earnedRewardCards = {}", 1, true),
	"victory must retain earned rewards after the unlock overlay is dismissed")
assert(source:find("drawRewardsPanel(rightX, rewardsY", 1, true),
	"victory must render its rewards panel from the actual unlock collection")
assert(source:find("Text.printfShadow(reward.name", 1, true),
	"the rewards panel must name the unlocked reward")
assert(not source:find('L("victory.coinsEarned")', 1, true),
	"remaining money must not be presented as coins earned")
assert(not source:find('L("runRecap.score"), "+"', 1, true),
	"score must not be presented as a reward")

print("victory reward fixtures passed")

-- Dependency-free source checks for the Victory screen's simplified layout.
local file = assert(io.open("ui/menu/screens/victory.lua", "r"))
local source = file:read("*a")
file:close()

assert(not source:find("drawRewardsPanel", 1, true),
	"victory must not render a rewards panel")
assert(not source:find("mapRewardCards", 1, true),
	"victory must not retain reward-card presentation state")
assert(source:find("drawDamagePanel(rightX, contentY, rightW, contentH, alpha)", 1, true),
	"the damage panel must fill the right column")
assert(not source:find('L("victory.abilitiesUsed")', 1, true),
	"victory must not display an abilities-used row")
assert(source:find("local summaryH = contentH * 0.56", 1, true),
	"the shortened summary must leave more room for medals")
assert(not source:find('L("victory.coinsEarned")', 1, true),
	"remaining money must not be presented as coins earned")
assert(not source:find('L("victory.moneyRemaining")', 1, true),
	"victory must not display a money-remaining row")
assert(not source:find('L("runRecap.score"), "+"', 1, true),
	"score must not be presented as a reward")
assert(not source:find("drawRewardUnlockCard", 1, true),
	"victory must not render a separate reward unlock popup")
assert(not source:find("rewardCardBlockingInput", 1, true),
	"reward unlocks must not block victory screen input")

print("victory layout fixtures passed")

local Constants = require("core.constants")

local state = {
	-- Gameplay data
	money = 100,
	moneyLerp = 100,
	lives = 20,
	livesAnim = 0,
	score = 0,
	-- Run-local recap counters. These deliberately do not mirror persistent
	-- achievement or per-tower history totals.
	totalKills = 0,

	mapIndex = 1,
	worldMapIndex = 1,
	wave = 1,
	waveAnim = 1,
	waveLeaks = 0,
	totalLeaks = 0,
	inPrep = true,

	paused = false,
	pauseT = 0,
	gameOver = false,
	victory = false,
	endless = false,
	-- Experimental run systems are intentionally limited to replay modes.  Keep
	-- these flags independent from save data so old module discoveries remain
	-- compatible without changing the standard campaign rules.
	challenge = false,
	activeBoss = nil,
	activeBossKind = nil,
	speed = 1,

	endT = 0,
	endReady = false,
	endTitle = nil,
	endReason = nil,

	previousCompletionDifficulty = nil,
	wasFirstClear = false,
	unlockedTowersThisVictory = {},
	unlockedRewardsThisVictory = {},
	unlockedAbilitiesThisVictory = {},

	carouselT = 1,
	carouselDir = 0,

	placing = nil,
	placingFade = 0,
	placingFadeT = 0,
	selectedTower = nil,
	selectedEnemy = nil,
	-- Up to four abilities can be equipped. Cooldowns are tracked separately so
	-- using one ability does not lock the rest of the loadout.
	equippedAbilities = {"meteor", "frost_nova"},
	abilityCooldowns = {},
	abilityTargeting = nil,

	hoverGX = nil,
	hoverGY = nil,

	mode = "menu", -- "menu", "campaign", "game", "pause"

	ignoreStats = false,

	modules = {},
	moduleInventory = {},
	modulePicker = {
		active = false,
		choices = nil,
		waveOffered = 0,
		mode = "wave_reward",
		title = nil,
		subtitle = nil,
		hint = nil,
		tower = nil,
	},

	-- Combat data
	combatStats = {
		damageView = 0,
		damageByTower = {},
		bossDamageByTower = {},
		totalDamage = 0,
		bossTotalDamage = 0,
		showDamageMeter = false,
		damageAlpha = 0,
		damageFadeSpeed = 14,
	},

	spatialStats = {
		localQueryCount = 0,
		localCandidateTotal = 0,
	},

	frameId = 0,
}

function state.isReplayMode()
	return state.challenge == true or state.endless == true
end

function state.addDamage(kind, dmg, isBoss)
    if not kind or not dmg or dmg <= 0 then
		return
	end

    local combatStats = state.combatStats
    combatStats.damageByTower[kind] = (combatStats.damageByTower[kind] or 0) + dmg
    combatStats.totalDamage = (combatStats.totalDamage or 0) + dmg

    if isBoss then
        combatStats.bossDamageByTower[kind] = (combatStats.bossDamageByTower[kind] or 0) + dmg
        combatStats.bossTotalDamage = (combatStats.bossTotalDamage or 0) + dmg
    end

	combatStats.damageDirty = true
end

function state.resetDamage()
	local stats = state.combatStats
	local towerList = Constants.TOWER_LIST
	local damageByTower = {}
	local bossDamageByTower = {}

	stats.damageView = 0

	stats.totalDamage = 0
	stats.bossTotalDamage = 0

	for i = 1, #towerList do
		local kind = towerList[i]

		damageByTower[kind] = 0
		bossDamageByTower[kind] = 0
	end

	stats.damageByTower = damageByTower
	stats.bossDamageByTower = bossDamageByTower
end

function state.resolveMapIndex(index)
	if Constants.IS_DEMO then
		return 1
	end

	return index
end

return state

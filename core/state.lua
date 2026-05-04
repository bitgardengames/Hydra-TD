local Constants = require("core.constants")

local state = {
	-- Gameplay data
	money = 100,
	moneyLerp = 100,
	lives = 20,
	livesAnim = 0,
	score = 0,

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
	activeBoss = nil,
	speed = 1,

	endT = 0,
	endReady = false,
	endTitle = nil,
	endReason = nil,

	previousCompletionDifficulty = nil,
	wasFirstClear = false,

	carouselT = 1,
	carouselDir = 0,

	placing = nil,
	placingFade = 0,
	placingFadeT = 0,
	selectedTower = nil,
	selectedEnemy = nil,

	hoverGX = nil,
	hoverGY = nil,

	mode = "menu", -- "menu", "campaign", "game", "pause"

	inputSource = "keyboard",

	ignoreStats = false,

	modules = {},
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

}

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

	stats.damageView = 0

	stats.totalDamage = 0
	stats.bossTotalDamage = 0

	-- Clear existing keys
	for k in pairs(stats.damageByTower) do
		stats.damageByTower[k] = nil
	end

	for k in pairs(stats.bossDamageByTower) do
		stats.bossDamageByTower[k] = nil
	end

	local towerList = Constants.TOWER_LIST

	for i = 1, #towerList do
		local kind = towerList[i]

		stats.damageByTower[kind] = 0
		stats.bossDamageByTower[kind] = 0
	end
end

function state.resolveMapIndex(index)
	if Constants.IS_DEMO then
		return 1
	end

	return index
end

return state

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
	activeBossKind = nil,
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

	local function addDamageValue(t, key, value)
		t[key] = (t[key] or 0) + value
	end

	local combatStats = state.combatStats
	addDamageValue(combatStats.damageByTower, kind, dmg)
	combatStats.totalDamage = combatStats.totalDamage + dmg

	if isBoss then
		addDamageValue(combatStats.bossDamageByTower, kind, dmg)
		combatStats.bossTotalDamage = combatStats.bossTotalDamage + dmg
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

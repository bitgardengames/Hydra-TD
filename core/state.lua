local state = {
	-- Gameplay data
	money = 100,
	moneyLerp = 100,
	lives = 20,
	livesAnim = 0,
	score = 0,

	mapIndex = 1,
	worldMapIndex = 1,
	wave = 0,
	waveAnim = 1,
	inPrep = true,
	prepTimer = 6.0,

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

	stats.damageByTower.lancer = 0
	stats.bossDamageByTower.lancer = 0

	stats.damageByTower.slow = 0
	stats.bossDamageByTower.slow = 0

	stats.damageByTower.cannon = 0
	stats.bossDamageByTower.cannon = 0

	stats.damageByTower.shock = 0
	stats.bossDamageByTower.shock = 0

	stats.damageByTower.poison = 0
	stats.bossDamageByTower.poison = 0
end

return state
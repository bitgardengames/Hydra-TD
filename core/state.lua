local state = {
	money = 100,
	moneyLerp = 100,
	lives = 20,
	livesAnim = 0,
	score = 0,

	mapIndex = 1,
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

	stats = {
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

    local stats = state.stats
    stats.damageByTower[kind] = (stats.damageByTower[kind] or 0) + dmg
    stats.totalDamage = (stats.totalDamage or 0) + dmg

    if isBoss then
        stats.bossDamageByTower[kind] = (stats.bossDamageByTower[kind] or 0) + dmg
        stats.bossTotalDamage = (stats.bossTotalDamage or 0) + dmg
    end

	stats.damageDirty = true
end

state.stats.damageByTower.lancer = 0
state.stats.damageByTower.slow = 0
state.stats.damageByTower.cannon = 0
state.stats.damageByTower.shock = 0
state.stats.damageByTower.poison = 0

return state
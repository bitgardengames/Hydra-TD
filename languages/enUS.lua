return {
	meta = {
		name = "English",
		locale = "enUS",
		font = "latin",
	},

	menu = {
		play = "Play",
		settings = "Settings",
		quit = "Quit",
		back = "Back",
		resume = "Resume",
		restart = "Restart",
		mainMenu = "Main Menu",
		nextMap = "Next Map",
		endless = "Endless Mode",
		paused = "Paused",
	},

	settings = {
		title = "Settings",
		music = "Music Volume",
		sfx = "SFX Volume",
		difficulty = "Difficulty",
		fullscreen = "Fullscreen",
		tabAudio = "Audio",
		tabGameplay = "Gameplay",
		tabVideo = "Video",
		tabControls = "Controls",
		controlsComingSoon = "Rebinding UI coming soon.",
		on = "On",
		off = "Off",
	},

	campaign = {
		locked = "LOCKED",
		mapOf = "Map %d of %d",
	},

	difficulty = {
		easy = "Easy",
		normal = "Normal",
		hard = "Hard",
	},

	ui = {
		hotkey = "[%s] ",
		seconds = "%.1fs",
	},

	status = {
		slow = "Slow",
		poison = "Poison",
	},

	damage = {
		normal = "Damage",
		boss = "Boss Damage",
		noneBoss = "No boss damage yet",
	},

	tower = {
		lancer = "Lancer",
		slow = "Slow",
		cannon = "Cannon",
		shock = "Shock",
		poison = "Poison",
		plasma = "Plasma",
	},

	towerDesc = {
		lancer = "Rapid single-target fire",
		slow = "Chills enemies, slowing their movement",
		cannon = "Explosive shots with heavy splash",
		shock = "Chains lightning between targets",
		poison = "Stacks damage over time",
		plasma = "Burns through enemies along its path",
	},

	module = {
		move_linear = "Straight Shots",
		move_boomerang = "Boomerang",
		move_wave = "Wave Shots",
		move_spiral = "Spiral Shots",
		orbit = "Orbiting Shots",

		split = "Split Shots",
		chain = "Chain Lightning",
		aoe = "Explosive Impact",
		tick = "Damage Over Time",
		growth = "Growing Projectiles",
		bounce = "Chaotic Bounce",

		slow = "Chilling Hits",
		poison = "Venom Infusion",
		infect = "Infection Spread",
		orbital_spawn = "Orbital Spawn",
		static = "Static Field",

		pierce = "Piercing Shots",
		suspend = "Delayed Fire",
		explode = "Explosive Hits",
		target_low_hp = "Cull Weakest",
		target_farthest_progress = "Lead Priority",
		target_farthest_range = "Outer Ring",

		beam = "Beam Conversion",
		slow_glacier_core = "Glacier Core",
		slow_permafrost = "Permafrost Shells",
		slow_frost_nova = "Frost Nova",
		slow_shatterburst = "Shatterburst",
		slow_cold_snap = "Cold Snap",
		slow_black_ice = "Black Ice",
		slow_absolute_zero = "Absolute Zero",
		slow_hailstorm = "Hailstorm Engine",
		lancer_deadeye = "Deadeye",
		lancer_volley = "Volley Driver",
		lancer_arc_lance = "Arc Lance",
		poison_blight = "Blight Rounds",
		poison_plague = "Plague Cloud",
		poison_neurotoxin = "Neurotoxin",
		cannon_seige = "Siege Battery",
		cannon_cluster = "Cluster Payload",
		cannon_aftershock = "Aftershock",
		shock_storm = "Storm Coil",
		shock_conductor = "Conductor Field",
		shock_overload = "Overload Array",
		plasma_lance = "Plasma Lance",
		plasma_supernova = "Supernova Core",
		plasma_vortex = "Vortex Helix",
	},

	moduleDesc = {
		move_linear = "Projectiles travel in a straight line instead of homing.",
		move_boomerang = "Shots fly out, then return to the tower.",
		move_wave = "Projectiles move in a wavy pattern.",
		move_spiral = "Shots spiral as they travel.",
		orbit = "Projectiles orbit around the tower.",

		split = "Shots split into multiple projectiles on hit.",
		chain = "Damage jumps between nearby enemies.",
		aoe = "Hits deal area damage.",
		tick = "Projectiles deal damage over time in an area.",
		growth = "Projectiles grow larger and stronger over time.",
		bounce = "Projectiles bounce in random directions.",

		slow = "Hits slow enemies.",
		poison = "Applies stacking poison damage.",
		infect = "Poison spreads to nearby enemies on death.",
		orbital_spawn = "Spawns orbiting projectiles on hit.",
		static = "Creates a damaging static field.",

		pierce = "Projectiles pass through enemies without being consumed.",
		suspend = "Shots pause briefly before firing.",
		explode = "Hits create an explosion.",
		target_low_hp = "Prioritizes the enemy with the lowest HP in range.",
		target_farthest_progress = "Prioritizes enemies furthest along the path.",
		target_farthest_range = "Prioritizes enemies farthest from the tower but still in range.",

		beam = "Converts projectiles into continuous beams.",
		slow_glacier_core = "Longer and stronger slows for lane control.",
		slow_permafrost = "Slowing impacts burst in a small freezing splash.",
		slow_frost_nova = "Hits create static frost zones that punish clustered enemies.",
		slow_shatterburst = "Hits on slowed enemies fracture into slowing frost shards.",
		slow_cold_snap = "Prioritizes weakened enemies and detonates slowed targets in icy bursts.",
		slow_black_ice = "Targets advancing enemies with long-duration chilling splash hits.",
		slow_absolute_zero = "Maximum slow lock with shatter volleys and persistent frost zones.",
		slow_hailstorm = "Splits into hail shards and triggers extra burst damage on slowed clusters.",
		lancer_deadeye = "Prioritizes weak enemies to finish targets quickly.",
		lancer_volley = "Shots split on impact for better crowd pressure.",
		lancer_arc_lance = "Hits chain into nearby enemies for mixed wave clear.",
		poison_blight = "Higher poison damage and duration for elite takedowns.",
		poison_plague = "Weaker poison stacks spread to nearby enemies on death.",
		poison_neurotoxin = "Poisoned hits also briefly slow targets.",
		cannon_seige = "Long-range bombardment with larger blast radius.",
		cannon_cluster = "Explosions split into secondary payloads.",
		cannon_aftershock = "Impacts leave damaging static shock zones.",
		shock_storm = "More chain jumps for maximum lane coverage.",
		shock_conductor = "Chains are supported by persistent static fields.",
		shock_overload = "Chains trigger orbital discharges on impact.",
		plasma_lance = "Long straight plasma with high tick cadence.",
		plasma_supernova = "Plasma burns and bursts for extra area pressure.",
		plasma_vortex = "Spiral plasma expands as it travels.",
	},

	modulePicker = {
		upgradeTitle = "%s Specialization",
		upgradeSubtitle = "Choose an upgrade • $%d",
		hint = "Press 1, 2, or 3 • Click a card",
		selectCta = "Click to Upgrade",
		noSpec = "No specialization selected yet.",
		currentSpec = "Current: %s",
	},

	enemy = {
		grunt = "Grunt",
		tank = "Tank",
		runner = "Runner",
		boss = "Boss",
	},

	hud = {
		lives = "Lives %d",
		wave = "Wave %d",
		prep = "Press %s to start",
		spawning = "Spawning %d - Alive %d",
	},

	messages = {
		bonus = "Perfect Wave +$%s",
	},

	inspect = {
		towerTitle = "%s level %d",
		upgradeTitle = "Upgrade to level %d",
		damage = "Damage: %s",
		kills = "Kills: %d",
		hp = "HP: %s / %s",
		modifiers = "Modifiers:",
	},

	stats = {
		damage = "Damage",
		fireRate = "Fire Rate",
		range = "Range",
	},

	actions = {
		upgrade = "Upgrade",
		sell = "Sell",
	},

	modifier = {
		effect = "effect",
		damage = "damage",
	},

	floater = {
		upgrade = "Upgrade!",
		cannotPlace = "Can't",
		needMoney = "Need $",
	},

	game = {
		victory = "Victory!",
		gameOver = "Defeat",
		bossBreach = "Boss breach",
		outOfLives = "Out of lives",
	},

	gameOver = {
		map = "Map",
		waveReached = "Wave Reached",
		score = "Score",
		momentum = "Momentum",
		momentumStrong = "Strong",
		momentumSteady = "Steady",
		momentumShaky = "Shaky",
		leaks = "Leaks",
		livesRemaining = "Lives Remaining",
		difficultyLabel = "Difficulty",
		recapCollapse = "The line broke at the finish. One extra stopper lane could swing this run.",
		recapClose = "So close. Your core setup was working—tighten boss control and you are there.",
		recapEarly = "Rough opening. Prioritize early lane coverage before greedier upgrades.",
		recapMid = "Solid start, then pressure won. Shift more power into mid-wave stabilization.",
		tipBossBreach = "A boss slipped through. Add focused burst damage and slows before the next boss wave.",
		tipOutOfLives = "Leaks add up quickly. Build earlier lane coverage and upgrade your core towers sooner.",
		tipDefault = "Adjust your tower mix and module choices to handle mid-wave pressure spikes.",
		shortcuts = "Press R to restart • Esc for main menu",
	},

	victory = {
		subtitle = "Defense successful",
		medalProgress = "Difficulty medals earned",
		hint = "Push to a higher difficulty or continue in Endless Mode for a tougher run.",
		shortcuts = "Press N for next map • Esc for main menu",
	},

	map = {
		riverbend = "Riverbend",
		switchback = "Switchback",
		highpass = "High Pass",
		roundabout = "Roundabout",
		gauntlet = "Gauntlet",
		snaketrail = "Snake Trail",
		backtrack = "Backtrack",
		lowvalley = "Low Valley",
		circuit = "Circuit",
		outerloop = "Outer Loop",
		terrace = "Terrace",
		highridge = "High Ridge",
		crossflow = "Crossflow",
		steppingstones = "Stepping Stones",
		twinloop = "Twin Loop",
	},

	presence = {
		menu = "In Menu",
		campaign = "Map Selection",
		gameStatus = "Wave %s - %s",
	},

	achievement = {
		boss_1 = "First Blood",
		boss_50 = "No Mercy",

		kill_500 = "Still Standing",
		kill_1500 = "Keep Them Coming",
		kill_3000 = "Unstoppable Force",

		tower_lancer_250 = "Between the Eyes",
		tower_slow_250 = "Stopped Cold",
		tower_cannon_250 = "Heavy Artillery",
		tower_shock_250 = "High Voltage",
		tower_poison_250 = "It Adds Up",
		tower_plasma_250 = "Overcharge",

		tower_lancer_1000 = "Bullseye",
		tower_slow_1000 = "Absolute Zero",
		tower_cannon_1000 = "Blown Away",
		tower_shock_1000 = "Chain Reaction",
		tower_poison_1000 = "Lethal Dose",
		tower_plasma_1000 = "Critical Mass", -- Power Overwhelming?

		campaign_easy = "First Steps",
		campaign_normal = "Holding the Line",
		campaign_hard = "Total Control",

		no_leaks_normal = "Sealed Tight",
		no_leaks_hard = "Dead End",
		last_second = "Last Second",

		tower_upgrade_1 = "Rising Power",
		tower_upgrade_100 = "Built Up",
	},

	achievementDesc = {
		boss_1 = "Defeat your first boss",
		boss_50 = "Defeat 50 bosses",

		kill_500 = "Defeat 500 enemies",
		kill_1500 = "Defeat 1,500 enemies",
		kill_3000 = "Defeat 3,000 enemies",

		tower_lancer_250 = "Defeat 250 enemies with the Lancer",
		tower_slow_250 = "Defeat 250 enemies with the Slow tower",
		tower_cannon_250 = "Defeat 250 enemies with the Cannon",
		tower_shock_250 = "Defeat 250 enemies with the Shock tower",
		tower_poison_250 = "Defeat 250 enemies with the Poison tower",
		tower_plasma_250 = "Defeat 250 enemies with the Plasma tower",

		tower_lancer_1000 = "Defeat 1,000 enemies with the Lancer",
		tower_slow_1000 = "Defeat 1,000 enemies with the Slow tower",
		tower_cannon_1000 = "Defeat 1,000 enemies with the Cannon",
		tower_shock_1000 = "Defeat 1,000 enemies with the Shock tower",
		tower_poison_1000 = "Defeat 1,000 enemies with the Poison tower",
		tower_plasma_1000 = "Defeat 1,000 enemies with the Plasma tower",

		campaign_easy = "Complete the campaign on Easy",
		campaign_normal = "Complete the campaign on Normal",
		campaign_hard = "Complete the campaign on Hard",

		no_leaks_normal = "Complete a map on Normal without any enemies escaping",
		no_leaks_hard = "Complete a map on Hard without any enemies escaping",
		last_second = "Defeat an enemy at the last second before it escapes",

		tower_upgrade_1 = "Upgrade a tower",
		tower_upgrade_100 = "Upgrade towers 100 times",
	},

	overlay = {
		demoCompleteTitle = "Demo Complete!",
		demoCompleteText = "Thank you for playing the Hydra TD demo!\n\nWishlist the full game to be notified of updates and sales.",

		wishlistSteam = "Wishlist on Steam",
		closeButton = "Close",

		reviewTitle = "Hydra TD Complete!",
		reviewText = "Thank you for playing Hydra TD!\n\nIf you enjoyed the game, a Steam review\nhelps indie developers more than you might think.",

		reviewButton = "Write a Steam Review",
		continue = "Continue",
	},
}

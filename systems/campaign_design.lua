local Maps = require("world.map_defs")
local CampaignUnlocks = require("systems.campaign_unlocks")

local CampaignDesign = {}

-- Teaching plan keyed by map id. Map order remains world/map_defs.lua; rewards
-- remain systems/campaign_unlocks.lua. Each entry states the playable lesson,
-- the pressure that demonstrates it, and the intended non-stat counterplay.
local teachingByMapId = {
	riverbend = {
		lesson = "Cover several bends with each tower to create one shared kill zone.",
		pressure = "Steady Grunt packs test coverage without a second enemy role.",
		counterplay = "Use Lancer on long lanes and Slow near overlapping corners to turn bends into shared damage windows.",
	},
	switchback = {
		lesson = "Slow enemies at overlapping switchbacks so Lancers can fire through the pack.",
		pressure = "Dense Grunt packs test crowd control.",
		counterplay = "Anchor Slow where multiple switchback legs overlap, then line up Lancer shots down the bends so slowed packs stay in piercing lanes.",
	},
	highpass = {
		lesson = "Use Cannon splash at bends to clear tightly packed enemies.",
		pressure = "Compact Grunt packs test area damage; Tanks only anchor the pack.",
		counterplay = "Place Cannon where bends keep packed grunts inside the blast radius, then look ahead to Poison as the upcoming reward for sustained tank damage.",
	},
	roundabout = {
		lesson = "Keep Poison on durable targets while they circle the central loop.",
		pressure = "High-health enemies test sustained damage.",
		counterplay = "Place Poison where the loop repeatedly re-enters range, then use Slow and Lancer/Cannon retargeting to keep poisoned enemies under fire until the damage-over-time finishes them.",
	},
	gauntlet = {
		lesson = "Build one kill zone that combines control, splash, and sustained damage.",
		pressure = "Mixed formations test kill-zone balance.",
		counterplay = "Line up Lancer on long lanes, use Slow and Cannon where enemies bunch, keep Poison on durable targets, and save Meteor for the most dangerous breakthrough.",
	},
	snaketrail = {
		lesson = "Hold Tanks in the long bends so Poison has time to finish them.",
		pressure = "Tank health tests sustained damage uptime.",
		counterplay = "Use Slow to extend the long bends, then keep Poison focused on each Tank until it falls.",
	},
	backtrack = {
		lesson = "Catch Runners at the repeated build pocket before they escape coverage.",
		pressure = "Runner speed tests reaction and control.",
		counterplay = "Slow Runners before the path revisits the central pocket and line Lancers up with their exit lane.",
	},
	lowvalley = {
		lesson = "Crack Bulwark armor with heavy hits instead of rapid small attacks.",
		pressure = "Bulwark armor tests per-hit damage.",
		counterplay = "Place Cannon at shared bends for repeated heavy blasts, then add Lancer or other high-damage fire to crack surviving Bulwarks before they leave the kill zone.",
	},
	circuit = {
		lesson = "Focus wounded Regenerators until they fall instead of spreading damage.",
		pressure = "Regeneration tests finishing power.",
		counterplay = "Keep focused fire on wounded Regenerators, then use the Weakest targeting option earned after Circuit to automate finishing low-health targets before they recover.",
	},
	outerloop = {
		lesson = "Concentrate the counters already learned into a few overlapping kill zones.",
		pressure = "Long travel gaps test coverage discipline.",
		counterplay = "Use active abilities to contain runner leaks, Strongest targeting to focus tanks and Bulwarks, and Weakest targeting to finish Regenerators before they recover.",
	},
	terrace = {
		lesson = "Eliminate Warcallers before attacking the enemies they support.",
		pressure = "Warcaller speed auras test target priority.",
		counterplay = "Focus Warcallers first, using Plasma as the premium sustained-damage option while Slow keeps each priority target in range.",
	},
	highridge = {
		lesson = "Break Shieldbearer barriers with Shock chains and concentrated burst.",
		pressure = "Shields test barrier-breaking speed.",
		counterplay = "Focus Shock chains and heavy Cannon bursts on each barrier, then clean up the exposed formation once the shield breaks.",
	},
	crossflow = {
		lesson = "Place one coordinated defense where the crossing lanes share range.",
		pressure = "Simultaneous lane crossings test shared coverage.",
		counterplay = "Place Shock near the crossings to break shields, use Plasma to focus Warcallers, and keep Poison on Regenerators so they cannot recover between engagements.",
	},
	steppingstones = {
		lesson = "Alternate Frost Nova and Meteor between the two build pockets.",
		pressure = "Separated engagements test ability cooldown timing.",
		counterplay = "Assign Frost Nova to hold enemies in one pocket and Meteor to burst a pack threatening another, then alternate their cooldowns so both pockets are protected.",
	},
	twinloop = {
		lesson = "Apply every learned counter where the two loops overlap.",
		pressure = "Reversing mixed formations test adaptation at one focal point.",
		counterplay = "Coordinate every tower with Meteor and Frost Nova, shifting target priority as each formation reaches the loop overlap.",
	},
}

function CampaignDesign.get(mapIndex)
	local map = Maps[mapIndex]
	if not map then return nil end

	local teaching = teachingByMapId[map.id]
	if not teaching then return nil end

	return {
		mapId = map.id,
		mapIndex = mapIndex,
		nameKey = map.nameKey,
		lesson = teaching.lesson,
		pressure = teaching.pressure,
		reward = CampaignUnlocks.getRewardForMap(map),
		counterplay = teaching.counterplay,
		hintKey = "campaign.hints." .. map.id,
	}
end

function CampaignDesign.getAll()
	local entries = {}
	for mapIndex = 1, #Maps do
		entries[#entries + 1] = CampaignDesign.get(mapIndex)
	end
	return entries
end

return CampaignDesign

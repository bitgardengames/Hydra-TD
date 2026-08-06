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
		lesson = "Use Cannon splash at overlapping switchbacks to clear packed enemies.",
		pressure = "Dense Grunt packs test crowd control.",
		counterplay = "Anchor Slow where multiple legs overlap, then place Cannon and Lancer so every delayed pack takes splash and piercing fire.",
	},
	highpass = {
		lesson = "Time Meteor to erase the densest pack while towers cover the other bends.",
		pressure = "Compact Grunt packs test area damage and ability timing.",
		counterplay = "Use Cannon at shared bends and save Meteor for the largest breakthrough; Poison is the clear reward for later durable enemies.",
	},
	roundabout = {
		lesson = "Keep Poison on durable targets while they circle the central loop.",
		pressure = "High-health enemies test sustained damage.",
		counterplay = "Place Poison where the loop repeatedly re-enters range, then use Slow and Lancer/Cannon retargeting to keep poisoned enemies under fire until the damage-over-time finishes them.",
	},
	gauntlet = {
		lesson = "Use Strongest targeting to hold fire on the most durable threat.",
		pressure = "Mixed formations test kill-zone balance.",
		counterplay = "Set sustained-damage towers to Strongest, use Slow and Cannon where enemies bunch, and save Meteor for the most dangerous breakthrough.",
	},
	snaketrail = {
		lesson = "Chain Shock through Tank escorts while Poison finishes the Tank.",
		pressure = "Tank health tests sustained damage uptime.",
		counterplay = "Use Slow to extend the long bends, chain Shock through escorts, and keep Poison focused on each Tank until it falls.",
	},
	backtrack = {
		lesson = "Catch newly introduced Runners with Frost Nova at the repeated build pocket.",
		pressure = "Runner speed tests reaction and control.",
		counterplay = "Slow Runners before the path revisits the central pocket and line Lancers up with their exit lane.",
	},
	lowvalley = {
		lesson = "Crack newly introduced Bulwark armor, then use Weakest targeting to finish survivors.",
		pressure = "Bulwark armor tests per-hit damage.",
		counterplay = "Place Cannon at shared bends for repeated heavy blasts, then add Lancer or other high-damage fire to crack surviving Bulwarks before they leave the kill zone.",
	},
	circuit = {
		lesson = "Read the enhanced preview, then focus newly introduced Regenerators until they fall.",
		pressure = "Regeneration tests finishing power.",
		counterplay = "Use the preview to prepare each counter, then set focused towers to Weakest so wounded Regenerators fall before they recover.",
	},
	outerloop = {
		lesson = "Use Plasma to concentrate sustained fire in a few overlapping kill zones.",
		pressure = "Long travel gaps test coverage discipline.",
		counterplay = "Use active abilities to contain runner leaks, Strongest targeting to focus tanks and Bulwarks, and Weakest targeting to finish Regenerators before they recover.",
	},
	terrace = {
		lesson = "Coordinate both ability slots to eliminate newly introduced Warcallers first.",
		pressure = "Warcaller speed auras test target priority.",
		counterplay = "Focus Warcallers first, using Plasma as the premium sustained-damage option while Slow keeps each priority target in range.",
	},
	highridge = {
		lesson = "Break Shieldbearer barriers with Shock chains and concentrated burst.",
		pressure = "Shields test barrier-breaking speed.",
		counterplay = "Focus Shock chains and heavy Cannon bursts on each barrier, then clean up the exposed formation once the shield breaks.",
	},
	crossflow = {
		lesson = "Place one coordinated defense where crossing lanes share range and enhanced abilities cover leaks.",
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

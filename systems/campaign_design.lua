local Maps = require("world.map_defs")
local CampaignUnlocks = require("systems.campaign_unlocks")

local CampaignDesign = {}

-- Teaching plan keyed by map id. Map order remains world/map_defs.lua; rewards
-- remain systems/campaign_unlocks.lua. Each entry states the pressure and the
-- intended non-stat counterplay.
local teachingByMapId = {
	riverbend = {
		pressure = "Steady Grunt packs test coverage without a second enemy role.",
		counterplay = "Use Lancer on long lanes and Slow near overlapping corners to turn bends into shared damage windows.",
	},
	switchback = {
		pressure = "Dense Grunt packs test crowd control.",
		counterplay = "Anchor Slow where multiple legs overlap, then place Cannon and Lancer so every delayed pack takes splash and piercing fire.",
	},
	highpass = {
		pressure = "Compact Grunt packs test area damage and ability timing.",
		counterplay = "Use Cannon at shared bends and save Meteor for the largest breakthrough; Poison is the clear reward for later durable enemies.",
	},
	roundabout = {
		pressure = "High-health enemies test sustained damage.",
		counterplay = "Place Poison where the loop repeatedly re-enters range, then use Slow and Lancer/Cannon retargeting to keep poisoned enemies under fire until the damage-over-time finishes them.",
	},
	gauntlet = {
		pressure = "Mixed formations test kill-zone balance.",
		counterplay = "Set sustained-damage towers to Strongest, use Slow and Cannon where enemies bunch, and save Meteor for the most dangerous breakthrough.",
	},
	snaketrail = {
		pressure = "Tank health tests sustained damage uptime.",
		counterplay = "Use Slow to extend the long bends, chain Shock through escorts, and keep Poison focused on each Tank until it falls.",
	},
	backtrack = {
		pressure = "Runner speed tests reaction and control.",
		counterplay = "Slow Runners before the path revisits the central pocket and line Lancers up with their exit lane.",
	},
	lowvalley = {
		pressure = "Bulwark armor tests per-hit damage.",
		counterplay = "Place Cannon at shared bends for repeated heavy blasts, then add Lancer or other high-damage fire to crack surviving Bulwarks before they leave the kill zone.",
	},
	circuit = {
		pressure = "Regeneration tests finishing power.",
		counterplay = "Use the preview to prepare each counter, then set focused towers to Weakest so wounded Regenerators fall before they recover.",
	},
	outerloop = {
		pressure = "Long travel gaps test coverage discipline.",
		counterplay = "Use active abilities to contain runner leaks, Strongest targeting to focus tanks and Bulwarks, and Weakest targeting to finish Regenerators before they recover.",
	},
	terrace = {
		pressure = "Warcaller speed auras test target priority.",
		counterplay = "Focus Warcallers first, using Plasma as the premium sustained-damage option while Slow keeps each priority target in range.",
	},
	highridge = {
		pressure = "Shields test barrier-breaking speed.",
		counterplay = "Focus Shock chains and heavy Cannon bursts on each barrier, then clean up the exposed formation once the shield breaks.",
	},
	crossflow = {
		pressure = "Simultaneous lane crossings test shared coverage.",
		counterplay = "Place Shock near the crossings to break shields, use Plasma to focus Warcallers, and keep Poison on Regenerators so they cannot recover between engagements.",
	},
	steppingstones = {
		pressure = "Separated engagements test ability cooldown timing.",
		counterplay = "Assign Frost Nova to hold enemies in one pocket and Meteor to burst a pack threatening another, then alternate their cooldowns so both pockets are protected.",
	},
	twinloop = {
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

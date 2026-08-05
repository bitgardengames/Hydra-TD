local Maps = require("world.map_defs")
local CampaignUnlocks = require("systems.campaign_unlocks")

local CampaignDesign = {}

-- Teaching plan keyed by map id. Map order remains world/map_defs.lua; rewards
-- remain systems/campaign_unlocks.lua. Each entry states the playable lesson,
-- the pressure that demonstrates it, and the intended non-stat counterplay.
local teachingByMapId = {
	riverbend = {
		lesson = "Place basic towers where one range circle covers multiple bends instead of spreading damage evenly along the road.",
		pressure = "Grunt-only waves create a readable baseline for path length, leaks, and kill zones.",
		counterplay = "Use Lancer on long lanes and Slow near overlapping corners to turn bends into shared damage windows.",
	},
	switchback = {
		lesson = "Use switchback bends to make Slow multiply Lancer damage as enemies linger through repeated long-lane shots.",
		pressure = "Dense grunt groups stretch across the repeated turns and punish Lancers that fire without enough control time.",
		counterplay = "Anchor Slow where multiple switchback legs overlap, then line up Lancer shots down the bends so slowed packs stay in piercing lanes.",
	},
	highpass = {
		lesson = "Use Cannon splash as the primary answer to dense grunt packs before they overwhelm single-target towers.",
		pressure = "High Pass sends compact grunt waves with only a few tanks mixed in, making splash placement the main lesson while previewing tougher health profiles.",
		counterplay = "Place Cannon where bends keep packed grunts inside the blast radius, then look ahead to Poison as the upcoming reward for sustained tank damage.",
	},
	roundabout = {
		lesson = "Keep sustained damage ticking around the central loop by maintaining Poison uptime on durable enemies.",
		pressure = "Roundabout traffic and first boss-add pressure stretch poison coverage across simultaneous front and back threats.",
		counterplay = "Place Poison where the loop repeatedly re-enters range, then use Slow and Lancer/Cannon retargeting to keep poisoned enemies under fire until the damage-over-time finishes them.",
	},
	gauntlet = {
		lesson = "Pass the campaign's first fundamentals test by combining Lancer, Slow, Cannon, Poison, and Meteor in one plan.",
		pressure = "Mixed waves and suppression and displacement boss variants test every tool learned so far across alternating tight and open sections.",
		counterplay = "Line up Lancer on long lanes, use Slow and Cannon where enemies bunch, keep Poison on durable targets, and save Meteor for the most dangerous breakthrough.",
	},
	snaketrail = {
		lesson = "React to fast runners before they exit tower coverage, especially on short linking segments.",
		pressure = "Runners enter the campaign as speed checks that exploit gaps between snake turns.",
		counterplay = "Pre-place Slow at segment exits, use Lancer along the longest straight, and trigger Frost Nova when runners pass the central bend.",
	},
	backtrack = {
		lesson = "Prioritize high-health enemies when the path revisits the same build pocket, then unlock Strongest targeting to automate that focus.",
		pressure = "Tanks absorb shots while faster enemies hide behind them on a backtracking lane.",
		counterplay = "Focus Poison or Plasma on the highest-health tanks while Cannon clears their escorts; after clearing Backtrack, set towers to Strongest targeting to keep that priority automatic.",
	},
	lowvalley = {
		lesson = "Counter Bulwark armor with Cannon blasts and other heavy hits instead of relying on rapid low-damage attacks.",
		pressure = "Bulwarks introduce armor that shrugs off small hits, forcing each attack to deal enough damage to punch through.",
		counterplay = "Place Cannon at shared bends for repeated heavy blasts, then add Lancer or other high-damage fire to crack surviving Bulwarks before they leave the kill zone.",
	},
	circuit = {
		lesson = "Finish damaged enemies before regeneration recovers the health already taken from them.",
		pressure = "Regenerators punish partial damage on a circuit with several safe recovery intervals between damage pockets.",
		counterplay = "Keep focused fire on wounded Regenerators, then use the Weakest targeting option earned after Circuit to automate finishing low-health targets before they recover.",
	},
	outerloop = {
		lesson = "Pass a long-map midgame exam by coordinating every counter learned for runners, tanks, Bulwarks, and Regenerators.",
		pressure = "Mixed runner, tank, Bulwark, and Regenerator waves stretch full-map coverage across long outer lanes and punish gaps between kill zones.",
		counterplay = "Use active abilities to contain runner leaks, Strongest targeting to focus tanks and Bulwarks, and Weakest targeting to finish Regenerators before they recover.",
	},
	terrace = {
		lesson = "Prioritize support enemies and eliminate them before their aura value compounds across the wave.",
		pressure = "Warcallers accelerate nearby enemies, making each delayed support kill increase the pressure from the pack around it.",
		counterplay = "Focus Warcallers first, using Plasma as the premium sustained-damage option while Slow keeps each priority target in range.",
	},
	highridge = {
		lesson = "Use Shock and burst-focused attacks to break shields quickly instead of wasting sustained fire on an intact barrier.",
		pressure = "The first Shieldbearers create defensive formations that reward chained shocks and concentrated burst damage before protected enemies leave the kill zone.",
		counterplay = "Focus Shock chains and heavy Cannon bursts on each barrier, then clean up the exposed formation once the shield breaks.",
	},
	crossflow = {
		lesson = "Mix shield, support, and regeneration counters where crossing lanes let one coordinated defense cover multiple fronts.",
		pressure = "Shieldbearers, Warcallers, and Regenerators overlap across crossing lanes, testing barrier break, support priority, and finishing power at the same time.",
		counterplay = "Place Shock near the crossings to break shields, use Plasma to focus Warcallers, and keep Poison on Regenerators so they cannot recover between engagements.",
	},
	steppingstones = {
		lesson = "Assemble reusable build plans for maps with disconnected pockets and staggered engagement ranges.",
		pressure = "Alternating short steps make tower placement mistakes expensive because enemies repeatedly leave range.",
		counterplay = "Use saved build loadouts to compare control-heavy and burst-heavy plans, then place Slow/Plasma around the most repeated pockets.",
	},
	twinloop = {
		lesson = "Synthesize every counter into a final route that revisits itself and changes threat direction mid-map.",
		pressure = "Full specialist mixes and boss pressure test runners, tanks, bulwarks, regenerators, warcallers, and shieldbearers together.",
		counterplay = "Use optional endless variants to practice specialized loadouts: Shock for shields, Poison for regen, Plasma for priority, Slow/Frost Nova for leaks.",
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

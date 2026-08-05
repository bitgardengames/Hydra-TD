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
		lesson = "Learn shield and bulwark timing: break protection before committing burst damage.",
		pressure = "Bulwarks introduce protected fronts that reduce the value of scattered low-impact hits.",
		counterplay = "Stack Shock or sustained Lancer fire at the shield-break point, then spend the utility module slot on control or cleanup.",
	},
	circuit = {
		lesson = "Finish regenerating enemies decisively and avoid letting them idle between damage pockets.",
		pressure = "Regenerators punish partial damage on a circuit with several safe recovery intervals.",
		counterplay = "Use Poison uptime plus Cull Weak to execute low-health targets before regeneration erases progress.",
	},
	outerloop = {
		lesson = "Plan full-map coverage and leak prevention when the path stretches towers away from the exit.",
		pressure = "Long outer lanes split attention between early damage economy and late emergency control.",
		counterplay = "Create an early economy-neutral kill zone, keep Frost Nova for the final leg, and use targeting options to stop leaks for the challenge badge.",
	},
	terrace = {
		lesson = "Identify support enemies quickly and remove them before their aura value compounds.",
		pressure = "Warcallers introduce support-role pressure by accelerating or enabling nearby waves.",
		counterplay = "Use codex information to spot support roles, then assign priority fire from Lancer/Plasma while Slow holds the pack in range.",
	},
	highridge = {
		lesson = "Counter shields with deliberate priority rather than letting towers waste shots into protected followers.",
		pressure = "Shieldbearers create defensive formations on dry terrain with fewer natural stall pockets.",
		counterplay = "Enable shield-priority targeting, break the carrier with Shock chains or Plasma focus, then let Cannon clean exposed followers.",
	},
	crossflow = {
		lesson = "Exploit crossing lanes where projectile chains and forked hits can solve multiple fronts at once.",
		pressure = "Mixed shieldbearer/regenerator waves stress both shield break and finishing power across separated water pockets.",
		counterplay = "Install Chain Fork on Shock near lane crossings and pair it with Poison finishers for enemies that survive the chain burst.",
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

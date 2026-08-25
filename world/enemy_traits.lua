-- Shared player-facing intelligence for enemy mechanics. Enemy definitions opt
-- into these records with `traits`, so previews and the bestiary cannot drift
-- away from the combat rules they describe.
local Traits = {
	armored = {
		tag = "Armored",
		mechanic = "Flat armor reduces every hit; sufficiently heavy hits gain bonus damage.",
		tell = "A thick, dark outer shell.",
		counter = "Use heavy single hits that overwhelm its flat reduction.",
		answers = {"Cannon / Siege Shells", "Lancer / Opening Strike"},
	},
	regenerates = {
		tag = "Regenerates",
		mechanic = "Restores health after a short time without taking damage.",
		tell = "Green healing pulses around its body.",
		counter = "Maintain focus fire or damage over time so healing cannot catch up.",
		answers = {"Lancer / Focus Fire", "Poison specializations"},
	},
	support = {
		tag = "Support",
		mechanic = "Accelerates nearby enemies while it remains alive.",
		tell = "A pulsing aura links it to nearby allies.",
		counter = "Use concentrated fire or area damage to remove it quickly.",
		answers = {"Lancer / Focus Fire", "Cannon area specializations"},
	},
	summons = {
		tag = "Summoner",
		mechanic = "Periodically creates two runners at its current position on the path.",
		tell = "Orbiting runes contract as its next pair of runners approaches.",
		counter = "Focus it early or use area damage to clear each runner pair.",
		answers = {"Lancer / Focus Fire", "Cannon area specializations"},
	},
	fast = {
		tag = "Fast",
		mechanic = "Crosses uncovered sections of the path quickly.",
		tell = "Small body and rapid movement.",
		counter = "Cover the path early with slows or rapid attacks.",
		answers = {"Slow towers", "Rapid-fire specializations"},
	},
	boss_summoner = {
		tag = "Boss Mechanic",
		mechanic = "Arrives with frequent groups of light reinforcements.",
		tell = "Groups of grunts continue entering while the boss is alive.",
		counter = "Use area or chain damage to clear reinforcements while focusing the boss.",
		answers = {"Cannon area specializations", "Shock chain specializations"},
	},
	boss_displacement = {
		tag = "Boss Mechanic",
		mechanic = "Arrives with fast runner reinforcements.",
		tell = "Small groups of runners continue entering while the boss is alive.",
		counter = "Slow the runners and maintain focused damage on the boss.",
		answers = {"Slow/control specializations", "Lancer burst specializations"},
	},
	boss_suppression = {
		tag = "Boss Mechanic",
		mechanic = "Suppresses one tower for five seconds about every twenty seconds.",
		tell = "A red interference aura surrounds the disabled tower.",
		counter = "Spread damage across several towers so one shutdown cannot halt your defense.",
		answers = {"Several affordable towers", "Long-range towers with overlapping coverage"},
	},
	boss_aegis = {
		tag = "Boss Mechanic",
		mechanic = "Raises a damage-reducing shield for two seconds every six seconds.",
		tell = "Three cyan shield plates close around it while protection is active.",
		counter = "Save burst damage for the clearly telegraphed gaps between shields.",
		answers = {"Lancer burst specializations", "Rapid-fire towers between shield windows"},
	},
	boss_ravager = {
		tag = "Boss Mechanic",
		mechanic = "Breaks into a final sprint below 45% health.",
		tell = "Its eyes and trailing speed streaks turn red when enraged.",
		counter = "Keep slows ready and concentrate damage before its final sprint.",
		answers = {"Slow/control specializations", "Lancer burst specializations"},
	},
}

function Traits.get(id)
	return Traits[id]
end

function Traits.forEnemy(def)
	local result = {}
	for i = 1, #(def and def.traits or {}) do
		local trait = Traits[def.traits[i]]
		if trait then result[#result + 1] = trait end
	end
	return result
end

-- Useful to content tools/tests: every special mechanic must advertise more
-- than one real build answer, rather than quietly prescribing one tower.
function Traits.validateEnemyDefs(enemyDefs)
	local errors = {}
	for kind, def in pairs(enemyDefs) do
		for _, id in ipairs(def.traits or {}) do
			local trait = Traits[id]
			if not trait then
				errors[#errors + 1] = kind .. ": unknown trait " .. tostring(id)
			elseif #(trait.answers or {}) < 2 then
				errors[#errors + 1] = kind .. ": trait " .. id .. " needs at least two answers"
			end
		end
	end
	return #errors == 0, errors
end

return Traits

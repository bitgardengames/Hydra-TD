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
	shielded = {
		tag = "Shielded",
		mechanic = "A separate shield absorbs damage and takes extra damage from burst and chain hits.",
		tell = "A bright ring surrounds it until the shield breaks.",
		counter = "Break the shield with burst volleys or chain attacks.",
		answers = {"Lancer / Volley", "Shock chain specializations"},
	},
	support = {
		tag = "Support",
		mechanic = "Accelerates nearby enemies while it remains alive.",
		tell = "A pulsing aura links it to nearby allies.",
		counter = "Use priority targeting or concentrated fire to remove it first.",
		answers = {"Strongest/priority targeting", "Lancer / Focus Fire"},
	},
	fast = {
		tag = "Fast",
		mechanic = "Crosses uncovered sections of the path quickly.",
		tell = "Small body and rapid movement.",
		counter = "Cover the path early with slows or rapid attacks.",
		answers = {"Slow towers", "Rapid-fire specializations"},
	},
	boss_mechanic = {
		tag = "Boss Mechanic",
		mechanic = "Telegraphs a powerful ability, followed by a vulnerable window.",
		tell = "A large warning animation before the ability fires.",
		counter = "Prepare control or burst, then commit damage during the exposed window.",
		answers = {"Burst specializations", "Slow/control specializations"},
	},
	boss_summoner = {
		tag = "Boss Mechanic",
		mechanic = "Summons reinforcement waves, then enters an exposed window.",
		tell = "A long summoning charge gathers around the boss.",
		counter = "Clear adds with area or chain damage, then burst the exposed boss.",
		answers = {"Cannon area specializations", "Shock chain specializations"},
	},
	boss_displacement = {
		tag = "Boss Mechanic",
		mechanic = "Dashes forward with a shockwave, then becomes exposed.",
		tell = "A brief shockwave charge points down the path.",
		counter = "Use slows before the dash or burst damage in the exposed window.",
		answers = {"Slow/control specializations", "Lancer burst specializations"},
	},
	boss_suppression = {
		tag = "Boss Mechanic",
		mechanic = "Projects an aura that temporarily suppresses nearby towers.",
		tell = "An expanding aura warns which towers are in danger.",
		counter = "Spread damage across safe positions or burst during its exposed window.",
		answers = {"Long-range specializations", "Burst specializations"},
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

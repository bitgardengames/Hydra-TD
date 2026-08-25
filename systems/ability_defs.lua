-- Active abilities are data-driven: targeting, timing, and effect values live here
-- while systems.abilities executes each effect kind.
local AbilityDefs = {
	meteor = {id="meteor", nameKey="ability.meteor.name", descKey="ability.meteor.desc", utilityRole="burst", chargeRequired=56, targeting="point", target={entities="enemies", singular="enemy", plural="enemies", requireAffected=false, color={1,.38,.18}}, effect={kind="damage_area",radius=82,damage=75,travelTime=.85}},
	frost_nova = {id="frost_nova", nameKey="ability.frostNova.name", descKey="ability.frostNova.desc", utilityRole="control", chargeRequired=44, targeting="point", target={entities="enemies", singular="enemy", plural="enemies", requireAffected=true, color={.35,.8,1}}, effect={kind="slow_area",radius=105,factor=.35,duration=5}},
	-- Overdrive's affected markers are only a targeting affordance. Once cast,
	-- towers use their dedicated attack-speed pulse to communicate the buff.
	overdrive = {id="overdrive", nameKey="ability.overdrive.name", descKey="ability.overdrive.desc", utilityRole="tower_buff", chargeRequired=64, targeting="point", target={entities="towers", singular="tower", plural="towers", requireAffected=true, color={.8,.4,1}}, sustained={area=false, entityMarker=false}, effect={kind="tower_haste_area",radius=110,attackSpeed=1.70,duration=7}},
	gravity_well = {id="gravity_well", nameKey="ability.gravityWell.name", descKey="ability.gravityWell.desc", utilityRole="formation", chargeRequired=72, targeting="point", target={entities="enemies", singular="enemy", plural="enemies", requireAffected=true, color={.58,.32,1}}, sustained={area=true, entityMarker=true}, effect={kind="gravity_well",radius=95,duration=3,pullSpeed=36,damage=28}},
	gold_rush = {id="gold_rush", nameKey="ability.goldRush.name", descKey="ability.goldRush.desc", utilityRole="economy", chargeRequired=96, targeting="instant", sustained={hud=true}, effect={kind="income_multiplier",duration=8,multiplier=1.5}},
	last_stand = {id="last_stand", nameKey="ability.lastStand.name", descKey="ability.lastStand.desc", utilityRole="emergency", chargeRequired=80, targeting="point", target={entities="towers", singular="tower", plural="towers", requireAffected=true, color={1,.72,.18}}, sustained={area=true, entityMarker=true}, effect={kind="last_stand",radius=110,attackSpeed=1.45,duration=6,volleys=1}},
}
AbilityDefs.order = {"meteor","frost_nova","overdrive","gravity_well","gold_rush","last_stand"}
-- Scheduled enemies grant one charge, bosses grant this explicit amount, and
-- enemies created by summoners grant none. Ability-caused kills grant none.
AbilityDefs.bossCharge = 5
return AbilityDefs

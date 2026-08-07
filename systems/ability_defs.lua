-- Active abilities are data-driven: targeting, timing, base values, and campaign
-- enhancement values live here while systems.abilities executes each effect kind.
local AbilityDefs = {
	meteor = {id="meteor", nameKey="ability.meteor.name", descKey="ability.meteor.desc", utilityRole="burst", cooldown=35, targeting="point", effect={kind="damage_area",radius=82,damage=85}, upgradeId="enhanced_abilities", upgradedEffect={kind="damage_area",radius=96,damage=115}},
	frost_nova = {id="frost_nova", nameKey="ability.frostNova.name", descKey="ability.frostNova.desc", utilityRole="control", cooldown=28, targeting="point", effect={kind="slow_area",radius=105,factor=.35,duration=5}, upgradeId="enhanced_abilities", upgradedEffect={kind="slow_area",radius=120,factor=.28,duration=6.5}},
	overdrive = {id="overdrive", nameKey="ability.overdrive.name", descKey="ability.overdrive.desc", utilityRole="tower_buff", cooldown=38, targeting="point", effect={kind="tower_haste_area",radius=110,attackSpeed=1.70,duration=7}, upgradeId="enhanced_abilities", upgradedEffect={kind="tower_haste_area",radius=125,attackSpeed=1.85,duration=8}},
	gravity_well = {id="gravity_well", nameKey="ability.gravityWell.name", descKey="ability.gravityWell.desc", utilityRole="formation", cooldown=40, targeting="point", effect={kind="gravity_well",radius=95,duration=3,pullSpeed=36,damage=28}, upgradeId="enhanced_abilities", upgradedEffect={kind="gravity_well",radius=110,duration=3,pullSpeed=44,damage=42}},
	gold_rush = {id="gold_rush", nameKey="ability.goldRush.name", descKey="ability.goldRush.desc", utilityRole="economy", cooldown=55, targeting="instant", effect={kind="income_multiplier",duration=8,multiplier=1.5}},
	last_stand = {id="last_stand", nameKey="ability.lastStand.name", descKey="ability.lastStand.desc", utilityRole="emergency", cooldown=45, targeting="point", effect={kind="last_stand",radius=110,attackSpeed=1.45,duration=6,volleys=1}, upgradeId="enhanced_abilities", upgradedEffect={kind="last_stand",radius=125,attackSpeed=1.45,duration=6,volleys=2,volleyDelay=1.5}},
}
AbilityDefs.order = {"meteor","frost_nova","overdrive","gravity_well","gold_rush","last_stand"}
return AbilityDefs

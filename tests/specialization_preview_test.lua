-- Run with the LÖVE test harness; construction uses real gameplay entities.
package.path = "./?.lua;./?/init.lua;" .. package.path
local Preview=require("ui.specialization_preview")
local EnemyDefs=require("world.enemy_defs")
local expected={"marksman","rupture","deep_freeze","cold_field","virulent","contagion","siege","bombardment","capacitor","forked_lightning","accelerator","overcharged"}
for _,id in ipairs(expected) do
 local def=assert(Preview.definitions[id],"missing definition for "..id)
 assert(def.duration and def.path and def.camera and def.tower and def.enemies)
 for _,spawn in ipairs(def.enemies) do assert(EnemyDefs[spawn.kind],id.." uses unknown enemy "..tostring(spawn.kind)) end
end
print("specialization gameplay sandbox definitions passed")

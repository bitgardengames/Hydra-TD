-- EXPERIMENTAL: retained for explicit internal module playtests. These
-- definitions are not part of normal campaign or replay balance.
local Helpers = require("systems.module_defs.helpers")

local ModuleDefs = {}
local catalog = Helpers.newCatalog(ModuleDefs)

require("systems.module_defs.movement")(catalog)
require("systems.module_defs.output")(catalog)
require("systems.module_defs.status")(catalog)
require("systems.module_defs.tower_specializations")(catalog)
require("systems.module_defs.compatibility")(catalog)

return ModuleDefs

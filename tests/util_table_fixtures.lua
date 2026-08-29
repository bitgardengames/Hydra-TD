-- Shared table utility contract fixtures. Run from the repository root.
package.path = "./?.lua;./?/init.lua;" .. package.path

local Util = require("core.util")

local nested = {value = 1}
local destination = {retained = true}
assert(Util.shallowCopyInto(destination, {nested = nested}) == destination)
assert(destination.retained and destination.nested == nested, "shallow copy changed nested references")

assert(Util.copyNonNilInto(destination, nil) == destination, "nil overlay was not accepted")
Util.copyNonNilInto(destination, {added = 2})
assert(destination.added == 2, "non-nil overlay was not copied")

local tableKey = {}
local shared = {name = "shared"}
local source = {[tableKey] = shared, first = shared, second = shared}
source.self = source
setmetatable(source, {marker = true})
local clone = Util.deepCloneGraph(source)
assert(clone ~= source and clone.self == clone, "graph cycle was not cloned")
assert(clone.first == clone.second and clone.first ~= shared, "shared graph reference was not preserved")
assert(clone[tableKey] == clone.first, "table key was cloned or keyed value was not cloned")
assert(getmetatable(clone) == nil, "metatable was copied")

print("table utility fixtures passed")

-- Dependency-free recovery fixtures. Run from the repository root with Lua/LuaJIT.
package.path = "./?.lua;" .. package.path

local function compiler(source, name)
	if loadstring then return loadstring(source, name) end
	return load(source, name, "t", {})
end

local files = {}
local directories = {}

love = {
	filesystem = {
		getInfo = function(path)
			if files[path] then return {type = "file"} end
			if directories[path] then return {type = "directory"} end
		end,
		createDirectory = function(path) directories[path] = true; return true end,
		write = function(path, contents) files[path] = contents; return true end,
		load = function(path)
			if not files[path] then return nil, "missing" end
			return compiler(files[path], "@" .. path)
		end,
		remove = function(path) files[path] = nil; return true end,
		rename = function(from, to)
			if not files[from] then return false, "missing source" end
			files[to], files[from] = files[from], nil
			return true
		end,
	},
}

package.loaded["core.hotkeys"] = {
	getDefaultBindings = function() return {shop = {}, actions = {}} end,
}
local Save = require("core.save")

local function reset(seed)
	files, directories = seed or {}, {saves = true}
	Save.data, Save.dirty, Save.dirtyTimer = nil, false, nil
end

local function check(value, message)
	assert(value, message)
end

-- Malformed primaries are retained for diagnosis instead of overwritten.
reset({["saves/save.lua"] = "return { broken ="})
Save.load()
local diagnostic
for path in pairs(files) do
	if path:match("^saves/save%.corrupt%-%d%d%d%d%d%d%d%d%-%d%d%d%d%d%d") then diagnostic = path end
end
check(diagnostic and files[diagnostic], "malformed primary was not preserved")
check(Save.data.version == 6, "malformed save did not produce fresh data")

-- Older saves migrate while retaining fields this version does not know about.
reset({["saves/save.lua"] = "return { version = 1, unknownFutureField = { enabled = true } }"})
Save.load()
check(Save.data.version == 6, "old version was not migrated")
check(Save.data.unknownFutureField.enabled, "unknown field was discarded")
check(files["saves/save.bak.lua"], "pre-migration save was not backed up")

-- An interrupted temporary write never supersedes a known-good primary.
reset({
	["saves/save.lua"] = "return { version = 6, sentinel = 'primary' }",
	["saves/save.tmp.lua"] = "return { version = 6, sentinel = 'temporary' }",
})
Save.load()
check(Save.data.sentinel == "primary", "temporary file was loaded as primary")

-- A corrupt primary recovers from backup and promotes the recovered data.
reset({
	["saves/save.lua"] = "not valid lua",
	["saves/save.bak.lua"] = "return { version = 6, sentinel = 'backup' }",
})
Save.load()
check(Save.data.sentinel == "backup", "backup was not restored")
local restored = assert(love.filesystem.load("saves/save.lua"))()
check(restored.sentinel == "backup", "backup data was not promoted")

-- Dirty writes are coalesced until the timer expires.
Save.data.sentinel = "coalesced"
Save.markDirty()
Save.update(0.1)
check(assert(love.filesystem.load("saves/save.lua"))().sentinel == "backup", "dirty save flushed too early")
Save.update(0.3)
check(assert(love.filesystem.load("saves/save.lua"))().sentinel == "coalesced", "dirty save did not flush")

print("save fixtures passed")

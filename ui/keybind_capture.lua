local Hotkeys = require("core.hotkeys")
local Save = require("core.save")
local Sound = require("systems.sound")
local L = require("core.localization")

local Capture = {}
Capture.__index = Capture

local function bindingSection(kind)
	local keybinds = Save.data.settings.keybinds
	return kind == "shop" and keybinds.shop or keybinds.actions
end

local function bindingFor(row)
	return bindingSection(row.bindingKind)[row.bindingId]
end

local function formatBinding(key)
	if not key or key == "" or key == "none" then
		return L("settings.controlUnbound")
	end

	return key:upper()
end

local function findRow(rows, id)
	for _, row in ipairs(rows) do
		if row.id == id then
			return row
		end
	end
end

function Capture.new()
	return setmetatable({}, Capture)
end

function Capture:close()
	self.rowId = nil
	self.conflictMessage = nil
	self.pendingChange = nil
	self.hint = nil
end

function Capture:start(row)
	self.rowId = row.id
	self.conflictMessage = nil
	self.pendingChange = nil
	self.hint = L("settings.controlListeningHint")
	Sound.play("uiMove")
end

function Capture:text(row)
	if self.rowId == row.id then
		return L("settings.controlListening")
	end

	return formatBinding(bindingFor(row))
end

function Capture:commit(change)
	if change.conflictRow then
		bindingSection(change.conflictRow.bindingKind)[change.conflictRow.bindingId] = change.previous
	end

	bindingSection(change.row.bindingKind)[change.row.bindingId] = change.key
	Hotkeys.refreshFromSave()
	Save.markDirty()
end

function Capture:setBinding(row, key, rows)
	local previous = bindingFor(row)
	local conflictRow

	if key and key ~= "none" then
		for _, other in ipairs(rows) do
			if other.type == "keybind" and other.id ~= row.id and bindingFor(other) == key then
				conflictRow = other
				break
			end
		end
	end

	if conflictRow then
		self.pendingChange = {
			row = row,
			key = key,
			previous = previous,
			conflictRow = conflictRow,
			conflictPrevious = bindingFor(conflictRow),
		}
		self.conflictMessage = L(
			"settings.controlConflictSwapPreview",
			row.label,
			formatBinding(previous),
			formatBinding(key),
			conflictRow.label,
			formatBinding(self.pendingChange.conflictPrevious),
			formatBinding(previous)
		)
		self.hint = L("settings.controlConflictConfirmHint")
		Sound.play("uiMove")
		return false
	end

	self.conflictMessage = nil
	self.pendingChange = nil
	self.hint = L("settings.controlListeningHint")
	self:commit({row = row, key = key, previous = previous})
	return true
end

function Capture:restoreDefaults()
	Save.data.settings.keybinds = Hotkeys.getDefaultBindings()
	Hotkeys.refreshFromSave()
	Save.markDirty()
	self.conflictMessage = L("settings.controlsDefaultsRestored")
	self.pendingChange = nil
	Sound.play("uiConfirm")
end

function Capture:keypressed(key, rows)
	if not self.rowId then
		return false
	end

	if key == "escape" then
		self:close()
		Sound.play("uiBack")
		return true
	end

	if self.pendingChange then
		if key == "return" then
			self:commit(self.pendingChange)
			self:close()
			Sound.play("uiConfirm")
		end
		return true
	end

	local row = findRow(rows, self.rowId)
	if row then
		local committed = self:setBinding(row, key == "backspace" and "none" or key, rows)
		if committed then
			self:close()
			Sound.play("uiConfirm")
		end
	end

	return true
end

return Capture

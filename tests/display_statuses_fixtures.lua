local slowColor = {0.2, 0.4, 1}
local poisonColor = {0.2, 0.8, 0.2}
package.loaded["core.theme"] = {
	tower = {slow = slowColor, poison = poisonColor},
	ui = {good = {0, 1, 0}, bad = {1, 0, 0}, money = {1, 1, 0}},
}
package.loaded["core.localization"] = function(key, value)
	if key == "status.multiplier" then return string.format("x%.1f", value) end
	return "localized:" .. key
end

local DisplayStatuses = dofile("world/enemy_display_statuses.lua")
local RowBuffer = dofile("ui/status_row_buffer.lua")
local buffer = RowBuffer.new()
local rows = buffer.rows

local function update(enemy)
	local count = DisplayStatuses.visit(enemy, RowBuffer.writeVisitor, buffer)
	RowBuffer.finish(buffer, count)
	return count
end

assert(update({}) == 0 and buffer.count == 0, "an enemy without statuses produced rows")

local enemy = {
	slowTimer = 2, slowDuration = 4,
	poisonTimer = 3, poisonDuration = 4, poisonStacks = 3,
	support = true, supportBoost = 1.5,
	regeneration = {delay = 5}, regenDelay = 1,
	summon = {period = 8}, summonTimer = 2,
}
assert(update(enemy) == 6, "simultaneous statuses were omitted")
assert(rows[1].id == "slow" and rows[2].id == "poison" and rows[3].id == "support_aura"
	and rows[4].id == "support_boost" and rows[5].id == "regeneration_suppressed"
	and rows[6].id == "summon_preparing", "status ordering changed")
assert(rows[1].label == "localized:status.slow" and rows[1].color == slowColor)
assert(rows[1].remainingFraction == 0.5 and rows[2].remainingFraction == 0.75)
assert(rows[2].stacks == 3 and rows[4].value == "x1.5")

local retainedSlow = rows[1]
enemy.slowTimer = 0
enemy.poisonTimer = 0
enemy.support = false
enemy.supportBoost = 1
enemy.regenDelay = 0
enemy.summonTimer = 0
assert(update(enemy) == 0 and buffer.count == 0 and rows[1].id == nil,
	"expired statuses left stale row data")

enemy.slowTimer = 1
assert(update(enemy) == 1 and buffer.count == 1, "status did not reappear")
assert(rows[1] == retainedSlow, "cleared records were not reused")
local retained = rows[1]
enemy.poisonTimer, enemy.poisonStacks = 1, 2
assert(update(enemy) == 2)
enemy.poisonTimer = 0
assert(update(enemy) == 1 and buffer.count == 1 and rows[1] == retained and rows[2].id == nil,
	"shrinking a retained buffer did not reuse active records or clear stale data")

local snapshot = DisplayStatuses.snapshot(enemy)
assert(#snapshot == 1 and snapshot[1].id == "slow" and snapshot[1] ~= rows[1])
print("display status fixtures: ok")

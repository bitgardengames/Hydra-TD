-- Focused regression coverage for fixed-tick interpolation and render-time nudges.
local State = { renderAlpha = 0 }
package.loaded["core.state"] = State
package.loaded["world.enemies"] = { enemies = {} }

local EnemyRenderState = dofile("render/enemy_render_state.lua")
local pathEnemy = {
	x = 10, y = 10, prevX = 0, prevY = 0,
	nudgeX = 0, nudgeY = 0,
}
local nudgedEnemy = {
	x = 10, y = 10, prevX = 0, prevY = 0,
	nudgeX = 0, nudgeY = 0,
	nudgeTargetX = 8, nudgeTargetY = 4,
	nudgeTargetK = 0, nudgeFollowK = 12,
}
local enemies = { pathEnemy, nudgedEnemy }
local lastPathX, lastPathY = -math.huge, -math.huge
local lastNudgedX, lastNudgedY = -math.huge, -math.huge
local frame = 0

local function render(alpha)
	frame = frame + 1
	State.renderAlpha = alpha
	EnemyRenderState.prepare(enemies, nil, 1 / 240, frame)

	assert(pathEnemy.rx >= lastPathX and pathEnemy.ry >= lastPathY,
		"ordinary path rendering moved backwards")
	assert(nudgedEnemy.rx >= lastNudgedX and nudgedEnemy.ry >= lastNudgedY,
		"nudged path rendering moved backwards")
	local baseX = pathEnemy.prevX + (pathEnemy.x - pathEnemy.prevX) * alpha
	local baseY = pathEnemy.prevY + (pathEnemy.y - pathEnemy.prevY) * alpha
	assert(math.abs(pathEnemy.rx - baseX) < 1e-9 and math.abs(pathEnemy.ry - baseY) < 1e-9,
		"path position did not use simulation interpolation")
	assert(math.abs(nudgedEnemy.rx - (baseX + nudgedEnemy.nudgeX)) < 1e-9
		and math.abs(nudgedEnemy.ry - (baseY + nudgedEnemy.nudgeY)) < 1e-9,
		"current presentation nudge was resampled with simulation alpha")

	lastPathX, lastPathY = pathEnemy.rx, pathEnemy.ry
	lastNudgedX, lastNudgedY = nudgedEnemy.rx, nudgedEnemy.ry
end

-- Several presentation frames approach a fixed tick, then alpha restarts after
-- simulation advances the position endpoints.
render(0.25)
render(0.50)
render(0.75)
pathEnemy.prevX, pathEnemy.x = pathEnemy.x, 20
pathEnemy.prevY, pathEnemy.y = pathEnemy.y, 20
nudgedEnemy.prevX, nudgedEnemy.x = nudgedEnemy.x, 20
nudgedEnemy.prevY, nudgedEnemy.y = nudgedEnemy.y, 20
render(0)
render(0.25)
render(0.50)
render(0.75)

assert(pathEnemy.prevNudgeX == nil and pathEnemy.prevNudgeY == nil)
assert(nudgedEnemy.prevNudgeX == nil and nudgedEnemy.prevNudgeY == nil)
print("enemy render state fixtures: ok")

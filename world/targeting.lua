local Util = require("core.util")

local Targeting = {}

local dist2 = Util.dist2

--[[
	Targeting.findClosest(...)
	Targeting.findLowestHP(...)
	Targeting.findBossPriority(...)

	-- Make an enum table
	Targeting.MODES = {
		PROGRESS = "progress",
	}

	-- Then towers can do:
	t.targetMode = Targeting.MODES.PROGRESS
--]]

function Targeting.isValidTarget(tower, e)
	if not e or e.hp <= 0 or e.dying then
		return false
	end

	local dx = e.x - tower.x
	local dy = e.y - tower.y

	return dx * dx + dy * dy <= tower.range2
end

-- Target enemy furthest along the path (primary TD heuristic)
function Targeting.findProgressTarget(tower, enemies)
    local best = nil
    local bestProg = -1
    local r2 = tower.range * tower.range

    for _, e in ipairs(enemies) do
        local dx = e.x - tower.x
        local dy = e.y - tower.y

        if dx * dx + dy * dy <= r2 then
            -- Prefer enemies further along the path
            -- Slight bias against slowed enemies (keeps flow feeling good)
            local slowBias = (e.slowTimer and e.slowTimer > 0) and 5 or 0 -- 5-15 pixels
			local prog = e.dist - slowBias

            if prog > bestProg then
                bestProg = prog
                best = e
            end
        end
    end

    return best
end

return Targeting
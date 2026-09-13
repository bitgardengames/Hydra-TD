local centered = {}

package.loaded["core.camera"] = {
	centerOn = function(x, y, zoom)
		centered[#centered + 1] = {x = x, y = y, zoom = zoom}
	end,
}

love = {
	timer = {
		getDelta = function()
			return 1 / 60
		end,
	},
}

local CineCam = require("tools.trailer.camera")
local target = {x = 10, y = 20}
local camera = CineCam.follow{
	getTarget = function()
		return target
	end,
	offset = {x = 2, y = -3},
	zoom = 4,
}

camera.update(0)
assert(#centered == 1, "a valid target should update the camera")
assert(centered[1].x == 12 and centered[1].y == 17, "target offsets should be applied")

-- Enemy pooling clears every field on a dead enemy while trailer context can
-- still reference its table. The camera should hold instead of crashing.
target.x = nil
target.y = nil
camera.update(1)
assert(#centered == 1, "a cleared target should leave the camera unchanged")

print("trailer camera fixtures: ok")

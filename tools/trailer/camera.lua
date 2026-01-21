local Camera = require("core.camera")

local CineCam = {}

local function smoothstep(t)
    return t * t * (3 - 2 * t)
end

function CineCam.pan(opts)
    return {
        update = function(t)
            local t = math.min(1, t / opts.duration)
            local p = smoothstep(t)

            Camera.wx = opts.from.x + (opts.to.x - opts.from.x) * p
            Camera.wy = opts.from.y + (opts.to.y - opts.from.y) * p
            Camera.wscale = opts.from.zoom + (opts.to.zoom - opts.from.zoom) * p
        end
    }
end

return CineCam

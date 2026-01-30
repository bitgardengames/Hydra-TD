local Camera = require("tools.trailer.camera")
local Actions = require("tools.trailer.actions")

return {
    type = "logo",
    duration = 11,

	logo = {
		t = 0.0,
		dur = 12,
		fadeIn = 0.25,
		fadeOut = 0.0,
	},

    text = {
        {
            t = 2.8,
            text = "Wishlist on Steam",
            dur = 12,
            fadeIn = 0.35,
            fadeOut = 0.45,
			smallText = true,
        },
    },
}
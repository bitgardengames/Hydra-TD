local Camera = require("tools.trailer.camera")
local Actions = require("tools.trailer.actions")

return {
    type = "logo",
    duration = 9.0,

	logo = {
		t = 0.0,
		dur = 9.25,
		fadeIn = 0.25,
		fadeOut = 0.0,
	},

    text = {
        {
            t = 1.8,
            text = "Wishlist on Steam",
            dur = 9,
            fadeIn = 0.25,
            fadeOut = 0.25,
        },
    },
}

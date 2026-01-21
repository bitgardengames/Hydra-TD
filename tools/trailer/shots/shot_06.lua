local Camera = require("tools.trailer.camera")
local Actions = require("tools.trailer.actions")

return {
    type = "logo",
    duration = 10.0,

	logo = {
		t = 0.0,
		dur = 10.25,
		fadeIn = 0.25,
		fadeOut = 0.0,
	},

    text = {
        {
            t = 2.2,
            text = "Wishlist on Steam",
            dur = 10.25,
            fadeIn = 0.25,
            fadeOut = 0.25,
        },
    },
}

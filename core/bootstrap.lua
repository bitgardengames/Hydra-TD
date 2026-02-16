local Bootstrap = {}

function Bootstrap.initFull()
    local Save = require("core.save")
    local Difficulty = require("systems.difficulty")
    local Localization = require("core.localization")
    local Fonts = require("core.fonts")
    local Scale = require("core.scale")
    local Camera = require("core.camera")
    local Sound = require("systems.sound")

    Save.load()
    Difficulty.set(Save.data.settings.difficulty)
    Localization.load(Save.data.settings.language or "enUS")
    Fonts.load()
    Scale.update()
    Camera.load()
    Sound.load()
    Sound.playMusic("bg")

    require("ui.glyph_defs")
	
	--require("ui.glyphs").exportSheet("glyphs.png", {cols = 6})
end

function Bootstrap.initMinimal()
    require("core.fonts").load()
    require("core.scale").update()
    require("core.camera").load()
end

return Bootstrap
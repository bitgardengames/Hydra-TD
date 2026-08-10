-- Dependency-free graphics/layout fixtures. Run from the repository root.
package.path = "./?.lua;" .. package.path

love = {graphics = {getDimensions = function() return 1280, 720 end}}
local Scale = require("core.scale")

local cases = {
	{name = "smallest", w = 1280, h = 720, ui = 1.0},
	{name = "windowed_16_10", w = 1280, h = 800, ui = 1.0},
	{name = "full_hd", w = 1920, h = 1080, ui = 1.0},
	{name = "ultrawide", w = 3440, h = 1440, ui = 1.0},
	{name = "large_ui", w = 1280, h = 800, ui = 1.5},
}

for _, fixture in ipairs(cases) do
	assert(Scale.suggestMSAA(fixture.w, fixture.h) == 8, fixture.name .. " uses 8x MSAA")
	local usableH = fixture.h - 48
	local menuLineH = math.ceil(48 * fixture.ui)
	assert(usableH >= menuLineH * 6, fixture.name .. " cannot show six settings rows")
	local tooltipW = math.min(260 * fixture.ui, fixture.w - 12)
	assert(tooltipW > 0 and tooltipW <= fixture.w - 12, fixture.name .. " tooltip constraint")
end

local accessibility = {
	{reducedFlash = true, screenShakeIntensity = 0, showDamageNumbers = false, cameraMotion = false},
	{reducedFlash = true, screenShakeIntensity = 0, showDamageNumbers = false, highDensityParticles = false},
}
for _, fixture in ipairs(accessibility) do
	assert(fixture.reducedFlash and fixture.screenShakeIntensity == 0 and not fixture.showDamageNumbers)
end

print("graphics settings fixtures passed")

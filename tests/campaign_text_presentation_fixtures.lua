-- Dependency-free source checks for campaign screen text presentation.
local campaignFile = assert(io.open("ui/menu/screens/campaign.lua", "r"))
local campaignSource = campaignFile:read("*a")
campaignFile:close()

assert(not campaignSource:find("lg.print", 1, true),
	"campaign screen text must use the shadowed text helpers")
assert(campaignSource:find("Text.printShadow", 1, true),
	"campaign screen must render unaligned text with a shadow")
assert(campaignSource:find("Text.printfShadow", 1, true),
	"campaign screen must render aligned text with a shadow")
assert(campaignSource:find("lg.setColor(Theme.ui.text)\n\t\tText.printShadow(index", 1, true),
	"selected and unselected map names must use the same text color")
assert(not campaignSource:find('lg.rectangle("line", rowX, highlightY', 1, true),
	"map selection rows must not draw an animated outline")
assert(campaignSource:find("lg.setColor(Theme.ui.buttonHover)\n\tlg.circle(\"fill\", markerX", 1, true)
	and campaignSource:find("lg.setColor(selected and Theme.ui.buttonHover or Theme.ui.panel)", 1, true),
	"selected map indicators must use the highlighted UI button color")
assert(campaignSource:find("lg.setColor(active and Theme.ui.buttonHover or Theme.ui.panel)", 1, true),
	"selected difficulty buttons must use the highlighted UI button color")
assert(campaignSource:find("lg.setColor(DIFFICULTY_COLORS[key])", 1, true),
	"selected and unselected difficulty buttons must use the same text color")
assert(not campaignSource:find('lg.rectangle("line", cx, cardY, cardW, DIFFICULTY_CARD_H', 1, true),
	"selected difficulty buttons must not draw an outline highlight")
assert(campaignSource:find("local CAMPAIGN_CARD_MAX_W = 1168", 1, true)
	and campaignSource:find("local CAMPAIGN_CARD_MAX_H = 734", 1, true),
	"campaign card must use the tall reference layout")
assert(campaignSource:find("nativePreview(map.id, LIST_PREVIEW_W, LIST_PREVIEW_H)", 1, true)
	and campaignSource:find("lg.draw(entry.canvas, previewX, previewY)", 1, true),
	"campaign map list previews must render and draw at their native pixel size")
assert(campaignSource:find("nativePreview(map.id, w, maxPreviewH)", 1, true),
	"campaign selected-map previews must have a separate native-sized render target")
assert(campaignSource:find("local SPACE = 12", 1, true)
	and campaignSource:find("local PANEL_PAD = 28", 1, true)
	and campaignSource:find("local SECTION_INSET = 28", 1, true),
	"campaign columns must derive their geometry from shared spacing tokens")
assert(campaignSource:find("local LIST_ROW_STEP = LIST_ROW_H + SPACE", 1, true)
	and campaignSource:find("local cardW = (w - labelW - SPACE * 2) / 3", 1, true),
	"campaign lists and horizontal difficulty cards must use the shared gap")
assert(campaignSource:find("local LIST_ROW_H = 80", 1, true)
	and campaignSource:find("local DIFFICULTY_CARD_H = 52", 1, true),
	"campaign selection controls must use the reference heights")
assert(campaignSource:find("local listH = l.left.h - SECTION_INSET - LIST_HEADER_H - BUTTON_BOTTOM_GAP - BACK_BUTTON_H - SPACE", 1, true),
	"campaign map list must derive its height from the action geometry")
assert(campaignSource:find("local BUTTON_BOTTOM_GAP = 30", 1, true),
	"campaign actions must align to the shared panel padding")
assert(campaignSource:find("local BACK_BUTTON_H = 68", 1, true)
	and campaignSource:find("local PLAY_BUTTON_H = 108", 1, true)
	and campaignSource:find("local DIFFICULTY_PLAY_GAP = 26", 1, true),
	"campaign action geometry must use shared height tokens")
assert(campaignSource:find("local leftW = floor(contentW * 0.347)", 1, true)
	and campaignSource:find("local centerW = contentW - gap - leftW", 1, true),
	"campaign card must use a narrow map list and wide detail column")

local buttonFile = assert(io.open("ui/button.lua", "r"))
local buttonSource = buttonFile:read("*a")
buttonFile:close()

assert(buttonSource:find('btn.label:gsub("\\n", "")', 1, true),
	"button labels must account for every line when vertically centered")
assert(buttonSource:find("(h - labelHeight) * 0.5", 1, true),
	"button label blocks must be vertically centered")

local bootstrapFile = assert(io.open("core/bootstrap.lua", "r"))
local bootstrapSource = bootstrapFile:read("*a")
bootstrapFile:close()
assert(bootstrapSource:find("MapPreviewCache.buildAll(118, 66)", 1, true),
	"campaign list thumbnails must be warmed at their native resolution")

local cacheFile = assert(io.open("world/map_preview_cache.lua", "r"))
local cacheSource = cacheFile:read("*a")
cacheFile:close()
assert(cacheSource:find('local key = w .. "x" .. h', 1, true),
	"map previews must be cached separately for every native destination size")
assert(cacheSource:find('canvas:setFilter("nearest", "nearest")', 1, true),
	"map preview canvases must retain the game's pixel-art texture filtering")
assert(cacheSource:find("MapRender.renderFullMapToCanvas(canvas)", 1, true)
	and not cacheSource:find("MapRender.renderGameplayFramedToCanvas(canvas)", 1, true),
	"map previews must show every tile instead of inheriting the gameplay camera crop")

local renderFile = assert(io.open("world/map_render.lua", "r"))
local renderSource = renderFile:read("*a")
renderFile:close()
assert(renderSource:find("lg.scale(canvasW / MAP_W, canvasH / MAP_H)", 1, true),
	"full-map previews must scale the complete authored grid into their canvas")

print("campaign text presentation fixtures passed")

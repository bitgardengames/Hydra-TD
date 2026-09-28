local Localization = {}

local languages = {}
local current = nil
local fallback = nil

local select = select
local format = string.format

-- Load languages
function Localization.load(defaultLocale)
    local files = love.filesystem.getDirectoryItems("languages")

    for _, file in ipairs(files) do
        if file:match("%.lua$") then
            local locale = file:gsub("%.lua$", "")

            languages[locale] = require("languages." .. locale)
        end
    end

    fallback = languages.enUS
    Localization.set(defaultLocale or "enUS")
end

function Localization.set(locale)
    current = languages[locale] or fallback

    -- tell Fonts to switch
    if current.meta and current.meta.font then
        require("core.fonts").setLocale(current.meta.font)
    end
end

function Localization.get(key, ...)
	local node = current
	local fb = fallback

	for part in key:gmatch("[^%.]+") do
		node = node and node[part]
		fb = fb and fb[part]
	end

	if not node and not fb then
		print("Missing localization:", key)
		return key
	end

	local str = node or fb or key

	if select("#", ...) > 0 then
		local ok, out = pcall(format, str, ...)

		return ok and out or str
	end

	return str or key
end

-- Tower titles are kept here so every UI surface applies branch naming and
-- punctuation consistently, while older/localized tower names still fall back.
function Localization.towerTitle(tower)
	if not tower then return "" end
	local base = Localization.get(tower.def.nameKey)
	if tower.specialization then
		return Localization.get("inspect.specializedTowerTitle",
			Localization.get("branch." .. tower.specialization .. ".name"), base, tower.level or 1)
	end
	return Localization.get("inspect.towerTitle", base, tower.level or 1)
end

return setmetatable(Localization, {
	__call = function(_, ...)
		return Localization.get(...)
	end
})

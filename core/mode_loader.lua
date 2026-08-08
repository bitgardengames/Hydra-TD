local ModeLoader = {}

local exporters = {
	art = "tools.art_export",
	achievements = "tools.achievement_export",
	map = "tools.map_export.main",
	trailer = "tools.trailer.trailer_main",
	capsule = "tools.capsule_export"
}

function ModeLoader.run(mode)
	local moduleName = exporters[mode]
	if not moduleName then
		return false
	end

	return true, require(moduleName).run()
end

return ModeLoader

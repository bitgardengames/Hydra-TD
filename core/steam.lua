local ok, steam = pcall(require, "luasteam")

local Steam = {
	loaded = false
}

function Steam.load()
	if ok and steam then
		local init = steam.init()

		if init then
			Steam.loaded = true

			steam.friends.onGameOverlayActivated = function(data)
				if data.active then
					-- We can pause here
				end
			end

			steam.userStats.onUserStatsReceived = function(data)
				print("onUserStatsReceived:", data)
			end
		end
	end
end

function Steam.update()
	if Steam.loaded then
		steam.runCallbacks()
	end
end

function Steam.setRichPresence(text)
	if Steam.loaded and text then
		steam.friends.setRichPresence("status", text)
		steam.friends.setRichPresence("steam_display", "#Status")
	end
end

function Steam.unlockAchievement(id)
	if Steam.loaded and id then
		steam.userStats.setAchievement(id)
		steam.userStats.storeStats()
	end
end

function Steam.setStat(stat, value)
	if Steam.loaded and stat then
		steam.userStats.setStatInt(stat, value or 1)
		steam.userStats.storeStats()
	end
end

function Steam.storeStats()
	if Steam.loaded then
		steam.userStats.storeStats()
	end
end

function Steam.shutdown()
	if Steam.loaded then
		steam.shutdown()
	end
end

return Steam
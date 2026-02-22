local ok, steam = pcall(require, "luasteam")

local Steam = {
	loaded = false
}

function Steam.load()
	if ok and steam then
		if steam.init() then
			Steam.loaded = true

			steam.friends.setRichPresence("steam_display", "Booted")

			--[[print('dumping "steam" object:')
			for k, v in pairs(steam) do
				print(k, v)

				if type(v) == "table" then
					print('dumping ' .. k .. " object:")
					for k2, v2 in pairs(v) do
						print(k2, v2)

						if type(v2) == "table" then
							print('dumping ' .. k2 .. " object:")
							for k3, v3 in pairs(v2) do
								print(k3, v3)
							end
						end
					end
				end
			end]]
		end
	end

	-- steam.utils.isSteamRunningOnSteamDeck()
	-- steam.utils.isSteamInBigPictureMode()
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

return Steam
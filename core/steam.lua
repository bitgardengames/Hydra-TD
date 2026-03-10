local ok, steam = pcall(require, "luasteam")

local Steam = {
	loaded = false
}

--[[
	Current dump of what luasteam exposes

	===== STEAM MODULE DUMP =====
	steam.friends   table
	steam.friends.inviteUserToGame  function
	steam.friends.getFriendCount    function
	steam.friends.getFriendByIndex  function
	steam.friends.getFriendRichPresence     function
	steam.friends.setRichPresence   function
	steam.friends.activateGameOverlay       function
	steam.friends.activateGameOverlayToWebPage      function
	steam.friends.getFriendPersonaName      function
	steam.extra     table
	steam.extra.parseUint64 function
	steam.userStats table
	steam.userStats.getLeaderboardEntryCount        function
	steam.userStats.getLeaderboardName      function
	steam.userStats.getLeaderboardSortMethod        function
	steam.userStats.getLeaderboardDisplayType       function
	steam.userStats.uploadLeaderboardScore  function
	steam.userStats.setAchievement  function
	steam.userStats.storeStats      function
	steam.userStats.downloadLeaderboardEntries      function
	steam.userStats.setStatInt      function
	steam.userStats.getStatInt      function
	steam.userStats.getStatFloat    function
	steam.userStats.setStatFloat    function
	steam.userStats.getAchievement  function
	steam.userStats.resetAllStats   function
	steam.userStats.findLeaderboard function
	steam.userStats.findOrCreateLeaderboard function
	steam.apps      table
	steam.apps.getLaunchCommandLine function
	steam.apps.getCurrentGameLanguage       function
	steam.apps.isDlcInstalled       function
	steam.gameServer        table
	steam.gameServer.logOn  function
	steam.gameServer.logOnAnonymous function
	steam.gameServer.logOff function
	steam.gameServer.bLoggedOn      function
	steam.gameServer.bSecure        function
	steam.gameServer.setDedicatedServer     function
	steam.gameServer.init   function
	steam.gameServer.endAuthSession function
	steam.gameServer.shutdown       function
	steam.gameServer.mode   table
	steam.gameServer.mode.NoAuthentication  number
	steam.gameServer.mode.Authentication    number
	steam.gameServer.mode.AuthenticationAndSecure   number
	steam.gameServer.beginAuthSession       function
	steam.gameServer.runCallbacks   function
	steam.gameServer.getSteamID     function
	steam.init      function
	steam.user      table
	steam.user.getPlayerSteamLevel  function
	steam.user.getSteamID   function
	steam.user.getAuthSessionTicket function
	steam.user.cancelAuthTicket     function
	steam.shutdown  function
	steam.networkingUtils   table
	steam.networkingUtils.initRelayNetworkAccess    function
	steam.networkingUtils.getRelayNetworkStatus     function
	steam.networkingSockets table
	steam.networkingSockets.getIdentity     function
	steam.networkingSockets.createListenSocketIP    function
	steam.networkingSockets.createListenSocketP2P   function
	steam.networkingSockets.connectByIPAddress      function
	steam.networkingSockets.connectP2P      function
	steam.networkingSockets.acceptConnection        function
	steam.networkingSockets.closeConnection function
	steam.networkingSockets.closeListenSocket       function
	steam.networkingSockets.sendMessageToConnection function
	steam.networkingSockets.receiveMessagesOnConnection     function
	steam.networkingSockets.initAuthentication      function
	steam.networkingSockets.getAuthenticationStatus function
	steam.networkingSockets.getConnectionInfo       function
	steam.networkingSockets.createPollGroup function
	steam.networkingSockets.destroyPollGroup        function
	steam.networkingSockets.setConnectionPollGroup  function
	steam.networkingSockets.receiveMessagesOnPollGroup      function
	steam.networkingSockets.flushMessagesOnConnection       function
	steam.networkingSockets.sendMessages    function
	steam.networkingSockets.flags   table
	steam.networkingSockets.flags.Send_UnreliableNoNagle    number
	steam.networkingSockets.flags.Send_UnreliableNoDelay    number
	steam.networkingSockets.flags.Send_Reliable     number
	steam.networkingSockets.flags.Send_ReliableNoNagle      number
	steam.networkingSockets.flags.Send_Unreliable   number
	steam.input     table
	steam.input.activateActionSet   function
	steam.input.activateActionSetLayer      function
	steam.input.deactivateActionSetLayer    function
	steam.input.deactivateAllActionSetLayers        function
	steam.input.getActiveActionSetLayers    function
	steam.input.getActionSetHandle  function
	steam.input.getAnalogActionData function
	steam.input.getAnalogActionHandle       function
	steam.input.getAnalogActionOrigins      function
	steam.input.getConnectedControllers     function
	steam.input.getControllerForGamepadIndex        function
	steam.input.getCurrentActionSet function
	steam.input.getDigitalActionData        function
	steam.input.getDigitalActionHandle      function
	steam.input.getDigitalActionOrigins     function
	steam.input.getGamepadIndexForController        function
	steam.input.getGlyphForActionOrigin_Legacy      function
	steam.input.getInputTypeForHandle       function
	steam.input.getMotionData       function
	steam.input.getStringForActionOrigin    function
	steam.input.runFrame    function
	steam.input.setLEDColor function
	steam.input.showBindingPanel    function
	steam.input.stopAnalogActionMomentum    function
	steam.input.legacy_triggerHapticPulse   function
	steam.input.legacy_triggerRepeatedHapticPulse   function
	steam.input.triggerVibration    function
	steam.input.getActionOriginFromXboxOrigin       function
	steam.input.translateActionOrigin       function
	steam.input.getDeviceBindingRevision    function
	steam.input.getRemotePlaySessionID      function
	steam.input.init        function
	steam.input.shutdown    function
	steam.utils     table
	steam.utils.getEnteredGamepadTextLength function
	steam.utils.isSteamInBigPictureMode     function
	steam.utils.isSteamRunningOnSteamDeck   function
	steam.utils.showGamepadTextInput        function
	steam.utils.showFloatingGamepadTextInput        function
	steam.utils.getAppID    function
	steam.utils.getEnteredGamepadTextInput  function
	steam.runCallbacks      function
	steam.UGC       table
	steam.UGC.createItem    function
	steam.UGC.startItemUpdate       function
	steam.UGC.setItemContent        function
	steam.UGC.setItemDescription    function
	steam.UGC.setItemPreview        function
	steam.UGC.setItemTitle  function
	steam.UGC.submitItemUpdate      function
	steam.UGC.getNumSubscribedItems function
	steam.UGC.getSubscribedItems    function
	steam.UGC.getItemState  function
	steam.UGC.getItemInstallInfo    function
	steam.UGC.getItemUpdateProgress function
	steam.UGC.startPlaytimeTracking function
	steam.UGC.stopPlaytimeTracking  function
	steam.UGC.stopPlaytimeTrackingForAllItems       function
	steam.UGC.subscribeItem function
	steam.UGC.unsubscribeItem       function
	===== END STEAM MODULE =====
--]]

function Steam.debugDump()
	if not steam then
		print("Steam module not loaded")
		return
	end

	local function dump(tbl, prefix, depth)
		if depth > 3 then
			return
		end

		for k, v in pairs(tbl) do
			local key = tostring(k)
			local path = prefix and (prefix .. "." .. key) or key

			print(path, type(v))

			if type(v) == "table" then
				dump(v, path, depth + 1)
			end
		end
	end

	print("===== STEAM MODULE DUMP =====")
	dump(steam, "steam", 0)
	print("===== END STEAM MODULE =====")
end

function Steam.load()
	if ok and steam then
		local init = steam.init()

		if init then
			Steam.loaded = true

			Steam.debugDump()
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

function Steam.setOverlayHook(callback)
	if steam and steam.friends and callback then
		steam.friends.onGameOverlayActivated = function(data)
			if data.active then -- I could also just do callback(data.active) if that ever comes up
				callback()
			end
		end
	end
end

function Steam.openStorePage(appid)
	if Steam.loaded and steam and steam.friends then
		local url = "https://store.steampowered.com/app/" .. tostring(appid)
		steam.friends.activateGameOverlayToWebPage(url)
	end
end

function Steam.isSteamDeck()
	if Steam.loaded and steam.utils then
		return steam.utils.isSteamRunningOnSteamDeck()
	end
end

function Steam.shutdown()
	if Steam.loaded then
		steam.shutdown()
	end
end

return Steam
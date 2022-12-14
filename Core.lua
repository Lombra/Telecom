local Libra = LibStub("Libra")

local Telecom = Libra:NewAddon(...)
_G.Telecom = Telecom
Libra:EmbedWidgets(Telecom)

local function getPresenceByTag(battleTagQuery)
	if not battleTagQuery then return end
	for i = 1, BNGetNumFriends() do
		local accountInfo = C_BattleNet.GetFriendAccountInfo(i)
		if accountInfo and accountInfo.battleTag == battleTagQuery then
			return accountInfo.accountName, accountInfo.bnetAccountID
		end
	end
	-- print("Unable to resolve BattleTag", battleTagQuery)
end

local function copyDefaults(src, dst)
	if not src then return {} end
	if not dst then dst = {} end
	for k, v in pairs(src) do
		if type(v) == "table" then
			dst[k] = copyDefaults(v, dst[k])
		elseif type(v) ~= type(dst[k]) then
			dst[k] = v
		end
	end
	return dst
end

local defaults = {
	activeThreads = {},
	threads = {},
	
	width = 512,
	height = 256,
	point = "RIGHT",
	x = -128,
	y = 0,
	threadListWidth = 128,
	
	font = "Arial Narrow",
	fontSize = 12,
	
	sound = "TellMessage",
	
	threadListBNetFriends = true,
	threadListWoWFriends = true,
	threadListShowOffline = false,
	
	clearEditboxFocusOnSend = true,
	clearEditboxOnFocusLost = true,
	editboxTextPerThread = true,
	
	defaultHandlerWhileSuppressed = true,
	suppress = {
		combat = false,
		encounter = false,
		pvp = false,
		dnd = false,
	},
	closeThreadsOnLogout = false,
	
	autoCleanArchive = {
		BN_WHISPER = true,
		WHISPER = true,
	},
	archiveKeep = {
		BN_WHISPER = 7 * 24 * 3600,
		WHISPER = 0,
	},
	
	timestamps = true,
	timestampFormat = "%H:%M ",
	indentWrap = true,
	
	classColors = true,
	separateOutgoingColor = false,
	useDefaultColor = {
		BN_WHISPER = true,
		WHISPER = true,
	},
	color = {
		BN_WHISPER = {r = 0, g = 1.0, b = 246/255},
		BN_WHISPER_INFORM = {r = 0, g = 1.0, b = 246/255},
		WHISPER = {r = 1.0, g = 0.5, b = 1.0},
		WHISPER_INFORM = {r = 1.0, g = 0.5, b = 1.0},
	},
}

function Telecom:OnInitialize()
	if not TelecomDB and PMDB then
		TelecomDB = PMDB
	end

	TelecomDB = copyDefaults(defaults, TelecomDB)
	self.db = TelecomDB
	
	TelecomFrame:SetSize(self.db.width, self.db.height)
	TelecomFrame:ClearAllPoints()
	TelecomFrame:SetPoint(self.db.point, self.db.x, self.db.y)
	TelecomFrame:SetShown(self.db.shown)
	
	Telecom.threadListInset:SetWidth(self.db.threadListWidth)
	
	local activeThreads = self.db.activeThreads
	for i = #activeThreads, 1, -1 do
		local thread = activeThreads[i]
		if thread.type == "BN_WHISPER" and not thread.battleTag then
			tremove(activeThreads, i)
		end
	end
	
	local threads = self.db.threads
	for i = #threads, 1, -1 do
		local thread = threads[i]
		if thread.type == "BN_WHISPER" and not thread.battleTag then
			tremove(threads, i)
		end
	end
	
	self:UpdatePresences()
	
	self:CreateScrollButtons()
	self:UpdateThreads()
	
	self:UpdateSelection()
	self:LoadSettings()
	
	local LSM = LibStub("LibSharedMedia-3.0")
	if not LSM:IsValid("font", self.db.font) then
		LSM.RegisterCallback(self, "LibSharedMedia_Registered", function(event, mediaType, key)
			if key == Telecom.db.font then
				Telecom.chatLog:SetFont(LSM:Fetch("font", key), Telecom.db.fontSize)
				LSM.UnregisterCallback(self, event)
			end
		end)
	end
	
	-- print("BNIsSelf:", BNIsSelf(BNGetInfo()))
	
	self:RegisterEvent("PLAYER_ENTERING_WORLD")
	self:RegisterEvent("PLAYER_LOGOUT")
	self:RegisterEvent("UPDATE_CHAT_COLOR")
	self:RegisterEvent("FRIENDLIST_UPDATE")
	self:RegisterEvent("BN_FRIEND_LIST_SIZE_CHANGED")
	self:RegisterEvent("PLAYER_FLAGS_CHANGED")
	self:RegisterEvent("BN_FRIEND_INFO_CHANGED")
	self:RegisterEvent("BN_CONNECTED")
	-- self:RegisterEvent("BN_DISCONNECTED")
	-- self:RegisterEvent("BN_SELF_ONLINE")
	-- self:RegisterEvent("BN_SELF_OFFLINE")
	-- self:RegisterEvent("BN_FRIEND_ACCOUNT_ONLINE")
	-- self:RegisterEvent("BN_FRIEND_ACCOUNT_OFFLINE")
	self:RegisterEvent("CHAT_MSG_AFK")
	self:RegisterEvent("CHAT_MSG_DND")
	self:RegisterEvent("CHAT_MSG_SYSTEM")
	-- self:RegisterEvent("CHAT_MSG_BN_WHISPER_PLAYER_OFFLINE")
end

function Telecom:PLAYER_ENTERING_WORLD()
	self:CleanArchive()
	
	-- need to insert into UISpecialFrames after PLAYER_LOGIN as all special frames gets hidden at that point
	tinsert(UISpecialFrames, "TelecomFrame")
	if self.db.shown then
		Telecom:SelectThread(self.db.selectedTarget, self.db.selectedType)
	end
	self:UnregisterEvent("PLAYER_ENTERING_WORLD")
end

function Telecom:PLAYER_LOGOUT()
	local activeThreads = self.db.activeThreads
	if self.db.closeThreadsOnLogout then
		for i = #activeThreads, 1, -1 do
			local thread = activeThreads[i]
			self:CloseThread(thread.target, thread.type)
		end
	end
	self:CleanArchive()
end

function Telecom:GetFriendInfo(name)
	local friendInfo = C_FriendList.GetFriendInfo(name)
	if friendInfo then
		return true, friendInfo.connected, friendInfo.afk, friendInfo.dnd, friendInfo.level, friendInfo.className, friendInfo.area
	end
end

function Telecom:FRIENDLIST_UPDATE()
	if self:GetSelectedThread() then
		self:UpdateInfo()
	end
	self:UpdateThreads()
end

function Telecom:BN_FRIEND_LIST_SIZE_CHANGED()
	self:UpdatePresences()
	self:UpdateSelection()
end

function Telecom:PLAYER_FLAGS_CHANGED(unit)
	if self:GetSelectedThread() and (self:GetFullCharacterName(UnitName(unit)) == self:GetSelectedThread().target) then
		self:UpdateInfo()
	end
	-- self:UpdateThreads()
end

function Telecom:BN_FRIEND_INFO_CHANGED(index)
	if index and self:GetSelectedThread() and (C_BattleNet.GetFriendAccountInfo(index).bnetAccountID == self:GetSelectedThread().targetID) then
		self:UpdateInfo()
	end
	-- print("IsLoggingOut:", IsLoggingOut())
	self:UpdateThreads()
end

function Telecom:BN_CONNECTED(...)
	-- presence IDs will have changed once Battle.net connection is reestablished
	self:UpdatePresences()
	self:UpdateSelection()
end

function Telecom:BN_DISCONNECTED(...)
	-- print("BN_DISCONNECTED", ...)
end

function Telecom:BN_SELF_ONLINE(...)
	-- print("BN_SELF_ONLINE", ...)
	-- self:UpdatePresences()
end

function Telecom:BN_SELF_OFFLINE(...)
	-- print("BN_SELF_OFFLINE", ...)
end

function Telecom:BN_FRIEND_ACCOUNT_ONLINE(bnetIDAccount)
	local thread = self:GetThread(select(2, BNGetFriendInfoByID(bnetIDAccount)), "BN_WHISPER", true)
	if thread then
		self:SaveMessage(thread, nil, "%s has come online.")
	end
end

function Telecom:BN_FRIEND_ACCOUNT_OFFLINE(bnetIDAccount)
	if not BNConnected() then return end
	local thread = self:GetThread(select(2, BNGetFriendInfoByID(bnetIDAccount)), "BN_WHISPER", true)
	if thread then
		self:SaveMessage(thread, nil, "%s has gone offline.")
	end
end

function Telecom:BN_TOON_NAME_UPDATED(id, toonName, dunno)
end

function Telecom:CHAT_MSG_BN_WHISPER_PLAYER_OFFLINE(message, sender, language, channelString, target, flags, _, _, channelName, _, _, guid, bnetIDAccount)
	local thread = self:GetThread(sender, "BN_WHISPER", true)
	if thread then
		self:SaveMessage(sender, "BN_WHISPER", nil, message)
	end
end

function Telecom:UpdatePresences()
	for i, thread in ipairs(self.db.activeThreads) do
		if thread.type == "BN_WHISPER" then
			thread.target, thread.targetID = getPresenceByTag(thread.battleTag)
		end
	end
	for i, thread in ipairs(self.db.threads) do
		if thread.type == "BN_WHISPER" then
			thread.target, thread.targetID = getPresenceByTag(thread.battleTag)
		end
	end
	local lastTell = self.db.lastTell
	local lastTold = self.db.lastTold
	if self.db.lastTellType == "BN_WHISPER" then
		lastTell = getPresenceByTag(lastTell)
	end
	if self.db.lastToldType == "BN_WHISPER" then
		lastTold = getPresenceByTag(lastTold)
	end
	if lastTell then ChatEdit_SetLastTellTarget(lastTell, self.db.lastTellType) end
	if lastTold then ChatEdit_SetLastToldTarget(lastTold, self.db.lastToldType) end
end

function Telecom:UpdateSelection()
	if self.db.selectedType == "BN_WHISPER" then
		local selectedTarget = getPresenceByTag(self.db.selectedBattleTag)
		self.db.selectedTarget = selectedTarget
		if selectedTarget and self.db.shown then
			Telecom:SelectThread(selectedTarget, self.db.selectedType)
		end
	end
end

function Telecom:CleanArchive()
	local now = time()
	local threads = self.db.threads
	for i = #threads, 1, -1 do
		local thread = threads[i]
		local messages = thread.messages
		if self.db.autoCleanArchive[thread.type] then
			local threshold = self.db.archiveKeep[thread.type]
			for i = #messages, 1, -1 do
				local message = messages[i]
				if not message.active and (now - message.timestamp) > threshold then
					tremove(messages, i)
				end
			end
			if #messages == 0 and not self:IsThreadActive(thread.target, thread.type) then
				-- self:CloseThread(thread.target, thread.type)
				self:DeleteThread(thread.target, thread.type)
			end
		end
	end
end

function Telecom:GetThread(target, chatType)
	for i, thread in ipairs(self.db.threads) do
		if thread.target == target and thread.type == chatType then
			return thread
		end
	end
end

function Telecom:CreateThread(target, chatType, isGM)
	local thread = {
		target = target,
		type = chatType,
		isGM = isGM,
		messages = {},
	}
	if chatType == "BN_WHISPER" then
		thread.battleTag = self:GetBattleTag(target)
	end
	if not self:GetThread(target, chatType) then
		tinsert(self.db.threads, thread)
	end
	self:ActivateThread(target, chatType)
	return thread
end

function Telecom:DeleteThread(target, chatType)
	for i, thread in ipairs(self.db.threads) do
		if thread.target == target and thread.type == chatType then
			tremove(self.db.threads, i)
			break
		end
	end
end

function Telecom:IsThreadActive(target, chatType)
	for i, thread in ipairs(self.db.activeThreads) do
		if thread.target == target and thread.type == chatType then
			return true
		end
	end
end

function Telecom:ActivateThread(target, chatType)
	if chatType == "WHISPER" and not target:match("%-") then
		target = gsub(strlower(target), ".", strupper, 1).."-"..gsub(GetRealmName(), " ", "")
	end
	if not self:GetThread(target, chatType) then return end
	local thread = {
		target = target,
		type = chatType,
	}
	if chatType == "BN_WHISPER" then
		thread.battleTag = self:GetBattleTag(target)
	end
	tinsert(self.db.activeThreads, thread)
	self:UpdateThreads()
	return thread
end

function Telecom:CloseThread(target, chatType)
	local activeThreads = self.db.activeThreads
	for i, thread in ipairs(activeThreads) do
		if thread.target == target and thread.type == chatType then
			local lastTold, lastToldType = ChatEdit_GetLastToldTarget()
			if lastTold == target and lastToldType == chatType then
				ChatEdit_SetLastToldTarget(nil, nil)
			end
			tremove(activeThreads, i)
			thread = self:GetThread(target, chatType)
			if #activeThreads == 0 then
				TelecomFrame:Hide()
				self.selectedThread = nil
			elseif thread == self:GetSelectedThread() then
				local thread = activeThreads[i] or activeThreads[i - 1]
				self:SelectThread(thread.target, thread.type)
			end
			-- remove informational messages, such as system messages
			for i = #thread.messages, 1, -1 do
				local message = thread.messages[i]
				if not message.messageType then
					tremove(thread.messages, i)
				end
			end
			-- if this thread type is set to instantly delete, then do that here, or if no messages were sent
			if #thread.messages == 0 or (self.db.autoCleanArchive[chatType] and self.db.archiveKeep[chatType] == 0) then
				self:DeleteThread(target, chatType)
			else
				-- these messages are no longer part of the active thread session
				for i = #thread.messages, 1, -1 do
					local message = thread.messages[i]
					if not message.active then break end
					message.active = nil
					message.unread = nil
				end
			end
			self:UpdateThreads()
			break
		end
	end
end

function Telecom:GetSelectedThread()
	return self.selectedThread
end

function Telecom:GetBattleTag(accountName)
	local bnetIDAccount = BNet_GetBNetIDAccount(accountName)
	if bnetIDAccount then
		local accountInfo = C_BattleNet.GetAccountInfoByID(bnetIDAccount)
		return accountInfo.battleTag
	end
end

function Telecom:GetFullCharacterName(name)
	if not name:match("%-") then
		name = name.."-"..gsub(GetRealmName(), " ", "")
	end
	return name
end

function Telecom:GetDateStamp(timestamp)
	local text
	local currentTime = date("*t", time())
	if (currentTime.yday == timestamp.yday and currentTime.year == timestamp.year) then
		text = HONOR_TODAY
	else
		text = CALENDAR_FULLDATE_MONTH_NAMES[timestamp.month].." "..timestamp.day
	end
	return "- "..text
end

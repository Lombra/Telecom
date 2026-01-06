local addonName, Telecom = ...
local LSM = LibStub("LibSharedMedia-3.0")


hooksecurefunc("ChatEdit_SetLastTellTarget", function(target, chatType)
	if chatType == "BN_WHISPER" then
		target = Telecom:GetBattleTag(target)
	end
	if target then
		Telecom.db.lastTell, Telecom.db.lastTellType = target, chatType
	end
end)

hooksecurefunc("ChatEdit_SetLastToldTarget", function(target, chatType)
	if chatType == "BN_WHISPER" then
		target = Telecom:GetBattleTag(target)
	end
	if target then
		Telecom.db.lastTold, Telecom.db.lastToldType = target, chatType
	end
end)


local function openChat(target, chatType)
	if chatType == "WHISPER" then
		target = Telecom:GetFullCharacterName(target)
	end
	if not Telecom:IsThreadActive(target, chatType) then
		Telecom:CreateThread(target, chatType)
	end
	Telecom:SelectThread(target, chatType)
	Telecom:Show()
	Telecom.editbox:SetFocus()
end

local hooks = {
	ReplyTell = function(chatFrame)
		local lastTell, lastTellType = ChatFrameUtil.GetLastTellTarget()
		if lastTell then
			Telecom.editbox.setText = true
			openChat(lastTell, lastTellType)
		end
	end,
	ReplyTell2 = function(chatFrame)
		local lastTold, lastToldType = ChatFrameUtil.GetLastToldTarget()
		if lastTold then
			Telecom.editbox.setText = true
			openChat(lastTold, lastToldType)
		end
	end,
	SendTell = function(name)
		openChat(name, "WHISPER")
	end,
	SendBNetTell = function(name)
		openChat(name, "BN_WHISPER")
	end,
}

for functionName, hook in pairs(hooks) do
	local originalFunction = ChatFrameUtil[functionName]
	ChatFrameUtil[functionName] = function(...)
		if Telecom:ShouldSuppress() then
			originalFunction(...)
			return
		end
		
		hook(...)
	end
end


local function messageEventFilter(event, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9, arg10, arg11, arg12, arg13, arg14)
	local shouldDiscardMessage, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9, arg10, arg11, arg12, arg13, arg14 =
		ChatFrameUtil.ProcessMessageEventFilters(TelecomFrame, event, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9, arg10, arg11, arg12, arg13, arg14)
	if shouldDiscardMessage then
				return true
	end
	return false, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9, arg10, arg11, arg12, arg13, arg14
end


local chatEvents = {
	CHAT_MSG_WHISPER = "in",
	CHAT_MSG_WHISPER_INFORM = "out",
	CHAT_MSG_BN_WHISPER = "in",
	CHAT_MSG_BN_WHISPER_INFORM = "out",
}

local f = CreateFrame("Frame")
f:SetScript("OnEvent", function(self, event, ...)
	Telecom:HandleChatEvent(event, ...)
end)

local function filter(frame)
	return frame ~= TelecomFrame and not (Telecom:ShouldSuppress() and Telecom.db.defaultHandlerWhileSuppressed)
end

ChatFrameUtil.AddMessageEventFilter("CHAT_MSG_AFK", filter)
ChatFrameUtil.AddMessageEventFilter("CHAT_MSG_DND", filter)

for event in pairs(chatEvents) do
	ChatFrameUtil.AddMessageEventFilter(event, filter)
	f:RegisterEvent(event)
end

function Telecom:HandleChatEvent(event, ...)
	local filter, message, sender, language, channelString, target, flags, _, _, channelName, _, _, guid, bnetIDAccount = messageEventFilter(event, ...)
	if filter then
		return
	end
	local isGM = (flags == "GM")
	local chatType = Chat_GetChatCategory(event:sub(10))
	if chatType == "WHISPER" and not isGM then
			sender = self:GetFullCharacterName(sender)
	end
	if not self:IsThreadActive(sender, chatType) then
		self:CreateThread(sender, chatType, isGM or nil)
	end
	local thread = self:GetThread(sender, chatType)
	if chatType == "WHISPER" then
		thread.targetID = guid
	end
	if chatType == "BN_WHISPER" then
		thread.targetID = bnetIDAccount
	end
	local shouldSuppress = self:ShouldSuppress()
	local messageType = chatEvents[event]
	if messageType == "in" and not (TelecomFrame:IsShown() and thread == self:GetSelectedThread()) then
		-- incoming message whose thread is not currently shown, flag thread as unread
		thread.unread = true
		self:UpdateThreadList()
	end
	self:SaveMessage(sender, chatType, messageType, message)
	if shouldSuppress then
		return
	end
	-- if the target of the currently selected thread is not the sender of this PM, then select their thread
	if self:GetSelectedThread() ~= thread and not self.editbox:HasFocus() then
		self:SelectThread(sender, chatType)
	end
	self:Show()
	if messageType == "in" then
		ChatEdit_SetLastTellTarget(sender, chatType)
		PlaySoundFile(LSM:Fetch("sound", self.db.sound), "MASTER")
		-- PlaySoundFile([[Interface\AddOns\Telecom\Whisper.ogg]], "MASTER")
		FlashClientIcon()
	end
end

function Telecom:CHAT_MSG_AFK(...)
	local filter, message, sender = messageEventFilter("CHAT_MSG_AFK", ...)
	if filter then
		return
	end
	sender = self:GetFullCharacterName(sender)
	-- if thread then
		self:SaveMessage(sender, "WHISPER", nil, CHAT_AFK_GET..message)
	-- end
end

function Telecom:CHAT_MSG_DND(...)
	local filter, message, sender = messageEventFilter("CHAT_MSG_DND", ...)
	if filter then
		return
	end
	sender = self:GetFullCharacterName(sender)
	if self:IsThreadActive(sender, "WHISPER") then
		self:SaveMessage(sender, "WHISPER", nil, CHAT_DND_GET..message)
	end
end

-- local ERR_CHAT_PLAYER_NOT_FOUND_S = "No player named '%s' is currently playing."
local ERR_CHAT_PLAYER_NOT_FOUND_S = gsub(ERR_CHAT_PLAYER_NOT_FOUND_S, "%.", "%."):format("(.+)")

function Telecom:CHAT_MSG_SYSTEM(...)
	local filter, message = messageEventFilter("CHAT_MSG_SYSTEM", ...)
	if filter then
		return
	end
	local sender = strmatch(message, ERR_CHAT_PLAYER_NOT_FOUND_S)
	if not sender then return end
	if not sender:match("%-") then
		sender = gsub(strlower(sender), ".", strupper, 1).."-"..gsub(GetRealmName(), " ", "")
	end
	if self:IsThreadActive(sender, "WHISPER") then
		self:SaveMessage(sender, "WHISPER", nil, _G.ERR_CHAT_PLAYER_NOT_FOUND_S)
	end
end

local suppress = {
	combat = function() return UnitAffectingCombat("player") end,
	encounter = IsEncounterInProgress,
	pvp = function()
		local isInstance, instanceType = IsInInstance()
		if instanceType ~= "pvp" and instanceType ~= "arena" then return end
		for i = 1, 40 do
			local spellID = select(11, UnitBuff("player", i))
			if spellID == 44521 or spellID == 32727 then
				return
			end
		end
		return true
	end,
	dnd = IsChatDND,
}

-- this function deterrmines whether chat messages should be sent to the addon or the default chat frame (true for send to chat frame)
function Telecom:ShouldSuppress()
	if TelecomFrame:IsShown() then
		-- always send to addon if it's already shown
		return false
	end
	for k, v in pairs(suppress) do
		if self.db.suppress[k] and v() then
			return true
		end
	end
end

function Telecom:SaveMessage(target, chatType, messageType, messageText)
	local thread = self:GetThread(target, chatType)
	local message = {
		messageType = messageType,
		text = messageText,
		timestamp = time(),
		-- from = sender,
		active = true,
		unread = true,
	}
	if (TelecomFrame:IsShown() or not self:ShouldSuppress()) and (self:GetSelectedThread() == thread or not self.editbox:HasFocus()) then
		message.unread = nil
	end
	tinsert(thread.messages, message)
	if thread == self:GetSelectedThread() then
		local message2 = thread.messages[#thread.messages - 1]
		local currentTime = date("*t", message.timestamp)
		local time2 = message2 and date("*t", message2.timestamp)
		if message2 and (time2.yday ~= currentTime.yday or time2.year ~= currentTime.year) then
			self.chatLog:AddMessage(self:GetDateStamp(time2), 0.8, 0.8, 0.8)
			self.chatLog:AddMessage(" ")
			self.chatLog:AddMessage(self:GetDateStamp(currentTime), 0.8, 0.8, 0.8)
		end
		
		self:PrintMessage(thread, message)
	end
end

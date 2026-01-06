local addonName, Telecom = ...


local playerFactionGroup = UnitFactionGroup("player")

local reverseclassnames = {}
for k,v in pairs(LOCALIZED_CLASS_NAMES_MALE) do reverseclassnames[v] = k end
for k,v in pairs(LOCALIZED_CLASS_NAMES_FEMALE) do reverseclassnames[v] = k end

local threadListItems = {}

local frameStructure = {
	name = "TelecomFrame",
	inherits = "BasicFrameTemplate",
	toplevel = true,
	enableMouse = true,
	movable = true,
	dontSavePosition = true,
	
	scripts = {
		OnDragStart = "StartMoving",
		OnDragStop = function(self)
			self:StopMovingOrSizing()
			Telecom.db.point, Telecom.db.x, Telecom.db.y = select(3, self:GetPoint())
		end,
		OnShow = function(self)
			Telecom:GetSelectedThread().unread = nil
			Telecom:UpdateThreadList()
			Telecom.db.shown = true
		end,
		OnHide = function(self)
			self:StopMovingOrSizing()
			Telecom.db.point, Telecom.db.x, Telecom.db.y = select(3, self:GetPoint())
			Telecom.db.shown = nil
		end,
	}
}

local frame = Telecom:CreateFrame("Frame", UIParent, frameStructure)
frame.TitleText:SetText("Telecom")
frame:RegisterForDrag("LeftButton")


local insetLeft = CreateFrame("Frame", nil, frame, "InsetFrameTemplate")
insetLeft:SetPoint("TOPLEFT", PANEL_INSET_LEFT_OFFSET, PANEL_INSET_TOP_OFFSET)
insetLeft:SetPoint("BOTTOM", 0, PANEL_INSET_BOTTOM_OFFSET + 2)
insetLeft.Bg:SetDrawLayer("BACKGROUND", 1)
Telecom.threadListInset = insetLeft


local function createScrollButton(listFrame)
	local button = CreateFrame("Button", nil, insetLeft)
	button:SetHeight(10)
	button:SetPoint("LEFT")
	button:SetPoint("RIGHT")
	button:SetScript("OnClick", scroll)
	button:SetScript("OnEnter", onEnter)
	button:SetScript("OnLeave", onLeave)
	button:SetScript("OnMouseDown", onMouseDown)
	button:SetScript("OnMouseUp", onMouseUp)
	button:SetScript("OnHide", onHide)
	local t = insetLeft:CreateTexture(nil, "BACKGROUND", nil, 2)
	t:SetAllPoints(button)
	t:SetTexture([[Interface\Buttons\UI-Listbox-Highlight2]])
	t:SetVertexColor(0.6, 0.75, 1.0, 0.5)
	-- t:SetVertexColor(1.7, 1.7, 1.7, 0.5)
	-- t:SetTexCoord(0, 1, 0, 14/16)
	button.texture = button:CreateTexture()
	button.texture:SetSize(16, 16)
	button.texture:SetPoint("CENTER")
	button.texture:SetTexture([[Interface\Calendar\MoreArrow]])
	-- button.texture:SetVertexColor(0.5, 0.5, 0.5)
	return button
end

local scrollUp = createScrollButton()
scrollUp:SetPoint("TOP", 0, -2)
scrollUp.delta = 1
scrollUp.texture:SetTexCoord(0, 1, 1, 0)
scrollUp.texture:SetPoint("BOTTOM")

local t = insetLeft:CreateTexture()
t:SetPoint("BOTTOMLEFT", scrollUp, 3, -2)
t:SetPoint("RIGHT", -3, 0)
t:SetHeight(1)
t:SetTexture(0.5, 0.5, 0.5)

local scrollDown = createScrollButton()
scrollDown:SetPoint("BOTTOM", 0, 2)
scrollDown.delta = -1
scrollDown.texture:SetPoint("TOP")

local t = insetLeft:CreateTexture()
t:SetPoint("TOPLEFT", scrollDown, 3, 2)
t:SetPoint("RIGHT", -3, 0)
t:SetHeight(1)
t:SetTexture(0.5, 0.5, 0.5)

local function onClick(self)
	local target, type = self.target, self.type
	if not Telecom:IsThreadActive(target, type) then
		Telecom:CreateThread(target, type)
	end
	Telecom:SelectThread(target, type)
end

local function onEnter(self)
	if Telecom:IsThreadActive(self.target, self.type) then
		self.close:Show()
		self.icon:Hide()
		self.flash:Stop()
		self.text:SetPoint("RIGHT", self.icon, "LEFT", -2, 0)
	end
end

local function onLeave(self)
	if Telecom:IsThreadActive(self.target, self.type) and not self.close:IsMouseMotionFocus() then
		self.close:Hide()
		local thread = Telecom:GetThread(self.target, self.type)
		if not self.selected then
			self:UnlockHighlight()
			if thread.unread then
				self.flash:Play()
			end
		end
		if self.type == "BN_WHISPER" then
			self.icon:Show()
		else
			self.text:SetPoint("RIGHT", -2, 0)
		end
	end
end

local closeScripts = {
	OnEnter = function(self)
		self:SetAlpha(1.0)
		self.parent:LockHighlight()
	end,
	OnLeave = function(self)
		self:SetAlpha(0.5)
		if not self.parent:IsMouseMotionFocus() then
			onLeave(self.parent)
		end
	end,
	OnClick = function(self)
		Telecom:CloseThread(self.parent.target, self.parent.type)
	end,
	OnMouseDown = function(self)
		self.texture:SetPoint("CENTER", 1, -1)
	end,
	OnMouseUp = function(self)
		self.texture:SetPoint("CENTER", 0, 0)
	end,
}

local function setButtonStatus(button, showStatus, isOnline, isAFK, isDND)
	button.status:SetShown(showStatus)
	button.shadow:SetShown(showStatus)
	if showStatus then
		if not isOnline then
			button.status:SetVertexColor(0.2, 0.2, 0.2)
		elseif isAFK then
			button.status:SetVertexColor(1, 0.5, 0)
		elseif isDND then
			button.status:SetVertexColor(1, 0, 0)
		else
			button.status:SetVertexColor(0, 1, 0)
		end
	end
end

local scrollFrame = Telecom:CreateScrollFrame("Hybrid", insetLeft)
Telecom.scroll = scrollFrame
local separator = scrollFrame.scrollChild:CreateTexture()
separator:SetTexture([[Interface\FriendsFrame\UI-FriendsFrame-OnlineDivider]])
separator:SetTexCoord(0, 1, 3/16, 0.75)
scrollFrame:SetPoint("TOPRIGHT", scrollUp, "BOTTOMRIGHT", -4, -2)
scrollFrame:SetPoint("BOTTOMLEFT", scrollDown, "TOPLEFT", 4, 4)
scrollFrame:SetButtonHeight(16)
scrollFrame:SetHeaderHeight(9)
scrollFrame.getNumItems = function()
	return #threadListItems
end
scrollFrame.onScroll = function(self)
	self.scrollBar:Hide()
	if not self.separatorShown then
		separator:Hide()
	end
	scrollFrame.separatorShown = nil
	scrollDown.texture:SetDesaturated(self.range <= 0)
end
scrollFrame.updateButton = function(button, index)
	local object = threadListItems[index]
	
	button:SetEnabled(not object.separator)
	button.text:SetPoint("RIGHT", -2, 0)
	
	if object.separator then
		button:SetHeader()
		button.text:SetText(nil)
		button.close:Hide()
		button.icon:Hide()
		button.flash:Stop()
		setButtonStatus(button, false)
		separator:SetAllPoints(button)
		separator:Show()
		scrollFrame.separatorShown = true
		return
	end
	
	button:ResetHeight()
	
	local thread = Telecom:GetThread(object.target, object.type)
	
	local selectedThread = Telecom:GetSelectedThread()
	if selectedThread and thread == selectedThread then
		button:LockHighlight()
		button.selected = true
	else
		button:UnlockHighlight()
		button.selected = nil
	end
	
	if Telecom:IsThreadActive(object.target, object.type) then
		if (thread.unread and thread ~= selectedThread) and not (button:IsMouseOver() or button.close:IsMouseOver()) then
			if not button.flash:IsPlaying() then
				button.flash:Play()
			end
		elseif button.flash:IsPlaying() then
			button.flash:Stop()
		end
	else
		button.close:Hide()
	end
	
	if object.type == "WHISPER" then
		local name = Ambiguate(object.target, "none")
		local isFriend, connected, isAFK, isDND = Telecom:GetFriendInfo(name)
		button.text:SetText(name)
		button.icon:Hide()
		setButtonStatus(button, isFriend, connected, isAFK, isDND)
	end
	
	if object.type == "BN_WHISPER" then
		local bnetIDAccount = object.target and GetAutoCompletePresenceID(object.target)
		if bnetIDAccount then
			local accountInfo = C_BattleNet.GetAccountInfoByID(bnetIDAccount)
			button.text:SetText(object.target or UNKNOWN)
			button.icon:Show()
			button.icon:SetTexture(BNet_GetBattlenetClientAtlas(accountInfo.gameAccountInfo.clientProgram))
			button.text:SetPoint("RIGHT", button.icon, "LEFT", -2, 0)
			local isAFK = accountInfo.isAFK or accountInfo.gameAccountInfo.isGameAFK
			local isDND = accountInfo.isDND or accountInfo.gameAccountInfo.isGameBusy
			setButtonStatus(button, true, accountInfo.gameAccountInfo.isOnline, isAFK, isDND)
		else
			button.text:SetText(UNKNOWN)
			setButtonStatus(button, false)
		end
	end
	
	button.target = object.target
	button.type = object.type
	if button:IsMouseMotionFocus() then
		if Telecom:IsThreadActive(object.target, object.type) then
			button.icon:Hide()
			button.text:SetPoint("RIGHT", button.icon, "LEFT", -2, 0)
		end
	end
end
scrollFrame.createButton = function(parent)
	local button = CreateFrame("Button", nil, parent)
	button:SetPoint("RIGHT")
	button:SetScript("OnClick", onClick)
	button:SetScript("OnEnter", onEnter)
	button:SetScript("OnLeave", onLeave)
	
	button:SetHighlightTexture([[Interface\Buttons\UI-Listbox-Highlight2]])
	button:GetHighlightTexture():SetVertexColor(0.196, 0.388, 0.8)
	
	button.shadow = button:CreateTexture(nil, "BACKGROUND")
	button.shadow:SetSize(16, 16)
	button.shadow:SetPoint("LEFT")
	button.shadow:SetTexture([[Interface\AddOns\Telecom\StatusBackground]])
	button.shadow:SetBlendMode("MOD")
	
	button.status = button:CreateTexture()
	button.status:SetSize(16, 16)
	button.status:SetPoint("LEFT")
	button.status:SetTexture([[Interface\AddOns\Telecom\Status]])
	
	button.text = button:CreateFontString(nil, nil, "GameFontHighlightSmall")
	button.text:SetPoint("LEFT", button.status, "RIGHT")
	button.text:SetJustifyH("LEFT")
	button.text:SetWordWrap(false)
	
	button.icon = button:CreateTexture()
	button.icon:SetSize(16, 16)
	button.icon:SetPoint("RIGHT", -2, 0)
	
	button.close = CreateFrame("Button", nil, button)
	button.close:SetSize(16, 16)
	button.close:SetPoint("RIGHT", -2, 0)
	button.close:SetAlpha(0.5)
	button.close:Hide()
	button.close.parent = button
	
	button.close.texture = button.close:CreateTexture()
	button.close.texture:SetSize(16, 16)
	button.close.texture:SetPoint("CENTER")
	button.close.texture:SetTexture([[Interface\FriendsFrame\ClearBroadcastIcon]])
	
	for script, handler in pairs(closeScripts) do
		button.close:SetScript(script, handler)
	end
	
	local flash = button:CreateTexture()
	flash:SetAllPoints()
	flash:SetTexture([[Interface\Buttons\UI-Listbox-Highlight2]])
	flash:SetVertexColor(0.196, 0.388, 0.8)
	flash:SetBlendMode("ADD")
	flash:SetAlpha(0)
	
	button.flash = flash:CreateAnimationGroup()
	button.flash:SetLooping("BOUNCE")
	
	local fade = button.flash:CreateAnimation("Alpha")
	fade:SetFromAlpha(0)
	fade:SetToAlpha(1)
	fade:SetDuration(0.8)
	fade:SetSmoothing("OUT")
	
	return button
end

scrollFrame.scrollBar:HookScript("OnValueChanged", function(self, value)
	local min, max = self:GetMinMaxValues()
	scrollUp.texture:SetDesaturated(value == min)
	scrollDown.texture:SetDesaturated(value == max)
	-- scrollUp:SetShown(value > min)
	-- scrollDown:SetShown(value < max)
	-- print(self.offset, self.range)
end)

scrollFrame:SetScript("OnMouseWheel", function(self, delta, stepSize)
	local minVal, maxVal = 0, self.range
	stepSize = stepSize or self.stepSize or self.buttonHeight
	if delta == 1 then
		self.scrollBar:SetValue(max(minVal, self.scrollBar:GetValue() - stepSize))
	else
		self.scrollBar:SetValue(min(maxVal, self.scrollBar:GetValue() + stepSize))
	end
end)


local function addTooltipAccountInfo(gameAccountInfo)
	local client = gameAccountInfo.clientProgram
	if client == BNET_CLIENT_WOW then
		local class = gameAccountInfo.className
		local color = (CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS)[reverseclassnames[class]]
		GameTooltip:AddLine(client)
		GameTooltip:AddLine(gameAccountInfo.characterName, color.r, color.g, color.b)
		GameTooltip:AddLine(format(TOOLTIP_UNIT_LEVEL_RACE, gameAccountInfo.characterLevel, gameAccountInfo.raceName))
		GameTooltip:AddLine(class)
		GameTooltip:AddLine(gameAccountInfo.realmDisplayName)
		GameTooltip:AddLine(gameAccountInfo.factionName)
		GameTooltip:AddLine(gameAccountInfo.areaName)
	elseif client ~= BNET_CLIENT_APP then
		GameTooltip:AddLine(client)
		GameTooltip:AddLine(gameAccountInfo.characterName)
		GameTooltip:AddLine(gameAccountInfo.richPresence)
	end
end

local infoPanel = CreateFrame("Frame", nil, frame)
infoPanel:SetPoint("LEFT", insetLeft, "RIGHT", PANEL_INSET_LEFT_OFFSET, 0)
infoPanel:SetPoint("TOPRIGHT", PANEL_INSET_RIGHT_OFFSET, PANEL_INSET_TOP_OFFSET)
infoPanel:SetHeight(32)
infoPanel:EnableMouse(true)
infoPanel:SetScript("OnEnter", function(self)
	local thread = Telecom:GetSelectedThread()
	
	if thread.type ~= "BN_WHISPER" then return end
	
	local accountInfo = C_BattleNet.GetAccountInfoByID(thread.targetID)
	local gameAccountInfo = accountInfo.gameAccountInfo
	
	if not gameAccountInfo.isOnline then return end
	
	GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
	GameTooltip:AddLine(accountInfo.accountName, HIGHLIGHT_FONT_COLOR.r, HIGHLIGHT_FONT_COLOR.g, HIGHLIGHT_FONT_COLOR.b)
	-- GameTooltip:AddLine(accountInfo.battleTag)
	GameTooltip:AddLine(accountInfo.customMessage, BATTLENET_FONT_COLOR.r, BATTLENET_FONT_COLOR.g, BATTLENET_FONT_COLOR.b, true)
	GameTooltip:AddLine(accountInfo.note)
	
	GameTooltip:AddLine(" ")
	addTooltipAccountInfo(gameAccountInfo)
	
	local friendIndex = BNGetFriendIndex(thread.targetID)
	for accountIndex = 1, C_BattleNet.GetFriendNumGameAccounts(friendIndex) do
		local gameAccountInfo = C_BattleNet.GetFriendGameAccountInfo(friendIndex, accountIndex)
		local client = gameAccountInfo.clientProgram
		if not gameAccountInfo.hasFocus and client ~= BNET_CLIENT_APP and client ~= BNET_CLIENT_CLNT and client ~= "BSAp" then
			GameTooltip:AddLine(" ")
			addTooltipAccountInfo(gameAccountInfo)
		end
	end
	
	GameTooltip:Show()
end)
infoPanel:SetScript("OnLeave", GameTooltip_Hide)

infoPanel.icon = infoPanel:CreateTexture()
infoPanel.icon:SetSize(24, 24)
infoPanel.icon:SetPoint("LEFT", 4, 0)

infoPanel.target = infoPanel:CreateFontString(nil, nil, "GameFontHighlightLarge")
infoPanel.target:SetPoint("TOPLEFT", infoPanel.icon, "TOPRIGHT", 8, 1)

infoPanel.toon = infoPanel:CreateFontString(nil, nil, "GameFontHighlightSmall")
infoPanel.toon:SetPoint("BOTTOMLEFT", infoPanel.icon, "BOTTOMRIGHT", 8, -1)

local function invite(self, target)
	InviteUnit(Ambiguate(target, "none"))
end

local function inviteBNet(self, target)
	BNInviteFriend(target)
end

-- local urlFormat = "http://%s.battle.net/wow/%s/character/%s/%s/advanced"

-- local REGION = strlower(GetCVar("portal"))
-- GetLocale()

-- local function bnetProfile(self, target, chatType)
	-- local name, realm = strsplit("-", target)
	-- local url = format(urlFormat, REGION, "en", realm:gsub("(%l)(%U)", "%1-%2"):gsub(), name)
	-- StaticPopup_Show("SHOW_URL", url:match("^%l+://([^/]+)"):gsub("^www%.", ""), nil, url)
-- end

local function ignore(self, target)
	AddOrDelIgnore(Ambiguate(target, "none"))
end

local function viewFriends(self, target)
	FriendsFriendsFrame_Show(BNet_GetBNetIDAccount(target))
end

local function openArchive(self, target, chatType)
	Telecom:SelectArchive(target, chatType)
end

local menuButton = CreateFrame("Button", nil, infoPanel)
menuButton:SetNormalTexture([[Interface\ChatFrame\UI-ChatIcon-ScrollDown-Up]])
menuButton:SetPushedTexture([[Interface\ChatFrame\UI-ChatIcon-ScrollDown-Down]])
menuButton:SetDisabledTexture([[Interface\ChatFrame\UI-ChatIcon-ScrollDown-Disabled]])
menuButton:SetHighlightTexture([[Interface\Buttons\UI-Common-MouseHilight]])
menuButton:SetSize(32, 32)
menuButton:SetPoint("RIGHT")
menuButton:SetScript("OnClick", function(self)
	self.menu:Toggle(Telecom:GetSelectedThread())
end)

menuButton.menu = Telecom:CreateDropdown("Menu")
menuButton.menu.relativeTo = menuButton
menuButton.menu.initialize = function(self, level)
	if level == 1 then
		local thread = UIDROPDOWNMENU_MENU_VALUE
		
		local info = UIDropDownMenu_CreateInfo()
		info.text = INVITE
		info.value = thread.target
		if thread.type == "WHISPER" then
			info.func = invite
			info.arg1 = thread.target
		else
			-- if more than 1 invitable toon, then make a submenu here, otherwise invite directly
			local index = BNGetFriendIndex(thread.targetID)
			local numGameAccounts = C_BattleNet.GetFriendNumGameAccounts(index)
			if numGameAccounts > 1 then
				local numValidToons = 0
				local lastToonID
				for i = 1, numGameAccounts do
					local gameAccountInfo = C_BattleNet.GetFriendGameAccountInfo(index, i)
					if gameAccountInfo.clientProgram == BNET_CLIENT_WOW and gameAccountInfo.factionName == playerFactionGroup and gameAccountInfo.realmID ~= 0 then
						numValidToons = numValidToons + 1
						lastToonID = gameAccountInfo.gameAccountID
					end
				end
				if numValidToons > 1 then
					info.hasArrow = true
				elseif numValidToons == 1 then
					info.func = inviteBNet
					info.arg1 = lastToonID
				else
					info.disabled = true
				end
			else
				local gameAccountInfo = C_BattleNet.GetGameAccountInfoByID(thread.targetID)
				if gameAccountInfo.clientProgram == BNET_CLIENT_WOW and gameAccountInfo.factionName == playerFactionGroup and gameAccountInfo.realmID ~= 0 then
					info.func = inviteBNet
					info.arg1 = gameAccountInfo.gameAccountID
				else
					info.disabled = true
				end
			end
		end
		info.notCheckable = true
		self:AddButton(info, level)
		
		if thread.type == "WHISPER" then
			local info = UIDropDownMenu_CreateInfo()
			info.text = IGNORE
			info.func = ignore
			info.arg1 = thread.target
			info.arg2 = thread.type
			info.notCheckable = true
			self:AddButton(info, level)
		end
		
		if thread.type == "BN_WHISPER" then
			local info = UIDropDownMenu_CreateInfo()
			info.text = VIEW_FRIENDS_OF_FRIENDS
			info.func = viewFriends
			info.arg1 = thread.target
			info.arg2 = thread.type
			info.notCheckable = true
			self:AddButton(info, level)
		end
		
		local target = thread.target
		if thread.type == "BN_WHISPER" then
			local accountInfo = C_BattleNet.GetAccountInfoByID(thread.targetID)
			if accountInfo.gameAccountInfo.clientProgram == BNET_CLIENT_WOW then
				target = accountInfo.gameAccountInfo.characterName
			end
		end
		local info = UIDropDownMenu_CreateInfo()
		info.text = TARGET
		info.attributes = {
			["type"] = "macro",
			["macrotext"] = "/targetexact "..Ambiguate(target, "none"),
		}
		info.disabled = InCombatLockdown()
		info.notCheckable = true
		self:AddButton(info, level)
		
		local info = UIDropDownMenu_CreateInfo()
		info.text = "View archive"
		info.func = openArchive
		info.arg1 = thread.target
		info.arg2 = thread.type
		info.disabled = (#thread.messages == 0)
		info.notCheckable = true
		self:AddButton(info, level)
		
		-- if thread.type == "WHISPER" then
			-- local info = UIDropDownMenu_CreateInfo()
			-- info.text = "Battle.net profile"
			-- info.func = bnetProfile
			-- info.arg1 = thread.target
			-- info.notCheckable = true
			-- self:AddButton(info, level)
		-- end
	end
	if level == 2 then
		-- LE_PARTY_CATEGORY_HOME
		-- list all invitable toons
		local index = BNGetFriendIndex(BNet_GetBNetIDAccount(UIDROPDOWNMENU_MENU_VALUE))
		for i = 1, C_BattleNet.GetFriendNumGameAccounts(index) do
			local gameAccountInfo = C_BattleNet.GetFriendGameAccountInfo(index, i)
			if gameAccountInfo.clientProgram == BNET_CLIENT_WOW and gameAccountInfo.factionName == playerFactionGroup and gameAccountInfo.realmID ~= 0 then
				local info = UIDropDownMenu_CreateInfo()
				info.text = gameAccountInfo.characterName
				info.func = inviteBNet
				info.arg1 = bnetIDGameAccount
				info.notCheckable = true
				self:AddButton(info, level)
			end
		end
	end
end


local MAX_MESSAGE_LENGTH = 255

local function zero(text)
	return text:gsub(".", 0)
end

-- super delicate message splitting logic
local function splitMessage(message)
	local maskedMessage = message
	
	local nextStart = 1
	
	repeat
		local linkStart, linkEnd, pipes = string.find(maskedMessage, "(|+)cff......|H", nextStart)
		
		-- if the number of pipes is odd, then the last one is not escaped
		if linkStart and (#pipes % 2 == 1) then
			-- valid start of link found at message[linkStart]
			-- search from this position onwards to find the pieces to complete the link
			local nextSearchPos = linkStart
			local found
			while true do
				local s, e, pipes = string.find(maskedMessage, "(|+)h", nextSearchPos)
				if not s then
					-- no more link pieces (valid or no) were found, break
					nextStart = linkEnd + 1
					break
				end
				if (#pipes % 2 == 1) then
					if found then
						-- final link piece found, link is complete
						maskedMessage = maskedMessage:sub(1, nextStart - 1)..maskedMessage:sub(nextStart, linkStart + #pipes - 2):gsub("%S+", zero):gsub("%S ", "1 "):gsub("%S$", "1")..string.rep("0", e + 2 - linkStart + #pipes - 1).."1"..maskedMessage:sub(e + 2 + 1)
						nextStart = e + 2 + 1
						break
					end
					-- next valid link piece found, search from this position onwards to find the last one
					found = true
				end
				nextSearchPos = e
			end
		elseif linkEnd then
			maskedMessage = maskedMessage:sub(1, nextStart - 1)..maskedMessage:sub(nextStart, linkStart - 1):gsub("%S+", zero):gsub("%S ", "1 "):gsub("%S$", "1")..maskedMessage:sub(linkStart, linkEnd):gsub("%S+", zero):gsub("%S ", "1 ")..maskedMessage:sub(linkEnd + 1)
			nextStart = linkEnd + 1
		end
	until not linkStart
	
	maskedMessage = maskedMessage:sub(1, nextStart - 1)..maskedMessage:sub(nextStart):gsub("%S+", zero):gsub("%S ", "1 "):gsub("%S$", "1")
	
	local messagePieces = {}
	
	local lastStart = 1
	local lastStop = 0
	local nextStart = 0
	
	repeat
		local wordEnd = string.find(maskedMessage, "1", nextStart)
		if wordEnd - lastStart + 1 > MAX_MESSAGE_LENGTH then
			-- including this word will make the string too long, print piece up until previous word, and start a new piece starting from this word
			tinsert(messagePieces, string.sub(message, lastStart, lastStop))
			lastStart = maskedMessage:find("0*1", lastStop + 1)
		end
		lastStop = wordEnd
		nextStart = maskedMessage:find("0*1", wordEnd + 1)
	until not nextStart
	
	-- the remaining text fits into one message
	-- so send the previous piece..
	tinsert(messagePieces, string.sub(message, lastStart, lastStop))
	-- ..and the remainder
	if nextStart then
		tinsert(messagePieces, message:sub(nextStart))
	end
	
	return messagePieces
end

local editbox = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
Telecom.editbox = editbox
editbox:SetHeight(20)
editbox:SetPoint("LEFT", insetLeft, "RIGHT", 9, 0)
editbox:SetPoint("BOTTOMRIGHT", -6, 5)
editbox:SetFontObject("ChatFontSmall")
editbox:SetAutoFocus(false)
editbox:SetScript("OnEnterPressed", function(self)
	local type = self:GetAttribute("chatType")
	local text = self:GetText()
	if string.find(text, "%s*[^%s]+") then
		-- translate group tags into non localised tags
		text = SubstituteChatMessageBeforeSend(text)
		if type == "WHISPER" then
			local target = self:GetAttribute("tellTarget")
			ChatEdit_SetLastToldTarget(target, type)
			if #text > MAX_MESSAGE_LENGTH then
				for i, message in ipairs(splitMessage(text)) do
					SendChatMessage(message, type, self.languageID, target)
				end
			else
				SendChatMessage(text, type, self.languageID, target)
			end
		elseif type == "BN_WHISPER" then
			local target = self:GetAttribute("tellTarget")
			local bnetIDAccount = BNet_GetBNetIDAccount(target)
			if bnetIDAccount then
				ChatEdit_SetLastToldTarget(target, type)
				if #text > MAX_MESSAGE_LENGTH then
					for i, message in ipairs(splitMessage(text)) do
						BNSendWhisper(bnetIDAccount, message)
					end
				else
					BNSendWhisper(bnetIDAccount, text)
				end
			else
				local info = ChatTypeInfo["SYSTEM"]
				self.chatFrame:AddMessage(format(BN_UNABLE_TO_RESOLVE_NAME, target), info.r, info.g, info.b)
			end
		-- elseif type == "BN_CONVERSATION" then
			-- local target = tonumber(editbox:GetAttribute("channelTarget"))
			-- BNSendConversationMessage(target, text);
		end
		if addHistory then
			self:AddHistoryLine(text)
		end
	end
	self:SetText("")
	Telecom:GetSelectedThread().editboxText = nil
	if Telecom.db.clearEditboxFocusOnSend then
		self:ClearFocus()
	end
end)
editbox:SetScript("OnEscapePressed", editbox.ClearFocus)
editbox:SetScript("OnTabPressed", function(self)
	-- local nextTell, nextTellType = ChatEdit_GetNextTellTarget(self:GetAttribute("tellTarget"), self:GetAttribute("chatType"))
	-- Telecom:SelectThread(nextTell, nextTellType)
	for i, thread in ipairs(Telecom.db.activeThreads) do
		if thread.target == self:GetAttribute("tellTarget") and thread.type == self:GetAttribute("chatType") then
			if IsShiftKeyDown() then i = i - 2 end
			local nextThread = Telecom.db.activeThreads[i % #Telecom.db.activeThreads + 1]
			Telecom:SelectThread(nextThread.target, nextThread.type)
			break
		end
	end
end)
editbox:SetScript("OnEditFocusGained", function(self)
	ACTIVE_CHAT_EDIT_BOX = self
	frame:Raise()
end)
editbox:SetScript("OnEditFocusLost", function(self)
	ACTIVE_CHAT_EDIT_BOX = nil
	if Telecom.db.clearEditboxOnFocusLost then
		self:SetText("")
		Telecom:GetSelectedThread().editboxText = nil
	end
end)
editbox:SetScript("OnTextChanged", function(self, isUserInput)
	if isUserInput and Telecom.db.editboxTextPerThread then
		Telecom:GetSelectedThread().editboxText = self:GetText()
	end
end)
editbox:SetScript("OnUpdate", function(self)
	if self.setText then
		self:SetText(Telecom:GetSelectedThread().editboxText or "")
		self.setText = nil
	end
end)


local chatLogInset = CreateFrame("Frame", nil, frame, "InsetFrameTemplate")
chatLogInset:SetPoint("TOP", infoPanel, "BOTTOM", 0, 0)
chatLogInset:SetPoint("RIGHT", PANEL_INSET_RIGHT_OFFSET, 0)
chatLogInset:SetPoint("LEFT", insetLeft, "RIGHT", PANEL_INSET_LEFT_OFFSET, 0)
chatLogInset:SetPoint("BOTTOM", editbox, "TOP", 0, 4)
chatLogInset.Bg:SetDrawLayer("BACKGROUND", 1)
Telecom.chatlogInset = chatLogInset

local linkTypes = {
	achievement = true,
	enchant = true,
	glyph = true,
	instancelock = true,
	item = true,
	quest = true,
	spell = true,
	talent = true,
}


local chatLog = CreateFrame("ScrollingMessageFrame", nil, chatLogInset)
Telecom.chatLog = chatLog
chatLog:SetPoint("TOPRIGHT", -6, -6)
chatLog:SetPoint("BOTTOMLEFT", 6, 5)
chatLog:SetMaxLines(256)
chatLog:SetJustifyH("LEFT")
chatLog:SetFading(false)
chatLog:SetIndentedWordWrap(true)
-- chatLog:SetToplevel(true)
chatLog:SetHyperlinksEnabled(true)
chatLog:SetScript("OnHyperlinkClick", function(self, link, text, button)
	SetItemRef(link, text, button, self)
end)
chatLog:SetScript("OnHyperlinkEnter", function(self, link)
	if linkTypes[link:match("^([^:]+)")] then
		ShowUIPanel(GameTooltip)
		GameTooltip:SetOwner(UIParent, "ANCHOR_CURSOR")
		GameTooltip:SetHyperlink(link)
		GameTooltip:Show()
	end
end)
chatLog:SetScript("OnHyperlinkLeave", GameTooltip_Hide)
chatLog:SetScript("OnMouseWheel", function(self, delta)
	if delta > 0 then
		if IsShiftKeyDown() then
			self:PageUp()
		else
			self:ScrollUp()
		end
	else
		if IsShiftKeyDown() then
			self:PageDown()
		else
			self:ScrollDown()
		end
	end
end)


chatLog:SetOnScrollChangedCallback(function(self)
	local atBottom = self:AtBottom()
	self.scrollToBottom:SetShown(not atBottom)
	-- if processing then return end
	local thread = Telecom:GetSelectedThread()
	if atBottom then
		thread.scroll = nil
	else
		thread.scroll = self:GetNumMessages() - self:GetScrollOffset()
	end
end)


local scrollToBottom = CreateFrame("Button", nil, frame)
scrollToBottom:SetNormalTexture([[Interface\ChatFrame\UI-ChatIcon-ScrollEnd-Up]])
scrollToBottom:SetPushedTexture([[Interface\ChatFrame\UI-ChatIcon-ScrollEnd-Down]])
scrollToBottom:SetDisabledTexture([[Interface\ChatFrame\UI-ChatIcon-ScrollEnd-Disabled]])
scrollToBottom:SetHighlightTexture([[Interface\Buttons\UI-Common-MouseHilight]])
scrollToBottom:SetSize(32, 32)
scrollToBottom:SetPoint("BOTTOMRIGHT", chatLogInset)
scrollToBottom:Hide()
scrollToBottom:SetScript("OnClick", function(self, button)
	chatLog:ScrollToBottom()
	-- self:Hide()
end)
scrollToBottom:SetScript("OnHide", function(self)
	self.flash:Stop()
end)
chatLog.scrollToBottom = scrollToBottom

scrollToBottom.flash = scrollToBottom:CreateTexture(nil, "OVERLAY")
scrollToBottom.flash:SetAllPoints()
scrollToBottom.flash:SetTexture([[Interface\ChatFrame\UI-ChatIcon-BlinkHilight]])
scrollToBottom.flash:SetAlpha(0)

local flash = scrollToBottom.flash:CreateAnimationGroup()
flash:SetLooping("BOUNCE")
scrollToBottom.flash = flash

local fade = flash:CreateAnimation("Alpha")
fade:SetFromAlpha(0)
fade:SetToAlpha(1)
fade:SetDuration(0.8)
fade:SetSmoothing("OUT")


-- WHISPER
-- WHISPER_INFORM
-- AFK
-- DND
-- BN_WHISPER
-- BN_WHISPER_INFORM

function Telecom:UpdateColorByID(chatType, r, g, b)
	local function TransformColorByID(text, messageR, messageG, messageB, messageChatTypeID, messageAccessID, lineID)
		if messageChatTypeID == chatType then
			return true, r, g, b
		end
		return false
	end
	chatLog:AdjustMessageColors(TransformColorByID)
end

function Telecom:UPDATE_CHAT_COLOR(chatType, r, g, b)
	if not self.db.useDefaultColor[chatType] then return end
	self:UpdateColorByID(GetChatTypeIndex(chatType), r, g, b)
	self:UpdateColorByID(GetChatTypeIndex(chatType.."_INFORM"), r, g, b)
end

function Telecom:UpdateChatColor(chatType, r, g, b)
	local color = self.db.useDefaultColor[chatType] and ChatTypeInfo[chatType] or self.db.color[chatType]
	self:UpdateColorByID(GetChatTypeIndex(chatType), color.r, color.g, color.b)
	if not self.db.useDefaultColor[chatType] and self.db.separateOutgoingColor then
		color = self.db.color[chatType.."_INFORM"]
	end
	self:UpdateColorByID(GetChatTypeIndex(chatType.."_INFORM"), color.r, color.g, color.b)
end

function Telecom:Show()
	frame:Show()
end

function Telecom:UpdateThreadList()
	scrollFrame:update()
end

function Telecom:CreateScrollButtons()
	scrollFrame:CreateButtons()
end

local function insert(target, chatType)
	if not Telecom:IsThreadActive(target, chatType) then
		tinsert(threadListItems, {
			target = target,
			type = chatType,
		})
	end
end

local function addBNetFriend(index)
	local accountInfo = C_BattleNet.GetFriendAccountInfo(index)
	if accountInfo then
		insert(accountInfo.accountName, "BN_WHISPER")
	end
end

local function addWoWFriend(index)
	local friendInfo = C_FriendList.GetFriendInfoByIndex(index)
	if not friendInfo then return end
	local name = friendInfo.name
	if not name:match("%-") then
		name = name.."-"..gsub(GetRealmName(), " ", "")
	end
	insert(name, "WHISPER")
end

function Telecom:UpdateThreads()
	wipe(threadListItems)
	
	for i, thread in ipairs(self.db.activeThreads) do
		tinsert(threadListItems, thread)
	end
	
	local numBNetTotal, numBNetOnline, numBNetFavorite, numBNetFavoriteOnline = BNGetNumFriends()
	local numWoWTotal = C_FriendList.GetNumFriends()
	local numWoWOnline = C_FriendList.GetNumOnlineFriends() or 0
	
	if self.db.threadListBNetFriends then
		for i = 1, numBNetFavoriteOnline do
			addBNetFriend(i)
		end
		for i = numBNetFavorite + 1, numBNetOnline + (numBNetFavorite - numBNetFavoriteOnline) do
			addBNetFriend(i)
		end
	end
	
	if self.db.threadListWoWFriends then
		for i = 1, numWoWOnline do
			addWoWFriend(i)
		end
	end
	
	if self.db.threadListShowOffline then
		if self.db.threadListBNetFriends then
			for i = numBNetFavoriteOnline + 1, numBNetFavorite do
				addBNetFriend(i)
			end
			for i = numBNetOnline + (numBNetFavorite - numBNetFavoriteOnline) + 1, numBNetTotal do
				addBNetFriend(i)
			end
		end
		
		if self.db.threadListWoWFriends then
			for i = numWoWOnline + 1, numWoWTotal do
				addWoWFriend(i)
			end
		end
	end
	
	local numActiveThreads = #Telecom.db.activeThreads
	
	if (numActiveThreads > 0) and (#threadListItems > numActiveThreads) then
		-- insert the separator item between the active threads and the "friends list"
		tinsert(threadListItems, numActiveThreads + 1, {separator = true})
		scrollFrame:ExpandButton(numActiveThreads)
	else
		scrollFrame:CollapseButton()
	end
	self:UpdateThreadList()
end

local function printMessage(thread, messageIndex, addToTop)
	local message1 = thread.messages[messageIndex]
	local message2 = thread.messages[messageIndex + 1]
	if not addToTop then
		Telecom:PrintMessage(thread, message1, addToTop)
	end
	local time1 = date("*t", message1.timestamp)
	local time2 = message2 and date("*t", message2.timestamp)
	if message2 and (time2.yday ~= time1.yday or time2.year ~= time1.year) then
		if addToTop then
			-- printing at top needs to be done in reverse order
			message1, message2 = message2, message1
			time1, time2 = time2, time1
		end
		if addToTop then
			chatLog:BackFillMessage(Telecom:GetDateStamp(time1), 0.8, 0.8, 0.8)
			chatLog:BackFillMessage(" ")
			chatLog:BackFillMessage(Telecom:GetDateStamp(time2), 0.8, 0.8, 0.8)
		else
			chatLog:AddMessage(Telecom:GetDateStamp(time1), 0.8, 0.8, 0.8)
			chatLog:AddMessage(" ")
			chatLog:AddMessage(Telecom:GetDateStamp(time2), 0.8, 0.8, 0.8)
		end
	elseif not message1.active and (not message2 or message2.active) then
		if addToTop then
			chatLog:BackFillMessage(" ")
		else
			chatLog:AddMessage(" ")
		end
	end
	if addToTop then
		Telecom:PrintMessage(thread, message1, addToTop)
	end
end

local MAX_INSTANT_MESSAGES = 64

local function printThrottler(self, elapsed)
	for i = 1, MAX_INSTANT_MESSAGES do
		printMessage(self.currentThread, self.messageThrottleIndex, true)
		self.messageThrottleIndex = self.messageThrottleIndex - 1
		if self.messageThrottleIndex == 0 then
			self:RemoveOnUpdate()
			break
		end
	end
end

function Telecom:SelectThread(target, chatType)
	local thread = self:GetThread(target, chatType)
	if thread == self:GetSelectedThread() then return end
	self.selectedThread = thread
	self.db.selectedTarget = target
	self.db.selectedType = chatType
	if chatType == "BN_WHISPER" then
		self.db.selectedBattleTag = thread.battleTag
	else
		self.db.selectedBattleTag = nil
	end
	editbox:SetAttribute("chatType", chatType)
	editbox:SetAttribute("tellTarget", target)
	self:RefreshThread(thread)
	if Telecom.db.editboxTextPerThread then
		editbox:SetText(thread.editboxText or "")
	end
	menuButton.menu:Close()
	scrollToBottom:Hide()
	-- scrollToBottom.flash:Stop()
	self:UpdateInfo()
	self:UpdateThreadList()
	if frame:IsShown() then
		thread.unread = nil
	end
end

function Telecom:RefreshThread(thread)
	if not thread then return end
	chatLog:Clear()
	local numMessages = #thread.messages
	-- printing too many messages at once causes a noticable screen freeze, so we apply throttling at a certain amount of messages
	if numMessages > MAX_INSTANT_MESSAGES then
		for i = numMessages - MAX_INSTANT_MESSAGES + 1, numMessages do
			printMessage(thread, i)
		end
		self.currentThread = thread
		self.messageThrottleIndex = numMessages - MAX_INSTANT_MESSAGES
		self:SetOnUpdate(printThrottler)
	else
		for i = 1, #thread.messages do
			printMessage(thread, i)
		end
		self:RemoveOnUpdate()
	end
end

local darken = 0.2

local lastMessageType

function Telecom:PrintMessage(thread, message, addToTop)
	local messageType, messageText, timestamp, isActive, isUnread = message.messageType, message.text, message.timestamp, message.active, message.unread
	local chatType = thread.type
	local color = self.db.useDefaultColor[chatType] and ChatTypeInfo[chatType] or self.db.color[chatType]
	local r, g, b = color.r, color.g, color.b
	if not isActive then
		r, g, b = 0.9, 0.9, 0.9
		if messageType == "out" then
			r, g, b = r - darken, g - darken, b - darken
		end
	end
	if messageType then
		-- if messageType ~= lastMessageType then
			local sender
			if messageType == "out" then
				sender = "You"
				chatType = chatType.."_INFORM"
			else
				sender = thread.target or UNKNOWN
				if thread.type == "WHISPER" then
					sender = Ambiguate(sender, "none")
					if thread.targetID and self.db.classColors then
						local localizedClass, englishClass, localizedRace, englishRace = GetPlayerInfoByGUID(thread.targetID)
						local color = englishClass and (CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS)[englishClass]
						if color then
							sender = format("|c%s%s|r", color.colorStr, sender)
						end
					end
				end
				sender = "|cff56a3ff"..sender.."|r"
			end
			messageText = "|cffffffff"..sender.."|r: "..messageText
		-- end
	else
		local color = ChatTypeInfo["SYSTEM"]
		r, g, b = color.r, color.g, color.b
		messageText = format(messageText, Ambiguate(thread.target, "none"))
	end
	if self.db.timestamps then
		if isUnread and thread.unread then
			messageText = format("|cffff8040%s|r", date(self.db.timestampFormat, timestamp))..messageText
			-- messageText = format("|cffff6000%s|r", date(self.db.timestampFormat, timestamp))..messageText
		else
			messageText = format("|cffd0d0d0%s|r", date(self.db.timestampFormat, timestamp))..messageText
		end
	end
	message.unread = nil
	-- lastMessageType = messageType
	if addToTop then
		chatLog:BackFillMessage(messageText, r, g, b, isActive and GetChatTypeIndex(chatType), accessID, extraData)
	else
		chatLog:AddMessage(messageText, r, g, b, isActive and GetChatTypeIndex(chatType), accessID, extraData)
	end
	if not addToTop and not chatLog:AtBottom() and not scrollToBottom.flash:IsPlaying() then
		scrollToBottom.flash:Play()
	end
end


function Telecom:UpdateInfo()
	local selectedThread = self:GetSelectedThread()
	local name, info
	infoPanel.icon:SetTexture(nil)
	infoPanel.icon:SetHeight(24)
	if selectedThread.type == "BN_WHISPER" then
		if not selectedThread.target then
			name = UNKNOWN
		else
			local bnetIDAccount = BNet_GetBNetIDAccount(selectedThread.target)
			if not selectedThread.targetID then
				selectedThread.targetID = bnetIDAccount
			end
			if bnetIDAccount then
				local accountInfo = C_BattleNet.GetAccountInfoByID(bnetIDAccount)
				local gameAccountInfo = accountInfo.gameAccountInfo
				local characterName = gameAccountInfo and gameAccountInfo.characterName
				local client = gameAccountInfo and gameAccountInfo.clientProgram
				
				infoPanel.icon:SetTexCoord(0, 1, 0, 1)
				name = accountInfo.accountName or UNKNOWN
				if not gameAccountInfo.isOnline then
					name = name.." |cff808080("..FRIENDS_LIST_OFFLINE..")"
					info = "|cff808080"..format(BNET_LAST_ONLINE_TIME, FriendsFrame_GetLastOnline(accountInfo.lastOnlineTime))
				elseif accountInfo.isAFK or gameAccountInfo.isGameAFK then
					name = name.." |cffff8000"..CHAT_FLAG_AFK
				elseif accountInfo.isDND or gameAccountInfo.isGameBusy then
					name = name.." |cffff0000"..CHAT_FLAG_DND
				end
				if characterName then
					info = characterName or ""
					if client == BNET_CLIENT_WOW then
						local areaName = gameAccountInfo.areaName
						if areaName and areaName ~= "" then
							info = info.." - "..areaName
						end
					else
						info = gameAccountInfo.richPresence
					end
				end
				C_Texture.SetTitleIconTexture(infoPanel.icon, client, Enum.TitleIconVersion.Medium)
			end
		end
	else
		-- try various means of getting information about the target
		local target = Ambiguate(selectedThread.target, "none")
		name = target
		-- friend list
		local isFriend, connected, isAFK, isDND, level, class, area = self:GetFriendInfo(target)
		if isFriend and connected and level and level > 0 then
			info = format("Level %d %s - %s", level, class, area)
			infoPanel.icon:SetAtlas(GetClassAtlas(reverseclassnames[class]))
		end
		-- Unit* API, in case they're in the group
		local level = UnitLevel(target)
		if level > 0 then
			info = format("Level %d %s", level, UnitClass(target))
			if UnitIsAFK(target) then
				name = name.." |cffff8000"..CHAT_FLAG_AFK
			elseif UnitIsDND(target) then
				name = name.." |cffff0000"..CHAT_FLAG_DND
			elseif not UnitIsConnected(target) then
				name = name.." |cff808080("..FRIENDS_LIST_OFFLINE..")"
			end
		end
		-- or GUID from chat event
		if not info and selectedThread.targetID then
			local localizedClass, englishClass, localizedRace, englishRace = GetPlayerInfoByGUID(selectedThread.targetID)
			if englishClass then
				infoPanel.icon:SetAtlas(GetClassAtlas(englishClass))
				info = localizedClass
			end
		elseif selectedThread.isGM then
			infoPanel.icon:SetHeight(12)
			infoPanel.icon:SetTexCoord(0, 1, 0, 1)
			infoPanel.icon:SetTexture([[Interface\ChatFrame\UI-ChatIcon-Blizz]])
		end
	end
	infoPanel.target:SetText(name or Ambiguate(selectedThread.target, "none"))
	infoPanel.toon:SetText(info)
end
